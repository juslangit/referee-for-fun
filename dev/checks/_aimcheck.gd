extends Node

## Can a shuttle be aimed at a line and actually land on it?
##
## This is the check the whole game rests on. The umpire is judging millimetres, so the
## solver and the shuttle have to agree about where the floor is to within far less than
## the width of a line. They stopped agreeing when the run-off apron was laid underneath
## the mat and the playing surface rose by a centimetre: the shuttle knew, and the
## solver was still aiming at the old height.

var _landed := false
var _where := Vector3.ZERO

func _ready() -> void:
	var arena: Node = load("res://scenes/match.tscn").instantiate()
	add_child(arena)
	await get_tree().physics_frame

	var from := Vector3(0.0, 2.6, -4.5)
	var targets := [
		[Vector3(3.05, 0.0, 4.00), "dead on the doubles sideline"],
		[Vector3(3.09, 0.0, 4.00), "4 cm past the sideline"],
		[Vector3(1.00, 0.0, 6.70), "dead on the back line"],
		[Vector3(-2.59, 0.0, 5.94), "where two lines cross"],
		[Vector3(0.00, 0.0, 2.40), "safely mid-court"],
	]

	var worst := 0.0
	for entry in targets:
		var target: Vector3 = entry[0]
		var velocity := Vector3.ZERO
		for angle in [30.0, 36.0, 42.0, 48.0, 54.0]:
			velocity = ShotSolver.solve(from, target, angle, Court.SURFACE_Y)
			if velocity != Vector3.ZERO:
				break
		if velocity == Vector3.ZERO:
			print("%-32s NO SOLUTION" % entry[1])
			continue

		var shuttle := Shuttle.new()
		arena.add_child(shuttle)
		_landed = false
		shuttle.landed.connect(func(point: Vector3) -> void:
			_landed = true
			_where = point)
		shuttle.launch(from, velocity)
		for f in 900:
			await get_tree().physics_frame
			if _landed:
				break
		var miss := Vector2(_where.x - target.x, _where.z - target.z).length()
		worst = maxf(worst, miss)
		print("%-32s aimed %v  landed %v  miss %.1f mm" % [
			entry[1], target, _where, miss * 1000.0])
		shuttle.queue_free()

	print("worst miss %.1f mm — a line is 40 mm wide" % (worst * 1000.0))
	get_tree().quit()
