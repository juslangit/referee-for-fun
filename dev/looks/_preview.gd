extends Node3D

## Lines up the downloaded models so they can be looked at and measured. Scale and
## orientation from Sketchfab are anybody's guess, so both get reported.

const MODELS := [
	"res://assets/sketchfab/pro_badminton_player_animation/pro_badminton_player_animation.glb",
	"res://assets/sketchfab/olympic_athlete/olympic_athlete.glb",
	"res://assets/sketchfab/athlete_ussr/athlete_ussr.glb",
	"res://assets/sketchfab/female_athlete_ussr/female_athlete_ussr.glb",
]

func _ready() -> void:
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.16, 0.17, 0.20)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.8, 0.8, 0.85)
	environment.ambient_light_energy = 1.0
	var world := WorldEnvironment.new()
	world.environment = environment
	add_child(world)

	var key := DirectionalLight3D.new()
	key.rotation = Vector3(deg_to_rad(-40.0), deg_to_rad(35.0), 0.0)
	key.light_energy = 1.4
	add_child(key)

	var x := 0.0
	for path in MODELS:
		var scene := load(path)
		if scene == null:
			print("could not load ", path)
			continue
		var model: Node3D = scene.instantiate()
		add_child(model)
		model.position = Vector3(x, 0.0, 0.0)

		var box := _bounds(model)
		var animations := _animation_names(model)
		print("%-34s size %6.2f x %6.2f x %6.2f   bottom y %+.2f   %s" % [
			path.get_file(), box.size.x, box.size.y, box.size.z, box.position.y,
			("animations: " + ", ".join(animations)) if not animations.is_empty() else "no animations",
		])
		x += 2.5

	var camera := Camera3D.new()
	camera.fov = 42.0
	add_child(camera)
	camera.global_position = Vector3(3.7, 1.4, 7.0)
	camera.look_at(Vector3(3.7, 0.9, 0.0), Vector3.UP)
	camera.current = true

	for f in 8:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://dev/shots/_shot_models.png")
	print("saved")
	get_tree().quit()


func _bounds(node: Node) -> AABB:
	var box := AABB()
	var started := false
	for child in _every(node):
		if child is MeshInstance3D and child.mesh != null:
			var here: AABB = child.global_transform * child.mesh.get_aabb()
			box = here if not started else box.merge(here)
			started = true
	return box


func _animation_names(node: Node) -> Array:
	for child in _every(node):
		if child is AnimationPlayer:
			return child.get_animation_list()
	return []


func _every(node: Node) -> Array:
	var found := [node]
	for child in node.get_children():
		found.append_array(_every(child))
	return found
