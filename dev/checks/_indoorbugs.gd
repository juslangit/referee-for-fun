extends Node

## Luqman's three reports, reproduced.
##
##   1. No line judges on court.
##   2. The six are not standing in their positions when the match starts.
##   3. Pressing SPACE after the first serve gives no rally.
##
## All three were fixed. This is now the check that keeps them fixed, so it ends in
## PASS or FAIL rather than only printing what it found. A wall of numbers with no
## verdict reads exactly the same whether the game is healthy or broken, and these
## three in particular were found by Luqman playing rather than by anything here —
## which is the reason to make them fail out loud if they ever come back.

var _failures: Array[String] = []


func _expect(ok: bool, what: String) -> void:
	if not ok:
		_failures.append(what)


func _ready() -> void:
	var arena: Node = load("res://scenes/volleyball.tscn").instantiate()
	arena.print_truth_while_testing = false
	add_child(arena)
	await get_tree().physics_frame

	arena.career = Career.new()
	arena.career.sport = Career.INDOOR
	# The rung a new career actually starts on, which is where the report came from.
	arena.career.tier = int(OS.get_environment("TIER")) if OS.has_environment("TIER") else 0
	arena.settings.taught_indoor = true
	arena.ui.match_requested.emit()
	await get_tree().process_frame
	if arena.pressure.exists():
		arena.ui.briefing_acknowledged.emit()
		await get_tree().process_frame
	arena.begin_match()
	for f in 6:
		await get_tree().physics_frame

	print("1. LINE JUDGES")
	var promised: bool = arena.career.venue()["line_judges"]
	# Typed by hand: `arena` is a bare Node here, so the compiler cannot infer an int
	# out of `line_judges.size()` and the whole script silently fails to parse.
	var built: int = arena.line_judges.size()
	var seen: int = _visible(arena.line_judges)
	print("   venue promises them: %s" % promised)
	print("   built: %d, visible: %d" % [built, seen])
	if promised:
		_expect(built > 0, "the venue promises line judges and none were built")
		_expect(seen == built, "%d line judge(s) were built but only %d are visible" % [built, seen])

	print()
	print("2. WHERE THE TWELVE ARE STANDING, before a ball is served")
	for team in [Sides.Team.RED, Sides.Team.BLUE]:
		var spots: Array[String] = []
		for player in arena.team_of(team):
			spots.append("%.1f,%.1f" % [player.position.x, player.position.z])
		print("   %-5s %s" % [Sides.label(team), "  ".join(spots)])
	print("   all on the same spot: %s" % _stacked(arena))
	_expect(not _stacked(arena), "the six are standing on one spot before the first serve")

	print()
	print("3. PRESSING SPACE, RALLY BY RALLY")
	var played := 0
	for attempt in 6:
		if arena._phase != arena.Phase.READY:
			print("   attempt %d: phase is %d, not READY — nothing would happen" % [
				attempt + 1, arena._phase])
			break
		arena.start_rally()
		var waited := 0
		while arena._phase == arena.Phase.IN_PLAY and waited < 4000:
			await get_tree().physics_frame
			waited += 1
		if arena._phase != arena.Phase.AWAITING_CALL:
			print("   attempt %d: the rally never came down (phase %d after %d frames)" % [
				attempt + 1, arena._phase, waited])
			break
		played += 1
		print("   attempt %d: rally played, %d contacts, landed %.1f,%.1f" % [
			attempt + 1, arena.rally.contacts,
			arena.rally.landing_point.x, arena.rally.landing_point.z])
		arena._awaiting_since = Time.get_ticks_msec()
		arena.make_call(&"in" if arena.rally.was_in else &"out")
		var settle := 0
		while arena._phase == arena.Phase.AWAITING_CALL and settle < 600:
			await get_tree().process_frame
			settle += 1
	_expect(played == 6, "only %d of 6 whistles produced a rally" % played)

	print("")
	if _failures.is_empty():
		print("PASS  all three reports stay fixed")
	else:
		for failure in _failures:
			print("FAIL  " + failure)
	get_tree().quit()


func _visible(judges: Array) -> int:
	var seen := 0
	for judge in judges:
		if judge.visible:
			seen += 1
	return seen


func _stacked(arena: Node) -> bool:
	var first: Vector3 = arena.players[0].position
	for player in arena.players:
		if player.team == arena.players[0].team and player.position.distance_to(first) > 0.4:
			return false
	return true
