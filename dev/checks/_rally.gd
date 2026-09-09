extends Node

## Referees a whole quick game honestly, and reports what the rallies actually look
## like. If the rallies are one shot long, or nothing ever lands near a line, or the
## game never finishes, the match does not work no matter how good the rest is.

func _ready() -> void:
	var arena: Node = load("res://scenes/match.tscn").instantiate()
	arena.print_truth_while_testing = false
	add_child(arena)
	await get_tree().physics_frame
	arena._set_up_the_match(true)
	arena.begin_match()

	print("%-4s %-6s %-24s %-30s %s" % ["#", "shots", "truth", "offence", "score"])

	var shot_counts: Array[int] = []
	var left_alone := 0
	var out_calls := 0
	var rallies := 0
	var net_faults := 0
	var judge_wrong := 0
	var offences := {}

	while not arena.board.is_over and rallies < 60:
		rallies += 1
		arena._start_rally()
		var waited := 0
		while arena._phase != arena.Phase.AWAITING_CALL and waited < 3000:
			await get_tree().physics_frame
			waited += 1
		if waited >= 3000:
			print("  !! rally %d never finished" % rallies)
			break

		var rally: Rally = arena.rally
		var shots: int = arena._shots_this_rally
		shot_counts.append(shots)
		if not rally.was_in:
			out_calls += 1

		var untouched: bool = arena.rally_left_alone
		if untouched:
			left_alone += 1

		if not rally.crossed_the_net:
			net_faults += 1
		if rally.line_judge_said_in != rally.was_in:
			judge_wrong += 1

		var truth_text := "IN THE NET" if not rally.crossed_the_net else "%s by %.3f m" % [
			"IN" if rally.was_in else "OUT", absf(rally.margin)
		]
		var offence: Incident = rally.incident
		if offence.happened():
			var key: String = Incident.label(offence.kind)
			offences[key] = offences.get(key, 0) + 1

		# Referee it honestly: call the offence if there was one, otherwise the line.
		if offence.happened():
			var id: StringName = {
				Incident.Kind.NET_TOUCH: &"net_touch",
				Incident.Kind.CARRY: &"carry",
				Incident.Kind.DOUBLE_HIT: &"double_hit",
				Incident.Kind.OBSTRUCTION: &"obstruction",
			}[offence.kind]
			arena._make_call(id, offence.by)
		else:
			arena._make_call(&"in" if rally.was_in else &"out")

		print("%-4d %-6d %-24s %-30s %d-%d" % [
			rallies, shots, truth_text, offence.describe(),
			arena.board.points[Sides.Team.RED], arena.board.points[Sides.Team.BLUE],
		])

	var total := 0
	var longest := 0
	for n in shot_counts:
		total += n
		longest = maxi(longest, n)

	print("\n%d rallies, %.1f shots each on average, longest %d" % [
		rallies, float(total) / maxf(1.0, float(shot_counts.size())), longest
	])
	print("%d landed out (%.0f%%), %d were left alone by the receiver" % [
		out_calls, 100.0 * out_calls / maxf(1.0, float(rallies)), left_alone
	])
	print("offences: ", offences)
	print("%d landed in the net, line judge was wrong %d times (%.0f%%)" % [
		net_faults, judge_wrong, 100.0 * judge_wrong / maxf(1.0, float(rallies))
	])
	print("game over: %s   RED %d — %d BLUE   (suspicion %.3f)" % [
		"yes" if arena.board.is_over else "NO — it never ended",
		arena.board.points[Sides.Team.RED],
		arena.board.points[Sides.Team.BLUE],
		arena.suspicion.level,
	])
	get_tree().quit()
