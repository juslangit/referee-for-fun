extends Node

## Looks down on the whole court so the seating can be checked at a glance.

func _ready() -> void:
	var arena: Node = load("res://scenes/match.tscn").instantiate()
	add_child(arena)
	await get_tree().physics_frame
	arena._on_length_chosen(false)
	arena._on_favour_chosen(Sides.Team.NONE)
	arena.ui.visible = false

	for judge in arena.line_judges:
		print("%-16s watches %-6s  seat %v" % [judge.name, Sides.label(judge.watches), judge.position])
		judge.announce(judge.watches == Sides.Team.BLUE)

	arena.camera.current = false
	var above := Camera3D.new()
	above.fov = 74.0
	arena.add_child(above)
	above.global_position = Vector3(8.2, 7.4, 0.0)
	above.look_at(Vector3(-0.5, 0.4, 0.0), Vector3.UP)
	above.current = true

	for f in 8:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://_shot_layout.png")
	print("saved")
	get_tree().quit()
