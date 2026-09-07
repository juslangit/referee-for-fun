extends Node

## Referees a whole quick game honestly, and reports what the rallies actually look
## like. If the rallies are one shot long, or nothing ever lands near a line, or the
## game never finishes, the match does not work no matter how good the rest is.

func _ready() -> void:
	var arena: Node = load("res://scenes/match.tscn").instantiate()
	arena.print_truth_while_testing = false
	add_child(arena)
	await get_tree().physics_frame
	arena._on_length_chosen(true)
	arena._on_favour_chosen(Sides.Team.NONE)

	print("%-4s %-6s %-7s %-28s %s" % ["#", "shots", "left it", "truth", "score"])

	var shot_counts: Array[int] = []
	var left_alone := 0
	var out_calls := 0
	var rallies := 0

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

		arena._make_call(&"in" if rally.was_in else &"out")
		print("%-4d %-6d %-7s %-28s %d-%d" % [
			rallies, shots, "yes" if untouched else "",
			"%s by %.3f m" % ["IN" if rally.was_in else "OUT", absf(rally.margin)],
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
	print("game over: %s   RED %d — %d BLUE   (suspicion %.3f)" % [
		"yes" if arena.board.is_over else "NO — it never ended",
		arena.board.points[Sides.Team.RED],
		arena.board.points[Sides.Team.BLUE],
		arena.suspicion.level,
	])
	get_tree().quit()
