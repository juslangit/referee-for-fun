extends Node

## Can a match in each sport actually finish?
##
## Every harness so far stops after a fixed number of rallies, so the end of a match —
## the ending screen, the career fold-in, the promotion — has never been reached in the
## two volleyballs at all. A crash there would be the worst bug in the game: it would
## take the match with it.
##
## Also reports how many rallies each sport's shortest match needs, because that is how
## long the player is actually being asked to sit there.

func _ready() -> void:
	for scene in ["res://scenes/beach.tscn", "res://scenes/volleyball.tscn"]:
		await _play_to_the_end(scene)
	get_tree().quit()


func _play_to_the_end(scene: String) -> void:
	var arena: Node = load(scene).instantiate()
	arena.print_truth_while_testing = false
	add_child(arena)
	await get_tree().physics_frame

	var beach: bool = scene.ends_with("beach.tscn")
	arena.career = Career.new()
	arena.career.sport = Career.BEACH if beach else Career.INDOOR
	if OS.has_environment("TIER"):
		arena.career.tier = int(OS.get_environment("TIER"))
	if beach:
		arena.settings.taught_beach = true
	else:
		arena.settings.taught_indoor = true

	var venue: Dictionary = arena.career.venue()
	arena.ui.match_requested.emit()
	await get_tree().process_frame
	if arena.pressure.exists():
		arena.ui.briefing_acknowledged.emit()
		await get_tree().process_frame
	arena.begin_match()
	for f in 3:
		await get_tree().process_frame

	print("=== %s, %s" % ["beach" if beach else "indoor", venue["name"]])
	print("   sets to %d, decider to %d, first to %d sets" % [
		arena.board.target, arena.board.decider_target, arena.board.games_needed])

	# Award points straight to the board rather than playing them out: this is about
	# whether the end of a match works, not about the rallies on the way to it.
	var rallies := 0
	var to := Sides.Team.RED
	while not arena.board.is_over and rallies < 400:
		arena.board.award(to)
		rallies += 1
		# A realistic split rather than a whitewash, so the sets go the distance.
		if randf() < 0.42:
			to = Sides.opponent(to)
		await get_tree().process_frame

	print("   the shortest possible match is about %d rallies" % rallies)
	print("   match reported over: %s" % arena.board.is_over)
	await get_tree().process_frame
	await get_tree().process_frame
	print("   the ending screen came up: %s" % (
		"yes" if arena._phase == arena.Phase.REMOVED else "NO — the match just stopped"))
	print("   reputation after it: %d / 100" % roundi(arena.career.reputation * 100.0))

	arena.queue_free()
	await get_tree().process_frame
	print()
