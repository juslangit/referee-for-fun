extends Node

## Does the hall actually move?
##
## A source sweep found that badminton overrode neither `cheer()` nor `jeer()`, so the
## spine's empty versions ran and the stands never came out of their seats — for points
## *or* at the umpire. Nothing anywhere failed, because a hall that never reacts looks
## exactly like a hall with nothing to react to, and every automated check in this
## project was reading numbers rather than watching the room.
##
## So this watches the room. `Stands` keeps a timer per seat while somebody is out of
## their chair, which is the one thing that can be read from outside and cannot be
## faked by a call being priced correctly.

func _ready() -> void:
	var bad := 0
	for sport: String in {"badminton": "res://scenes/match.tscn"}:
		bad += await _hall_reacts(sport, "res://scenes/match.tscn")
	print("")
	if bad == 0:
		print("PASS  the hall gets out of its seats")
	else:
		print("FAIL  %d hall(s) sat through everything" % bad)
	get_tree().quit()


func _hall_reacts(sport: String, scene: String) -> int:
	var hall: Node = load(scene).instantiate()
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

	var stands: Stands = hall.the_stands()
	print("%s: %d seats" % [sport, _seated(stands)])
	if _out_of_seats(stands) > 0:
		print("   somebody was already standing before anything happened   <-- WRONG")
		return 1

	# Whichever comes first: a point somebody celebrates, or a call somebody objects to.
	var moved := 0
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
		for f in 8:
			await get_tree().process_frame
		moved = _out_of_seats(stands)
		print("   rally %d: %-9s visibility %.3f  %d out of their seats" % [
			attempt, Rally.Verdict.keys()[rally.verdict()], rally.visibility(), moved])
		if moved > 0:
			return 0
	print("   eight rallies and nobody moved   <-- WRONG")
	return 1


func _seated(stands: Stands) -> int:
	var total := 0
	for group in stands._crowd_seats.size():
		total += (stands._crowd_seats[group] as Array).size()
	return total


func _out_of_seats(stands: Stands) -> int:
	var up := 0
	for group in stands._crowd_jumps.size():
		var jumps: PackedFloat32Array = stands._crowd_jumps[group]
		for i in jumps.size():
			if jumps[i] > 0.0:
				up += 1
	return up
