extends Node

## Walks up the ladder and checks that each rung actually changes the match, rather
## than just changing the words on the screen.

func _ready() -> void:
	var arena: Node = load("res://scenes/match.tscn").instantiate()
	add_child(arena)
	await get_tree().physics_frame

	print("%-26s %-7s %-6s %-9s %-9s %s" % [
		"venue", "judges", "cam", "format", "scrutiny", "a 5 cm lie costs"
	])

	for i in Career.LADDER.size():
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

		print("%-26s %-7d %-6s %-9s %-9.2f %+.4f" % [
			Career.LADDER[i]["name"],
			arena.line_judges.size(),
			"yes" if arena.has_shuttle_cam else "no",
			"to %d" % arena.board.target,
			arena.suspicion.scrutiny,
			cost,
		])

	print("\n--- saving and reloading ---")
	var career := Career.new()
	career.tier = 2
	career.reputation = 0.63
	career.matches_refereed = 9
	career.save()
	var back := Career.load_or_start()
	print("  wrote tier 2, reputation 0.63, 9 matches")
	print("  read  tier %d, reputation %.2f, %d matches  ->  %s" % [
		back.tier, back.reputation, back.matches_refereed,
		"ok" if back.tier == 2 and is_equal_approx(back.reputation, 0.63) else "MISMATCH",
	])
	Career.start_again().save()
	print("  after starting again: tier %d, reputation %.2f" % [
		Career.load_or_start().tier, Career.load_or_start().reputation
	])
	get_tree().quit()
