extends Node

## Cheats badly and obviously three times, and photographs the two moments that
## follow: the tournament referee being called, and being taken off the match.

func _ready() -> void:
	var arena: Node = load("res://scenes/match.tscn").instantiate()
	arena.print_truth_while_testing = true
	add_child(arena)
	await get_tree().physics_frame
	arena.begin_match()

	for i in range(3):
		if arena.suspicion.is_removed:
			break
		# A shuttle sailing most of a metre wide. Nobody in the hall could miss it.
		var shuttle: Shuttle = arena.serve(
			Vector3(0.0, 2.45, -3.0),
			Vector3(CourtSpec.HALF_WIDTH_DOUBLES + 0.9, 0.0, 3.0),
			36.0,
			Sides.Team.RED
		)
		while not shuttle.has_landed:
			await get_tree().physics_frame
		arena._phase = arena.Phase.AWAITING_CALL
		arena._make_call(&"in")

		if arena.suspicion.has_been_warned and not arena.suspicion.is_removed:
			for f in 3:
				await get_tree().process_frame
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png("res://_shot_warned.png")

	for f in 4:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://_shot_removed.png")
	print("saved")
	get_tree().quit()
