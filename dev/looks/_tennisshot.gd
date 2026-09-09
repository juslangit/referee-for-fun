extends Node

## A tennis match from the chair: the service boxes, the sag in the net, and a ball
## being played off the bounce.

func _ready() -> void:
	var court: Node = load("res://scenes/tennis.tscn").instantiate()
	court.print_truth_while_testing = false
	add_child(court)
	await get_tree().physics_frame
	court.career = Career.new()
	court.career.sport = Career.TENNIS
	court.career.tier = 3
	court.settings.taught_tennis = true
	court.ui.match_requested.emit()
	await get_tree().process_frame
	if court.pressure.exists():
		court.ui.briefing_acknowledged.emit()
		await get_tree().process_frame
	court.begin_match()
	for f in 3:
		await get_tree().process_frame

	for r in 3:
		court.start_rally()
		var waited := 0
		while court._phase != court.Phase.AWAITING_CALL and waited < 4000:
			await get_tree().physics_frame
			waited += 1
		court._awaiting_since = Time.get_ticks_msec()
		court.make_call(&"in" if court.rally.was_in else &"out")
		for f in 8:
			await get_tree().process_frame

	court.start_rally()
	court.ui.announce("", Color.WHITE)
	for f in 8:
		await get_tree().physics_frame
	await _shot("res://dev/shots/tennis_serve.png")

	var waited := 0
	while court._phase == court.Phase.IN_PLAY and waited < 200:
		await get_tree().physics_frame
		waited += 1
	await _shot("res://dev/shots/tennis_call.png")
	print("court %.2f x %.2f m singles, %.2f wide for doubles" % [
		TennisSpec.HALF_WIDTH_SINGLES * 2.0, TennisSpec.HALF_LENGTH * 2.0,
		TennisSpec.HALF_WIDTH_DOUBLES * 2.0])
	print("score bug reads: %s" % court.board.called_score(court.serving))
	print("saved 2")
	get_tree().quit()


func _shot(path: String) -> void:
	for f in 6:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
