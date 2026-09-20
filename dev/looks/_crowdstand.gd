extends Node

## The hall reacting: seated, mid-cheer, and on its feet over a bad call.
##
## Luqman on 2026-09-20: "make the audience sitting down, if they are cheering, they stand
## up." Each spectator is two meshes and exactly one of them is drawn, so this is the look
## that shows the swap actually happening rather than the seated half staying put.

func _ready() -> void:
	var arena: Node = load("res://scenes/match.tscn").instantiate()
	arena.print_truth_while_testing = false
	add_child(arena)
	await get_tree().physics_frame
	arena._set_up_the_match(false)
	arena.begin_match()
	arena.ui.visible = false
	arena.court.dress(2)
	arena.court.stands.set_density(1.0)
	for f in 8:
		await get_tree().process_frame

	await _shot("sitting")

	arena.court.stands.cheer()
	# Part way into the arc, where the most people are off their seats.
	await _wait(0.35)
	await _shot("cheering")

	# Everybody down again before the next reaction, so the two do not overlap.
	await _wait(1.4)
	arena.court.stands.jeer(0.9)
	await _wait(1.2)
	await _shot("standing")
	print("saved")
	get_tree().quit()


func _wait(seconds: float) -> void:
	var until := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < until:
		await get_tree().process_frame


func _shot(tag: String) -> void:
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://dev/shots/crowd_%s.png" % tag)
