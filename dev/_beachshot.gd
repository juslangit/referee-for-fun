extends Node

## The beach match from the referee's stand, mid-rally.

func _ready() -> void:
	var arena: Node = load("res://scenes/beach.tscn").instantiate()
	arena.print_truth_while_testing = false
	add_child(arena)
	await get_tree().physics_frame

	# A few rallies so the score is not 0-0 and the players have moved.
	for r in 3:
		arena.start_rally()
		var waited := 0
		while arena._phase != arena.Phase.AWAITING_CALL and waited < 4000:
			await get_tree().physics_frame
			waited += 1
		arena._awaiting_since = Time.get_ticks_msec()
		arena.make_call(&"in" if arena.rally.was_in else &"out")

	# Catch one in the air.
	arena.start_rally()
	arena.ui.announce("", Color.WHITE)
	for f in 55:
		await get_tree().physics_frame
	await _shot("res://dev/shots/beach_rally.png")

	# And the moment of the call.
	var waited := 0
	while arena._phase != arena.Phase.AWAITING_CALL and waited < 4000:
		await get_tree().physics_frame
		waited += 1
	await _shot("res://dev/shots/beach_call.png")
	print("saved 2, score %d-%d" % [
		arena.board.points[Sides.Team.RED], arena.board.points[Sides.Team.BLUE]])
	get_tree().quit()


func _shot(path: String) -> void:
	for f in 6:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
