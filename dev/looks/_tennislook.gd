extends Node3D

## The tennis court, before anything is built on it.
##
## Two things to check by eye rather than by arithmetic: that the two sets of sidelines
## read as one court rather than a mess, and that the net actually looks like it sags.

func _ready() -> void:
	var court := TennisCourt.new()
	court.name = "Court"
	add_child(court)

	var light := DirectionalLight3D.new()
	light.rotation = Vector3(deg_to_rad(-58.0), deg_to_rad(30.0), 0.0)
	light.light_energy = 1.5
	add_child(light)
	var world := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.10, 0.12, 0.16)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.60, 0.64, 0.72)
	env.ambient_light_energy = 1.1
	world.environment = env
	add_child(world)

	# A ball on the singles sideline, at the size it is really judged at.
	var ball := TennisBall.new()
	ball.floor_height = TennisCourt.SURFACE_Y
	add_child(ball)
	ball.freeze = true
	ball.global_position = Vector3(
		TennisSpec.HALF_WIDTH_SINGLES - 0.01,
		TennisCourt.SURFACE_Y + TennisBall.TENNIS_RADIUS, -5.0)

	var camera := Camera3D.new()
	camera.fov = 70.0
	camera.cull_mask = camera.cull_mask & ~TennisCourt.CHAIR_LAYER
	add_child(camera)

	camera.position = Vector3(
		TennisSpec.POST_X + TennisCourt.CHAIR_OFFSET, TennisCourt.EYE_HEIGHT, 0.0)
	camera.look_at(Vector3(-2.0, 0.6, 0.0))
	await _shot("res://dev/shots/tennis_chair.png")

	camera.position = Vector3(0.0, 26.0, 0.0)
	camera.look_at(Vector3.ZERO, Vector3.FORWARD)
	await _shot("res://dev/shots/tennis_above.png")

	print("court %.2f x %.2f m (doubles), %.2f wide for singles" % [
		TennisSpec.HALF_WIDTH_DOUBLES * 2.0, TennisSpec.HALF_LENGTH * 2.0,
		TennisSpec.HALF_WIDTH_SINGLES * 2.0])
	print("net: %.3f m at the posts, %.3f m in the middle" % [
		TennisSpec.net_height_at(TennisSpec.POST_X), TennisSpec.net_height_at(0.0)])
	print("   at the singles sideline it is %.3f m" % [
		TennisSpec.net_height_at(TennisSpec.HALF_WIDTH_SINGLES)])
	get_tree().quit()


func _shot(path: String) -> void:
	for f in 8:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
