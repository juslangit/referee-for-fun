extends Node

## Photographs the two screens the player actually sees: the choice before the
## match, and the moment just after a call.

func _ready() -> void:
	seed(4271)
	var arena: Node = load("res://scenes/match.tscn").instantiate()
	arena.print_truth_while_testing = false
	add_child(arena)

	for i in 8:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://dev/shots/_shot_prematch.png")

	arena.begin_match()
	arena.start_rally()
	while arena._phase != arena.Phase.AWAITING_CALL:
		await get_tree().physics_frame

	print("truth was: ", arena.rally.describe())
	arena.make_call(&"in")

	for i in 4:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://dev/shots/_shot_call.png")
	print("saved both")
	get_tree().quit()
