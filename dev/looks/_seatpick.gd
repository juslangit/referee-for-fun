extends Node

## The candidate seats, side by side, each one in all three of the ways a downloaded model
## might need standing up.
##
## Luqman on 2026-09-20: the crowd should be sitting on "a bench or chair like in a real
## stadium". There are four models already in the repo that could be it, and which way up
## each one wants to be is not guessable from the outside — see the comment on Props.z_up.

const CANDIDATES := [
	["stadium_seat", "res://assets/sketchfab/stadium_seat/stadium_seat.glb"],
	["arena_seats", "res://assets/sketchfab/low_poly_stadium_sports_arena_seats/low_poly_stadium_sports_arena_seats.glb"],
	["gym_bench", "res://assets/sketchfab/gym_bench_chair/gym_bench_chair.glb"],
	["plastic_chair", "res://assets/sketchfab/plastic_chair/plastic_chair.glb"],
]

const WAYS_UP := ["as it comes", "z up", "z down"]


func _ready() -> void:
	var world := Node3D.new()
	add_child(world)

	var light := DirectionalLight3D.new()
	light.rotation = Vector3(deg_to_rad(-48.0), deg_to_rad(35.0), 0.0)
	light.light_energy = 1.5
	world.add_child(light)

	var sky := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.16, 0.18, 0.22)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.75, 0.78, 0.85)
	env.ambient_light_energy = 0.7
	sky.environment = env
	world.add_child(sky)

	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(40, 40)
	ground.mesh = plane
	var grey := StandardMaterial3D.new()
	grey.albedo_color = Color(0.40, 0.42, 0.45)
	ground.material_override = grey
	world.add_child(ground)

	for c in CANDIDATES.size():
		var label := Label3D.new()
		label.text = String(CANDIDATES[c][0])
		label.font_size = 64
		label.pixel_size = 0.0032
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.position = Vector3(-2.4 + c * 1.6, 1.55, 1.6)
		world.add_child(label)

		for w in WAYS_UP.size():
			var correction := [Transform3D.IDENTITY, Props.z_up(), Props.z_down()][w]
			# Turned a little off square so the shape reads, rather than face on.
			var seat := Props.node(String(CANDIDATES[c][1]), Stands.SEAT_HEIGHT,
				Props.turned(-25.0) * correction)
			if seat == null:
				print("%-14s %-11s could not be loaded" % [CANDIDATES[c][0], WAYS_UP[w]])
				continue
			seat.position = Vector3(-2.4 + c * 1.6, 0.0, -w * 1.6)
			world.add_child(seat)
			print("%-14s %-11s placed" % [CANDIDATES[c][0], WAYS_UP[w]])

	for w in WAYS_UP.size():
		var label := Label3D.new()
		label.text = WAYS_UP[w]
		label.font_size = 48
		label.pixel_size = 0.0030
		label.modulate = Color(0.75, 0.80, 0.90)
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.position = Vector3(-3.7, 0.5, -w * 1.6)
		world.add_child(label)

	var eye := Camera3D.new()
	eye.look_at_from_position(Vector3(0.4, 3.3, 4.6), Vector3(0.0, 0.5, -1.6), Vector3.UP)
	eye.fov = 50.0
	eye.current = true
	world.add_child(eye)

	for f in 12:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://dev/shots/seat_candidates.png")
	print("saved")
	get_tree().quit()
