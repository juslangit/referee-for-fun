extends Node3D

## The held props and balls in a row at their real sizes, beside a 1.8 m post for
## scale, each printed with the size it came out. For checking a prop swap.
##
##     godot --path . res://dev/looks/_propline.tscn

func _ready() -> void:
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-45, 30, 0)
	add_child(sun)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.78, 0.8, 0.8)
	env.environment.ambient_light_color = Color.WHITE
	env.environment.ambient_light_energy = 0.6
	add_child(env)

	var items := [
		["badminton racket", Models.racket()],
		["tennis racket", Models.tennis_racket()],
		["table tennis bat", Models.bat()],
		["shuttlecock", Models.shuttlecock()],
		["tennis ball", Models.ball(Models.TENNIS_BALL, 0.067)],
		["volleyball", Models.ball(Models.VOLLEYBALL, 0.211)],
	]
	var x := 0.0
	for item in items:
		var node: Node3D = item[1]
		if node == null:
			print("MISSING %s" % item[0])
			continue
		add_child(node)
		node.position = Vector3(x, 0.5, 0)
		var box := Models._bounds(node)
		print("%s: %.3f x %.3f x %.3f  (long along Z expected for held things)" % [item[0], box.size.x, box.size.y, box.size.z])
		x += 0.45

	var cam := Camera3D.new()
	add_child(cam)
	cam.fov = 35
	cam.current = true
	# Looking down -X... from the side, so a racket's long axis (Z) runs across the shot.
	cam.position = Vector3(x * 0.5 - 0.2, 4.6, 0.0)
	cam.look_at(Vector3(x * 0.5 - 0.2, 0.5, 0.0), Vector3.FORWARD)
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://dev/shots/_propline.png")

	cam.position = Vector3(x * 0.5 - 0.2, 0.55, 4.2)
	cam.look_at(Vector3(x * 0.5 - 0.2, 0.5, 0.0))
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://dev/shots/_propline_side.png")
	get_tree().quit()
