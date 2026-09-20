extends Node

## The net, close up, from the umpire's side — the thing an umpire looks through all match.

func _ready() -> void:
	var scene := OS.get_environment("SCENE")
	if scene.is_empty():
		scene = "res://scenes/match.tscn"
	var hall: Node = load(scene).instantiate()
	hall.print_truth_while_testing = false
	add_child(hall)
	await get_tree().physics_frame
	hall.career = Career.new()
	hall.ui.hide_menus()
	hall.ui.show_hud(false)

	var eye := Camera3D.new()
	hall.add_child(eye)
	# Aimed at the top of this sport's net rather than badminton's. A volleyball net is
	# 2.43 m and a table tennis one 15 cm; one fixed camera cannot see both.
	var top := float(OS.get_environment("NET_TOP")) if OS.has_environment("NET_TOP") else 1.2
	eye.look_at_from_position(
		Vector3(top * 1.8, top * 1.1, top * 1.7), Vector3(0.0, top * 0.8, 0.0), Vector3.UP)
	eye.fov = 45.0
	eye.current = true
	for f in 10:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://dev/shots/_shot_net%s.png" % OS.get_environment("TAG"))
	get_tree().quit()
