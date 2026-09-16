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
	print("PASS" if _problems.is_empty() else "FAIL:\n   " + "\n   ".join(_problems))
	get_tree().quit()


## What went wrong, if anything. A check that only prints cannot fail, and this one is
## watching for the worst bug in the game — an ending that takes the match with it — so
## it has to be able to say so rather than leave the reader to read the numbers.
var _problems: Array[String] = []


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

	var sport: String = "beach" if beach else "indoor"
	print("   the shortest possible match is about %d rallies" % rallies)
	print("   match reported over: %s" % arena.board.is_over)
	if not arena.board.is_over:
		_problems.append("%s: the board never ended, after %d awarded points" % [sport, rallies])
	await get_tree().process_frame
	await get_tree().process_frame
	var ended: bool = arena._phase == arena.Phase.REMOVED
	print("   the ending screen came up: %s" % (
		"yes" if ended else "NO — the match just stopped"))
	if not ended:
		_problems.append("%s: the match stopped without an ending screen" % sport)
	var reputation := roundi(arena.career.reputation * 100.0)
	print("   reputation after it: %d / 100" % reputation)
	if reputation < 0 or reputation > 100:
		_problems.append("%s: reputation left at %d, outside 0-100" % [sport, reputation])

	arena.queue_free()
	await get_tree().process_frame
	print()
