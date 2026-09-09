extends Node

## An indoor match from the stand: twelve players, two liberos, and the attack lines.

func _ready() -> void:
	var arena: Node = load("res://scenes/volleyball.tscn").instantiate()
	arena.print_truth_while_testing = false
	add_child(arena)
	await get_tree().physics_frame
	arena.career = Career.new()
	arena.career.sport = Career.INDOOR
	arena.career.tier = 3
	arena.settings.taught_indoor = true
	arena.ui.match_requested.emit()
	await get_tree().process_frame
	if arena.pressure.exists():
		arena.ui.briefing_acknowledged.emit()
		await get_tree().process_frame
	arena.begin_match()
	for f in 3:
		await get_tree().process_frame

	for r in 3:
		arena.start_rally()
		var waited := 0
		while arena._phase != arena.Phase.AWAITING_CALL and waited < 4000:
			await get_tree().physics_frame
			waited += 1
		arena._awaiting_since = Time.get_ticks_msec()
		arena.make_call(&"in" if arena.rally.was_in else &"out")
		for f in 6:
			await get_tree().process_frame

	# Lined up for the serve, which is the moment the rotation has to be read.
	arena.start_rally()
	arena.ui.announce("", Color.WHITE)
	for f in 10:
		await get_tree().physics_frame
	await _shot("res://dev/shots/indoor_serve.png")

	for f in 70:
		await get_tree().physics_frame
	await _shot("res://dev/shots/indoor_rally.png")
	print("saved 2")
	get_tree().quit()


func _shot(path: String) -> void:
	for f in 6:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
