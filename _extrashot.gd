extends Node

## Catches the moment after a landing: the line camera in the corner of the screen
## and the line judge's call in the air above their head.

func _ready() -> void:
	var arena: Node = load("res://scenes/match.tscn").instantiate()
	arena.print_truth_while_testing = true
	add_child(arena)
	await get_tree().physics_frame
	arena._on_length_chosen(false)
	arena._on_favour_chosen(Sides.Team.NONE)

	# Keep playing until one lands near enough to a line to be worth photographing.
	for attempt in range(14):
		arena._start_rally()
		var waited := 0
		while arena._phase != arena.Phase.AWAITING_CALL and waited < 3000:
			await get_tree().physics_frame
			waited += 1
		if absf(arena.rally.margin) < 0.09:
			break
		arena._make_call(&"in" if arena.rally.was_in else &"out")

	# Wait for the line judge to actually say something before looking at them.
	await get_tree().create_timer(0.9).timeout

	# Take the mouse away from the camera first, or a stray motion event will swing
	# the view straight back to facing forwards.
	arena.camera.active = false
	arena.camera.look_at(arena.line_judge.global_position + Vector3(0.0, 1.5, 0.0), Vector3.UP)
	arena.camera.fov = 55.0
	for f in 4:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://_shot_extras.png")
	# And the line camera's own picture, at the size the player actually sees it.
	arena.shuttle_cam.texture().get_image().save_png("res://_shot_shuttlecam.png")
	print("line camera at %v looking at the landing" % arena.shuttle_cam.camera.global_position)
	print("landed at (%.3f, %.3f), margin %+.3f m" % [
		arena.rally.landing_point.x, arena.rally.landing_point.z, arena.rally.margin
	])
	print("line judge said %s" % ("IN" if arena.rally.line_judge_said_in else "OUT"))
	print("saved")
	get_tree().quit()
