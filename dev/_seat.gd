extends Node

## What the player actually sees from the chair. The layout shot is taken from inside
## the near stands and distorts everything at the edge of frame, so it is no use for
## judging whether the crowd looks right.

func _ready() -> void:
	var arena: Node = load("res://scenes/match.tscn").instantiate()
	add_child(arena)
	await get_tree().physics_frame
	arena._on_length_chosen(false)
	arena.begin_match()
	arena.ui.visible = false
	var wanted := OS.get_environment("TIER")
	if not wanted.is_empty():
		arena.court.dress(int(wanted))
		arena.court.stands.set_density([0.25, 0.7, 1.0][int(wanted)])
	for f in 8:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://_shot_seat%s.png" % OS.get_environment("TIER"))
	print("saved")
	get_tree().quit()
