extends Node

## Where the triangles are.
##
## `_fps` found badminton drawing eighteen to twenty-three million triangles a frame, six
## times table tennis, and running at a third of the speed. This lists every visible model
## in a venue by what it costs — triangles times however many copies are drawn — and says
## which of them cast shadows, because every shadow-casting light draws its casters again.
##
## Windowed, because a headless run keeps no mesh data to count.
##
##   SPORT=badminton  TIER=0

const SCENES := {
	"badminton": ["res://scenes/match.tscn", Career.BADMINTON],
	"beach": ["res://scenes/beach.tscn", Career.BEACH],
	"indoor": ["res://scenes/volleyball.tscn", Career.INDOOR],
	"tennis": ["res://scenes/tennis.tscn", Career.TENNIS],
	"table_tennis": ["res://scenes/table_tennis.tscn", Career.TABLE_TENNIS],
	"takraw": ["res://scenes/sepak_takraw.tscn", Career.TAKRAW],
}

var _faces := {}


func _ready() -> void:
	for pick in _picks():
		await _count(pick[0], pick[1])
	get_tree().quit()


func _picks() -> Array:
	if OS.has_environment("SPORT"):
		var tier := int(OS.get_environment("TIER")) if OS.has_environment("TIER") else 0
		return [[OS.get_environment("SPORT"), tier]]
	return [["badminton", 0], ["badminton", 4], ["beach", 0]]


func _count(sport: String, tier: int) -> void:
	var arena: OfficiatedMatch = load(SCENES[sport][0]).instantiate()
	arena.print_truth_while_testing = false
	add_child(arena)
	await get_tree().physics_frame
	arena.career = Career.new()
	arena.career.sport = SCENES[sport][1]
	arena.career.tier = tier
	arena.settings.taught = true
	arena.settings.taught_beach = true
	arena.settings.taught_indoor = true
	arena.settings.taught_tennis = true
	arena.settings.taught_table_tennis = true
	arena.settings.taught_takraw = true
	if sport == "badminton":
		arena._on_match_requested()
		if arena.pressure.exists():
			arena.ui.hide_briefing()
	else:
		arena.ui.match_requested.emit()
		await get_tree().process_frame
		if arena.pressure.exists():
			arena.ui.briefing_acknowledged.emit()
			await get_tree().process_frame
	arena.begin_match()
	for f in 10:
		await get_tree().process_frame

	var groups := {}
	var total := 0
	var shadowed := 0
	for node in arena.find_children("*", "GeometryInstance3D", true, false):
		var geometry := node as GeometryInstance3D
		if not geometry.is_visible_in_tree():
			continue
		var triangles := 0
		var copies := 1
		var what := ""
		if geometry is MeshInstance3D and geometry.mesh != null:
			triangles = _triangles(geometry.mesh)
			what = _name_of(geometry.mesh, geometry)
		elif geometry is MultiMeshInstance3D and geometry.multimesh != null \
				and geometry.multimesh.mesh != null:
			var multi: MultiMesh = geometry.multimesh
			triangles = _triangles(multi.mesh)
			copies = multi.visible_instance_count if multi.visible_instance_count >= 0 \
				else multi.instance_count
			what = "MULTI " + _name_of(multi.mesh, geometry)
		else:
			continue
		var casts := geometry.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var key := "%s  %s%s" % [_top(arena, geometry), what, "  [shadow]" if casts else ""]
		if not groups.has(key):
			groups[key] = {"triangles": 0, "nodes": 0, "each": triangles}
		groups[key]["triangles"] += triangles * copies
		groups[key]["nodes"] += copies
		total += triangles * copies
		if casts:
			shadowed += triangles * copies

	var lights := 0
	var shadow_lights := 0
	for light in arena.find_children("*", "Light3D", true, false):
		if (light as Light3D).is_visible_in_tree():
			lights += 1
			if light.shadow_enabled:
				shadow_lights += 1
	var skeletons := arena.find_children("*", "Skeleton3D", true, false).size()
	var animators := arena.find_children("*", "AnimationPlayer", true, false).size()

	print("")
	print("=== %s, tier %d, %s" % [sport, tier, arena.career.venue()["name"]])
	print("   %d triangles in the scene, %d of them casting shadows" % [total, shadowed])
	print("   %d lights, %d casting shadows   %d skeletons   %d animation players" % [
		lights, shadow_lights, skeletons, animators])
	var rows := groups.keys()
	rows.sort_custom(func(a, b) -> bool: return groups[a]["triangles"] > groups[b]["triangles"])
	print("   %12s %7s %9s  %s" % ["triangles", "copies", "each", "what"])
	for key in rows.slice(0, 22):
		print("   %12d %7d %9d  %s" % [
			groups[key]["triangles"], groups[key]["nodes"], groups[key]["each"], key])

	arena.queue_free()
	await get_tree().process_frame


func _triangles(mesh: Mesh) -> int:
	if not _faces.has(mesh):
		_faces[mesh] = mesh.get_faces().size() / 3
	return _faces[mesh]


func _name_of(mesh: Mesh, node: Node) -> String:
	if mesh.resource_path != "":
		return mesh.resource_path.get_file().left(48)
	return String(node.name).left(48)


## Which part of the venue this belongs to: the first node under the match.
func _top(arena: Node, node: Node) -> String:
	var path := arena.get_path_to(node)
	var first := String(path.get_name(0))
	if path.get_name_count() > 2:
		first += "/" + String(path.get_name(1))
	return first.left(34)
