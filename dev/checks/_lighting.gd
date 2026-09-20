extends Node

## Is every hall lit by one rig, and does that rig actually reach the corners?
##
##   godot --headless --path . res://dev/checks/_lighting.tscn
##
## Badminton kept its own copy of the lighting rig until 2026-09-20 — `HallLight` was
## written from badminton's numbers when the other sports needed the same look, and the
## original was left in `Venue` because badminton was not what had been asked for. Two
## copies of one rig is a bug waiting to happen, and it happened: widening the spotlight
## cone on 2026-09-18 meant editing both files by hand to keep the sports looking alike.
##
## Two things are checked, and neither is "does it look right", because that is what the
## `looks` folder is for.
##
## **One environment per hall.** The comment in `HallLight.light()` and the one in
## `Venue.dress()` both warn that two WorldEnvironments in a scene is a coin toss over
## which the renderer uses — and a refactor that moves a rig is exactly how a scene ends
## up with both. Nothing else in the project would notice.
##
## **The beams reach.** A spotlight's `spot_range` is a hard cut-off: past it the light
## simply stops. The far corner of a badminton court is 15.47 m from the furthest lamp,
## so a range under that would leave the corner dark no matter how bright the lamp is —
## and a corner you cannot see is a landing you cannot judge.

## Every sport, and whether it is lit by the shared truss rig.
##
## Three are, and three are not, which this check found rather than assumed. Beach is
## outdoors and has no truss to hang anything from. **Tennis and table tennis still have
## the flat rig `HallLight` was written to replace** — one directional light over a high
## ambient, which is a room with the strip lights on. That is the same complaint Luqman
## made about takraw and volleyball on 2026-09-16; nobody has made it about these two yet,
## so they were never changed. Recorded here rather than quietly asserted away.
const HALLS := [
	["badminton", "res://scenes/match.tscn", true],
	["beach", "res://scenes/beach.tscn", false],
	["indoor volleyball", "res://scenes/volleyball.tscn", true],
	["tennis", "res://scenes/tennis.tscn", false],
	["table tennis", "res://scenes/table_tennis.tscn", false],
	["sepak takraw", "res://scenes/sepak_takraw.tscn", true],
]

var _failures: Array[String] = []


func _expect(ok: bool, what: String) -> void:
	print("   %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures.append(what)


func _ready() -> void:
	for hall in HALLS:
		await _look_at(hall[0], hall[1], hall[2])

	print("")
	if _failures.is_empty():
		print("PASS  one rig per hall, and its beams reach the corners")
	else:
		for failure in _failures:
			print("FAIL  " + failure)
	get_tree().quit()


func _look_at(sport: String, path: String, on_the_truss: bool) -> void:
	var arena: Node = load(path).instantiate()
	arena.print_truth_while_testing = false
	add_child(arena)
	for f in 8:
		await get_tree().physics_frame

	var airs: Array[Node] = []
	var spots: Array[Node] = []
	var suns: Array[Node] = []
	_gather(arena, airs, spots, suns)

	print("=== %s: %d environment, %d spot, %d sun" % [sport, airs.size(), spots.size(), suns.size()])
	_expect(airs.size() == 1,
		"%s is lit by exactly one environment (%d)" % [sport, airs.size()])
	if on_the_truss:
		_expect(spots.size() > 0, "%s has lamps over the court (%d)" % [sport, spots.size()])
	else:
		print("   lit without a truss — nothing to assert about lamps here")
	_expect(suns.size() >= 1, "%s has a sun to cast one clean shadow" % sport)

	# How far the furthest lamp is from the furthest corner it has to light.
	var reach := 0.0
	var furthest := 0.0
	for node in spots:
		var spot := node as SpotLight3D
		reach = maxf(reach, spot.spot_range)
		for corner in _corners(arena):
			furthest = maxf(furthest, spot.global_position.distance_to(corner))
	if furthest > 0.0:
		print("   furthest throw %.2f m, shortest range %.2f m" % [furthest, _shortest(spots)])
		_expect(_shortest(spots) > furthest,
			"%s: every beam out-reaches its furthest corner (%.2f m of %.2f m)" % [
				sport, _shortest(spots), furthest])

	arena.queue_free()
	await get_tree().process_frame


## The corners of the playing surface, taken from the court the scene actually built
## rather than from a table of numbers that could drift away from it.
func _corners(arena: Node) -> Array[Vector3]:
	var box := AABB()
	var started := false
	for node in arena.find_children("*", "MeshInstance3D", true, false):
		var mesh_instance := node as MeshInstance3D
		if mesh_instance.mesh == null or not mesh_instance.visible:
			continue
		if not mesh_instance.name.to_lower().contains("line"):
			continue
		var here := mesh_instance.global_transform * mesh_instance.mesh.get_aabb()
		box = here if not started else box.merge(here)
		started = true
	if not started:
		return []
	var out: Array[Vector3] = []
	for x in [box.position.x, box.position.x + box.size.x]:
		for z in [box.position.z, box.position.z + box.size.z]:
			out.append(Vector3(x, 0.0, z))
	return out


func _shortest(spots: Array[Node]) -> float:
	var least := INF
	for node in spots:
		least = minf(least, (node as SpotLight3D).spot_range)
	return least


func _gather(node: Node, airs: Array[Node], spots: Array[Node], suns: Array[Node]) -> void:
	if node is WorldEnvironment:
		airs.append(node)
	elif node is SpotLight3D:
		spots.append(node)
	elif node is DirectionalLight3D:
		suns.append(node)
	for child in node.get_children():
		_gather(child, airs, spots, suns)
