extends Node

## The antenna call: does it happen, is it seen, and does lying about it cost anything?
##
## The truth for this has been recorded on the rally since beach volleyball was built —
## `inside_the_antennae` — and there has never been a way for the referee to say it. What
## makes it worth having is that it is the one boundary in these sports judged **in the
## air**: every other line leaves a mark in the sand that both sides walk over and look
## at, and this one leaves nothing at all.

func _ready() -> void:
	_what_a_lie_costs()
	print()
	await _does_it_happen("beach", "res://scenes/beach.tscn", Career.BEACH)
	print()
	await _does_it_happen("indoor", "res://scenes/volleyball.tscn", Career.INDOOR)
	get_tree().quit()


func _what_a_lie_costs() -> void:
	print("what the call is worth, priced by how far outside the rod it went")
	print("%-44s %10s %10s %9s" % ["", "margin", "visibility", "charged"])
	for outside in [0.04, 0.20, 0.55]:
		_price("denying it — called the ball IN", outside, &"in", false)
	_price("inventing one, the ball well inside", -1.60, &"antenna", true)
	_price("calling it correctly", 0.30, &"antenna", true)


func _price(what: String, outside: float, id: StringName, accuse: bool) -> void:
	var rally := BeachRally.new()
	rally.struck_by = Sides.Team.RED
	rally.record_landing(Vector3(1.0, 0.02, 6.0), Sides.Team.BLUE)
	# `outside` is how far past the rod it went, so a positive number means it was NOT
	# inside. Getting that the wrong way round is what the first run of this measured.
	rally.inside_the_antennae = outside <= 0.0
	rally.antenna_margin = -outside
	rally.record_call(BeachCallBook.get_call(id),
		Sides.Team.RED if accuse else Sides.Team.NONE)

	var suspicion := Suspicion.new()
	suspicion.scrutiny = 1.0
	var charged := suspicion.register_judgement(
		rally.verdict() as int, rally.visibility(), 0.0,
		rally.call.severity, 0.4, false, false, rally.changed_the_result())
	print("%-44s %10.2f %10.3f %9.3f  %s" % [
		what, -outside, rally.visibility(), charged,
		"CORRECT" if rally.verdict() == Rally.Verdict.CORRECT else "WRONG"])


func _does_it_happen(name: String, scene: String, sport: StringName) -> void:
	var arena: Node = load(scene).instantiate()
	arena.print_truth_while_testing = false
	add_child(arena)
	await get_tree().physics_frame
	arena.career = Career.new()
	arena.career.sport = sport
	arena.settings.taught_beach = true
	arena.settings.taught_indoor = true
	arena.ui.match_requested.emit()
	await get_tree().process_frame
	if arena.pressure.exists():
		arena.ui.briefing_acknowledged.emit()
		await get_tree().process_frame
	arena.begin_match()
	for f in 3:
		await get_tree().process_frame

	var rallies := 0
	var outside := 0
	var margins: Array[float] = []
	for r in 60:
		# Forced rather than rolled. At about one rally in eighty it would take a whole
		# match to see one, and what is being checked here is the geometry, not the dice.
		arena.start_rally()
		arena._chasing_it_wide = true
		var waited := 0
		while arena._phase != arena.Phase.AWAITING_CALL and waited < 4000:
			await get_tree().physics_frame
			waited += 1
		if arena._phase != arena.Phase.AWAITING_CALL:
			break
		rallies += 1
		if not arena.rally.inside_the_antennae:
			outside += 1
			margins.append(arena.rally.antenna_margin)
		arena._awaiting_since = Time.get_ticks_msec()
		arena.make_call(&"antenna", arena.rally.struck_by) if not arena.rally.inside_the_antennae \
			else arena.make_call(&"in" if arena.rally.was_in else &"out")
		var w := 0
		while arena._phase == arena.Phase.AWAITING_CALL and w < 900:
			await get_tree().process_frame
			w += 1
		if arena.board.is_over or arena._phase == arena.Phase.REMOVED:
			break

	var worst := 0.0
	for m in margins:
		worst = minf(worst, m)
	print("%s: %d rallies, %d crossed outside an antenna (%.0f%%), furthest out %.2f m" % [
		name, rallies, outside, 100.0 * float(outside) / maxf(1.0, float(rallies)), -worst])
	arena.queue_free()
	await get_tree().process_frame
