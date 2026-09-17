extends Node

## Walks up the ladder and checks that each rung actually changes the match, rather
## than just changing the words on the screen.
##
## "Actually changes the match" is the claim, so it is the claim this ends on: every
## rung is watched harder than the one below it, the same 5 cm lie costs more at every
## rung than at the one below, the top of the ladder is played to a longer format than
## the bottom, and a saved career comes back off disk as the one that was written.
##
## What does NOT vary is printed rather than failed. The same two line judges and the
## same shuttle camera stand at the school hall and at the international final, so the
## badminton ladder is made of scrutiny and format and nothing else. Saying that out
## loud stops the table being read as proof of variety it does not have.

func _ready() -> void:
	var arena: Node = load("res://scenes/match.tscn").instantiate()
	add_child(arena)
	await get_tree().physics_frame

	print("%-26s %-7s %-6s %-9s %-9s %s" % [
		"venue", "judges", "cam", "format", "scrutiny", "a 5 cm lie costs"
	])

	var scrutinies: Array[float] = []
	var costs: Array[float] = []
	var targets: Array[int] = []
	var judge_counts: Array[int] = []
	var cams: Array[bool] = []

	for i in Career.BADMINTON_LADDER.size():
		arena.career.tier = i
		arena._on_match_requested()
		await get_tree().process_frame

		# What the same small lie would cost an umpire standing in this hall.
		var suspicion := Suspicion.new()
		suspicion.scrutiny = arena.suspicion.scrutiny
		var rally := Rally.new(Sides.Team.RED, true)
		rally.record_landing(Vector3(CourtSpec.HALF_WIDTH_DOUBLES + 0.05, 0.01, 3.0))
		rally.record_call(CallBook.get_call(&"in"))
		var cost := suspicion.register(rally)

		scrutinies.append(arena.suspicion.scrutiny)
		costs.append(cost)
		targets.append(arena.board.target)
		judge_counts.append(arena.line_judges.size())
		cams.append(arena.has_shuttle_cam)

		print("%-26s %-7d %-6s %-9s %-9.2f %+.4f" % [
			Career.BADMINTON_LADDER[i]["name"],
			arena.line_judges.size(),
			"yes" if arena.has_shuttle_cam else "no",
			"to %d" % arena.board.target,
			arena.suspicion.scrutiny,
			cost,
		])

	var problems: Array[String] = []
	for i in range(1, scrutinies.size()):
		var below: String = Career.BADMINTON_LADDER[i - 1]["name"]
		var here: String = Career.BADMINTON_LADDER[i]["name"]
		if scrutinies[i] <= scrutinies[i - 1]:
			problems.append("%s is watched no harder than %s (%.2f after %.2f)" % [
				here, below, scrutinies[i], scrutinies[i - 1]])
		if costs[i] <= costs[i - 1]:
			problems.append("the same 5 cm lie costs no more at %s than at %s (%+.4f after %+.4f)" % [
				here, below, costs[i], costs[i - 1]])
	if targets[targets.size() - 1] <= targets[0]:
		problems.append("the top of the ladder is played to the same %d points as the bottom" % targets[0])

	# Constant across the ladder today, and said rather than asserted: if a rung is ever
	# given a third line judge or has its camera taken away, that is a change to the
	# design and not a failure of this check.
	var same_judges := judge_counts.count(judge_counts[0]) == judge_counts.size()
	var same_cam := cams.count(cams[0]) == cams.size()
	print("\nthe same at every rung: %s%s" % [
		"%d line judges" % judge_counts[0] if same_judges else "nothing about the judges",
		", and the shuttle camera" if same_cam and cams[0] else ""])

	print("\n--- saving and reloading ---")
	var career := Career.new()
	career.tier = 2
	career.reputation = 0.63
	career.matches_refereed = 9
	career.save()
	var back := Career.load_or_start()
	print("  wrote tier 2, reputation 0.63, 9 matches")
	var round_tripped: bool = (back.tier == 2 and is_equal_approx(back.reputation, 0.63)
		and back.matches_refereed == 9)
	print("  read  tier %d, reputation %.2f, %d matches  ->  %s" % [
		back.tier, back.reputation, back.matches_refereed,
		"ok" if round_tripped else "MISMATCH",
	])
	if not round_tripped:
		problems.append("a career written to disk did not come back as the one that was written")

	Career.start_again().save()
	var fresh := Career.load_or_start()
	print("  after starting again: tier %d, reputation %.2f" % [fresh.tier, fresh.reputation])
	if fresh.tier != 0:
		problems.append("starting again left the career on tier %d rather than the bottom" % fresh.tier)

	print("")
	if problems.is_empty():
		print("PASS  every rung is watched harder and prices a lie higher than the one below")
	else:
		for problem in problems:
			print("FAIL  " + problem)
	get_tree().quit()
