extends Node

## Why does a material override not draw on these characters?
##
##   godot --path . res://dev/looks/_overridetest.tscn --quit-after 900
##
## Open since 2026-09-17 (D-072): setting `material_override` on a built player was
## verified set, on the right node, on a rendered layer, with no competitor — and the
## figure came back its original colour every time. The cause was never found and the
## workaround was a second character file per kit.
##
## Four figures, four ways of asking, side by side, so the answer is which one turns
## magenta rather than an argument about which should:
##
##   1  left alone
##   2  `material_override` set immediately after the model is added
##   3  `material_override` set **a frame later**, after `Models.settle` has run
##   4  `set_surface_override_material` on every surface, a frame later
##
## Three is the one to watch. Every figure in this game is sized by a `settle` that runs
## on the frame after the body is built — see `Player._settle_when_posed` — and anything
## done to the model before that has a frame in which to be undone.

func _ready() -> void:
	var world := Node3D.new()
	add_child(world)

	var key := DirectionalLight3D.new()
	key.rotation = Vector3(deg_to_rad(-40.0), deg_to_rad(32.0), 0.0)
	key.light_energy = 1.5
	world.add_child(key)
	var sky := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.18, 0.20, 0.24)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.8, 0.84, 0.9)
	env.ambient_light_energy = 0.85
	sky.environment = env
	world.add_child(sky)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(40, 40)
	ground.mesh = plane
	var grey := StandardMaterial3D.new()
	grey.albedo_color = Color(0.4, 0.42, 0.46)
	ground.material_override = grey
	world.add_child(ground)

	var magenta := StandardMaterial3D.new()
	magenta.albedo_color = Color(1.0, 0.0, 0.8)

	# The fifth is the one that matters: a real `Player`, built the way a match builds it,
	# because D-072's claim was about a **built figure** and not about a loaded model.
	var built := Player.new()
	built.team = Sides.Team.BLUE
	built.position = Vector3(-2.7 + 4 * 1.8, 0.0, 0.0)
	world.add_child(built)
	# A `Player` does not build itself. Nothing happens until a match calls this, which is
	# why the first run of this test found a figure with **no meshes in it at all**.
	built._build_body()
	var built_label := Label3D.new()
	built_label.text = "5 a real Player"
	built_label.font_size = 40
	built_label.pixel_size = 0.0024
	built_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	built_label.position = built.position + Vector3(0.0, 2.1, 0.0)
	world.add_child(built_label)

	var labels := ["1 untouched", "2 override now", "3 override next frame", "4 per surface"]
	var models: Array[Node3D] = []
	for i in 4:
		var model := Models.player(Sides.Team.BLUE)
		if model == null:
			print("no player model to test")
			get_tree().quit()
			return
		model.position = Vector3(-2.7 + i * 1.8, 0.0, 0.0)
		model.rotation.y = PI
		world.add_child(model)
		models.append(model)

		if i == 1:
			_paint(model, magenta, false)

		var label := Label3D.new()
		label.text = labels[i]
		label.font_size = 40
		label.pixel_size = 0.0024
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.position = model.position + Vector3(0.0, 2.1, 0.0)
		world.add_child(label)

	await get_tree().process_frame
	await get_tree().process_frame
	_paint(models[2], magenta, false)
	_paint(models[3], magenta, true)
	for f in 4:
		await get_tree().process_frame
	_paint(built, magenta, false)
	models.append(built)
	labels.append("5 a real Player")

	var eye := Camera3D.new()
	eye.look_at_from_position(Vector3(0.9, 1.5, 5.4), Vector3(0.9, 0.95, 0.0), Vector3.UP)
	eye.fov = 50.0
	eye.current = true
	world.add_child(eye)

	for f in 10:
		await get_tree().process_frame

	# What the scene actually holds, printed, because the picture says which one worked
	# and only this says why.
	for i in models.size():
		var pieces := 0
		var overridden := 0
		var surfaced := 0
		for node in _every(models[i]):
			if not (node is MeshInstance3D):
				continue
			var piece := node as MeshInstance3D
			pieces += 1
			if piece.material_override != null:
				overridden += 1
			for s in piece.get_surface_override_material_count():
				if piece.get_surface_override_material(s) != null:
					surfaced += 1
		print("%-24s %d mesh(es), %d with material_override, %d surface overrides" % [
			labels[i], pieces, overridden, surfaced])
		for node in _every(models[i]):
			if not (node is MeshInstance3D):
				continue
			var piece := node as MeshInstance3D
			print("      %-22s visible=%s inTree=%s layers=%d at %.2f,%.2f,%.2f scale %.2f" % [
				piece.name, piece.visible, piece.is_visible_in_tree(), piece.layers,
				piece.global_position.x, piece.global_position.y, piece.global_position.z,
				piece.global_basis.get_scale().y])

	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://dev/shots/override_test.png")
	print("saved")
	get_tree().quit()


func _paint(model: Node3D, paint: Material, per_surface: bool) -> void:
	for node in _every(model):
		if not (node is MeshInstance3D):
			continue
		var piece := node as MeshInstance3D
		if per_surface:
			for s in piece.get_surface_override_material_count():
				piece.set_surface_override_material(s, paint)
		else:
			piece.material_override = paint


func _every(node: Node) -> Array[Node]:
	var all: Array[Node] = []
	for child in node.get_children():
		all.append(child)
		all.append_array(_every(child))
	return all
