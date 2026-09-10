extends Node

## Can a badminton call actually be reviewed?
##
## The spine's `review()` points `ball_cam` at the landing, and badminton keeps its
## overhead camera as `shuttle_cam` and never sets `ball_cam`. Badminton's own `_review`,
## which uses the right camera, is not called by anything. This asks the question straight:
## at the national championship, where reviews exist, run one and see whether it finishes.

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
	var finished := false
	var run := func() -> void:
		await hall.review(Sides.Team.RED)
		finished = true
	run.call()
	for f in 600:
		await get_tree().process_frame
		if finished:
			break
	print("the review %s" % ("finished" if finished else "NEVER FINISHED"))
	get_tree().quit()
