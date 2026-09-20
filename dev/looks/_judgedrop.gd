extends Node

## The OUT signal from start to finish: four moments in one strip.
##
## The arms are posed in code, under a paused idle clip, and the pause has to be undone
## when the call is over. When it was not, the judge was left on the rig's rest pose —
## which on this model is a T-pose — and sat there with both arms out for the rest of the
## match. The numbers are in dev/checks/_judgearms; this is what it looks like.

const MOMENTS := [
	["1-before", 0.0],
	["2-going-out", 0.18],
	["3-held", 1.2],
	["4-after", LineJudge.SIGNAL_SECONDS + 1.0],
]


func _ready() -> void:
	var world := Node3D.new()
	add_child(world)

	var light := DirectionalLight3D.new()
	light.rotation = Vector3(deg_to_rad(-44.0), deg_to_rad(20.0), 0.0)
	light.light_energy = 1.4
	world.add_child(light)

	var sky := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.30, 0.36, 0.42)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.7, 0.75, 0.8)
	env.ambient_light_energy = 0.55
	sky.environment = env
	world.add_child(sky)

	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(30, 30)
	ground.mesh = plane
	var grey := StandardMaterial3D.new()
	grey.albedo_color = Color(0.32, 0.36, 0.32)
	ground.material_override = grey
	world.add_child(ground)

	# One seated judge, which is what badminton, tennis and table tennis use, turned to
	# face the camera rather than the middle of a court that is not here.
	var judge := LineJudge.new()
	judge.seated = true
	judge.position = Vector3(0.0, 0.0, 0.0)
	world.add_child(judge)
	for f in 20:
		await get_tree().physics_frame
	for child in judge.get_children():
		if child is Node3D:
			(child as Node3D).rotation.y = PI

	var eye := Camera3D.new()
	eye.look_at_from_position(Vector3(0.0, 1.5, 3.4), Vector3(0.0, 1.05, 0.0), Vector3.UP)
	eye.fov = 45.0
	eye.current = true
	world.add_child(eye)

	# The first frame is taken before the call, so the strip shows what the arms are
	# coming from as well as what they come back to.
	await _shot("res://dev/shots/judge_drop_%s.png" % MOMENTS[0][0])
	print("saved %s" % MOMENTS[0][0])
	judge.announce(false)
	var began := Time.get_ticks_msec()
	for i in range(1, MOMENTS.size()):
		var moment: Array = MOMENTS[i]
		var until := began + int(float(moment[1]) * 1000.0)
		while Time.get_ticks_msec() < until:
			await get_tree().process_frame
		await _shot("res://dev/shots/judge_drop_%s.png" % moment[0])
		print("saved %s" % moment[0])
	get_tree().quit()


func _shot(path: String) -> void:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
