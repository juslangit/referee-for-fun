extends Node

## A plan view of the court for the teaching screen.
##
## Drawn from the game rather than illustrated, so it cannot disagree with the court the
## player is actually judging — the lines here are the same CourtSpec numbers the rally
## is measured against. People are left out: the cull mask is the court layer only.

const WIDTH := 940
const HEIGHT := 520

func _ready() -> void:
	var arena: Node = load("res://scenes/match.tscn").instantiate()
	add_child(arena)
	await get_tree().physics_frame
	arena.court.dress(Venue.Tier.ARENA)
	arena.ui.visible = false

	# Everything but the court itself goes. A diagram of what is in and what is out
	# should have nothing else in it — and the camera has to sit under a roof that would
	# otherwise be the entire photograph, which is what happened first time.
	arena.court.venue.visible = false
	arena.court.stands.visible = false
	for child in arena.court.get_children():
		if String(child.name).begins_with("Ceiling"):
			(child as Node3D).visible = false

	# The people go too. They are meant to be excluded by the camera's cull mask and are
	# not — something in the character loading is leaving them on the court layer — so
	# they are hidden outright rather than trusted to the mask.
	for player in arena.players:
		(player as Node3D).visible = false
	for judge in arena._all_line_judges:
		(judge as Node3D).visible = false

	# The venue owned the lighting, so hiding it took the light with it.
	var lamp := DirectionalLight3D.new()
	lamp.rotation = Vector3(deg_to_rad(-72.0), deg_to_rad(20.0), 0.0)
	lamp.light_energy = 2.6
	lamp.shadow_enabled = false
	arena.add_child(lamp)

	for f in 6:
		await get_tree().process_frame

	var frame := SubViewport.new()
	frame.size = Vector2i(WIDTH, HEIGHT)
	frame.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	frame.world_3d = get_viewport().find_world_3d()
	add_child(frame)

	var above := Camera3D.new()
	above.projection = Camera3D.PROJECTION_ORTHOGONAL
	# Tall enough to hold the court across its width, with the run-off showing round it.
	above.size = 12.3
	above.cull_mask = 1
	above.position = Vector3(0.0, 14.0, 0.0)
	frame.add_child(above)
	# Up the picture is across the court, so its length lies along the picture's width.
	above.look_at(Vector3.ZERO, Vector3.RIGHT)
	above.current = true

	for f in 8:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	frame.get_texture().get_image().save_png("res://assets/ui/court_map.png")
	print("saved court map %dx%d" % [WIDTH, HEIGHT])
	get_tree().quit()
