extends Node

## The opening sequence, photographed: the loading screen, the title card, and the menu
## the key press reveals.

func _ready() -> void:
	var boot: Node = load("res://scenes/boot.tscn").instantiate()
	add_child(boot)
	# Early enough to catch the bar before the hall is built.
	await get_tree().process_frame
	await get_tree().process_frame
	await _shot("res://dev/shots/_shot_boot_loading.png")

	var waited := 0
	while boot.is_waiting() == false and waited < 900:
		await get_tree().process_frame
		waited += 1
	print("waiting for a key after %d frames: %s" % [waited, boot.is_waiting()])
	await _shot("res://dev/shots/_shot_boot_card.png")

	var press := InputEventKey.new()
	press.keycode = KEY_SPACE
	press.pressed = true
	Input.parse_input_event(press)
	await get_tree().create_timer(0.6).timeout
	print("still waiting after the key: %s" % boot.is_waiting())
	await _shot("res://dev/shots/_shot_boot_menu.png")
	get_tree().quit()


func _shot(path: String) -> void:
	for f in 3:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
