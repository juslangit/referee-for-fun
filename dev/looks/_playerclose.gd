extends Node

## A close look at the players under the hall's own lights, for judging their shading.
##
##     godot --path . res://dev/looks/_playerclose.tscn

func _ready() -> void:
	var arena: Node = load("res://scenes/match.tscn").instantiate()
	arena.print_truth_while_testing = false
	add_child(arena)
	await get_tree().physics_frame
	arena._set_up_the_match(false)
	arena.begin_match()
	for f in 30:
		await get_tree().physics_frame
	var figures: Array = get_tree().get_nodes_in_group("players")
	if figures.is_empty():
		figures = arena.find_children("*", "Player", true, false)
	var which := int(OS.get_environment("WHICH")) if not OS.get_environment("WHICH").is_empty() else 0
	var target: Node3D = figures[which % figures.size()]
	var cam := Camera3D.new()
	add_child(cam)
	cam.fov = 40.0
	cam.current = true
	# Follow it for a few frames: players are moving into position when the match opens.
	for f in 8:
		var at := target.global_position + Vector3(0, 0.95, 0)
		cam.global_position = at + Vector3(1.4, 0.35, 2.2)
		cam.look_at(at)
		await get_tree().process_frame
	print("looking at %s at %s" % [target.name, target.global_position])
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://dev/shots/_player_close.png")
	print("saved")
	get_tree().quit()
