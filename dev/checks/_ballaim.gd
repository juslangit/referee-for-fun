extends Node

## Does the ball land where it was aimed?
##
## The badminton version of this question is answered to a tenth of a millimetre by
## _aimcheck, and it has to be answered here too before any of the calls can be trusted:
## the landing point is the truth this whole game is built on, and a solver that is a
## metre out is a game that punishes honest referees for calls it got wrong itself.

func _ready() -> void:
	var court := BeachCourt.new()
	add_child(court)
	var ball := Ball.new()
	ball.floor_height = BeachCourt.SURFACE_Y
	add_child(ball)
	await get_tree().physics_frame

	var targets := [
		{"name": "deep, dead on the end line", "from": Vector3(0.0, 2.15, -9.1),
			"to": Vector3(0.0, 0.0, 8.0), "angle": 26.0},
		{"name": "into the middle", "from": Vector3(0.0, 2.15, -9.1),
			"to": Vector3(0.0, 0.0, 4.0), "angle": 34.0},
		{"name": "spiked from the net", "from": Vector3(0.0, 2.95, -1.5),
			"to": Vector3(2.0, 0.0, 6.0), "angle": -4.0},
		{"name": "on the sideline", "from": Vector3(0.0, 2.95, -1.5),
			"to": Vector3(4.0, 0.0, 5.0), "angle": 6.0},
		{"name": "a hand past the line", "from": Vector3(0.0, 2.95, -1.5),
			"to": Vector3(0.0, 0.0, 8.12), "angle": 6.0},
	]

	var worst := 0.0
	for shot in targets:
		var from: Vector3 = shot["from"]
		var to: Vector3 = shot["to"]
		to.y = BeachCourt.SURFACE_Y
		var velocity := ShotSolver.solve(
			from, to, shot["angle"], BeachCourt.SURFACE_Y, ShotSolver.ball_flight())
		if velocity == Vector3.ZERO:
			print("%-30s UNSOLVED" % shot["name"])
			continue

		ball.launch(from, velocity)
		var waited := 0
		while not ball.has_landed and waited < 2000:
			await get_tree().physics_frame
			waited += 1

		var miss := Vector2(ball.landing_point.x - to.x, ball.landing_point.z - to.z).length()
		worst = maxf(worst, miss)
		print("%-30s aimed %6.3f,%6.3f   landed %6.3f,%6.3f   miss %5.0f mm" % [
			shot["name"], to.x, to.z,
			ball.landing_point.x, ball.landing_point.z, miss * 1000.0])

	print()
	print("worst miss %.0f mm — the tape is %.0f mm wide" % [
		worst * 1000.0, BeachSpec.LINE_WIDTH * 1000.0])
	get_tree().quit()
