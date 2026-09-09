extends Node

## The sport menu, now that there is more than one sport in it.

func _ready() -> void:
	var arena: Node = load("res://scenes/match.tscn").instantiate()
	arena.print_truth_while_testing = false
	add_child(arena)
	await get_tree().physics_frame
	arena.ui._main_menu.visible = false
	arena.ui.show_sport_menu()
	for f in 8:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://dev/shots/sports.png")
	print("saved")
	get_tree().quit()
