extends Node

## Does the badminton reputation meter move when the umpire lies?
##
## `_whatsmissing` reported the meter appearing zero times in six blatant badminton lies,
## while every other sport showed it every time. This asks the narrower question with the
## numbers printed: what the call was recorded as, what suspicion did, and what the
## reputation was before and after.

func _ready() -> void:
	var hall: Node = load("res://scenes/match.tscn").instantiate()
	hall.print_truth_while_testing = false
	add_child(hall)
	await get_tree().physics_frame
	hall.career = Career.new()
	hall.career.sport = Career.BADMINTON
	hall.career.reputation = 0.80
	hall.settings.taught = true
	hall._on_match_requested()
	if hall.pressure.exists():
		hall.ui.hide_briefing()
	hall.begin_match()
	for f in 4:
		await get_tree().process_frame

	print("the HUD is up: %s   (the meter refuses to draw without it)" % hall.ui._hud.visible)
	print("%4s %10s %-10s %10s %12s %8s %8s %6s  %s" % [
		"#", "landed", "called", "verdict", "suspicion", "name", "meter", "note",
		"what it said"])
	# A fall in reputation with no sentence beside it is the empty panel case.
	#
	# Measured off reputation itself rather than off the meter being visible, which was
	# the first version and was wrong: the meter is also put up at the start of a match
	# and at the end of every set, with nothing having moved and deliberately no reason
	# beside it. Reading those as falls made row 0 fail for doing exactly what it should.
	var silent_falls := 0

	for r in 6:
		hall.start_rally()
		var w := 0
		while hall._phase != hall.Phase.AWAITING_CALL and w < 3000:
			await get_tree().physics_frame
			w += 1
		if hall._phase != hall.Phase.AWAITING_CALL:
			print("  rally %d never reached a call" % r)
			break

		var rally: Rally = hall.rally
		var before := roundi(hall.career.reputation_as_it_stands(
			hall.suspicion.level, hall.suspicion.is_removed) * 100.0)
		hall._awaiting_since = Time.get_ticks_msec()
		# A blatant lie: the opposite of what the shuttle did.
		hall.make_call(&"in" if not rally.was_in else &"out")

		var shown := false
		var noted := false
		var said := ""
		var w2 := 0
		while w2 < 240:
			await get_tree().process_frame
			w2 += 1
			if hall.ui._meter != null and hall.ui._meter.visible:
				shown = true
			if hall.ui._reason != null and hall.ui._reason.visible:
				noted = true
				said = hall.ui._reason_label.text
			if hall._phase != hall.Phase.AWAITING_CALL and w2 > 40:
				break

		var after := roundi(hall.career.reputation_as_it_stands(
			hall.suspicion.level, hall.suspicion.is_removed) * 100.0)
		var fell := after < before
		# The removal is the exception, and deliberately so. finish() tears the meter
		# down and stops it reporting, because the last fall of a match that ends with
		# the umpire being taken off has a whole screen to explain it and does not need
		# a sentence in the corner as well.
		var thrown_off: bool = hall._phase == hall.Phase.REMOVED
		if fell and not noted and not thrown_off:
			silent_falls += 1
		print("%4d %10s %-10s %10s %12.4f %8s %8s %6s  %s" % [
			r,
			"IN" if rally.was_in else "OUT",
			rally.call.label if rally.call != null else "nothing",
			Rally.Verdict.keys()[rally.verdict()],
			hall.suspicion.level,
			"%d>%d" % [before, after] if fell else "%d" % after,
			"SHOWN" if shown else "no",
			"yes" if noted else ("removed" if hall._phase == hall.Phase.REMOVED else "-"),
			said,
		])
		if hall._phase == hall.Phase.REMOVED:
			break

	print("")
	if silent_falls == 0:
		print("every fall in reputation came with a reason, bar the removal")
		print("   (MUST BE 0 silent falls)")
	else:
		print("%d meter drop(s) with an empty panel beside them   <-- PROBLEM" % silent_falls)
	get_tree().quit()
