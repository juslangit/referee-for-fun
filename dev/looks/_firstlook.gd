extends Node

## The two screens a first-timer has to understand, with nothing learned yet: the opening
## page of the lesson, and the moment the game first asks them for a call.

func _ready() -> void:
	var hall: Node = load("res://scenes/match.tscn").instantiate()
	hall.print_truth_while_testing = false
	add_child(hall)
	await get_tree().physics_frame
	hall.career = Career.start_again()
	hall.settings = Settings.new()          # nothing taught
	var ui: RefereeUI = hall.ui

	ui.hide_menus()
	ui.show_teaching(Career.BADMINTON)
	for f in 8:
		await get_tree().process_frame
	await _shot("res://dev/shots/_shot_first_lesson.png")

	# Into a rally, and stopped at the moment the call is wanted.
	ui.hide_teaching()
	ui.hide_menus()
	hall._on_match_requested()
	await get_tree().process_frame
	if hall.pressure.exists():
		ui.briefing_acknowledged.emit()
	hall.begin_match()
	for f in 6:
		await get_tree().physics_frame
	# The very first thing they see after the lesson: the chair, before anything moves.
	await _shot("res://dev/shots/_shot_first_view.png")
	print("camera pitch at match start: %.1f deg" % hall.camera.rotation_degrees.x)

	hall.start_rally()
	var waited := 0
	while hall._phase != hall.Phase.AWAITING_CALL and waited < 4000:
		await get_tree().physics_frame
		waited += 1
	print("reached the call after %d frames, phase %d" % [waited, hall._phase])
	for f in 6:
		await get_tree().process_frame
	await _shot("res://dev/shots/_shot_first_call.png")
	get_tree().quit()


func _shot(path: String) -> void:
	for f in 3:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
