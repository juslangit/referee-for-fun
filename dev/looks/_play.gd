extends Node

## The game exactly as a player reaches it: main menu, career screen, then the button
## that starts a match. No shortcuts — the debug scenes call the inner functions
## directly, which is precisely how a broken menu path would go unnoticed.

func _ready() -> void:
	var arena: Node = load("res://scenes/match.tscn").instantiate()
	add_child(arena)
	await get_tree().physics_frame
	print("career tier %d — %s" % [arena.career.tier, arena.career.venue()["name"]])

	# The two buttons a player actually presses.
	arena.ui.career_screen_requested.emit()
	await get_tree().process_frame
	arena.ui.match_requested.emit()
	for f in 10:
		await get_tree().process_frame

	print("dressing now %d, shuttle cam %s, run-off colour %s" % [
		arena.court.venue.tier, arena.has_shuttle_cam,
		arena.court.get_node("RunOff").material_override.albedo_color])
	arena.ui.visible = false
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://dev/shots/_shot_play.png")
	print("saved")
	get_tree().quit()
