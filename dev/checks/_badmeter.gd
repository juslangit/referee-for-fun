extends Node
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

	print("watching the reputation is wired: %s" % hall.career.reputation_changed.get_connections().size())
	for r in 6:
		hall.start_rally()
		var w := 0
		while hall._phase != hall.Phase.AWAITING_CALL and w < 3000:
			await get_tree().physics_frame
			w += 1
		if hall._phase != hall.Phase.AWAITING_CALL:
			break
		var before := hall.career.reputation_as_it_stands()
		hall._awaiting_since = Time.get_ticks_msec()
		hall.make_call(&"in" if not hall.rally.was_in else &"out")
		var shown := false
		for f in 40:
			await get_tree().process_frame
			if hall.ui._meter != null and hall.ui._meter.visible:
				shown = true
				break
		var after := hall.career.reputation_as_it_stands()
		print("  %d  %s  rep %.4f -> %.4f  (%d -> %d out of 100)  meter %s" % [
			r, Rally.Verdict.keys()[hall.rally.verdict()], before, after,
			roundi(before * 100.0), roundi(after * 100.0), "SHOWN" if shown else "no"])
		if hall._phase == hall.Phase.REMOVED:
			break
	get_tree().quit()
