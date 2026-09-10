extends Node

## Does the note on the left wait for the whistle?
##
## The meter is a number and is gone in three seconds. The note is a sentence, and a
## sentence read at the wrong moment is not read at all — so it holds until the umpire
## whistles the next rally, and only then fades. That is a behaviour with no visible
## failure: if the clock came back the note would still appear, still say the right
## thing, and simply be gone by the time anybody looked up from the court. So it is
## asserted rather than left to be noticed.

## Comfortably past the meter's own three seconds, so "still up" means it outlived the
## meter rather than that this scene looked too early.
const WELL_PAST_THE_METER := 4.5


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

	var bad := 0

	# A lie that actually costs something, which is not the same as a lie.
	#
	# One rally was the first version and it failed about one run in twelve for a reason
	# that had nothing to do with the note: a rally can end in a way where calling the
	# opposite of where the shuttle landed is still the correct verdict — an offence
	# happened and the point went to the side that deserved it anyway — so nothing is
	# charged, reputation does not move, and every assertion below fails at once while
	# the game is behaving perfectly. So it keeps playing until it finds one the hall
	# could see.
	var showed := false
	for attempt in 8:
		hall.start_rally()
		var w := 0
		while hall._phase != hall.Phase.AWAITING_CALL and w < 3000:
			await get_tree().physics_frame
			w += 1
		if hall._phase != hall.Phase.AWAITING_CALL:
			continue
		var rally: Rally = hall.rally
		hall._awaiting_since = Time.get_ticks_msec()
		hall.make_call(&"in" if not rally.was_in else &"out")
		for f in 6:
			await get_tree().process_frame
		if hall.ui._reason.visible:
			showed = true
			break

	if not showed:
		print("eight lies in a row and reputation never fell — nothing to test")
		get_tree().quit()
		return

	print("straight after the lie")
	bad += _expect(hall, "the meter", hall.ui._meter.visible, true)
	bad += _expect(hall, "the note", hall.ui._reason.visible, true)
	print("      it said: %s" % hall.ui._reason_label.text)

	await _wait(WELL_PAST_THE_METER)
	print("")
	print("%.1f seconds later, with no whistle" % WELL_PAST_THE_METER)
	bad += _expect(hall, "the meter", hall.ui._meter.visible, false)
	bad += _expect(hall, "the note", hall.ui._reason.visible, true)
	bad += _expect(hall, "the note at full opacity", hall.ui._reason.modulate.a > 0.99, true)

	# The whistle. Every sport reaches IN_PLAY to start a rally, which is what the note
	# listens to, so this is the same gesture in all five.
	hall.start_rally()
	var w2 := 0
	while hall._phase != hall.Phase.IN_PLAY and w2 < 3000:
		await get_tree().physics_frame
		w2 += 1
	print("")
	print("after the whistle (phase %s)" % hall.Phase.keys()[hall._phase])
	bad += _expect(hall, "the note is fading, not cut", hall.ui._reason.visible, true)

	await _wait(RefereeUI.METER_FADE_OUT + 0.2)
	bad += _expect(hall, "the note, once faded", hall.ui._reason.visible, false)

	print("")
	if bad == 0:
		print("the note waits for the whistle, and both fades survive")
	else:
		print("%d PROBLEM(S)" % bad)
	get_tree().quit()


func _wait(seconds: float) -> void:
	var left := seconds
	while left > 0.0:
		await get_tree().process_frame
		left -= get_process_delta_time()


func _expect(_hall: Node, what: String, got: bool, want: bool) -> int:
	var ok := got == want
	print("   %-32s %-5s %s" % [what, "up" if got else "gone", "" if ok else "<-- WRONG"])
	return 0 if ok else 1
