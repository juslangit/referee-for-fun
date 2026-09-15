extends Node3D

## The downloaded event props in a row, at the heights the venues use, from the front and
## the side, to see which way up each one arrives.
##
##     godot --path . res://dev/looks/_eventprops.tscn --resolution 1600x900

const ITEMS := [
	["res://assets/sketchfab/tv_camera/tv_camera.glb", 1.1],
	["res://assets/sketchfab/plastic_chair/plastic_chair.glb", 0.85],
	["res://assets/sketchfab/beach_umbrella_low_poly/beach_umbrella_low_poly.glb", 2.3],
]


func _ready() -> void:
	var light := DirectionalLight3D.new()
	light.rotation = Vector3(deg_to_rad(-46.0), deg_to_rad(28.0), 0.0)
	add_child(light)
	var world := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.2, 0.22, 0.26)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.6, 0.6, 0.65)
	world.environment = env
	add_child(world)
	for row in 2:
		for i in ITEMS.size():
			var item: Array = ITEMS[i]
			var model := Props.node(item[0], item[1])
			if model == null:
				print("missing ", item[0])
				continue
			model.position = Vector3((i - 2) * 2.6, 2.8 - row * 3.0, 0.0)
			model.rotation.y = 0.0 if row == 0 else PI * 0.5
			add_child(model)
	var camera := Camera3D.new()
	camera.position = Vector3(0.0, 2.2, 12.0)
	camera.fov = 50.0
	add_child(camera)
	for f in 10:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://dev/shots/event_props.png")
	print("saved")
	get_tree().quit()
