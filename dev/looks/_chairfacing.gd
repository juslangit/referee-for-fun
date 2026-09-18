extends Node

## Which way the umpire's high chair faces, seen from the court.
##
## The chair is on `CHAIR_LAYER`, which the umpire's own camera leaves out — the player
## is sitting in it, so it is never in their view. That means it is only ever seen during
## a cutscene, and a chair facing the wrong way there went unnoticed for as long as the
## chair has existed. Luqman, 2026-09-18: "in cutscenes, fix the umpire chair, it facing
## backwards".
##
## `SPIN=1.5707963` to try the opposite turn.

func _ready() -> void:
	var hall: Node = load("res://scenes/match.tscn").instantiate()
	hall.print_truth_while_testing = false
	add_child(hall)
	await get_tree().physics_frame
	hall.career = Career.new()
	hall.ui.hide_menus()
	hall.ui.show_hud(false)
	for player in hall.players:
		player.visible = false

	var chair := hall.court.find_child("UmpireChair", true, false) as Node3D
	print("chair at %.2f, %.2f" % [chair.global_position.x, chair.global_position.z])
	if OS.has_environment("SPIN"):
		for child in chair.get_children():
			(child as Node3D).rotation.y = float(OS.get_environment("SPIN"))
		print("turned to %s" % OS.get_environment("SPIN"))

	# A cutscene camera: out on the court, looking back at the chair — which is exactly
	# the angle the chair is only ever seen from.
	var eye := Camera3D.new()
	hall.add_child(eye)
	var at := chair.global_position
	eye.look_at_from_position(at + Vector3(-4.2, 2.1, 2.6), at + Vector3(0.0, 1.5, 0.0), Vector3.UP)
	eye.fov = 46.0
	# The chair layer is left out of the umpire's camera; a cutscene camera sees it.
	eye.cull_mask = 0xFFFFF
	eye.current = true
	for f in 10:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(
		"res://dev/shots/_shot_chair%s.png" % ("_spun" if OS.has_environment("SPIN") else ""))
	get_tree().quit()
