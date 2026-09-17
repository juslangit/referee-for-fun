extends Node

## Does a sepak takraw rally actually play, and does an honest referee survive it?
##
## The beach harness's two questions, asked of the sixth sport, plus the two things only this
## sport has: the service changes sides after every point whoever wins it, and every fault the
## referee can call — the serve's feet, an arm, the net, a crossing, a fourth touch — really
## happens, and is scored correct when it is called honestly.
##
##   godot --headless --path . res://dev/checks/_takrawplay.tscn
##   DOUBLES=1 for doubles. Ends in PASS or FAIL.

const RALLIES := 60


func _ready() -> void:
	var doubles := OS.has_environment("DOUBLES")
	var arena: Node = load("res://scenes/sepak_takraw.tscn").instantiate()
	arena.print_truth_while_testing = false
	add_child(arena)
	await get_tree().physics_frame
	arena.career = Career.new()
	arena.career.sport = Career.TAKRAW
	arena.career.doubles = doubles
	# A full best-of-three, so there are enough rallies for every kind of fault to turn up.
	arena.career.tier = 2
	arena.rebuild_players()
	arena.ui.match_requested.emit()
	await get_tree().process_frame
	if arena.pressure.exists():
		arena.ui.briefing_acknowledged.emit()
		await get_tree().process_frame
	arena.begin_match()
	for f in 3:
		await get_tree().process_frame

	var reasons: Array[String] = []
	var judged := 0
	var landed_in := 0
	var touched := 0
	var wrong := 0
	var died := 0
	var contacts := 0
	var faults := {}
	var server_before := Sides.Team.NONE
	var sets_before := 0
	var per_side: int = arena.players.size() / 2
	if per_side != (2 if doubles else 3):
		reasons.append("%d players a side, expected %d" % [per_side, 2 if doubles else 3])

	for frame in 90000:
		await get_tree().process_frame
		if arena._phase == arena.Phase.READY:
			server_before = arena.serving
			sets_before = arena.board.finished_sets.size()
			arena.start_rally()
			continue
		if arena._phase != arena.Phase.AWAITING_CALL:
			continue

		var rally: TakrawRally = arena.rally
		contacts += rally.contacts
		if rally.contacts < 3 and rally.struck_by != rally.served_by:
			died += 1
		if rally.was_in:
			landed_in += 1
		if rally.was_touched:
			touched += 1
		# Net touches and crossings are kept on the match until the call copies them over.
		var fault: Dictionary = rally._the_fault()
		var kind: StringName = fault.get("id", &"")
		if arena.net_toucher != Sides.Team.NONE:
			kind = &"net_touch"
		elif arena.centre_line_crosser != Sides.Team.NONE:
			kind = &"crossing"
		if kind != &"":
			faults[kind] = int(faults.get(kind, 0)) + 1

		# The honest referee: every fault that happened, then the touch, then the line.
		arena._awaiting_since = Time.get_ticks_msec()
		if rally.foot_fault:
			arena.make_call(&"service_fault", rally.served_by)
		elif rally.inside_fault:
			arena.make_call(&"inside_fault", rally.served_by)
		elif arena.net_toucher != Sides.Team.NONE:
			arena.make_call(&"net_touch", arena.net_toucher)
		elif arena.centre_line_crosser != Sides.Team.NONE:
			arena.make_call(&"crossing", arena.centre_line_crosser)
		elif rally.arm_toucher != Sides.Team.NONE:
			arena.make_call(&"arm", rally.arm_toucher)
		elif rally.four_toucher != Sides.Team.NONE:
			arena.make_call(&"four_touches", rally.four_toucher)
		elif rally.was_in:
			arena.make_call(&"in")
		elif rally.was_touched:
			arena.make_call(&"touch")
		else:
			arena.make_call(&"out")
		for f in 2:
			await get_tree().process_frame

		if rally.verdict() == Rally.Verdict.WRONG:
			wrong += 1
			print("   WRONG: %s" % rally.describe())
		# The serve goes to the other side after every point, except at a new set.
		if arena.board.finished_sets.size() == sets_before and not arena.board.is_over:
			if arena.serving == server_before:
				reasons.append("the serve stayed with %s after a point" % Sides.label(server_before))

		judged += 1
		if judged >= RALLIES or arena.board.is_over:
			break

	# A lie, to prove the check can fail: a fault invented against a side that did nothing.
	var liar := TakrawRally.new()
	liar.served_by = Sides.Team.RED
	liar.record_call(TakrawCallBook.get_call(&"service_fault"), Sides.Team.RED)
	if liar.verdict() != Rally.Verdict.WRONG:
		reasons.append("an invented service fault was not scored wrong")
	var scores := TakrawScore.new(false)
	for i in 14:
		scores.award(Sides.Team.RED)
		scores.award(Sides.Team.BLUE)
	scores.award(Sides.Team.RED)
	scores.award(Sides.Team.RED)
	if scores.games[Sides.Team.RED] != 0:
		reasons.append("16-14 ended a set that had been set up to 17")
	scores.award(Sides.Team.RED)
	if scores.games[Sides.Team.RED] != 1:
		reasons.append("17-14 did not win the set")

	print("format:          %s" % ("doubles" if doubles else "regu"))
	print("rallies judged:  %d" % judged)
	print("touches a rally: %.1f" % (float(contacts) / maxf(1.0, float(judged))))
	print("receiving side never reached a spike: %d" % died)
	print("landed in:       %d  (%.0f%%)" % [landed_in, 100.0 * landed_in / maxf(1.0, judged)])
	print("block touches:   %d" % touched)
	print("faults:          %s" % faults)
	print("scored WRONG:    %d   (must be 0)" % wrong)
	print("suspicion:       %.3f" % arena.suspicion.level)
	if wrong > 0:
		reasons.append("%d honest calls scored wrong" % wrong)
	if judged < 20:
		reasons.append("only %d rallies reached a call" % judged)
	if landed_in == 0 or landed_in == judged:
		reasons.append("every rally landed the same side of the line")
	if faults.size() < 3:
		reasons.append("only %d kinds of fault happened" % faults.size())
	if reasons.is_empty():
		print("PASS  sepak takraw plays, serves alternate, and an honest referee is right")
	else:
		print("FAIL  " + "; ".join(reasons))
	get_tree().quit()
