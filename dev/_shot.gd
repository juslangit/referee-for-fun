extends Node

## Loads the match scene, lets it settle, and saves what the umpire sees to a PNG.
## Handy for checking the view from the chair without opening the editor.

@export var frames_to_settle := 12

func _ready() -> void:
	add_child(load("res://scenes/match.tscn").instantiate())
	for i in frames_to_settle:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var image := get_viewport().get_texture().get_image()
	image.save_png("res://_shot.png")
	print("saved _shot.png")
	get_tree().quit()
