extends Node3D

## The beach court, before anything is built on top of it.
##
## Scale is the thing to check. A beach court is nearly a third longer than a badminton
## court and the net is a metre higher, so nothing about the badminton camera's numbers
## can be assumed to carry over — and a referee's stand at the wrong height would make
## every call in the sport unreadable.

func _ready() -> void:
	var court := BeachCourt.new()
	court.name = "Court"
	add_child(court)

	var light := DirectionalLight3D.new()
	light.rotation = Vector3(deg_to_rad(-52.0), deg_to_rad(38.0), 0.0)
	light.light_energy = 1.15
	add_child(light)
	var sky := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var s := Sky.new()
	s.sky_material = ProceduralSkyMaterial.new()
	env.sky = s
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.55
	sky.environment = env
	add_child(sky)

	# A ball sitting on the sideline, so the picture shows the thing being judged at
	# the size it really is against the tape it is really judged against.
	var ball := Ball.new()
	ball.floor_height = BeachCourt.SURFACE_Y
	add_child(ball)
	ball.freeze = true
	ball.global_position = Vector3(
		BeachSpec.HALF_WIDTH - 0.03, BeachCourt.SURFACE_Y + Ball.RADIUS, -3.0)

	var camera := Camera3D.new()
	camera.fov = 62.0
	add_child(camera)

	# 1. From the referee's stand, which is where the game is played from.
	camera.position = Vector3(
		BeachSpec.POST_X + BeachCourt.STAND_OFFSET, BeachCourt.EYE_HEIGHT, 0.0)
	# Down the length of the net, which is what the position is for. Both halves of the
	# court are then left and right of the view, exactly as they are from the badminton
	# chair — the net runs away from you, not across you.
	camera.look_at(Vector3(-2.0, 0.9, 0.0))
	camera.cull_mask = camera.cull_mask & ~BeachCourt.STAND_LAYER
	await _shot("res://dev/shots/beach_stand.png")

	# 2. From above, to check the rectangle is a rectangle.
	camera.position = Vector3(0.0, 21.0, 0.0)
	camera.look_at(Vector3.ZERO, Vector3.FORWARD)
	await _shot("res://dev/shots/beach_above.png")

	print("court %.1f x %.1f m, net %.2f m, referee's eye %.2f m" % [
		BeachSpec.HALF_WIDTH * 2.0, BeachSpec.HALF_LENGTH * 2.0,
		BeachSpec.NET_HEIGHT, BeachCourt.EYE_HEIGHT])
	print("the referee looks down on the tape from %.2f m above it" % [
		BeachCourt.EYE_HEIGHT - BeachSpec.NET_HEIGHT])
	get_tree().quit()


func _shot(path: String) -> void:
	for f in 8:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
