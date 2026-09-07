extends Node

## Which shots can the solver actually find? A shot it cannot find is a stroke the
## player fails to play, so if these fail often the rallies fall apart.

func _ready() -> void:
	var arena: Node = load("res://scenes/match.tscn").instantiate()
	add_child(arena)
	await get_tree().physics_frame

	print("%-34s %-10s %s" % ["shot", "found", "angle used"])
	var froms := [
		[Vector3(0.0, 2.45, -3.0), "serve, from 2.45 m"],
		[Vector3(0.0, 2.60, -5.0), "overhead from the back"],
		[Vector3(0.0, 2.20, -0.9), "at the net, high"],
		[Vector3(0.0, 0.80, -1.2), "at the net, low"],
		[Vector3(0.0, 1.20, -5.5), "deep and low"],
	]
	var targets := [
		[Vector3(0.0, 0.0, 0.40), "just over the net"],
		[Vector3(0.0, 0.0, 1.20), "a short drop"],
		[Vector3(0.0, 0.0, 3.50), "mid court"],
		[Vector3(2.9, 0.0, 6.60), "back corner"],
	]

	var failures := 0
	var tried := 0
	for f in froms:
		for t in targets:
			tried += 1
			var from: Vector3 = f[0]
			var target: Vector3 = t[0]
			var found := false
			var used := 0.0
			# Same sweep the match uses.
			var angle: float = arena._choose_angle(from)
			for attempt in 4:
				var candidate := ShotSolver.solve(from, target, angle, Court.MAT_THICKNESS)
				if candidate != Vector3.ZERO and arena._clears_the_net(from, target, candidate):
					found = true
					used = angle
					break
				angle += 9.0
			if not found:
				failures += 1
			print("%-34s %-10s %s" % [
				"%s -> %s" % [f[1], t[1]],
				"yes" if found else "NO",
				"%.0f deg" % used if found else "",
			])

	print("\n%d of %d shots could not be played" % [failures, tried])
	get_tree().quit()
