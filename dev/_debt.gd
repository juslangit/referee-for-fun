extends Node

## Does the umpire's own first mistake actually trap them?
##
## An umpire who lies on every call obvious enough that the hall can see it. The first
## such lie should hand them a debt — a side a point down because of them — and a later
## lie going the other way should settle it. Neither event may ever fire on a call the
## crowd could not see, because the game is not allowed to tell the player the truth.

func _ready() -> void:
	var arena: Node = load("res://scenes/match.tscn").instantiate()
	add_child(arena)
	await get_tree().physics_frame
	# A fresh career at the bottom of the ladder, so two blatant lies are survivable and
	# the run gets far enough to show the second half of the trap. A real umpire doing
	# this at an international final would be gone before the debt could be settled,
	# which is the correct behaviour and a very short test.
	arena.career = Career.new()
	arena.ui.match_requested.emit()
	await get_tree().process_frame
	arena.begin_match()

	print("%-4s %-9s %-7s %-6s %s" % ["#", "landed", "called", "seen", "what happened"])

	var judged := 0
	var quietly_wrong := 0
	for frame in 60000:
		await get_tree().process_frame
		if arena._phase == arena.Phase.READY:
			arena._start_rally()
			continue
		if arena._phase != arena.Phase.AWAITING_CALL:
			continue

		var rally: Rally = arena.rally
		var landed_in := CourtSpec.is_in(rally.landing_point, rally.doubles)
		var blatant: bool = absf(rally.margin) > Rally.BLATANT_MARGIN and rally.crossed_the_net

		var had_debt: bool = arena.debt != null
		var was_evened: bool = arena._debt_evened

		# Two lies and no more: the one that creates the debt, and the ones that might
		# settle it. Everything else is called honestly, so the umpire survives long
		# enough to be shown what they have done.
		var still_owing: bool = arena.debt == null or not arena._debt_evened
		var says_in := not landed_in if (blatant and still_owing) else landed_in
		arena._make_call(&"in" if says_in else &"out")
		judged += 1

		var note := ""
		if arena.debt != null and not had_debt:
			note = "DEBT taken on, %s are owed one" % Sides.label(arena._debt_direction)
		elif arena._debt_evened and not was_evened:
			note = "EVENED UP by a lie the other way"
		if not note.is_empty() or blatant:
			print("%-4d %-9s %-7s %-6.2f %s" % [
				judged,
				"IN" if landed_in else "OUT",
				"IN" if says_in else "OUT",
				rally.visibility(),
				note,
			])

		# The rule that must never break: nothing is ever revealed about a call the
		# hall could not see for itself.
		if (arena.debt != null and not had_debt) and rally.visibility() < Pressure.DEBT_NOTICED:
			quietly_wrong += 1

		for f in 18:
			await get_tree().process_frame
		if judged >= 60 or arena.board.is_over:
			break
		if arena._phase == arena.Phase.REMOVED:
			print("  ... taken off the match after %d calls" % judged)
			break

	print()
	print("calls judged: %d" % judged)
	print("debt taken on: %s" % ("no" if arena.debt == null else
		"yes, owed to %s" % Sides.label(arena._debt_direction)))
	print("evened up: %s" % ("yes" if arena._debt_evened else "no"))
	print("debts taken on a call the hall could not see: %d  (must be 0)" % quietly_wrong)

	if arena.debt != null:
		arena.debt.resolve(arena.board, arena.suspicion, arena._debt_evened)
		print("reads as: %s" % arena.debt.verdict_line())
	get_tree().quit()
