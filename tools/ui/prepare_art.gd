extends SceneTree

## Turns the two OpenArt images into game assets. Run once, headless:
##   godot --headless --path . --script res://tools/ui/prepare_art.gd
##
## The portrait sheet is five athletes side by side, split by thin black gaps; each one
## becomes its own tile picture. The title logo was drawn on flat chroma green, because an
## image model cannot give a transparent background, so the green is keyed out here.

const SHEET := "res://dev/ref/ui-redesign/sheet_portraits.png"
const LOGO := "res://dev/ref/ui-redesign/logo_green.png"
const ORDER := ["badminton", "beachvolleyball", "volleyball", "tennis", "tabletennis"]

## The sixth athlete, drawn later (2026-09-15) on its own with the sheet as the style
## reference, so it has to be fitted to the sheet's framing rather than cut from it.
const TAKRAW := "res://dev/ref/takraw/portrait_takraw_raw.png"


func _init() -> void:
	_split_portraits()
	_fit_the_takraw_portrait()
	_key_logo()
	quit()


func _split_portraits() -> void:
	var sheet := Image.load_from_file(ProjectSettings.globalize_path(SHEET))
	var w := sheet.get_width()
	var h := sheet.get_height()
	# A column is a gap when nearly every pixel down it is close to pure black. The
	# background is charcoal (about 28/255), the gaps are 0, so 14 separates them.
	var gap := PackedByteArray()
	gap.resize(w)
	for x in w:
		var dark := 0
		for y in range(0, h, 8):
			var c := sheet.get_pixel(x, y)
			if maxf(c.r, maxf(c.g, c.b)) < 14.0 / 255.0:
				dark += 1
		gap[x] = 1 if dark > (h / 8) * 0.9 else 0
	var runs: Array = []
	var start := -1
	for x in w + 1:
		var is_art := x < w and gap[x] == 0
		if is_art and start < 0:
			start = x
		elif not is_art and start >= 0:
			if x - start > w / 10:
				runs.append(Vector2i(start, x))
			start = -1
	print("portrait columns: ", runs)
	if runs.size() != ORDER.size():
		push_error("expected %d columns, found %d" % [ORDER.size(), runs.size()])
		return
	for i in runs.size():
		var r: Vector2i = runs[i]
		var inset := 4
		var part := sheet.get_region(Rect2i(r.x + inset, 0, r.y - r.x - inset * 2, h))
		var out := "res://assets/ui/portrait_%s.png" % ORDER[i]
		part.save_png(ProjectSettings.globalize_path(out))
		print("saved ", out, " ", part.get_size())


## Scaled and placed so the sepak takraw player stands where the other five do: the top of
## the head at the same height, cut off at the same point down the legs, on a tile the same
## size. Measured on the sheet and on the drawing: on the sheet the top of the head is 325 px
## down a 1344 px column and the bottom of the shirt is at 1315; on this drawing they are at
## 6% and 66% of its height.
func _fit_the_takraw_portrait() -> void:
	var src := Image.load_from_file(ProjectSettings.globalize_path(TAKRAW))
	src.convert(Image.FORMAT_RGBA8)
	var tile := Image.load_from_file(ProjectSettings.globalize_path("res://assets/ui/portrait_volleyball.png"))
	var w := tile.get_width()
	var h := tile.get_height()
	var head_top := 0.06 * src.get_height()
	var shirt_end := 0.66 * src.get_height()
	var scale := (1315.0 - 325.0) / (shirt_end - head_top)
	src.resize(int(src.get_width() * scale), int(src.get_height() * scale), Image.INTERPOLATE_LANCZOS)
	var out := Image.create(w, h, false, Image.FORMAT_RGBA8)
	out.fill(src.get_pixel(4, 4))
	var offset := Vector2i((w - src.get_width()) / 2, int(325.0 - head_top * scale))
	out.blit_rect(src, Rect2i(Vector2i.ZERO, src.get_size()), offset)
	out.save_png(ProjectSettings.globalize_path("res://assets/ui/portrait_takraw.png"))
	print("saved portrait_takraw ", out.get_size())


func _key_logo() -> void:
	var img := Image.load_from_file(ProjectSettings.globalize_path(LOGO))
	img.convert(Image.FORMAT_RGBA8)
	var w := img.get_width()
	var h := img.get_height()
	var box := Rect2i(w, h, -w, -h)
	for y in h:
		for x in w:
			var c := img.get_pixel(x, y)
			# How much greener the pixel is than its other two channels. The flat
			# background scores about 0.8; white, grey and gold score zero or below.
			var greenness := c.g - maxf(c.r, c.b)
			var a := 1.0 - clampf((greenness - 0.12) / (0.55 - 0.12), 0.0, 1.0)
			# Edge pixels are part green; pull the green back down so the logo has no
			# green fringe against a dark menu.
			c.g = minf(c.g, maxf(c.r, c.b) + 0.04)
			c.a = a
			img.set_pixel(x, y, c)
			if a > 0.05:
				box = box.merge(Rect2i(x, y, 1, 1)) if box.size.x >= 0 else Rect2i(x, y, 1, 1)
	var margin := 12
	box = box.grow(margin).intersection(Rect2i(0, 0, w, h))
	var logo := img.get_region(box)
	logo.save_png(ProjectSettings.globalize_path("res://assets/ui/title_logo.png"))
	print("saved title_logo.png ", logo.get_size())
