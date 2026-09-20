extends Node

## The baked crowd, side by side: the same two people sitting, leaning and on their feet.
##
## A MultiMesh cannot pose a skeleton, so a seated spectator has to arrive already
## seated. These come out of tools/blender/crowd_poses.py, which freezes the forge's
## spectator in a pose and applies the armature modifier.

const POSES := ["sit", "lean", "stand"]
const PEOPLE := ["crowd_a", "crowd_b"]


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
	env.background_color = Color(0.18, 0.20, 0.24)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.78, 0.82, 0.90)
	env.ambient_light_energy = 0.8
	sky.environment = env
	world.add_child(sky)

	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(40, 40)
	ground.mesh = plane
	var grey := StandardMaterial3D.new()
	grey.albedo_color = Color(0.40, 0.42, 0.46)
	ground.material_override = grey
	world.add_child(ground)

	for p in PEOPLE.size():
		for s in POSES.size():
			var path := "res://assets/characters/%s_%s.glb" % [PEOPLE[p], POSES[s]]
			if not ResourceLoader.exists(path):
				print("missing %s" % path)
				continue
			var person: Node3D = load(path).instantiate()
			person.position = Vector3(-1.5 + s * 1.5, 0.0, p * 1.6)
			person.rotation.y = PI
			world.add_child(person)

			# A seat under them, at the size and height the stands use, so a pose that
			# floats or sinks shows up here rather than in the hall.
			var seat := Props.node(Props.SEAT, Stands.SEAT_HEIGHT,
				Props.turned(Stands.CROWD_FACING), )
			if seat != null:
				seat.position = person.position
				world.add_child(seat)

			var label := Label3D.new()
			label.text = "%s %s" % [PEOPLE[p], POSES[s]]
			label.font_size = 36
			label.pixel_size = 0.0022
			label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			label.position = person.position + Vector3(0.0, 2.1, 0.0)
			world.add_child(label)

	var eye := Camera3D.new()
	eye.look_at_from_position(Vector3(0.0, 1.9, 4.6), Vector3(0.0, 0.9, 0.6), Vector3.UP)
	eye.fov = 48.0
	eye.current = true
	world.add_child(eye)

	for f in 12:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://dev/shots/crowd_poses.png")
	print("saved")
	get_tree().quit()
