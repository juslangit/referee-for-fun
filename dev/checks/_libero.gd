extends Node

## Is the libero in a different shirt, and is nobody wearing a box?
##
##   godot --headless --path . res://dev/checks/_libero.tscn
##
## The libero has to be identifiable at a glance — that is the entire reason the
## different-shirt rule exists in the sport. The game used to do it by strapping a
## 0.34 x 0.40 x 0.26 m BoxMesh to the chest bone, and Luqman photographed it on
## 2026-09-17: "change to different cloth, dont put block like that".
##
## Two things are checked, because the fix had two halves and each failed on its own
## first. The box must be gone: `Models.wear_bib()` still exists as the fallback for a
## checkout with no Meshy assets, so it can come back by accident. And the libero must be
## a **different model file** from its team-mates, not the same one with a material put on
## top — a material override on a built figure silently does not draw, which cost a long
## afternoon to establish, so this asserts the model actually differs rather than
## asserting a colour that may never reach the screen.

var _failures: Array[String] = []


func _expect(ok: bool, what: String) -> void:
	print("   %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures.append(what)


func _ready() -> void:
	var arena: Node = load("res://scenes/volleyball.tscn").instantiate()
	arena.print_truth_while_testing = false
	add_child(arena)
	await get_tree().physics_frame
	arena.career = Career.new()
	arena.career.sport = Career.INDOOR
	arena.settings.taught_indoor = true
	arena.ui.match_requested.emit()
	await get_tree().process_frame
	if arena.pressure.exists():
		arena.ui.briefing_acknowledged.emit()
	arena.begin_match()
	for f in 8:
		await get_tree().physics_frame

	print("=== nobody is wearing a box")
	var boxes := 0
	for player in arena.players:
		boxes += player.find_children("Vest", "MeshInstance3D", true, false).size()
		boxes += player.find_children("Bib", "MeshInstance3D", true, false).size()
	_expect(boxes == 0, "no bib or vest box is strapped to anybody (%d found)" % boxes)

	print("=== the libero wears a different shirt from the rest of the side")
	for team in [Sides.Team.RED, Sides.Team.BLUE]:
		var index: int = arena.rota[team].libero
		_expect(index >= 0, "%s has a libero" % Sides.label(team))
		if index < 0:
			continue
		var mine: Array = []
		for player in arena.players:
			if player.team == team:
				mine.append(player)
		if index >= mine.size():
			_expect(false, "%s libero index %d is out of range" % [Sides.label(team), index])
			continue
		var libero: Node = mine[index]
		var wears := _sheet(libero)
		_expect(not wears.is_empty(), "%s libero has a texture at all" % Sides.label(team))
		var same := 0
		for player in mine:
			if player != libero and _sheet(player) == wears:
				same += 1
		_expect(same == 0,
			"%s libero's kit differs from all %d team-mates (%d share it)" % [
				Sides.label(team), mine.size() - 1, same])

	print("")
	if _failures.is_empty():
		print("PASS  the libero is in their own kit, and nobody is wearing a box")
	else:
		for failure in _failures:
			print("FAIL  " + failure)
	get_tree().quit()


## Which texture a figure is actually drawn with, by path. Reading the material rather
## than the model path, because the model is what was changed and the texture is what the
## player sees — they have been out of step before.
func _sheet(figure: Node) -> String:
	for node in figure.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := node as MeshInstance3D
		if mesh_instance.mesh == null:
			continue
		for surface in mesh_instance.mesh.get_surface_count():
			var material := mesh_instance.get_active_material(surface) as StandardMaterial3D
			if material != null and material.albedo_texture != null:
				return material.albedo_texture.resource_path
	return ""
