extends Node

## Can a badminton call actually be reviewed?
##
## The spine's `review()` points `ball_cam` at the landing. Badminton keeps its overhead
## camera as `shuttle_cam`, and until 2026-09-13 never set `ball_cam`, so every badminton
## review stopped on its first frame. This asks the question straight: at the national
## championship, where reviews exist, run one and see whether it finishes.

func _ready() -> void:
	var hall: Node = load("res://scenes/match.tscn").instantiate()
	hall.print_truth_while_testing = false
	add_child(hall)
	await get_tree().physics_frame
	hall.career = Career.new()
	hall.career.sport = Career.BADMINTON
	hall.career.tier = 3
	hall.settings.taught = true
	hall._on_match_requested()
	if hall.pressure.exists():
		hall.ui.hide_briefing()
	hall.begin_match()
	for f in 4:
		await get_tree().process_frame

	print("reviews at this venue: %s   ball_cam: %s   shuttle_cam: %s" % [
		hall.has_challenge, hall.ball_cam, hall.shuttle_cam])

	hall.start_rally()
	var waited := 0
	while hall._phase != hall.Phase.AWAITING_CALL and waited < 4000:
		await get_tree().physics_frame
		waited += 1
	var rally: Rally = hall.rally
	rally.record_call(CallBook.get_call(&"in" if not rally.was_in else &"out"))
	print("asking for a review of: %s" % rally.describe())
	# A lambda captures a local by value, so a plain `finished = true` inside it never
	# reached the loop below, and this said NEVER FINISHED even of a review that had.
	var state := {"finished": false}
	var run := func() -> void:
		await hall.review(Sides.Team.RED)
		state.finished = true
	run.call()
	# A review is REVIEW_SUSPENSE + REVIEW_VERDICT of real time, and headless frames are
	# not a clock: 600 of them went by before a working review had finished.
	var started := Time.get_ticks_msec()
	while not state.finished and Time.get_ticks_msec() - started < 10000:
		await get_tree().process_frame
	print("the review took %.2f s" % ((Time.get_ticks_msec() - started) / 1000.0))
	print("the review %s" % ("finished" if state.finished else "NEVER FINISHED"))
	var problems: Array[String] = []
	if hall.ball_cam != hall.shuttle_cam:
		problems.append("ball_cam is not badminton's overhead camera")
	if not state.finished:
		problems.append("the review never finished")
	print("PASS" if problems.is_empty() else "FAIL: " + ", ".join(problems))
	get_tree().quit()
