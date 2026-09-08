extends Node

## The lesson, page by page, plus the first-run path: a player who has never been taught
## should meet it on the way to their first match without asking for it.

func _ready() -> void:
	var arena: Node = load("res://scenes/match.tscn").instantiate()
	add_child(arena)
	await get_tree().physics_frame
	arena.settings.taught = false

	# The route a first-timer takes: PLAY, then badminton.
	arena.ui.play_requested.emit()
	await get_tree().process_frame
	arena.ui.sport_chosen.emit(&"badminton")
	await get_tree().process_frame
	print("teaching shown unasked on a first career: %s" % arena.ui._teaching.visible)

	for page in RefereeUI.LESSONS.size():
		for f in 8:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("res://_shot_teach_%d.png" % page)
		if page < RefereeUI.LESSONS.size() - 1:
			arena.ui._lesson += 1
			arena.ui._draw_lesson()
			arena.ui._teaching.visible = true

	arena.ui.teaching_finished.emit()
	await get_tree().process_frame
	print("after GOT IT: teaching gone=%s, career screen up=%s, remembered=%s" % [
		not arena.ui._teaching.visible, arena.ui._career_panel.visible, arena.settings.taught])
	get_tree().quit()
