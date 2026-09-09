extends Node

## Every prop in a row at a known height, so which way up each one arrives can be seen
## rather than guessed. The white bars are one metre.

var ROW := [
	["stadium_seat, no correction", Props.SEAT, 0.88, false],
	["stadium_seat, z-up fixed", Props.SEAT, 0.88, true],
	["folding_chair", Props.FOLDING_CHAIR, 0.88, false],
	["folding_chair z-up", Props.FOLDING_CHAIR, 0.88, true],
	["high_chair", Props.HIGH_CHAIR, 2.60, false],
	["high_chair z-up", Props.HIGH_CHAIR, 2.60, true],
	["truss", Props.TRUSS, 0.80, false],
	["lamp", Props.LAMP, 0.55, false],
	["bench", Props.BENCH, 0.95, false],
	["bag", Props.BAG, 0.38, false],
	["bottle", Props.BOTTLE, 0.26, false],
]

func _ready() -> void:
	var light := DirectionalLight3D.new()
	light.rotation = Vector3(deg_to_rad(-52.0), deg_to_rad(38.0), 0.0)
	light.light_energy = 1.5
	add_child(light)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.16, 0.17, 0.20)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.55, 0.57, 0.62)
	e.ambient_light_energy = 0.9
	env.environment = e
	add_child(env)

	var x := 0.0
	for entry in ROW:
		var correction: Transform3D = Props.z_up() if entry[3] else Transform3D.IDENTITY
		var item := Props.node(entry[1], entry[2], correction)
		if item != null:
			item.position = Vector3(x, 0.0, 0.0)
			add_child(item)
		# A one metre stick beside each, to read the scale against.
		var stick := MeshInstance3D.new()
		var bar := BoxMesh.new()
		bar.size = Vector3(0.04, 1.0, 0.04)
		stick.mesh = bar
		stick.position = Vector3(x - 0.85, 0.5, 0.0)
		add_child(stick)
		print("%-28s %s" % [entry[0], "ok" if item != null else "MISSING"])
		x += 1.9

	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = x * 0.55
	camera.position = Vector3(x * 0.5 - 0.95, 1.3, 14.0)
	add_child(camera)
	camera.current = true
	for f in 6:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://dev/shots/_shot_props.png")
	print("saved")
	get_tree().quit()
