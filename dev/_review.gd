extends Node

## Does the review system catch a liar, and leave an honest umpire alone?
##
## Plays at the national championship, which is where Hawk-Eye starts. UMPIRE=liar calls
## the opposite of the truth on every close rally; anything else calls it straight.

func _ready() -> void:
	var arena: Node = load("res://scenes/match.tscn").instantiate()
	add_child(arena)
	await get_tree().physics_frame
	arena.career.tier = 3
	arena.ui.match_requested.emit()
	await get_tree().process_frame
	arena._on_favour_chosen(Sides.Team.BLUE)
	print("venue: %s   hawk-eye: %s" % [arena.career.venue()["name"], arena.has_hawk_eye])

	var lying := OS.get_environment("UMPIRE") == "liar"
	var judged := 0
	var challenges := 0
	var overturned := 0
	var before_level := 0.0
	var was_reviewing := false
	var shot_taken := false

	for frame in 60000:
		# A liar at this venue can be thrown off the court mid-test, which reloads the
		# scene and takes this node with it. Noticed the hard way: the first run died on
		# a null tree, which was not a bug in the game but the game working.
		if not is_inside_tree():
			break
		await get_tree().process_frame

		# Counted by watching the panel appear, not by watching reviews run out. A
		# successful challenge is handed back, so a liar being caught every time spends
		# none at all — which the first version of this test read as "no challenges".
		if arena._reviewing and not was_reviewing:
			challenges += 1
			if arena.suspicion.level - before_level > 0.20:
				overturned += 1
		was_reviewing = arena._reviewing
		if arena._reviewing:
			if not shot_taken:
				await RenderingServer.frame_post_draw
				get_viewport().get_texture().get_image().save_png("res://dev/shots/_shot_review.png")
				shot_taken = true
			continue
		if arena._phase == arena.Phase.READY:
			arena._start_rally()
			continue
		if arena._phase != arena.Phase.AWAITING_CALL:
			continue

		var rally: Rally = arena.rally
		var truth := CourtSpec.is_in(rally.landing_point, rally.doubles) and rally.crossed_the_net
		var say := truth
		# The liar only lies on the close ones, which is what a careful cheat does.
		if lying and absf(rally.margin) < 0.12:
			say = not truth
		if arena.suspicion.is_removed:
			print("!! the umpire was removed from the match after %d rallies" % judged)
			break
		before_level = arena.suspicion.level
		arena._make_call(&"in" if say else &"out")
		judged += 1
		for f in 12:
			await get_tree().process_frame
		while arena._reviewing:
			await get_tree().process_frame
		before_level = arena.suspicion.level
		if judged >= 18 or arena.board.is_over:
			break

	print("umpire: %s" % ("LIAR on close calls" if lying else "honest"))
	print("removed from the match: %s" % (arena.suspicion.is_removed if is_instance_valid(arena) else "scene reloaded"))
	print("rallies %d   challenges %d   of which overturned %d   suspicion %.3f" % [
		judged, challenges, overturned, arena.suspicion.level])
	print("reviews left: RED %d  BLUE %d" % [
		arena.challenge.remaining(Sides.Team.RED),
		arena.challenge.remaining(Sides.Team.BLUE)])
	get_tree().quit()
