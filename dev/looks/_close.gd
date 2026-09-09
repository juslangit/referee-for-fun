extends Node

## A close look at one player and one line judge, which is the only way to tell whether
## the racket is in the right hand and the official is on the chair rather than beside it.

func _ready() -> void:
	var arena: Node = load("res://scenes/match.tscn").instantiate()
	add_child(arena)
	await get_tree().physics_frame
	arena._set_up_the_match(false)
	arena.begin_match()
	arena.ui.visible = false
	await get_tree().process_frame

	for player in arena.players:
		var animator := Models.animator(player)
		print("%-6s clips: %s" % [Sides.label(player.team),
			", ".join(animator.get_animation_list()) if animator else "NONE"])
		break
	for judge in arena.line_judges:
		var animator := Models.animator(judge)
		print("judge %-12s seat %v  playing %s" % [judge.name, judge.position,
			animator.current_animation if animator else "NONE"])

	var subject: Node3D = arena.players[0]
	subject.swing(true)
	for f in 4:
		await get_tree().process_frame

	arena.camera.current = false
	var close := Camera3D.new()
	close.fov = 42.0
	arena.add_child(close)
	close.global_position = subject.global_position + Vector3(2.4, 1.6, 2.2)
	close.look_at(subject.global_position + Vector3(0.0, 1.0, 0.0), Vector3.UP)
	close.current = true
	for f in 6:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://dev/shots/_shot_close.png")

	var judge: Node3D = arena.line_judges[0]
	close.global_position = judge.global_position + Vector3(2.0, 1.5, 2.0)
	close.look_at(judge.global_position + Vector3(0.0, 0.9, 0.0), Vector3.UP)
	for f in 4:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://dev/shots/_shot_judge.png")
	print("saved")
	get_tree().quit()
