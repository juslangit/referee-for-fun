extends Node

## Do the two teams separate without colour when the setting is on?
##
##   godot --headless --path . res://dev/checks/_clearkits.tscn
##
## Measured on 2026-09-18: the shipped red kit has a luminance of 88 out of 255 and the
## blue 77. Eleven apart, so hue is the only thing telling the sides apart — and the whole
## game is deciding which side a rally went to. "Clearer team colours" swaps both teams
## for kits that separate by brightness too.
##
## Luminance is checked rather than the colours, because "is it red enough" is not the
## question a colour-blind player is asking. Rec. 709 weights, which is what an eye that
## cannot use hue is left with.

const APART := 40.0   ## below this, two kits read as the same shirt in greyscale

var _failures: Array[String] = []


func _expect(ok: bool, what: String) -> void:
	print("   %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures.append(what)


func _ready() -> void:
	print("=== the setting is off unless somebody asks for it")
	var fresh := Settings.new()
	_expect(not fresh.clear_kits, "a new player gets the kits as they always were")

	print("=== and it survives being saved")
	fresh.clear_kits = true
	_expect(fresh.clear_kits, "it can be turned on")

	print("=== the kits themselves")
	var plain := {
		Sides.Team.RED: _brightness(Models.PLAYERS[Sides.Team.RED]),
		Sides.Team.BLUE: _brightness(Models.PLAYERS[Sides.Team.BLUE]),
	}
	var clear := {
		Sides.Team.RED: _brightness(Models.CLEAR_MODELS[Sides.Team.RED]),
		Sides.Team.BLUE: _brightness(Models.CLEAR_MODELS[Sides.Team.BLUE]),
	}
	var was: float = absf(plain[Sides.Team.RED] - plain[Sides.Team.BLUE])
	var now: float = absf(clear[Sides.Team.RED] - clear[Sides.Team.BLUE])
	print("   as shipped:  red %.0f  blue %.0f  ->  %.0f apart" % [
		plain[Sides.Team.RED], plain[Sides.Team.BLUE], was])
	print("   clearer:     red %.0f  blue %.0f  ->  %.0f apart" % [
		clear[Sides.Team.RED], clear[Sides.Team.BLUE], now])
	_expect(now >= APART, "the clearer kits are at least %.0f apart in brightness" % APART)
	_expect(now > was, "and further apart than the ones they replace")

	print("=== every sport builds its players from the setting")
	var sports := 0
	for path in ["res://scripts/match.gd", "res://scripts/beach_match.gd",
			"res://scripts/volley_match.gd", "res://scripts/tennis_match.gd",
			"res://scripts/table_tennis_match.gd", "res://scripts/takraw_match.gd"]:
		# Matched loosely on purpose. The first version looked for one exact line, and
		# broke the moment that line grew a null guard for the looks that build a court
		# with no match around it — the behaviour was untouched and the check failed. A
		# check pinned to the spelling of a line is a check that fails on refactors and
		# says nothing about the game.
		var source := FileAccess.get_file_as_string(path)
		for line in source.split("\n"):
			if line.contains("player.clear_kit") and line.contains("clear_kits"):
				sports += 1
				break
	_expect(sports == 6, "all six sports pass the setting to their players (%d do)" % sports)

	print("")
	if _failures.is_empty():
		print("PASS  the teams can be told apart without colour, when asked for")
	else:
		for failure in _failures:
			print("FAIL  " + failure)
	get_tree().quit()


## The brightness of a model's kit: the most common strongly-coloured pixel of its
## texture, by Rec. 709 luminance.
func _brightness(model_path: String) -> float:
	var scene: PackedScene = load(model_path)
	var figure: Node3D = scene.instantiate()
	add_child(figure)
	var found := Color.BLACK
	var best := 0
	for node in figure.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := node as MeshInstance3D
		if mesh_instance.mesh == null:
			continue
		for surface in mesh_instance.mesh.get_surface_count():
			var material := mesh_instance.get_active_material(surface) as StandardMaterial3D
			if material == null or material.albedo_texture == null:
				continue
			var sheet := material.albedo_texture.get_image()
			sheet.resize(96, 96, Image.INTERPOLATE_NEAREST)
			var tally := {}
			for y in 96:
				for x in 96:
					var pixel := sheet.get_pixel(x, y)
					# 0.45, not 0.30. Skin sits at about 0.32 and covers more of the
					# sheet than the shirt does, so a lower floor measures the athlete's
					# arms and reports the blue kit at a luminance of 197.
					if pixel.s < 0.45 or pixel.v < 0.15:
						continue
					var key := Color(snappedf(pixel.r, 0.05), snappedf(pixel.g, 0.05),
						snappedf(pixel.b, 0.05))
					tally[key] = int(tally.get(key, 0)) + 1
					if int(tally[key]) > best:
						best = int(tally[key])
						found = key
	figure.queue_free()
	return 255.0 * (0.2126 * found.r + 0.7152 * found.g + 0.0722 * found.b)
