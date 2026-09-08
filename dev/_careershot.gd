extends Node

## Photographs the career screen at the bottom of the ladder and part way up it, and
## the screen you get when a match has just cost you something.

func _ready() -> void:
	var arena: Node = load("res://scenes/match.tscn").instantiate()
	arena.print_truth_while_testing = false
	add_child(arena)
	await get_tree().physics_frame

	await _shot(arena, "res://_shot_career_start.png")

	arena.career.tier = 3
	arena.career.reputation = 0.58
	arena.career.matches_refereed = 9
	arena.career.matches_at_tier = 1
	arena.ui.show_career(arena.career)
	await _shot(arena, "res://_shot_career_up.png")

	# Now play out the end of a match that went badly.
	arena.ui.show_career(arena.career)
	arena._on_match_requested()
	arena._on_favour_chosen(Sides.Team.RED)
	arena.suspicion.level = 0.62
	arena.suspicion.lean = -0.74
	arena.suspicion.wrong_calls = 7
	arena.suspicion.stolen_rallies = 5
	arena.board.points[Sides.Team.RED] = 21
	arena.board.points[Sides.Team.BLUE] = 17
	arena._finish_match("RED WIN THE MATCH", Sides.colour(Sides.Team.RED), false)
	await _shot(arena, "res://_shot_career_result.png")

	print("reputation after that match: %d / 100" % roundi(arena.career.reputation * 100.0))
	Career.start_again().save()
	print("saved career reset for you")
	print("saved")
	get_tree().quit()


func _shot(arena: Node, path: String) -> void:
	for f in 6:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
