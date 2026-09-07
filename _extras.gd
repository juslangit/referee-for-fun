extends Node

## Checks the three things added on request: two line judges, a camera that gets as
## close as it can, and a cost for standing there thinking about it.

func _ready() -> void:
	var arena: Node = load("res://scenes/match.tscn").instantiate()
	add_child(arena)
	await get_tree().physics_frame

	print("--- line judges ---")
	for judge in arena.line_judges:
		print("  %-16s watches %-6s  seat %v" % [judge.name, Sides.label(judge.watches), judge.position])
	for z in [6.65, 3.0, -3.0, -6.65]:
		var judge: LineJudge = arena._judge_watching(Vector3(3.0, 0.0, z))
		print("  shuttle at z %+6.2f  ->  %s speaks" % [z, judge.name if judge else "nobody"])

	print("\n--- how close the camera gets ---")
	print("  %-34s %-10s %s" % ["landing", "distance", "camera sits at"])
	var cases := [
		[Vector3(3.05, 0.01, 3.0), "exactly on the sideline"],
		[Vector3(3.07, 0.01, 3.0), "2 cm outside it"],
		[Vector3(3.25, 0.01, 3.0), "20 cm outside it"],
		[Vector3(4.05, 0.01, 3.0), "a metre outside it"],
		[Vector3(1.0, 0.01, 6.71), "1 cm past the back line"],
	]
	for entry in cases:
		var point: Vector3 = entry[0]
		arena.shuttle_cam.aim_at(point)
		var eye: Vector3 = arena.shuttle_cam.camera.global_position
		print("  %-34s %-10.2f %v" % [entry[1], eye.distance_to(point), eye])

	print("\n--- what standing there costs ---")
	for seconds in [0.0, 1.0, 2.5, 3.5, 5.0, 8.0, 20.0]:
		print("  %5.1f s  ->  %+.3f suspicion   %s" % [
			seconds, Suspicion.hesitation_cost(seconds), Crowd.react_to_delay(seconds)
		])
	get_tree().quit()
