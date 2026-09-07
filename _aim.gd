extends Node

## Can the players deliberately land a shuttle on a line? If not, close calls stay
## rare and the umpire has nothing interesting to judge.

func _ready() -> void:
	var arena: Node = load("res://scenes/match.tscn").instantiate()
	add_child(arena)
	await get_tree().physics_frame

	# Struck from the back of the far half, roughly overhead height.
	var from := Vector3(0.0, 2.6, -4.5)

	var targets := [
		[Vector3(3.05, 0, 4.00), "dead on the doubles sideline"],
		[Vector3(3.09, 0, 4.00), "4 cm past the sideline"],
		[Vector3(1.00, 0, 6.70), "dead on the back line"],
		[Vector3(1.00, 0, 6.76), "6 cm long"],
		[Vector3(-2.59, 0, 5.94), "singles line meets long service line"],
		[Vector3(0.00, 0, 2.40), "safely mid-court"],
	]

	for angle in [38.0, 14.0]:
		print("\n--- launch angle %.0f degrees (%s) ---" % [angle, "clear" if angle > 25.0 else "drive"])
		print("%-42s %9s %10s %8s   %s" % ["aimed at", "speed", "error", "time", "truth"])
		for entry in targets:
			var target: Vector3 = entry[0]
			var velocity := ShotSolver.solve(from, target, angle, Court.MAT_THICKNESS)
			if velocity == Vector3.ZERO:
				print("%-42s %9s" % [entry[1], "unreachable"])
				continue

			var shuttle := Shuttle.new()
			arena.add_child(shuttle)
			shuttle.launch(from, velocity)
			var elapsed := 0.0
			var step := 1.0 / float(Engine.physics_ticks_per_second)
			while not shuttle.has_landed and elapsed < 20.0:
				await get_tree().physics_frame
				elapsed += step

			var rally := Rally.new(true)
			rally.record_landing(shuttle.landing_point)
			var error := Vector2(
				shuttle.landing_point.x - target.x,
				shuttle.landing_point.z - target.z
			).length()
			print("%-42s %7.1f m/s %8.3f m %6.2f s   %s" % [
				entry[1], velocity.length(), error, elapsed, rally.describe()
			])
			shuttle.queue_free()

	get_tree().quit()
