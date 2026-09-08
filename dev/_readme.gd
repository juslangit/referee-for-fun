extends Node

## The pictures the README is built from.
##
## Kept as a scene rather than taken by hand so they can be retaken after the game
## changes, instead of slowly becoming a photograph of a version nobody can play.
## Writes into docs/, which is tracked — unlike dev/shots/, which is scratch.

func _ready() -> void:
	var arena: Node = load("res://scenes/match.tscn").instantiate()
	arena.print_truth_while_testing = false
	add_child(arena)
	await get_tree().physics_frame

	var career := Career.new()
	career.tier = 3
	career.matches_at_tier = 2
	career.matches_refereed = 9
	career.reputation = 0.74

	# 1. The front of the game, over the arena.
	arena.career = career
	arena.ui.show_main_menu(career)
	await _shot("res://docs/menu.png")

	# 2. The ladder you are climbing.
	arena.ui._main_menu.visible = false
	arena.ui.show_career(career)
	await _shot("res://docs/career.png")

	# 3. Somebody's reason for wanting a particular result.
	arena.ui.hide_career()
	arena._umpire_view()
	arena.ui.hide_menus()
	var pressure := Pressure._tournament()
	arena.ui.show_briefing(pressure)
	await _shot("res://docs/briefing.png")
	arena.ui.hide_briefing()

	# 4. The chair, mid-rally, which is where the game actually happens.
	arena._on_length_chosen(false)
	arena.ui.hide_briefing()
	arena.ui.hide_pre_match()
	arena._on_favour_chosen(Sides.Team.NONE)
	# Two rallies of warm-up, so the score is not 0-0 but the run still finishes.
	for r in 2:
		arena._start_rally()
		var waited := 0
		while arena._phase != arena.Phase.AWAITING_CALL and waited < 3000:
			await get_tree().physics_frame
			waited += 1
		arena._make_call(&"in" if arena.rally.was_in else &"out")
		for f in 8:
			await get_tree().process_frame

	arena._start_rally()
	# The previous rally's verdict is still on screen for a few seconds, and a picture
	# of a rally in flight captioned with the last one's result reads as a bug.
	arena.ui.announce("", Color.WHITE)
	for f in 80:
		await get_tree().physics_frame
	await _shot("res://docs/rally.png")

	# 5. The shuttle cam: the landing from directly overhead, once it is down.
	var waited := 0
	while arena._phase != arena.Phase.AWAITING_CALL and waited < 3000:
		await get_tree().physics_frame
		waited += 1
	await _shot("res://docs/call.png")

	# 6. The one moment the truth is public.
	#
	# Staged on a shuttle sitting on the sideline rather than wherever this particular
	# rally happened to finish. A shuttle a metre out photographs as a featureless red
	# square, which is honest and shows nothing: the review exists for the calls where
	# the line is in the picture and the answer is a matter of millimetres.
	# aim_at only points the camera, so the shuttle has to be put there too, or the
	# review photographs an empty court.
	var on_the_line := Vector3(
		CourtSpec.HALF_WIDTH_DOUBLES - 0.012, Court.SURFACE_Y, -3.1)
	arena._shuttle.position = on_the_line
	for f in 2:
		await get_tree().physics_frame
	arena.shuttle_cam.aim_at(on_the_line)
	arena.ui.show_review(Sides.Team.BLUE, 1, arena.shuttle_cam.texture())
	# A shuttle sitting a centimetre inside the sideline was IN, so that is what the
	# review says. A caption that disagreed with its own picture would be worse than
	# no picture.
	arena.ui.set_review_verdict("IN  ·  CALL OVERTURNED", Color(0.96, 0.42, 0.36))
	await _shot("res://docs/review.png")

	print("saved 6")
	get_tree().quit()


func _shot(path: String) -> void:
	for f in 6:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
