extends Node

## Do the cutscenes of the sports on the spine hand the match back in the state a match
## needs? `_cutscenes` asks this of badminton; this asks it of every other sport that has
## scenes, and asks the sports that do not yet have any to go straight to the first serve.
##
##   godot --headless --path . res://dev/checks/_sportcutscenes.tscn
##
## SPORTS=tennis for one of them. About a minute a sport: each walk-on is watched once.

const WITH_SCENES := {
	"tennis": ["res://scenes/tennis.tscn", Career.TENNIS],
	"table tennis": ["res://scenes/table_tennis.tscn", Career.TABLE_TENNIS],
	"indoor": ["res://scenes/volleyball.tscn", Career.INDOOR],
	"beach": ["res://scenes/beach.tscn", Career.BEACH],
}
## Every sport has its scenes now (2026-09-15). Kept, so a sport added later without any is
## still asked to go straight to the first serve.
const WITHOUT := {}

var _failures: Array[String] = []


func _ready() -> void:
	var only := OS.get_environment("SPORTS")
	for sport in WITH_SCENES:
		if not only.is_empty() and not only.split(",").has(sport):
			continue
		await _walk_on(sport, false)
		await _walk_on(sport, true)
		await _match_won(sport)
		await _taken_off(sport)
		await _walked_out(sport)
		await _moved_up(sport)
	for sport in WITHOUT:
		if not only.is_empty() and not only.split(",").has(sport):
			continue
		await _no_scenes(sport)
	print("")
	if _failures.is_empty():
		print("PASS  every sport's cutscenes hand the match back")
	else:
		for failure in _failures:
			print("FAIL  " + failure)
	get_tree().quit()


func _expect(ok: bool, what: String) -> void:
	print("   %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures.append(what)


func _arena(entry: Array) -> OfficiatedMatch:
	var arena: OfficiatedMatch = load(entry[0]).instantiate()
	arena.print_truth_while_testing = false
	arena.cutscenes = true
	add_child(arena)
	await get_tree().physics_frame
	arena.career = Career.start_again()
	arena.career.sport = entry[1]
	return arena


## Through the player's own route: the match menu, and the briefing if there is one.
func _into_a_match(arena: OfficiatedMatch) -> void:
	arena.ui.match_requested.emit()
	await get_tree().process_frame
	if arena.pressure.exists():
		arena.ui.briefing_acknowledged.emit()


## A match already under way, with the scenes off until the moment being tested.
func _under_way(arena: OfficiatedMatch) -> void:
	arena.cutscenes = false
	await _into_a_match(arena)
	await get_tree().process_frame
	arena.cutscenes = true


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


func _walk_on(sport: String, skip: bool) -> void:
	print("=== %s walk-on, %s" % [sport, "skipped two seconds in" if skip else "watched to the end"])
	var arena := await _arena(WITH_SCENES[sport])
	await _into_a_match(arena)
	var started := Time.get_ticks_msec()
	_expect(await _until(func() -> bool: return arena.cutscene != null, 2.0),
		"%s: the walk-on starts from the player's route into a match" % sport)
	var scene := arena.cutscene
	if scene == null:
		arena.queue_free()
		return
	var toss := {"winner": Sides.Team.NONE}
	scene.done.connect(func() -> void: toss.winner = scene.toss_winner)
	_expect(arena.ui.is_broadcasting(), "%s: the broadcast bars are up" % sport)
	_expect(arena._phase == OfficiatedMatch.Phase.MENU, "%s: nothing can be called during it" % sport)
	if skip:
		await get_tree().create_timer(2.0).timeout
		arena.ui.cutscene_skip.emit()
	var ended := await _until(func() -> bool: return arena._phase == OfficiatedMatch.Phase.READY, 45.0)
	var took := _seconds_since(started)
	_expect(ended, "%s: the match begins after it (%.1f s)" % [sport, took])
	if skip:
		_expect(took < 3.5, "%s: skipping ends it at once" % sport)
	await get_tree().process_frame
	_expect(not arena.ui.is_broadcasting(), "%s: the bars are gone" % sport)
	_expect(arena.camera.current, "%s: the view is back in the chair" % sport)
	_expect(_officials_left(arena) == 0, "%s: no officials are left on court" % sport)
	var everyone_back := true
	for player in arena.players:
		if not player.visible or player.position.distance_to(player.home) > 4.0:
			everyone_back = false
	_expect(everyone_back, "%s: every player is visible and near their place" % sport)
	_expect(arena.cutscene == null, "%s: the cutscene is freed" % sport)
	_expect(toss.winner != Sides.Team.NONE and arena.serving == toss.winner,
		"%s: whoever won the toss serves (%s)" % [sport, Sides.label(toss.winner)])
	arena.queue_free()
	await get_tree().process_frame


func _match_won(sport: String) -> void:
	print("=== %s match won" % sport)
	var arena := await _arena(WITH_SCENES[sport])
	await _under_way(arena)
	var matches_before := arena.career.matches_refereed
	var awarded := 0
	while not arena.board.is_over and awarded < 400:
		arena.board.award(Sides.Team.RED)
		awarded += 1
	_expect(await _until(func() -> bool: return arena.cutscene != null, 3.0),
		"%s: the handshakes start" % sport)
	_expect(arena.career.matches_refereed == matches_before + 1,
		"%s: the match is in the career before the cutscene plays" % sport)
	_expect(await _until(func() -> bool:
		return arena.players.all(func(p: Player) -> bool: return absf(p.position.z) < 0.8), 12.0),
		"%s: the players meet at the net" % sport)
	# Beside the chair, which is past the net post in tennis and beside the table in table
	# tennis: nearer the umpire's side than the middle of the court, either way.
	# Indoor volleyball shakes hands with the referee and then along the net, so its players
	# end up back at the net, not beside the stand: asked only that they met at the net.
	var chair_side := {"tennis": 5.5, "table tennis": 1.0, "beach": 2.0}.get(sport, -99.0) as float
	_expect(await _until(func() -> bool:
		return arena.players.all(func(p: Player) -> bool: return p.position.x > chair_side), 15.0),
		"%s: and then go to the umpire" % sport)
	_expect(await _until(func() -> bool: return arena.ui._ending.visible, 40.0),
		"%s: the result follows it" % sport)
	await get_tree().process_frame
	_expect(_officials_left(arena) == 0, "%s: the umpire is gone with it" % sport)
	arena.queue_free()
	await get_tree().process_frame


func _taken_off(sport: String) -> void:
	print("=== %s taken off" % sport)
	var arena := await _arena(WITH_SCENES[sport])
	await _under_way(arena)
	var removals_before := arena.career.times_removed
	arena.suspicion.is_removed = true
	arena.suspicion.removed_from_match.emit()
	_expect(await _until(func() -> bool: return arena.cutscene != null, 3.0),
		"%s: the official comes on" % sport)
	_expect(arena.career.times_removed == removals_before + 1,
		"%s: being taken off is saved before the walk off starts" % sport)
	_expect(Career.load_or_start().times_removed == arena.career.times_removed,
		"%s: and it is on disk" % sport)
	_expect(await _until(func() -> bool: return arena.ui._ending.visible, 40.0),
		"%s: the result follows it" % sport)
	arena.queue_free()
	await get_tree().process_frame


func _walked_out(sport: String) -> void:
	print("=== %s walked out" % sport)
	var arena := await _arena(WITH_SCENES[sport])
	await _under_way(arena)
	arena.ui.walk_out_requested.emit()
	await get_tree().create_timer(1.8).timeout
	_expect(arena.cutscene == null, "%s: walking out has no cutscene" % sport)
	_expect(arena.ui._ending.visible, "%s: the result comes straight up" % sport)
	arena.queue_free()
	await get_tree().process_frame


func _moved_up(sport: String) -> void:
	print("=== %s moved up" % sport)
	var arena := await _arena(WITH_SCENES[sport])
	arena.career.matches_at_tier = int(arena.career.venue()["matches_needed"]) - 1
	arena.career.reputation = 1.0
	var tier_before := arena.career.tier
	await _under_way(arena)
	arena.cutscenes = false
	arena.finish("RED WIN", Color.RED, false)
	await get_tree().process_frame
	_expect(arena.career.tier == tier_before + 1 and arena._promoted,
		"%s: a promotion is noticed" % sport)
	arena.cutscenes = true
	arena.cutscene = arena._make_cutscene()
	var shown := {"done": false}
	arena.cutscene.done.connect(func() -> void: shown.done = true)
	arena.cutscene.moved_up(arena.career.venue())
	_expect(await _until(func() -> bool: return shown.done, 15.0),
		"%s: the new court is shown and it ends" % sport)
	arena.queue_free()
	await get_tree().process_frame


func _no_scenes(sport: String) -> void:
	print("=== %s, which has no scenes yet" % sport)
	var arena := await _arena(WITHOUT[sport])
	await _into_a_match(arena)
	_expect(await _until(func() -> bool: return arena._phase == OfficiatedMatch.Phase.READY, 3.0),
		"%s: the match begins straight away" % sport)
	_expect(arena.cutscene == null and not arena.ui.is_broadcasting(), "%s: nothing is broadcast" % sport)
	arena.ui.walk_out_requested.emit()
	_expect(await _until(func() -> bool: return arena.ui._ending.visible, 3.0),
		"%s: and a finished match goes straight to the result" % sport)
	arena.queue_free()
	await get_tree().process_frame
