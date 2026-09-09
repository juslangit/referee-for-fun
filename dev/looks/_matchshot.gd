extends Node

## Photographs a rally in progress, with all four players on court.

func _ready() -> void:
	var arena: Node = load("res://scenes/match.tscn").instantiate()
	arena.print_truth_while_testing = false
	add_child(arena)
	await get_tree().physics_frame
	arena._set_up_the_match(false)
	arena.begin_match()

	# Let a few rallies play so the score is not 0-0 and the players are spread out.
	for r in range(4):
		arena._start_rally()
		var waited := 0
		while arena._phase != arena.Phase.AWAITING_CALL and waited < 3000:
			await get_tree().physics_frame
			waited += 1
		arena._make_call(&"in" if arena.rally.was_in else &"out")

	# Now catch one mid-flight.
	arena._start_rally()
	for f in 90:
		await get_tree().physics_frame

	for f in 4:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://dev/shots/_shot_match.png")
	print("saved, score RED %d - %d BLUE" % [
		arena.board.points[Sides.Team.RED], arena.board.points[Sides.Team.BLUE]
	])
	get_tree().quit()
