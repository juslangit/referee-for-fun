extends Node

## How long is the FIRST match of each sport?
##
## The state a player reaches first, not the most impressive one. Indoor volleyball's
## opening match was 123 rallies once, which is nobody's idea of a tutorial, and it was
## only found by measuring. Tennis has never been measured at all.

func _ready() -> void:
	print("%-10s %-22s %8s %8s %10s %12s" % [
		"sport", "venue", "calls", "minutes", "finished", "format"])
	for entry in [
		["beach", "res://scenes/beach.tscn", Career.BEACH],
		["indoor", "res://scenes/volleyball.tscn", Career.INDOOR],
		["tennis", "res://scenes/tennis.tscn", Career.TENNIS],
		["table tennis", "res://scenes/table_tennis.tscn", Career.TABLE_TENNIS],
		["takraw", "res://scenes/sepak_takraw.tscn", Career.TAKRAW],
	]:
		await _measure(entry[0], entry[1], entry[2])
	get_tree().quit()


func _measure(name: String, scene: String, sport: StringName) -> void:
	var arena: Node = load(scene).instantiate()
	arena.print_truth_while_testing = false
	add_child(arena)
	await get_tree().physics_frame

	arena.career = Career.new()
	arena.career.sport = sport
	arena.settings.taught_beach = true
	arena.settings.taught_indoor = true
	arena.settings.taught_tennis = true
	arena.settings.taught_table_tennis = true
	arena.settings.taught_takraw = true
	arena.ui.match_requested.emit()
	await get_tree().process_frame
	if arena.pressure.exists():
		arena.ui.briefing_acknowledged.emit()
		await get_tree().process_frame
	arena.begin_match()
	for f in 3:
		await get_tree().process_frame

	var venue: String = arena.career.venue()["name"]
	var board = arena.board
	var format := "to %d, %d game(s)" % [board.target, board.games_needed]
	if board is TennisScore:
		var tennis := board as TennisScore
		format = "%d set(s), %d games%s" % [
			tennis.sets_needed, tennis.games_to_win,
			", no-ad" if tennis.no_advantage else ""]

	var calls := 0
	var frames := 0
	var finished := false
	for frame in 400000:
		await get_tree().process_frame
		frames += 1
		if arena._phase == arena.Phase.READY:
			arena.start_rally()
			continue
		if arena._phase == arena.Phase.REMOVED or arena.board.is_over:
			finished = true
			break
		if arena._phase != arena.Phase.AWAITING_CALL:
			continue

		arena._awaiting_since = Time.get_ticks_msec()
		_call_it_honestly(arena, name)
		var waited := 0
		while arena._phase == arena.Phase.AWAITING_CALL and waited < 900:
			await get_tree().process_frame
			waited += 1
		calls += 1
		if calls > 400:
			break

	print("%-10s %-22s %8d %8.1f %10s %12s" % [
		name, venue, calls, float(frames) / 60.0 / 60.0,
		"yes" if finished else "NO — ran out", format])
	arena.queue_free()
	await get_tree().process_frame


func _call_it_honestly(arena: Node, name: String) -> void:
	var rally = arena.rally
	if name == "tennis":
		if rally.is_a_let():
			arena.make_call(&"let", rally.struck_by)
		elif rally.foot_fault:
			arena.make_call(&"foot_fault", rally.struck_by)
		elif rally.net_toucher != Sides.Team.NONE:
			arena.make_call(&"touched_net", rally.net_toucher)
		elif rally.reached_over_by != Sides.Team.NONE:
			arena.make_call(&"through_the_net", rally.reached_over_by)
		elif rally.not_up_by != Sides.Team.NONE:
			arena.make_call(&"not_up", rally.not_up_by)
		elif rally.is_a_serve:
			arena.make_call(&"in" if rally.serve_was_good else &"out")
		else:
			arena.make_call(&"in" if rally.was_in else &"out")
		return

	# Sepak takraw's honest referee, in the order _takrawplay calls it: the serve's feet
	# first, because they happen first, then the body faults, the touch and the line.
	if name == "takraw":
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
		return

	# Table tennis's honest umpire, in the order _ttplay calls it. Without this the
	# measurement fell through to the volleyball branch below and errored on the first
	# rally, because a TableTennisRally has no antennae and no handling fault.
	if name == "table tennis":
		if rally.is_a_let():
			arena.make_call(&"let", rally.served_by)
		elif rally.illegal_service:
			arena.make_call(&"illegal_service", rally.served_by)
		elif rally.volleyed_by != Sides.Team.NONE:
			arena.make_call(&"volley", rally.volleyed_by)
		elif rally.touched_the_table_by != Sides.Team.NONE:
			arena.make_call(&"touched_the_table", rally.touched_the_table_by)
		elif rally.double_bounce_by != Sides.Team.NONE:
			arena.make_call(&"double_bounce", rally.double_bounce_by)
		else:
			arena.make_call(&"in" if rally.rightful_winner() == rally.struck_by else &"out")
		return

	if not rally.inside_the_antennae:
		arena.make_call(&"antenna", rally.struck_by)
	elif rally.foot_fault:
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
