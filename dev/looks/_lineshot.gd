extends Node

## Lands a shuttle exactly on the doubles sideline and photographs it from the
## umpire's chair, zoomed in the way an umpire would actually focus on the spot.

func _ready() -> void:
	var arena: Node = load("res://scenes/match.tscn").instantiate()
	add_child(arena)
	await get_tree().physics_frame

	var target := Vector3(-CourtSpec.HALF_WIDTH_DOUBLES, 0.0, 1.6)
	var shuttle: Shuttle = arena.serve(Vector3(1.0, 2.6, -4.6), target, 40.0)

	while not shuttle.has_landed:
		await get_tree().physics_frame

	var camera: UmpireCamera = arena.camera
	camera.fov = 30.0
	camera.look_at(shuttle.landing_point + Vector3(0.0, 0.05, 0.0), Vector3.UP)

	for i in 6:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://dev/shots/_shot.png")
	print("landed at (%.4f, %.4f)" % [shuttle.landing_point.x, shuttle.landing_point.z])
	get_tree().quit()
