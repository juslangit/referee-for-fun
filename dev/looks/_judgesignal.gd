extends Node

## Every candidate axis for the line judge's OUT signal, side by side.
##
## The officials are a downloaded model and nothing says how their arm bones rest, so
## "both arms straight out to the sides" is a rotation of an unknown amount about an
## unknown axis. Guessing costs a render each; rendering all six at once costs one.

const AXES := [
	["+X", Vector3(1, 0, 0)], ["-X", Vector3(-1, 0, 0)],
	["+Y", Vector3(0, 1, 0)], ["-Y", Vector3(0, -1, 0)],
	["+Z", Vector3(0, 0, 1)], ["-Z", Vector3(0, 0, -1)],
]


func _ready() -> void:
	var world := Node3D.new()
	add_child(world)

	var light := DirectionalLight3D.new()
	light.rotation = Vector3(deg_to_rad(-44.0), deg_to_rad(20.0), 0.0)
	light.light_energy = 1.4
	world.add_child(light)

	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(30, 30)
	ground.mesh = plane
	var grey := StandardMaterial3D.new()
	grey.albedo_color = Color(0.32, 0.36, 0.32)
	ground.material_override = grey
	world.add_child(ground)

	var judges: Array[LineJudge] = []
	for i in AXES.size():
		var judge := LineJudge.new()
		judge.seated = false
		judge.signal_axis = AXES[i][1]
		# Spread along X, and turned to face the camera rather than the middle: their
		# own rotation aims them at the court, and there is no court here.
		judge.position = Vector3(-5.0 + i * 2.0, 0.0, 0.0)
		world.add_child(judge)
		judges.append(judge)

		var label := Label3D.new()
		label.text = AXES[i][0]
		label.font_size = 96
		label.pixel_size = 0.004
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.position = judge.position + Vector3(0.0, 2.3, 0.0)
		world.add_child(label)

	for f in 10:
		await get_tree().process_frame
	# All turned the same way, at the camera.
	#
	# A line judge aims themselves at the middle of the court — `atan2(-x, -z)` in
	# _build_standing — so six of them spread along X face six different directions and
	# the first render of this was six men in profile. There is no court here.
	for judge in judges:
		var body := judge.get_node_or_null("Judge")
		if body != null:
			body.rotation.y = 0.0
	for judge in judges:
		judge.signal_out()
	for f in 40:
		await get_tree().process_frame

	var camera := Camera3D.new()
	camera.fov = 46.0
	world.add_child(camera)
	camera.global_position = Vector3(-1.0, 1.5, 9.5)
	camera.look_at(Vector3(-1.0, 1.0, 0.0), Vector3.UP)
	camera.current = true

	for f in 6:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://dev/shots/judge_axes.png")
	print("six axes, %.0f degrees each" % LineJudge.SIGNAL_SWING)
	get_tree().quit()
