extends Node

## The tennis serve, held at each of its five shapes.
##
## Poses are authored blind, as numbers in a Python file, so this is the only way to find
## out whether "racket dropped behind the head, elbow high" produced that. The volleyball
## set needed three attempts and the first two were a man standing with his hands by his
## hips.

const AT := [
	[0.0 / 24.0, "stance"],
	[8.0 / 24.0, "toss"],
	[16.0 / 24.0, "trophy"],
	[22.0 / 24.0, "contact"],
	[34.0 / 24.0, "through"],
]


func _ready() -> void:
	var world := Node3D.new()
	add_child(world)

	var light := DirectionalLight3D.new()
	light.rotation = Vector3(deg_to_rad(-42.0), deg_to_rad(24.0), 0.0)
	light.light_energy = 1.4
	world.add_child(light)

	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(40, 40)
	ground.mesh = plane
	var court := StandardMaterial3D.new()
	court.albedo_color = Color(0.24, 0.42, 0.62)
	ground.material_override = court
	world.add_child(ground)

	for i in AT.size():
		var player := Player.new()
		player.volleyball = false
		player.racket_kind = &"tennis"
		world.add_child(player)
		player.setup(Sides.Team.RED, Vector3(-4.4 + i * 2.2, 0.0, 0.0))
		# Facing the camera rather than across a net that is not here. Player._build_body
		# aims them at their opponent's half; there is no opponent here.
		player.rotation.y = 0.0

		var label := Label3D.new()
		label.text = AT[i][1]
		label.font_size = 80
		label.pixel_size = 0.0035
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.position = Vector3(-4.4 + i * 2.2, 2.6, 0.0)
		world.add_child(label)

	for f in 10:
		await get_tree().process_frame

	var i := 0
	for player in world.get_children():
		if not (player is Player):
			continue
		var animator := Models.animator(player)
		if animator != null and animator.has_animation("tn_serve"):
			animator.play("tn_serve")
			animator.seek(AT[i][0], true)
			animator.pause()
		i += 1
	for f in 4:
		await get_tree().process_frame

	var camera := Camera3D.new()
	camera.fov = 42.0
	world.add_child(camera)
	camera.global_position = Vector3(0.0, 1.6, 8.6)
	camera.look_at(Vector3(0.0, 1.2, 0.0), Vector3.UP)
	camera.current = true

	for f in 6:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://dev/shots/tennis_serve_poses.png")
	print("five shapes of a serve")
	get_tree().quit()
