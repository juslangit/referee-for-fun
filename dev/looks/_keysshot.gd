extends Node

## The settings screen, now that the keys can be changed on it.

func _ready() -> void:
	var hall: Node = load("res://scenes/match.tscn").instantiate()
	hall.print_truth_while_testing = false
	add_child(hall)
	await get_tree().physics_frame
	hall.career = Career.new()
	hall.settings.taught = true
	hall.ui.hide_menus()
	hall.ui.show_settings(hall.settings, false)
	for f in 8:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://dev/shots/_shot_keys.png")
	get_tree().quit()
