extends Node

## The three front-of-game screens, photographed in the order a player meets them.

func _ready() -> void:
	var arena: Node = load("res://scenes/match.tscn").instantiate()
	add_child(arena)
	await get_tree().physics_frame
	arena.court.dress(Venue.Tier.ARENA)
	arena.court.stands.set_density(1.0)
	await _shot("res://_shot_menu_main.png")

	arena.ui.play_requested.emit()
	await _shot("res://_shot_menu_sport.png")

	arena.ui.main_menu_requested.emit()
	arena.ui.settings_requested.emit()
	await _shot("res://_shot_menu_settings.png")
	print("saved")
	get_tree().quit()

func _shot(path: String) -> void:
	for f in 8:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
