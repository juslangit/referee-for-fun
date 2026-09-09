extends Node3D

## Renders whatever Meshy has produced so far, side by side, with a metre reference.

func _ready() -> void:
	var here := DirAccess.open("res://assets/meshy")
	if here == null:
		print("nothing generated yet"); get_tree().quit(); return

	_light()
	var x := 0.0
	for folder in here.get_directories():
		for file in DirAccess.open("res://assets/meshy/%s" % folder).get_files():
			if not file.ends_with(".glb") or file.contains("_walking") or file.contains("_running"):
				continue
			var model: Node3D = load("res://assets/meshy/%s/%s" % [folder, file]).instantiate()
			add_child(model)
			await get_tree().process_frame
			var box := _measure(model)
			var scale_to := 1.0
			if box.size.y > 0.01:
				scale_to = 1.0 / box.size.y
			var bones := 0
			var clips: Array = []
			for node in _every(model):
				if node is Skeleton3D: bones = node.get_bone_count()
				if node is AnimationPlayer: clips = node.get_animation_list()
			print("%-30s %.2f x %.2f x %.2f m   %d bones   clips: %s" % [
				file, box.size.x, box.size.y, box.size.z, bones,
				", ".join(clips) if clips.size() else "none"])
			model.scale = Vector3.ONE * scale_to
			model.position = Vector3(x, -box.position.y * scale_to, 0)
			x += 1.3

	# A one-metre post, so the sizes can be read.
	var post := MeshInstance3D.new()
	var box_mesh := BoxMesh.new()
	box_mesh.size = Vector3(0.04, 1.0, 0.04)
	post.mesh = box_mesh
	post.position = Vector3(-0.9, 0.5, 0)
	add_child(post)

	var camera := Camera3D.new()
	add_child(camera)
	camera.position = Vector3(x * 0.5 - 0.9, 0.55, 3.4)
	camera.look_at(Vector3(x * 0.5 - 0.9, 0.55, 0), Vector3.UP)
	camera.current = true

	for f in 8: await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://dev/shots/_shot_meshy.png")
	print("saved")
	get_tree().quit()

func _light() -> void:
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.15, 0.16, 0.19)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.85, 0.85, 0.9)
	e.ambient_light_energy = 0.9
	var w := WorldEnvironment.new(); w.environment = e; add_child(w)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(deg_to_rad(-45), deg_to_rad(35), 0)
	sun.light_energy = 1.5
	add_child(sun)

func _measure(from: Node3D) -> AABB:
	var into := from.global_transform.affine_inverse()
	var box := AABB(); var started := false
	for child in _every(from):
		if child is MeshInstance3D and child.mesh != null:
			var placed: Node3D = child
			var driver: Node = child.get_node_or_null(child.skeleton)
			if driver is Skeleton3D: placed = driver
			var here: AABB = (into * placed.global_transform) * child.mesh.get_aabb()
			box = here if not started else box.merge(here); started = true
	return box

func _every(node: Node) -> Array:
	var f := [node]
	for c in node.get_children(): f.append_array(_every(c))
	return f
