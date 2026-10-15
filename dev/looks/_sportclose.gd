extends Node

## A close look at a player in any sport's hall, for checking what is in their hand.
##
##     SCENE=tennis WHICH=0 godot --path . res://dev/looks/_sportclose.tscn

func _ready() -> void:
	var name := OS.get_environment("SCENE") if OS.has_environment("SCENE") else "tennis"
	var arena: Node = load("res://scenes/%s.tscn" % name).instantiate()
	if "print_truth_while_testing" in arena:
		arena.print_truth_while_testing = false
	add_child(arena)
	await get_tree().physics_frame
	if arena.has_method("_set_up_the_match"):
		arena._set_up_the_match(false)
	if arena.has_method("begin_match"):
		arena.begin_match()
	for f in 60:
		await get_tree().physics_frame
	var figures: Array = []
	for node in arena.find_children("*", "Node3D", true, false):
		if node.has_meta("racket"):
			figures.append(node)
	print("%d figures holding something" % figures.size())
	if figures.is_empty():
		get_tree().quit()
		return
	var which := int(OS.get_environment("WHICH")) if OS.has_environment("WHICH") else 0
	var target: Node3D = figures[which % figures.size()]
	var held: Node3D = target.get_meta("racket")
	for layer in arena.find_children("*", "CanvasLayer", true, false):
		(layer as CanvasLayer).visible = false
	var cam := Camera3D.new()
	add_child(cam)
	cam.fov = 35.0
	cam.current = true
	for f in 8:
		var at := held.global_position.lerp(target.global_position + Vector3(0, 1.0, 0), 0.5)
		cam.global_position = at + Vector3(1.3, 0.3, 1.9)
		cam.look_at(at)
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://dev/shots/_close_%s.png" % name)
	print("saved")
	get_tree().quit()
