extends Node

## How high is a beach serve when it reaches the net?
##
## Thirteen of seventeen rallies died with the ball resting against the net at
## z = +/-0.12, which is exactly a ball's radius plus half the net's thickness. So the
## serve is not clearing. This asks the solver directly rather than watching rallies.

func _ready() -> void:
	var flight := ShotSolver.ball_flight()
	var from_z := -(BeachSpec.HALF_LENGTH + 1.1)
	print("%-8s %-9s %-9s %-10s %s" % [
		"angle", "target z", "speed", "at the net", "clears 2.43?"])

	for angle in [8.0, 14.0, 20.0, 26.0, 34.0]:
		for target_z in [1.5, 4.0, 7.4]:
			var from := Vector3(0.0, 2.15, from_z)
			var to := Vector3(0.0, BeachCourt.SURFACE_Y, target_z)
			var velocity := ShotSolver.solve(
				from, to, angle, BeachCourt.SURFACE_Y, flight)
			if velocity == Vector3.ZERO:
				print("%-8.0f %-9.1f %-9s %-10s %s" % [angle, target_z, "-", "-", "UNSOLVED"])
				continue
			var speed := velocity.length()
			# How high it is after travelling as far as the net.
			var at_net := ShotSolver.height_after(
				2.15 - BeachCourt.SURFACE_Y, speed, angle, absf(from_z), flight)
			print("%-8.0f %-9.1f %-9.1f %-10.2f %s" % [
				angle, target_z, speed, at_net,
				"yes" if at_net > BeachSpec.NET_HEIGHT else "NO"])
	get_tree().quit()
