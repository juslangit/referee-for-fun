extends Node

## Photographs the panel the umpire accuses people from, and the aftermath of a red
## card handed out for nothing at all.

func _ready() -> void:
	var arena: Node = load("res://scenes/match.tscn").instantiate()
	arena.print_truth_while_testing = false
	add_child(arena)
	await get_tree().physics_frame
	arena._set_up_the_match(false)
	arena.begin_match()

	for r in range(3):
		arena._start_rally()
		var waited := 0
		while arena._phase != arena.Phase.AWAITING_CALL and waited < 3000:
			await get_tree().physics_frame
			waited += 1
		arena._make_call(&"in" if arena.rally.was_in else &"out")

	# A rally is on the table, so the full list is available.
	arena._start_rally()
	var waiting := 0
	while arena._phase != arena.Phase.AWAITING_CALL and waiting < 3000:
		await get_tree().physics_frame
		waiting += 1
	arena._open_fault_panel()

	for f in 5:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://dev/shots/_shot_faults.png")

	# Now do the worst thing available.
	arena._on_punishment_chosen(&"red", Sides.Team.BLUE)
	for f in 5:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://dev/shots/_shot_card.png")

	print("after one red card for nothing: suspicion %.3f, mood %s" % [
		arena.suspicion.level, Suspicion.Mood.keys()[arena.suspicion.mood]
	])
	print("saved")
	get_tree().quit()
