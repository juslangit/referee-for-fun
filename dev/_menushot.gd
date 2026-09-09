extends Node

## The front of the game and the pause menu.

func _ready() -> void:
	var arena: Node = load("res://scenes/match.tscn").instantiate()
	arena.print_truth_while_testing = false
	add_child(arena)
	await get_tree().physics_frame
	await _shot("res://_shot_menu.png")

	# Part way into a career, so the menu has something to offer.
	arena.career.matches_refereed = 5
	arena.career.tier = 2
	arena.career.reputation = 0.71
	arena.ui.show_main_menu(arena.career)
	await _shot("res://_shot_menu_career.png")

	arena.ui._main_menu.visible = false
	arena._on_match_requested()
	# Whoever is leaning on you this week has their say first, and the briefing has to be
	# acknowledged rather than left standing — going straight to begin_match left it on
	# screen for the whole run, and the pause menu was then photographed underneath it.
	if arena.pressure.exists():
		arena.ui.hide_briefing()
	arena.begin_match()

	# Paused before a single call has been made, which is the only time the game offers
	# a way back to the menu that costs nothing.
	arena._pause()
	await _shot("res://_shot_pause_early.png")
	get_tree().paused = false
	arena.ui.hide_pause_menu()

	for r in range(2):
		arena._start_rally()
		var waited := 0
		while arena._phase != arena.Phase.AWAITING_CALL and waited < 3000:
			await get_tree().physics_frame
			waited += 1
		arena._make_call(&"in" if arena.rally.was_in else &"out")
	arena._pause()
	await _shot("res://_shot_pause.png")

	get_tree().paused = false
	Career.start_again().save()
	print("saved")
	get_tree().quit()


func _shot(path: String) -> void:
	for f in 6:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
