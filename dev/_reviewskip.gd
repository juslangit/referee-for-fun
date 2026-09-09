extends Node

## Can a review be waved on, and only at the right moment?
##
## Two halves to hold apart. The wait **before** the answer is the point of a review — it
## is the only moment in this game where an official sits and finds out in public whether
## they got away with something — so it must not be skippable. The wait after it is
## reading a line you have already read, and on the tenth review of a match it is dead
## time.
##
## `review()` is driven straight rather than waited for: a challenge needs a lie, a
## close call and somebody willing to spend a review, and forty rallies of hoping for
## all three at once measured nothing at all the first time this was written.

func _ready() -> void:
	var sand: Node = load("res://scenes/beach.tscn").instantiate()
	sand.print_truth_while_testing = false
	add_child(sand)
	await get_tree().physics_frame
	sand.career = Career.new()
	sand.career.sport = Career.BEACH
	sand.career.tier = 4
	sand.settings.taught_beach = true
	sand.ui.match_requested.emit()
	await get_tree().process_frame
	if sand.pressure.exists():
		sand.ui.briefing_acknowledged.emit()
		await get_tree().process_frame
	sand.begin_match()
	for f in 3:
		await get_tree().process_frame

	print("%-40s %10s %9s" % ["", "seconds", "skipped"])
	await _time_one(sand, false)
	await _time_one(sand, true)
	print()
	print("the suspense is %0.1f s and the verdict %0.1f s, so a waved-on review should"
		% [sand.REVIEW_SUSPENSE, sand.REVIEW_VERDICT])
	print("come in a shade over %0.1f s and never under it." % sand.REVIEW_SUSPENSE)
	get_tree().quit()


## How many times the skip was pressed before the answer was up, all of which must do
## nothing at all.
var _ignored_attempts := 0


## Holds the skip down for the whole review, from the frame it opens.
##
## It waits for the review to start first. Started before `review()` is called — which is
## the only place it can be started from, since review() is what is being timed — the
## loop found `_reviewing` still false and exited on its first line, and the measurement
## reported a skip that had never been pressed.
func _wave_it_on(sand: Node) -> void:
	while not sand._reviewing:
		await get_tree().process_frame
	while sand._reviewing:
		if not sand._can_skip_review:
			_ignored_attempts += 1
		sand._review_skipped = true
		await get_tree().process_frame


func _time_one(sand: Node, wave_it_on: bool) -> void:
	# A rally to review, and a call on it.
	sand.start_rally()
	var waited := 0
	while sand._phase != sand.Phase.AWAITING_CALL and waited < 4000:
		await get_tree().physics_frame
		waited += 1
	sand.rally.record_call(BeachCallBook.get_call(&"in"), Sides.Team.NONE)

	var started := Time.get_ticks_msec()
	_ignored_attempts = 0
	if wave_it_on:
		# Fire and forget, as a real method rather than a lambda. A lambda containing
		# `await`, called and not held, does not reliably keep running — the first
		# version of this measured a skip that never happened and reported it as no
		# difference at all.
		_wave_it_on(sand)
	await sand.review(Sides.Team.BLUE)
	var seconds := float(Time.get_ticks_msec() - started) / 1000.0

	print("%-40s %10.2f %9s" % [
		"waved on the moment it opened" if wave_it_on else "sat through",
		seconds, "yes" if wave_it_on else "no"])
	if wave_it_on:
		print("   it ignored %d attempts to skip the suspense" % _ignored_attempts)

	sand._phase = sand.Phase.READY
	for f in 4:
		await get_tree().process_frame
