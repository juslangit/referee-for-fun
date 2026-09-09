extends Node

## Does a beach rally actually play, and does an honest referee survive it?
##
## The same two questions the badminton harness asks, and the second one matters more
## here than anywhere: the touch call is new, it is priced differently from a line call,
## and if that pricing is wrong then a referee who gives every touch correctly still
## ends the match looking bought. That was exactly the bug Luqman found in badminton.

func _ready() -> void:
	var arena: Node = load("res://scenes/beach.tscn").instantiate()
	arena.print_truth_while_testing = false
	add_child(arena)
	await get_tree().physics_frame
	# In through the front of the match, the way a player does: the career screen now
	# comes up first, so nothing is ready until it has been asked for.
	arena.career = Career.new()
	arena.career.sport = Career.BEACH
	arena.ui.match_requested.emit()
	await get_tree().process_frame
	# Some venues open with a briefing, and its sheet covers the whole screen. Leaving
	# it up does not stop the match — begin_match works either way — it just darkens
	# every picture taken afterwards by 72%, which reads as a lighting bug.
	if arena.pressure.exists():
		arena.ui.briefing_acknowledged.emit()
		await get_tree().process_frame
	arena.begin_match()
	for f in 3:
		await get_tree().process_frame

	var judged := 0
	var landed_in := 0
	var touched := 0
	var wrong := 0
	var contacts := 0
	var abandoned := 0
	var margins: Array[float] = []

	for frame in 40000:
		await get_tree().process_frame
		if arena._phase == arena.Phase.READY:
			arena.start_rally()
			continue
		if arena._phase != arena.Phase.AWAITING_CALL:
			continue

		var rally: BeachRally = arena.rally
		if rally.contacts < 3:
			abandoned += 1
			print("   died on beat %d after %d contacts: aimed at %.2f,%.2f  landed %.2f,%.2f" % [
				arena._beat, rally.contacts, arena._aim.x, arena._aim.z,
				rally.landing_point.x, rally.landing_point.z])
		contacts += rally.contacts
		if rally.was_in:
			landed_in += 1
		if rally.was_touched:
			touched += 1
		margins.append(rally.margin)

		# The honest referee, and honest means *everything*: the faults as well as the
		# line and the touch. A referee who gives only the line is not being honest,
		# they are ignoring half the rulebook — that was the badminton harness's
		# LINES ONLY umpire, and reading its suspicion as unfairness was a mistake
		# once already.
		arena._awaiting_since = Time.get_ticks_msec()
		if rally.foot_fault:
			arena.make_call(&"foot_fault", arena.serving)
		elif rally.handling_fault:
			arena.make_call(&"double_contact", rally.struck_by)
		elif arena.net_toucher != Sides.Team.NONE:
			arena.make_call(&"net_touch", arena.net_toucher)
		elif arena.centre_line_crosser != Sides.Team.NONE:
			arena.make_call(&"centre_line", arena.centre_line_crosser)
		elif rally.was_in:
			arena.make_call(&"in")
		elif rally.was_touched:
			arena.make_call(&"touch")
		else:
			arena.make_call(&"out")

		if rally.verdict() == BeachRally.Verdict.WRONG:
			wrong += 1
			print("   WRONG: %s" % rally.describe())

		judged += 1
		if judged >= 30 or arena.board.is_over:
			break

	print("rallies judged:  %d" % judged)
	print("touches a rally: %.1f  (three is a clean rally: dig, set, attack)" % [
		float(contacts) / maxf(1.0, float(judged))])
	print("rallies that never reached an attack: %d" % abandoned)
	print("landed in:       %d  (%.0f%%)" % [
		landed_in, 100.0 * float(landed_in) / maxf(1.0, float(judged))])
	print("block touches:   %d  (%.0f%% of all rallies)" % [
		touched, 100.0 * float(touched) / maxf(1.0, float(judged))])
	print("scored WRONG:    %d   (must be 0 — this referee told the truth every time)" % wrong)
	print("suspicion:       %.3f   (warning at %.2f)" % [
		arena.suspicion.level, Suspicion.WARNING_LEVEL])

	if margins.size() > 0:
		# By how near the line, not by which side of it. Sorting the signed margins and
		# reading the first was reporting the ball that missed by the *most*.
		var nearness: Array[float] = []
		for m in margins:
			nearness.append(absf(m))
		nearness.sort()
		var within := 0
		for n in nearness:
			if n < 0.25:
				within += 1
		print("closest call:    %.3f m from the line" % nearness[0])
		print("within 25 cm of a line: %d of %d  (%.0f%%) — these are the ones worth lying about" % [
			within, judged, 100.0 * float(within) / maxf(1.0, float(judged))])
	get_tree().quit()
