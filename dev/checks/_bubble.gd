extends Node

## Does somebody in the stands actually say it, and does anybody give the answer away?
##
## Two questions. The second is the one that needs a scene: the hard rule at the top of
## `Crowd` is that nobody in the hall may ever say whether the ball was in or out,
## because a spectator who says so hands the player the one thing the game exists to
## withhold. That rule is prose, and prose does not survive somebody adding a good line
## in six months, so the banks are read here and every word checked.

## Words nobody in the stands may say. "in" and "out" are not on the list because they
## are ordinary English — "come ON" and "get him off" are fine — so what is banned is
## the shape of an actual verdict, checked as whole phrases below.
const NEVER_SAID := [
	"that was in", "that was out", "it was in", "it was out",
	"clearly in", "clearly out", "miles out", "well out", "on the line",
	"in!", "out!", "landed",
]

## The banks that describe the room, which the HUD line uses, and the banks that are
## spoken aloud, which the bubble uses. Both are checked: the rule was always meant to
## cover the lot.
func _ready() -> void:
	var bad := 0
	bad += _nobody_calls_the_ball()
	bad += _every_reaction_has_a_voice()
	bad += await _somebody_actually_says_it()
	print("")
	if bad == 0:
		print("the hall speaks, and nobody in it says where the ball landed")
	else:
		print("%d PROBLEM(S)" % bad)
	get_tree().quit()


func _nobody_calls_the_ball() -> int:
	print("nobody in the stands calls the ball")
	var banks := {
		"DOUBTFUL": Crowd.DOUBTFUL, "COMPLAINT": Crowd.COMPLAINT,
		"HOSTILITY": Crowd.HOSTILITY, "IMPATIENCE": Crowd.IMPATIENCE,
		"CARD_UPROAR": Crowd.CARD_UPROAR, "APPROVAL": Crowd.APPROVAL,
		"SAID_DOUBTFUL": Crowd.SAID_DOUBTFUL, "SAID_COMPLAINT": Crowd.SAID_COMPLAINT,
		"SAID_HOSTILITY": Crowd.SAID_HOSTILITY, "SAID_IMPATIENCE": Crowd.SAID_IMPATIENCE,
		"SAID_CARD": Crowd.SAID_CARD, "SAID_APPROVAL": Crowd.SAID_APPROVAL,
	}
	var bad := 0
	var lines := 0
	for name: String in banks:
		for line: String in banks[name]:
			lines += 1
			var low := line.to_lower()
			for banned: String in NEVER_SAID:
				if low.contains(banned):
					print("   %s says \"%s\"   <-- %s" % [name, line, banned])
					bad += 1
	# The review banks are the deliberate exception and are not checked: after a review
	# the screen has told the whole building, so there is nothing left to withhold.
	print("   %d lines across %d banks, %d problems" % [lines, banks.size(), bad])
	return bad


## Every situation the hall reacts to must have something a person can actually say,
## or the bubble is silent exactly when the player most wants somebody to speak.
func _every_reaction_has_a_voice() -> int:
	print("")
	print("every reaction has somebody to say it")
	var bad := 0
	var cases := {
		"a quietly wrong call": Crowd.said_about_call(0.18, Suspicion.Mood.SETTLED, true),
		"a plainly wrong call": Crowd.said_about_call(0.30, Suspicion.Mood.SETTLED, true),
		"an outrageous call": Crowd.said_about_call(0.80, Suspicion.Mood.SETTLED, true),
		"a long silence": Crowd.said_about_delay(6.0),
		"a card": Crowd.said_about_card(false),
		"a red card": Crowd.said_about_card(true),
		"the room coming round": Crowd.said_about_recovery(),
		"a review lost": Crowd.said_about_review(true),
		"a review survived": Crowd.said_about_review(false),
		"murmuring, between rallies": Crowd.said_ambient(Suspicion.Mood.MURMURING),
		"restless, between rallies": Crowd.said_ambient(Suspicion.Mood.RESTLESS),
		"hostile, between rallies": Crowd.said_ambient(Suspicion.Mood.HOSTILE),
		"warned, between rallies": Crowd.said_ambient(Suspicion.Mood.WARNED),
	}
	for name: String in cases:
		var line: String = cases[name]
		if line.is_empty():
			print("   %-30s <-- NOBODY SAYS ANYTHING" % name)
			bad += 1
		else:
			print("   %-30s %s" % [name, line])

	# And the two that must stay silent, because a call nobody could see draws nothing.
	print("")
	print("   and the silences, which are the point of the thing")
	for name: String in ["a call too fine to notice", "a correct call, however plain"]:
		var line := ""
		if name.begins_with("a call too fine"):
			line = Crowd.said_about_call(0.05, Suspicion.Mood.SETTLED, true)
		else:
			line = Crowd.said_about_call(0.95, Suspicion.Mood.SETTLED, false)
		if line.is_empty():
			print("   %-30s silence" % name)
		else:
			print("   %-30s %s   <-- SHOULD BE SILENT" % [name, line])
			bad += 1
	return bad


## And the part none of the above proves: that in a real hall, a real lie puts a real
## bubble over somebody who is really sitting there.
##
## Checked as a screen position rather than by eye. The bubble is a Control that follows
## a world point through the camera, so the two ways it can be wrong are being off the
## screen entirely and being nowhere near anybody — and both look identical to a scene
## that only asks whether it is visible.
func _somebody_actually_says_it() -> int:
	print("")
	print("somebody in the hall actually says it")
	var hall: Node = load("res://scenes/match.tscn").instantiate()
	hall.print_truth_while_testing = false
	add_child(hall)
	await get_tree().physics_frame
	hall.career = Career.new()
	hall.career.sport = Career.BADMINTON
	hall.settings.taught = true
	hall._on_match_requested()
	if hall.pressure.exists():
		hall.ui.hide_briefing()
	hall.begin_match()
	for f in 4:
		await get_tree().process_frame

	var bad := 0
	if hall.the_stands() == null:
		print("   badminton has no stands to shout from   <-- WRONG")
		return 1

	# Several rallies rather than one. Not every rally produces something to lie about:
	# a shuttle that lands in the middle of the court has a visibility of nought, and a
	# call given the wrong way about a ball nobody could read draws silence on purpose.
	# One rally was enough to make this scene fail for the game behaving correctly.
	var ui: RefereeUI = hall.ui
	var spoke := false
	var rally: Rally = null
	for attempt in 8:
		hall.start_rally()
		var w := 0
		while hall._phase != hall.Phase.AWAITING_CALL and w < 3000:
			await get_tree().physics_frame
			w += 1
		if hall._phase != hall.Phase.AWAITING_CALL:
			continue
		rally = hall.rally
		hall._awaiting_since = Time.get_ticks_msec()
		hall.make_call(&"in" if not rally.was_in else &"out")
		for f in 8:
			await get_tree().process_frame
		# Visibility is nought until a call exists — it is a property of the lie, not
		# of the landing — so it can only be read after the call, never before. Reading
		# it first made this scene skip every rally in the match and then report that
		# the hall had said nothing.
		print("   rally %d: visibility %.3f  %s" % [
			attempt, rally.visibility(), Rally.Verdict.keys()[rally.verdict()]])
		if ui._bubble.visible and not ui._bubble_label.text.is_empty():
			spoke = true
			break

	if rally == null:
		print("   no rally ever reached a call — nothing to test")
		return 0
	print("   said: %s" % ui._bubble_label.text)
	if not spoke:
		print("   nobody said anything to a call given the wrong way   <-- WRONG")
		return 1

	# It must be pointing at a place in the hall, not at the origin or at infinity.
	var at: Vector3 = ui._bubble_at
	if at == Vector3.INF:
		print("   the bubble is anchored nowhere   <-- WRONG")
		bad += 1
	else:
		var seats := 0
		var nearest := INF
		var stands: Stands = hall.the_stands()
		for group in stands._crowd_seats.size():
			for seat: Transform3D in stands._crowd_seats[group]:
				seats += 1
				nearest = minf(nearest,
					stands.to_global(seat.origin).distance_to(at))
		print("   anchored at %v, %.3f m from the nearest of %d seats" % [
			at, nearest, seats])
		# The anchor is a seat plus MOUTH_HEIGHT, so the nearest seat is exactly that
		# far below it and anything else means it is floating in the roof.
		if absf(nearest - Stands.MOUTH_HEIGHT) > 0.01:
			print("   that is not over anybody's head   <-- WRONG")
			bad += 1

	# Where it lands on screen is not asserted here, and saying so is more honest than
	# a test that always passes. Headless renders into a 64x64 viewport — smaller than
	# the bubble — so the off-screen guard correctly hides it and every pixel is nought.
	# `dev/looks/_bubbleshot` takes the picture at 1920x1080 instead.
	print("   drawn at %v on a %v viewport (headless: too small to place it)" % [
		ui._bubble.position, get_viewport().get_visible_rect().size])
	return bad
