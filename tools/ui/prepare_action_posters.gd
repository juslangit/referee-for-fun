extends SceneTree

## Turns the six OpenArt action posters into the sport tile pictures. Run headless:
##   godot --headless --path . --script res://tools/ui/prepare_action_posters.gd
##
## Luqman played the game on 2026-09-16 and asked for a poster per sport showing the
## player actually doing the thing — smashing, spiking, bicycle-kicking — instead of the
## standing portraits that were there before. Each was drawn on its own (Nano Banana Pro,
## image2image, with dev/ref/ui-redesign/sheet_portraits.png as the style reference), so
## unlike the old sheet there is nothing to cut apart. What there is to do is make six
## separately-drawn figures sit on the tile as one set.
##
## The old portraits were all the same shot — head-on, standing, cropped at the thighs —
## so they could be aligned by the top of the head. Action poses cannot: a tennis serve is
## tall and narrow, a table tennis loop is wide and low, and a takraw bicycle kick is
## upside down with the head at the BOTTOM. Aligning those by the head would throw them
## all over the tile.
##
## So each figure is instead found, measured and fitted: its bounding box against the flat
## charcoal background, scaled by whichever of width or height runs out first, and centred.
## Every figure then fills as much of its tile as it can without any limb leaving the
## frame, and the six read as a set because they are framed by the same rule rather than
## the same landmark.
##
## The charcoal itself is then cut away, so what the game gets is a player on nothing.

const RAW := "res://dev/ref/action-posters/%s_raw.png"
const OUT := "res://assets/ui/portrait_%s.png"
const SPORTS := [
	"badminton", "beachvolleyball", "volleyball", "tennis", "tabletennis", "takraw",
]

## The picture the game draws. 768x1376 is what the posters were generated at, and its
## shape is within 3% of the sport menu card's own 184x340 — closer than the old portraits
## managed. The game fits it inside the tile rather than filling it, so nothing is cropped
## and this shape only decides how much room a figure is given.
const TILE := Vector2i(768, 1376)

## How much of that picture a figure is allowed to fill. The margin is breathing room, so
## a spread hand or a raised foot never touches the edge.
const FILL_WIDE := 0.86
const FILL_TALL := 0.90

## How far a pixel must sit from the background colour to count as part of the figure.
## The background is a flat charcoal and the art has hard black outlines, so there is a
## wide gap between the two and nothing here is delicate.
const FIGURE_THRESHOLD := 0.09


func _init() -> void:
	for sport in SPORTS:
		_fit(sport)
	quit()


func _fit(sport: String) -> void:
	var path := RAW % sport
	if not FileAccess.file_exists(ProjectSettings.globalize_path(path)):
		push_error("no raw poster for %s at %s" % [sport, path])
		return
	var src := Image.load_from_file(ProjectSettings.globalize_path(path))
	src.convert(Image.FORMAT_RGBA8)

	var background := src.get_pixel(4, 4)
	var box := _figure_box(src, background)
	if box.size.x <= 0 or box.size.y <= 0:
		push_error("found no figure in %s" % path)
		return

	var figure := src.get_region(box)
	# Whichever of the two runs out first. Scaling to the height alone would push a wide
	# pose — the table tennis loop, the takraw kick — out through the sides.
	var room := Vector2(TILE.x * FILL_WIDE, TILE.y * FILL_TALL)
	var scale := minf(room.x / float(box.size.x), room.y / float(box.size.y))
	figure.resize(
		maxi(1, int(round(box.size.x * scale))),
		maxi(1, int(round(box.size.y * scale))),
		Image.INTERPOLATE_LANCZOS)

	_cut_the_background_out(figure, background)

	var out := Image.create(TILE.x, TILE.y, false, Image.FORMAT_RGBA8)
	out.fill(Color(0.0, 0.0, 0.0, 0.0))
	var at := Vector2i(
		(TILE.x - figure.get_width()) / 2,
		(TILE.y - figure.get_height()) / 2)
	out.blit_rect(figure, Rect2i(Vector2i.ZERO, figure.get_size()), at)
	out.save_png(ProjectSettings.globalize_path(OUT % sport))
	print("%-16s figure %s of %s  ->  scaled %.2f, placed at %s" % [
		sport, box.size, src.get_size(), scale, at])


## Makes the charcoal the poster was drawn on transparent, so the figure sits on the tile
## rather than on a visible rectangle of its own.
##
## This floods in from the edges rather than keying every charcoal-coloured pixel in the
## picture, and the difference is not academic: the badminton player's shorts are dark
## navy, within a hair of the background, and a colour key punched holes straight through
## them. Background is what the outside can reach; anything the black outline encloses is
## the player, whatever colour it happens to be.
func _cut_the_background_out(img: Image, background: Color) -> void:
	var w := img.get_width()
	var h := img.get_height()
	var seen := PackedByteArray()
	seen.resize(w * h)
	var stack: Array[int] = []
	for x in w:
		stack.append(x)
		stack.append((h - 1) * w + x)
	for y in h:
		stack.append(y * w)
		stack.append(y * w + w - 1)

	while not stack.is_empty():
		var i: int = stack.pop_back()
		if i < 0 or i >= seen.size() or seen[i] == 1:
			continue
		var x := i % w
		var y := i / w
		var c := img.get_pixel(x, y)
		var apart := absf(c.r - background.r) + absf(c.g - background.g) \
			+ absf(c.b - background.b)
		if apart >= FIGURE_THRESHOLD:
			continue
		seen[i] = 1
		img.set_pixel(x, y, Color(c.r, c.g, c.b, 0.0))
		if x > 0:
			stack.append(i - 1)
		if x < w - 1:
			stack.append(i + 1)
		if y > 0:
			stack.append(i - w)
		if y < h - 1:
			stack.append(i + w)


## The smallest rectangle holding everything that is not the background. Read every
## fourth pixel: the figure is thousands of pixels across and its outline is several
## pixels thick, so nothing can hide between the samples, and it is sixteen times quicker
## than reading all of them.
func _figure_box(img: Image, background: Color) -> Rect2i:
	var w := img.get_width()
	var h := img.get_height()
	var min_x := w
	var min_y := h
	var max_x := -1
	var max_y := -1
	for y in range(0, h, 4):
		for x in range(0, w, 4):
			var c := img.get_pixel(x, y)
			var apart := absf(c.r - background.r) + absf(c.g - background.g) \
				+ absf(c.b - background.b)
			if apart < FIGURE_THRESHOLD:
				continue
			min_x = mini(min_x, x)
			min_y = mini(min_y, y)
			max_x = maxi(max_x, x)
			max_y = maxi(max_y, y)
	if max_x < 0:
		return Rect2i()
	# Back out by the sampling step, so a limb that ended between two samples is not
	# clipped, then clamp to the picture.
	min_x = maxi(0, min_x - 4)
	min_y = maxi(0, min_y - 4)
	max_x = mini(w - 1, max_x + 4)
	max_y = mini(h - 1, max_y + 4)
	return Rect2i(min_x, min_y, max_x - min_x + 1, max_y - min_y + 1)
