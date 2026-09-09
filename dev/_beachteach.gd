extends Node

## The beach lesson, and a review on screen.

func _ready() -> void:
	var arena: Node = load("res://scenes/beach.tscn").instantiate()
	arena.print_truth_while_testing = false
	add_child(arena)
	await get_tree().physics_frame

	# Page three, which is the one the sport turns on.
	# _draw_lesson rebuilds the panel, and a freshly built sheet starts hidden — so the
	# page has to be chosen before it is shown, not after. show_teaching does it in that
	# order; doing it the other way round photographs an empty court.
	arena.ui.show_teaching(Career.BEACH)
	arena.ui._lesson = 2
	arena.ui._draw_lesson()
	arena.ui._teaching.visible = true
	await _shot("res://dev/shots/beach_lesson.png")
	arena.ui.hide_teaching()

	# And a review, staged on a ball sitting on the end line.
	arena.career = Career.new()
	arena.career.sport = Career.BEACH
	arena.career.tier = 3
	arena.settings.taught_beach = true
	arena.ui.match_requested.emit()
	await get_tree().process_frame
	if arena.pressure.exists():
		arena.ui.briefing_acknowledged.emit()
		await get_tree().process_frame
	for f in 3:
		await get_tree().process_frame

	var on_the_line := Vector3(1.2, BeachCourt.SURFACE_Y, BeachSpec.HALF_LENGTH - 0.02)
	arena._ball.freeze = true
	arena._ball.global_position = on_the_line + Vector3(0.0, Ball.RADIUS, 0.0)
	for f in 3:
		await get_tree().physics_frame
	arena.ball_cam.aim_at(on_the_line)
	arena.ui.show_review(Sides.Team.RED, 1, arena.ball_cam.texture())
	arena.ui.set_review_verdict("TOUCHED  ·  CALL OVERTURNED", Color(0.96, 0.42, 0.36))
	await _shot("res://dev/shots/beach_review.png")

	print("saved 2")
	get_tree().quit()


func _shot(path: String) -> void:
	for f in 8:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
