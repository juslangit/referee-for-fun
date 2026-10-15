extends Node3D

## The realistic cast in a row under plain light: umpire, line judge, and each crew role
## standing and crouched, posed exactly as the venues pose them. For checking the cast.
##
##     godot --path . res://dev/looks/_castline.tscn

func _ready() -> void:
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, 25, 0)
	add_child(sun)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.75, 0.77, 0.78)
	env.environment.ambient_light_color = Color.WHITE
	env.environment.ambient_light_energy = 0.7
	add_child(env)

	var dressing := EventDressing.new()
	var row: Array = [
		["umpire", Models.umpire()],
		["line judge", Models.official()],
		["photographer", dressing._crew("Photographer", false)],
		["photographer crouched", dressing._crew("Photographer", true)],
		["ball kid", dressing._crew("BallKid", false)],
		["ball kid crouched", dressing._crew("BallKid", true)],
		["camera operator", dressing._crew("Operator", false)],
	]
	var x := 0.0
	for item in row:
		var figure: Node3D = item[1]
		if figure == null:
			print("MISSING %s" % item[0])
			x += 1.0
			continue
		figure.position = Vector3(x, 0, 0)
		add_child(figure)
		# The officials pose themselves in the game; here they are stood like the crew.
		if item[0] in ["umpire", "line judge"]:
			var animator := Models.animator(figure)
			var clip := Models.clip_named(animator, ["stand", "idle"])
			if not clip.is_empty():
				animator.play(clip)
		x += 1.0
	for f in 4:
		await get_tree().process_frame
	var cam := Camera3D.new()
	add_child(cam)
	cam.fov = 40
	cam.current = true
	cam.position = Vector3((x - 1.0) * 0.5, 1.1, 8.5)
	cam.look_at(Vector3((x - 1.0) * 0.5, 0.85, 0))
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://dev/shots/_castline.png")
	get_tree().quit()
