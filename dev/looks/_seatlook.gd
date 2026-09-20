extends Node

## One seat model, alone and large, from three angles. `_seatpick` puts the candidates in
## a row, which is enough to tell them apart and not enough to judge one.

func _ready() -> void:
	var path := OS.get_environment("MODEL")
	var tag := OS.get_environment("TAG")
	var world := Node3D.new()
	add_child(world)

	var key := DirectionalLight3D.new()
	key.rotation = Vector3(deg_to_rad(-40.0), deg_to_rad(38.0), 0.0)
	key.light_energy = 1.6
	world.add_child(key)

	var sky := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.20, 0.22, 0.26)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.78, 0.82, 0.90)
	env.ambient_light_energy = 0.8
	sky.environment = env
	world.add_child(sky)

	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(60, 60)
	ground.mesh = plane
	var grey := StandardMaterial3D.new()
	grey.albedo_color = Color(0.38, 0.40, 0.44)
	ground.material_override = grey
	world.add_child(ground)

	# Left as it comes out of the file, at its own scale, so nothing about it is hidden
	# by a correction that might itself be wrong.
	var model: Node3D = load(path).instantiate()
	world.add_child(model)
	await get_tree().process_frame
	var box := _bounds(model)
	print("%s: %.2f wide, %.2f tall, %.2f deep, centred at %.2f,%.2f,%.2f" % [
		tag, box.size.x, box.size.y, box.size.z,
		box.get_center().x, box.get_center().y, box.get_center().z])

	var eye := Camera3D.new()
	eye.fov = 45.0
	eye.current = true
	world.add_child(eye)

	var reach := maxf(box.size.x, maxf(box.size.y, box.size.z)) * 1.5
	var angles := {"front": Vector3(0.1, 0.45, 1.0), "side": Vector3(1.0, 0.40, 0.15),
		"above": Vector3(0.6, 0.95, 0.8)}
	for name in angles:
		var from: Vector3 = box.get_center() + (angles[name] as Vector3).normalized() * reach
		eye.look_at_from_position(from, box.get_center(), Vector3.UP)
		for f in 4:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png(
			"res://dev/shots/seat_%s_%s.png" % [tag, name])
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
