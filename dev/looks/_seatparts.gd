extends Node

## Every separate object inside the arena-seats model, laid out in a grid and scaled to
## the same height, with its node name under it.
##
## The file is a SketchUp sample board: one long concrete plinth with half a dozen
## different seats stood on it, not a row of one seat. To use it, one seat has to be
## picked out by name, and the names are `instance_0` to `instance_21`.

const MODEL := "res://assets/sketchfab/low_poly_stadium_sports_arena_seats/low_poly_stadium_sports_arena_seats.glb"
const ACROSS := 6
const STEP := 1.3
const HEIGHT := 0.9


func _ready() -> void:
	var world := Node3D.new()
	add_child(world)

	var key := DirectionalLight3D.new()
	key.rotation = Vector3(deg_to_rad(-42.0), deg_to_rad(35.0), 0.0)
	key.light_energy = 1.5
	world.add_child(key)

	var sky := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.20, 0.22, 0.26)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.80, 0.84, 0.92)
	env.ambient_light_energy = 0.85
	sky.environment = env
	world.add_child(sky)

	var source: Node3D = load(MODEL).instantiate()
	add_child(source)
	await get_tree().process_frame

	var parts: Array[Node3D] = []
	for node in _every(source):
		if node is Node3D and String(node.name).begins_with("instance_"):
			parts.append(node as Node3D)

	var placed := 0
	for part in parts:
		var holder := Node3D.new()
		world.add_child(holder)
		var copy: Node3D = part.duplicate()
		# Flattened out of its parents' transforms, so every part is treated the same way
		# whatever depth it was found at.
		copy.transform = Transform3D.IDENTITY
		holder.add_child(copy)
		await get_tree().process_frame

		var box := _bounds(holder)
		if box.size.y <= 0.001 or box.size.length() <= 0.001:
			holder.queue_free()
			print("%-12s nothing to show" % part.name)
			continue
		var fit := HEIGHT / box.size.y
		holder.scale = Vector3.ONE * fit
		holder.position = Vector3(
			(placed % ACROSS) * STEP - (ACROSS - 1) * STEP * 0.5,
			-box.position.y * fit,
			int(placed / ACROSS) * STEP)

		var label := Label3D.new()
		label.text = String(part.name)
		label.font_size = 40
		label.pixel_size = 0.0022
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.position = holder.position + Vector3(0.0, HEIGHT + 0.12, 0.0)
		world.add_child(label)
		placed += 1

	print("%d parts laid out" % placed)
	source.visible = false

	var eye := Camera3D.new()
	eye.look_at_from_position(Vector3(0.0, 4.4, 5.6), Vector3(0.0, 0.3, 0.6), Vector3.UP)
	eye.fov = 52.0
	eye.current = true
	world.add_child(eye)

	for f in 10:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://dev/shots/seat_parts.png")
	print("saved")
	get_tree().quit()


func _bounds(node: Node) -> AABB:
	var box := AABB()
	var started := false
	for child in _every(node):
		if not (child is MeshInstance3D):
			continue
		var piece := child as MeshInstance3D
		if piece.mesh == null:
			continue
		var here := piece.global_transform * piece.mesh.get_aabb()
		box = here if not started else box.merge(here)
		started = true
	return box


func _every(node: Node) -> Array[Node]:
	var all: Array[Node] = []
	for child in node.get_children():
		all.append(child)
		all.append_array(_every(child))
	return all
