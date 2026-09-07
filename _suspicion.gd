extends Node

## Runs four different umpires through the same job and reports how much trouble
## each of them ends up in. The numbers here decide whether cheating is worth it,
## so they matter more than almost anything else in the game.

const RALLIES := 14

func _ready() -> void:
	print("%-10s %-9s %-6s %-6s %-6s %-10s %s" % [
		"umpire", "suspicion", "lean", "wrong", "stolen", "mood", "outcome"
	])
	for policy in ["honest", "careful", "greedy", "erratic"]:
		await _run(policy)
	get_tree().quit()


func _run(policy: String) -> void:
	var arena: Node = load("res://scenes/match.tscn").instantiate()
	arena.print_truth_while_testing = false
	add_child(arena)
	await get_tree().physics_frame
	# Seeded after the arena is built, so every policy referees the same match.
	seed(20260907)
	arena._on_favour_chosen(Sides.Team.RED)

	var suspicion: Suspicion = arena.suspicion
	var removed_at := 0

	for i in range(RALLIES):
		if suspicion.is_removed:
			break
		arena._start_rally()
		while arena._phase != arena.Phase.AWAITING_CALL:
			await get_tree().physics_frame

		var rally: Rally = arena.rally
		arena._make_call(_choose(policy, rally))
		if suspicion.is_removed and removed_at == 0:
			removed_at = i + 1

	var outcome := "survived"
	if suspicion.is_removed:
		outcome = "REMOVED after rally %d" % removed_at
	elif suspicion.has_been_warned:
		outcome = "warned"

	print("%-10s %-9.3f %+-6.2f %-6d %-6d %-10s %s" % [
		policy,
		suspicion.level,
		suspicion.lean,
		suspicion.wrong_calls,
		suspicion.stolen_rallies,
		Suspicion.Mood.keys()[suspicion.mood],
		outcome,
	])

	arena.queue_free()
	await get_tree().process_frame


func _choose(policy: String, rally: Rally) -> StringName:
	var honest: StringName = &"in" if rally.was_in else &"out"
	var helps_red: StringName = &"in" if rally.struck_by == Sides.Team.RED else &"out"

	match policy:
		# Calls it as it lands, every time.
		"honest":
			return honest
		# Wants RED to win, but only lies when nobody could be sure.
		"careful":
			if helps_red == honest:
				return honest
			return helps_red if absf(rally.margin) / Rally.BLATANT_MARGIN < 0.25 else honest
		# Wants RED to win and does not care who notices.
		"greedy":
			return helps_red
		# Not bent, just bad. Wrong roughly a third of the time, both ways.
		"erratic":
			if randf() < 0.33:
				return &"out" if honest == &"in" else &"in"
			return honest
	return honest
