extends Node3D

const CANDIDATES := [
	"res://assets/sketchfab/simple_character/simple_character.glb",
	"res://assets/sketchfab/lowpoly_simple_character/lowpoly_simple_character.glb",
	"res://assets/sketchfab/simple_low_poly_character/simple_low_poly_character.glb",
]

func _ready() -> void:
	_light()
	var x := 0.0
	for path in CANDIDATES:
		if not ResourceLoader.exists(path):
			print(path.get_file(), " MISSING"); continue
		var model: Node3D = load(path).instantiate()
		add_child(model)
		await get_tree().process_frame
		var box := _measure(model)
		var tris := 0
		var bones := 0
		var clips: Array = []
		for n in _every(model):
			if n is MeshInstance3D and n.mesh != null:
				for s in n.mesh.get_surface_count():
					tris += n.mesh.surface_get_arrays(s)[Mesh.ARRAY_INDEX].size() / 3
			if n is Skeleton3D: bones = n.get_bone_count()
			if n is AnimationPlayer: clips = n.get_animation_list()
		print("%-34s %.2f m tall, %d tris, %d bones, clips: %s" % [
			path.get_file(), box.size.y, tris, bones,
			", ".join(clips) if clips.size() else "none"])
		# No auto-fit. Skinned meshes report nonsense bounds and the fit turned one
		# candidate into a black wall and another into a speck.
		model.position = Vector3(x, 0, 0)
		x += 2.4

	var cam := Camera3D.new(); add_child(cam)
	cam.position = Vector3(x * 0.5 - 1.2, 1.0, 6.0)
	cam.look_at(Vector3(x * 0.5 - 1.2, 0.9, 0), Vector3.UP)
	cam.current = true
	for f in 8: await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://dev/shots/_shot_crowdpick.png")
	print("saved")
	get_tree().quit()

func _light() -> void:
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.15, 0.16, 0.19)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.9, 0.9, 0.95); e.ambient_light_energy = 1.0
	var w := WorldEnvironment.new(); w.environment = e; add_child(w)
	var s := DirectionalLight3D.new(); s.rotation = Vector3(deg_to_rad(-45), deg_to_rad(30), 0)
	s.light_energy = 1.4; add_child(s)

func _measure(from: Node3D) -> AABB:
	var into := from.global_transform.affine_inverse()
	var box := AABB(); var started := false
	for c in _every(from):
		if c is MeshInstance3D and c.mesh != null:
			var placed: Node3D = c
			var d: Node = c.get_node_or_null(c.skeleton)
			if d is Skeleton3D: placed = d
			var h: AABB = (into * placed.global_transform) * c.mesh.get_aabb()
			box = h if not started else box.merge(h); started = true
	return box

func _every(node: Node) -> Array:
	var f := [node]
	for c in node.get_children(): f.append_array(_every(c))
	return f
