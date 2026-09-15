extends SceneTree

## Turns the eight OpenArt images for the event venues into game assets. Run once, headless:
##   godot --headless --path . --script res://tools/events/prepare_event_art.gd
##
## Generated 2026-09-15 with GPT Image 2 (medium, 2K, 4:3) on Luqman's OpenArt account, at his
## go-ahead; the originals are in dev/ref/events. Every name in them is invented: the project
## does not carry real tournaments or real sponsors.
##
## - Five event logos drawn on white. The white is made transparent and the logo trimmed, so
##   it can sit on a coloured board, a screen or a banner.
## - Two sponsor sheets, six logos each on an even 3 x 2 grid. Cut into cells, keyed and trimmed.
## - One sheet of six crowd banners. Cut into cells and trimmed, but not keyed: the first banner
##   is white cloth, and keying white would cut holes in it.

const REF := "res://dev/ref/events/"
const OUT := "res://assets/events/"

const LOGOS := ["badminton", "tennis", "table_tennis", "indoor", "beach"]
const SPONSORS_A := ["teras_energy", "seri_bank", "rajawali_air", "segar", "kenari_telekom", "bayu_motor"]
const SPONSORS_B := ["teratai_hotels", "kopi_kampung", "pelangi_pay", "sinar_elektrik", "rimba_sports", "cuti_cuti_nusa"]
const BANNERS := ["malaysia_boleh", "jom_menang", "selamat_datang", "jalur_gemilang", "go_go_go", "kami_bersamamu"]

## How close to white a pixel has to be to count as background, and the band over which it
## fades rather than cutting hard, so anti-aliased edges stay smooth.
const WHITE_FROM := 0.86
const WHITE_TO := 0.97


func _init() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	for name in LOGOS:
		var img := _load(REF + "logo_%s.png" % name)
		_save(_trim(_key_white(img)), "logo_%s.png" % name)
	_cut(REF + "sponsors_a.png", SPONSORS_A, "sponsor_%s.png", true)
	_cut(REF + "sponsors_b.png", SPONSORS_B, "sponsor_%s.png", true)
	_cut(REF + "crowd_banners.png", BANNERS, "banner_%s.png", false)
	quit()


func _load(path: String) -> Image:
	var img := Image.load_from_file(ProjectSettings.globalize_path(path))
	img.convert(Image.FORMAT_RGBA8)
	return img


func _save(img: Image, file: String) -> void:
	# Boards and banners are small on screen; 1024 on the long side is plenty and keeps the
	# import light.
	var longest := maxi(img.get_width(), img.get_height())
	if longest > 1024:
		var k := 1024.0 / float(longest)
		img.resize(int(img.get_width() * k), int(img.get_height() * k), Image.INTERPOLATE_LANCZOS)
	img.save_png(ProjectSettings.globalize_path(OUT + file))
	print("saved ", file, " ", img.get_size())


## A 3 x 2 sheet into its six cells, top row left to right, then the bottom row.
func _cut(path: String, names: Array, pattern: String, key: bool) -> void:
	var sheet := _load(path)
	var cw := sheet.get_width() / 3
	var ch := sheet.get_height() / 2
	# Stay clear of the faint cell borders the model drew.
	var inset := 18
	for i in names.size():
		var col := i % 3
		var row := i / 3
		var cell := sheet.get_region(Rect2i(col * cw + inset, row * ch + inset, cw - inset * 2, ch - inset * 2))
		if key:
			cell = _key_white(cell)
		_save(_trim(cell, not key), pattern % names[i])


func _key_white(img: Image) -> Image:
	for y in img.get_height():
		for x in img.get_width():
			var c := img.get_pixel(x, y)
			var lightness := minf(c.r, minf(c.g, c.b))
			var alpha := 1.0 - clampf((lightness - WHITE_FROM) / (WHITE_TO - WHITE_FROM), 0.0, 1.0)
			if alpha < 1.0:
				img.set_pixel(x, y, Color(c.r, c.g, c.b, c.a * alpha))
	return img


## Cropped to what is actually drawn. A keyed image is trimmed to its opaque pixels; a banner,
## which keeps its background, to whatever is not near-white page.
func _trim(img: Image, by_white := false) -> Image:
	var min_x := img.get_width()
	var min_y := img.get_height()
	var max_x := -1
	var max_y := -1
	for y in range(0, img.get_height(), 2):
		for x in range(0, img.get_width(), 2):
			var c := img.get_pixel(x, y)
			var drawn := c.a > 0.1 if not by_white else minf(c.r, minf(c.g, c.b)) < 0.9
			if drawn:
				min_x = mini(min_x, x)
				min_y = mini(min_y, y)
				max_x = maxi(max_x, x)
				max_y = maxi(max_y, y)
	if max_x < 0:
		return img
	var pad := 8
	var rect := Rect2i(maxi(0, min_x - pad), maxi(0, min_y - pad), 0, 0)
	rect.end = Vector2i(mini(img.get_width(), max_x + pad), mini(img.get_height(), max_y + pad))
	return img.get_region(rect)
