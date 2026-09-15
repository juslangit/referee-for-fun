extends Node

## Do the badminton cutscenes hand the match back in the state a match needs?
##
## A cutscene is twenty seconds of the game doing things on its own, and the ways that goes
## wrong are all invisible in a screenshot: a match that never starts after it, a player
## left standing at the entrance, a toss that says RED and a serve that goes to BLUE, a
## career that is only saved once the walk off the court is over — so that quitting halfway
## through it escapes being taken off. This plays each of them through, watched and
## skipped, and checks the state it leaves behind.
##
##   godot --headless --path . res://dev/checks/_cutscenes.tscn
##
## About ninety seconds: the walk-on and the handshakes are played at real speed once each.

var _failures: Array[String] = []


func _ready() -> void:
	await _walk_on(false)
	await _walk_on(true)
	await _match_won()
	await _taken_off()
	await _walked_out()
	await _moved_up()
	print("")
	if _failures.is_empty():
		print("PASS  every cutscene hands the match back")
	else:
		for failure in _failures:
			print("FAIL  " + failure)
	get_tree().quit()


func _expect(ok: bool, what: String) -> void:
	print("   %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures.append(what)


func _arena() -> BadmintonMatch:
	var arena: BadmintonMatch = load("res://scenes/match.tscn").instantiate()
	arena.cutscenes = true
	add_child(arena)
	await get_tree().physics_frame
	arena.career = Career.start_again()
	arena.career.sport = Career.BADMINTON
	arena.settings.taught = true
	return arena


func _seconds_since(start: int) -> float:
	return float(Time.get_ticks_msec() - start) / 1000.0


## Waits on the wall clock for something to be true. Headless frames are not a clock.
func _until(condition: Callable, most: float) -> bool:
	var start := Time.get_ticks_msec()
	while not condition.call():
		if _seconds_since(start) > most:
			return false
		await get_tree().process_frame
	return true


func _officials_left(arena: Node) -> int:
	return arena.find_children("*", "Official", true, false).size()


func _walk_on(skip: bool) -> void:
	print("=== walk-on, %s" % ("skipped two seconds in" if skip else "watched to the end"))
	var arena := await _arena()
	arena.ui.match_requested.emit()
	await get_tree().process_frame
	if arena.pressure.exists():
		arena.ui.briefing_acknowledged.emit()
	var started := Time.get_ticks_msec()
	_expect(await _until(func() -> bool: return arena.cutscene != null, 2.0),
		"the walk-on starts from the player's route into a match")
	var toss := {"winner": Sides.Team.NONE}
	var scene := arena.cutscene
	scene.done.connect(func() -> void: toss.winner = scene.toss_winner)
	_expect(arena.ui.is_broadcasting(), "the broadcast bars are up")
	_expect(arena._phase == OfficiatedMatch.Phase.MENU, "nothing can be called during it")

	if skip:
		await get_tree().create_timer(2.0).timeout
		arena.ui.cutscene_skip.emit()
	var ended := await _until(func() -> bool: return arena._phase == OfficiatedMatch.Phase.READY, 40.0)
	var took := _seconds_since(started)
	_expect(ended, "the match begins after it (%.1f s)" % took)
	if skip:
		_expect(took < 3.5, "skipping ends it at once")
	await get_tree().process_frame

	_expect(not arena.ui.is_broadcasting(), "the bars are gone")
	_expect(arena.camera.current, "the view is back in the chair")
	_expect(_officials_left(arena) == 0, "no officials are left on court")
	var everyone_back := true
	for player in arena.players:
		if not player.visible or player.position.distance_to(player.home) > 4.0:
			everyone_back = false
	_expect(everyone_back, "every player is visible and on their own half")
	# The toss decides the first server. Its caption and the serve must agree.
	var tossed := arena.cutscene == null
	_expect(tossed, "the cutscene is freed")
	_expect(toss.winner != Sides.Team.NONE and arena.serving == toss.winner,
		"whoever won the toss serves (%s)" % Sides.label(toss.winner))
	arena.queue_free()
	await get_tree().process_frame


func _match_won() -> void:
	print("=== match won")
	var arena := await _arena()
	arena.board = Scoreboard.new(true)
	arena.board.match_won.connect(arena._on_match_won)
	arena.begin_match()
	await get_tree().process_frame
	var matches_before := arena.career.matches_refereed
	arena.board.points[Sides.Team.RED] = arena.board.target - 1
	arena.board.award(Sides.Team.RED)
	_expect(await _until(func() -> bool: return arena.cutscene != null, 3.0), "the handshakes start")
	_expect(arena.career.matches_refereed == matches_before + 1,
		"the match is in the career before the cutscene plays")
	# Every one of them within a pace of the net at the same moment, which only the
	# handshake asks of them.
	_expect(await _until(func() -> bool:
		return arena.players.all(func(p: Player) -> bool: return absf(p.position.z) < 0.8), 10.0),
		"the players go to the net")
	_expect(await _until(func() -> bool: return arena.ui._ending.visible, 30.0),
		"the result follows it")
	await get_tree().process_frame
	_expect(_officials_left(arena) == 0, "the umpire in the chair is gone with it")
	arena.queue_free()
	await get_tree().process_frame


func _taken_off() -> void:
	print("=== taken off")
	var arena := await _arena()
	arena.begin_match()
	await get_tree().process_frame
	var removals_before := arena.career.times_removed
	arena.suspicion.is_removed = true
	arena._on_removed_from_match()
	_expect(await _until(func() -> bool: return arena.cutscene != null, 3.0),
		"the tournament referee comes on")
	_expect(arena.career.times_removed == removals_before + 1,
		"being taken off is saved before the walk off starts")
	var saved := Career.load_or_start()
	_expect(saved.times_removed == arena.career.times_removed, "and it is on disk")
	_expect(await _until(func() -> bool: return arena.ui._ending.visible, 30.0),
		"the result follows it")
	arena.queue_free()
	await get_tree().process_frame


func _walked_out() -> void:
	print("=== walked out")
	var arena := await _arena()
	arena.begin_match()
	await get_tree().process_frame
	arena._on_walk_out_requested()
	await get_tree().create_timer(1.5).timeout
	_expect(arena.cutscene == null, "walking out has no cutscene")
	_expect(arena.ui._ending.visible, "the result comes straight up")
	arena.queue_free()
	await get_tree().process_frame


func _moved_up() -> void:
	print("=== moved up")
	var arena := await _arena()
	arena.career.matches_at_tier = int(arena.career.venue()["matches_needed"]) - 1
	arena.career.reputation = 1.0
	var tier_before := arena.career.tier
	arena.begin_match()
	await get_tree().process_frame
	arena.cutscenes = false
	arena._finish_match("RED WIN THE MATCH", Color.RED, false)
	await get_tree().process_frame
	_expect(arena.career.tier == tier_before + 1 and arena._promoted,
		"a promotion is noticed")
	arena.cutscenes = true
	arena.cutscene = arena._make_cutscene()
	var shown := {"done": false}
	arena.cutscene.done.connect(func() -> void: shown.done = true)
	arena.cutscene.moved_up(arena.career.venue())
	_expect(await _until(func() -> bool: return shown.done, 15.0), "the new hall is shown and it ends")
	_expect(arena.court.venue.tier == arena.career.venue()["dressing"], "the hall is dressed as the new rung")
	arena.queue_free()
	await get_tree().process_frame
