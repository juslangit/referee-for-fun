extends Node3D

## The ball kid frozen in each candidate crouch, side by side, to pick the one that stays
## low at the net post. Same light as _castline.

func _ready() -> void:
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, 25, 0)
	add_child(sun)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.75, 0.77, 0.78)
	env.environment.ambient_light_energy = 0.7
	add_child(env)
	var clips := ["kneel", "ready", "sit"]
	var x := 0.0
	for clip in clips:
		var holder := Node3D.new()
		holder.add_child(load("res://assets/meshy/crew_ballkid/crew_ballkid_animated.glb").instantiate())
		holder.position = Vector3(x, 0, 0)
		add_child(holder)
		var animator := Models.animator(holder)
		var name := Models.clip_named(animator, [clip])
		animator.play(name)
		animator.seek(animator.get_animation(name).length * float(OS.get_environment("AT") if OS.has_environment("AT") else "0.5"), true)
		animator.pause()
		print("%s -> %s" % [clip, name])
		x += 1.1
	for f in 3:
		await get_tree().process_frame
	var cam := Camera3D.new()
	add_child(cam)
	cam.fov = 40
	cam.current = true
	cam.position = Vector3((x - 1.1) * 0.5, 1.0, 8.0)
	cam.look_at(Vector3((x - 1.1) * 0.5, 0.7, 0))
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://dev/shots/_crouchpick.png")
	get_tree().quit()
