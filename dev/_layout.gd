extends Node

## Looks down on the whole court so the seating can be checked at a glance.

func _ready() -> void:
	var arena: Node = load("res://scenes/match.tscn").instantiate()
	add_child(arena)
	await get_tree().physics_frame
	arena._on_length_chosen(false)
	arena.begin_match()
	arena.ui.visible = false

	for judge in arena.line_judges:
		print("%-16s watches %-6s  seat %v" % [judge.name, Sides.label(judge.watches), judge.position])
		judge.announce(judge.watches == Sides.Team.BLUE)

	var wanted := OS.get_environment("TIER")
	if not wanted.is_empty():
		arena.court.dress(int(wanted))
		arena.court.stands.set_density([0.25, 0.7, 1.0][int(wanted)])
	# The roof comes off for this shot. It is a solid lid over the whole hall, and an
	# overhead camera outside it photographs the top of the lid.
	for node in arena.court.get_children():
		if node.name.begins_with("Ceiling"):
			(node as Node3D).visible = false

	arena.camera.current = false
	var above := Camera3D.new()
	above.fov = 62.0
	arena.add_child(above)
	# Back far enough to take in the second court and the far stand as well, since the
	# whole point of this shot is checking that everything got built.
	above.global_position = Vector3(7.0, 20.0, 23.0)
	above.look_at(Vector3(5.0, 0.5, -1.0), Vector3.UP)
	above.current = true

	for f in 8:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://_shot_layout%s.png" % OS.get_environment("TIER"))
	print("saved")
	get_tree().quit()
