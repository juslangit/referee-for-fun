extends Node

## Which way the chair is pointing, against the person sitting in it.
##
##   godot --path . res://dev/looks/_seatfacing.tscn --quit-after 900
##
## Luqman on 2026-09-21, looking at the front row from the court: *"the audience bench is
## not right, rotate it so it facing camera."*
##
## The seat and the person are turned by two separate numbers — `CROWD_FACING` for the
## chair and `PERSON_FACING` for the body — because they came from different places and
## neither model says which way it calls forward. When the crowd stopped being downloaded
## figures and became the forge's own spectator on 2026-09-20, the person got a new number
## and the chair kept the old one. If the two models agree about forward, the chair is now
## half a turn out and the row is a set of seats with their backs to the court.
##
## Four chairs, one person each, from where the umpire sits. The right one is the chair
## whose back is behind the person rather than in front of them.

const YAWS := [0.0, 90.0, 180.0, 270.0]


func _ready() -> void:
	var world := Node3D.new()
	add_child(world)

	var key := DirectionalLight3D.new()
	key.rotation = Vector3(deg_to_rad(-38.0), deg_to_rad(28.0), 0.0)
	key.light_energy = 1.5
	world.add_child(key)
	var sky := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.16, 0.18, 0.22)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.80, 0.84, 0.90)
	env.ambient_light_energy = 0.9
	sky.environment = env
	world.add_child(sky)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(40, 40)
	ground.mesh = plane
	var grey := StandardMaterial3D.new()
	grey.albedo_color = Color(0.34, 0.36, 0.40)
	ground.material_override = grey
	world.add_child(ground)

	for i in YAWS.size():
		var at := Vector3(-2.4 + i * 1.6, 0.0, 0.0)

		# The chair, turned by the candidate yaw.
		var chair := Props.node(Props.SEAT, Stands.SEAT_HEIGHT, Props.turned(YAWS[i]))
		if chair != null:
			chair.position = at
			world.add_child(chair)

		# The person, turned by the number the crowd actually uses, and only on the back
		# row — the front row is the chair on its own, because a body in the seat hides
		# the very thing being judged.
		if OS.has_environment("WITH_PEOPLE"):
			var sitter: Node3D = load("res://assets/characters/crowd_a_sit.glb").instantiate()
			sitter.position = at
			sitter.rotation.y = deg_to_rad(Stands.PERSON_FACING)
			world.add_child(sitter)

		# A marker at the chair's own -Z, which is the direction the forge's spectator
		# faces. If the chair is right, this pole stands in front of the seat.
		var pole := MeshInstance3D.new()
		var rod := BoxMesh.new()
		rod.size = Vector3(0.06, 0.9, 0.06)
		pole.mesh = rod
		var gold := StandardMaterial3D.new()
		gold.albedo_color = Color(0.95, 0.76, 0.30)
		pole.material_override = gold
		pole.position = at + Vector3(0.0, 0.45, 0.0) + Basis(
			Vector3.UP, deg_to_rad(YAWS[i])) * Vector3(0.0, 0.0, -0.75)
		world.add_child(pole)

		var label := Label3D.new()
		label.text = "chair %d°" % int(YAWS[i])
		label.font_size = 44
		label.pixel_size = 0.0024
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.position = at + Vector3(0.0, 1.75, 0.0)
		world.add_child(label)

	var eye := Camera3D.new()
	eye.look_at_from_position(Vector3(0.0, 1.35, 3.6), Vector3(0.0, 0.7, 0.0), Vector3.UP)
	eye.fov = 48.0
	eye.current = true
	world.add_child(eye)

	for f in 12:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://dev/shots/seat_facing.png")
	print("saved; the crowd currently uses chair %d deg" % int(Stands.CROWD_FACING))
	get_tree().quit()
