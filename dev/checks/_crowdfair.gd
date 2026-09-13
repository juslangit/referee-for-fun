extends Node

## Does the hall ever get angry at an umpire who was right?
##
## Luqman found this by playing: "sometimes if the referee made the right decision, the
## CPU still get mad at the player". `Crowd.react_to_call` took how plainly the ball
## could be read and the mood, and nothing else — so a ball plainly out that the umpire
## correctly called out arrived at 0.9 and the hall shouted "CHEAT!". The verdict was
## never passed in, and the function's own docstring claimed the opposite.
##
## The second half is the room coming round. It must be **earnable and rare**: it takes a
## visible bad call to sour the room, then three correct calls in a row, and then it is
## spent. A hall that says something approving on any correct call would be a scoreboard,
## and this game does not have one.

func _ready() -> void:
	_the_hall_never_turns_on_a_correct_call()
	print()
	_the_room_comes_round()
	print()
	_it_has_to_be_earned()
	print()
	await _in_a_real_match()
	print()
	print("PASS" if _problems.is_empty() else "FAIL:\n   " + "\n   ".join(_problems))
	get_tree().quit()


var _problems: Array[String] = []


func _must_be(what: String, got: int, wanted: int) -> void:
	if got != wanted:
		_problems.append("%s: %d, must be %d" % [what, got, wanted])


## The whole path, through judge() rather than through Suspicion on its own.
##
## The isolated tests above prove the arithmetic. This proves the wiring: that the line
## actually reaches the screen, that the players play the nod, and that an umpire who
## lies twice and then referees straight gets the room back.
func _in_a_real_match() -> void:
	print("and the same thing happening in a match")
	var hall: Node = load("res://scenes/table_tennis.tscn").instantiate()
	hall.print_truth_while_testing = false
	add_child(hall)
	await get_tree().physics_frame
	hall.career = Career.new()
	hall.career.sport = Career.TABLE_TENNIS
	hall.settings.taught_table_tennis = true
	hall._on_match_requested()
	if hall.pressure.exists():
		hall.ui.hide_briefing()
	hall.begin_match()
	for f in 4:
		await get_tree().process_frame

	var approved := 0
	var nodded := 0
	print("   %4s %-9s %-38s %s" % ["#", "verdict", "what the hall said", "players"])
	# Lies until two of them were plain enough to sour the room, then seven straight calls.
	# Lying on the first two rallies regardless came out 0/0 whenever both were edge balls
	# nobody could read — which the game is right to forgive nothing for.
	var visible_lies := 0
	var straight := 0
	for r in 24:
		if straight >= 7:
			break
		hall.start_rally()
		var w := 0
		while hall._phase != hall.Phase.AWAITING_CALL and w < 4000:
			await get_tree().physics_frame
			w += 1
		if hall._phase != hall.Phase.AWAITING_CALL:
			break

		var rally = hall.rally
		hall._awaiting_since = Time.get_ticks_msec()
		# A line stays up for 2.6 s and a short rally is shorter than that, so the last
		# call's line can still be on screen. Read, it counted one coming round twice.
		hall.ui._reaction_label.text = ""
		var lying := visible_lies < 2
		if lying:
			hall.make_call(&"in" if not rally.was_in else &"out")
		elif rally.is_a_let():
			hall.make_call(&"let", rally.served_by)
		elif rally.illegal_service:
			hall.make_call(&"illegal_service", rally.served_by)
		else:
			hall.make_call(&"in" if rally.rightful_winner() == rally.struck_by else &"out")

		if lying:
			if rally.verdict() == Rally.Verdict.WRONG \
					and rally.visibility() >= Suspicion.SOURS_THE_ROOM:
				visible_lies += 1
		else:
			straight += 1

		var said := ""
		var nodding := false
		for f in 40:
			await get_tree().process_frame
			if hall.ui._reaction_label != null and not hall.ui._reaction_label.text.is_empty():
				said = hall.ui._reaction_label.text
			for player in hall.players:
				if player.playing_clip() == "nod":
					nodding = true
		if said in Crowd.APPROVAL:
			approved += 1
		if nodding:
			nodded += 1
		print("   %4d %-9s %-38s %s" % [
			r,
			Rally.Verdict.keys()[rally.verdict()],
			said if not said.is_empty() else "(nothing)",
			"a nod towards the chair" if nodding else "",
		])
		if hall.board.is_over or hall._phase == hall.Phase.REMOVED:
			break

	if straight < 7:
		_problems.append("the match ran out after %d visible lies and %d straight calls"
			% [visible_lies, straight])
	print("   the hall came round %d time(s)   (MUST BE 1)" % approved)
	print("   the players acknowledged it %d time(s)   (MUST BE 1)" % nodded)
	_must_be("the hall came round in a match", approved, 1)
	_must_be("the players acknowledged it in a match", nodded, 1)


func _the_hall_never_turns_on_a_correct_call() -> void:
	print("what the hall says about a CORRECT call, at every visibility and mood")
	print("  (every one of these must be silence)")
	var spoke := 0
	for mood in [Suspicion.Mood.SETTLED, Suspicion.Mood.MURMURING,
			Suspicion.Mood.RESTLESS, Suspicion.Mood.HOSTILE, Suspicion.Mood.WARNED]:
		for step in 11:
			var seen := float(step) / 10.0
			var said := Crowd.react_to_call(seen, mood, false)
			if not said.is_empty():
				spoke += 1
				print("   %-10s visibility %.1f -> %s" % [
					Suspicion.Mood.keys()[mood], seen, said])
	print("  lines drawn by a correct call: %d   (MUST BE 0)" % spoke)
	_must_be("lines drawn by a correct call", spoke, 0)

	print("")
	print("and it still objects to a WRONG one, which is the whole point of it")
	var silent := 0
	for seen in [0.35, 0.60, 0.90]:
		var said := Crowd.react_to_call(seen, Suspicion.Mood.SETTLED, true)
		if said.is_empty():
			silent += 1
		print("   visibility %.2f -> %s" % [seen, said if not said.is_empty() else "(nothing)"])
	print("  plainly wrong calls that drew nothing: %d   (MUST BE 0)" % silent)
	_must_be("plainly wrong calls that drew nothing", silent, 0)


func _the_room_comes_round() -> void:
	print("a bad patch, and then putting it right")
	var suspicion := Suspicion.new()
	suspicion.scrutiny = 1.0

	print("   %-26s %-9s %5s %7s %s" % [
		"", "verdict", "run", "owed", "the hall"])
	# Two plain lies, then correct calls until the room says something.
	for i in 2:
		_wrong(suspicion, 0.8)
		_report(suspicion, "a plain wrong call", "WRONG")
	for i in 4:
		_correct(suspicion)
		_report(suspicion, "a correct call", "correct")


## The room must not come round off a clean run alone — there has to have been something
## to forgive first.
func _it_has_to_be_earned() -> void:
	print("an umpire who was never wrong is never congratulated")
	var suspicion := Suspicion.new()
	suspicion.scrutiny = 1.0
	var said := 0
	for i in 12:
		_correct(suspicion)
		if suspicion.the_room_comes_round():
			said += 1
	print("   12 correct calls from a clean sheet -> the hall spoke %d times   (MUST BE 0)"
		% said)
	_must_be("a clean sheet congratulated", said, 0)

	print("")
	print("and a lie nobody could see leaves nothing to forgive")
	var quiet := Suspicion.new()
	quiet.scrutiny = 1.0
	_wrong(quiet, 0.05)
	var after := 0
	for i in 6:
		_correct(quiet)
		if quiet.the_room_comes_round():
			after += 1
	print("   an invisible lie, then six correct calls -> spoke %d times   (MUST BE 0)"
		% after)
	_must_be("an invisible lie forgiven", after, 0)

	print("")
	print("but it only forgives you once per bad patch")
	var twice := Suspicion.new()
	twice.scrutiny = 1.0
	_wrong(twice, 0.8)
	var times := 0
	for i in 9:
		_correct(twice)
		if twice.the_room_comes_round():
			times += 1
	print("   one visible lie, then nine correct calls -> spoke %d times   (MUST BE 1)"
		% times)
	_must_be("one visible lie forgiven", times, 1)


func _wrong(suspicion: Suspicion, seen: float) -> void:
	suspicion.register_judgement(
		Rally.Verdict.WRONG as int, seen, 0.0, 1.0, 0.0, false, false, true)


func _correct(suspicion: Suspicion) -> void:
	suspicion.register_judgement(
		Rally.Verdict.CORRECT as int, 0.9, 0.0, 1.0, 0.0, false, false, false)


## `verdict` is passed in rather than read back off `clean_run`. Coming round resets the
## run, so the very call that earned it reported itself as a wrong one.
func _report(suspicion: Suspicion, what: String, verdict: String) -> void:
	var run := suspicion.clean_run
	var came_round := suspicion.the_room_comes_round()
	print("   %-26s %-9s %5d %7s %s" % [
		what,
		verdict,
		run,
		"yes" if suspicion.owed_a_word else "no",
		Crowd.react_to_recovery() if came_round else "(nothing)",
	])
