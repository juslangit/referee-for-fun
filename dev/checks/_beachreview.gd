extends Node

## Does the beach challenge fire, on what, and what does being caught cost?
##
## The top two beach rungs have been promising a video challenge in their blurb since
## the ladder was written, and until now there was nothing there. Three things to check:
## that an honest referee is never punished by it, that a liar is caught often enough to
## be afraid of it, and that a touch — the call this sport is about — is reviewable at
## all, since a camera pointed at the sand cannot see a fingertip.

func _ready() -> void:
	await _a_referee("honest")
	print()
	await _a_referee("liar")
	get_tree().quit()


func _a_referee(kind: String) -> void:
	var arena: Node = load("res://scenes/beach.tscn").instantiate()
	arena.print_truth_while_testing = false
	add_child(arena)
	await get_tree().physics_frame

	arena.career = Career.new()
	arena.career.sport = Career.BEACH
	arena.career.tier = 3  # World tour: the first rung that carries a challenge
	arena.settings.taught_beach = true
	arena.ui.match_requested.emit()
	await get_tree().process_frame
	if arena.pressure.exists():
		arena.ui.briefing_acknowledged.emit()
		await get_tree().process_frame
	for f in 3:
		await get_tree().process_frame

	print("=== %s referee at the %s (challenge: %s)" % [
		kind, arena.career.venue()["name"], "yes" if arena.has_challenge else "NO"])

	var judged := 0
	var reviews := 0
	var overturned := 0
	var on_a_touch := 0
	var lies := 0
	var before_being_caught := 0.0

	for frame in 40000:
		await get_tree().process_frame
		if arena._phase == arena.Phase.READY:
			arena.start_rally()
			continue
		if arena._phase != arena.Phase.AWAITING_CALL:
			continue

		var rally: BeachRally = arena.rally
		var was: float = arena.suspicion.level
		var reviews_left: int = arena.challenge.remaining(Sides.Team.RED) \
			+ arena.challenge.remaining(Sides.Team.BLUE)

		arena._awaiting_since = Time.get_ticks_msec()
		var honest_call := _truth(rally, arena)
		if kind == "honest":
			arena.make_call(honest_call.id, honest_call.against)
		else:
			# A liar who denies every touch, because it is the cheapest lie in the sport
			# and the one a camera can catch.
			if not rally.was_in and rally.was_touched:
				lies += 1
				arena.make_call(&"out")
			else:
				arena.make_call(honest_call.id, honest_call.against)

		# The call is a coroutine now that it can stop for a replay.
		var waited := 0
		while arena._phase == arena.Phase.AWAITING_CALL and waited < 900:
			await get_tree().process_frame
			waited += 1

		var spent: int = reviews_left - (arena.challenge.remaining(Sides.Team.RED)
			+ arena.challenge.remaining(Sides.Team.BLUE))
		if spent != 0 or arena.suspicion.level - was > 0.28:
			reviews += 1
			if rally.call != null and rally.call.judges_the_touch:
				on_a_touch += 1
			if spent == 0:
				overturned += 1
				before_being_caught += arena.suspicion.level - was

		judged += 1
		if judged >= 26 or arena.board.is_over or arena._phase == arena.Phase.REMOVED:
			break

	print("  rallies judged:   %d" % judged)
	if kind == "liar":
		print("  touches denied:   %d" % lies)
	print("  reviews called:   %d" % reviews)
	print("  calls overturned: %d" % overturned)
	print("  of those, about a touch rather than a line: %d" % on_a_touch)
	print("  suspicion:        %.3f  (warning %.2f)" % [
		arena.suspicion.level, Suspicion.WARNING_LEVEL])
	if overturned > 0:
		print("  average cost of being caught: %.3f" % (before_being_caught / overturned))
	arena.queue_free()
	await get_tree().process_frame


## What an honest referee would say.
func _truth(rally: BeachRally, arena: Node) -> Dictionary:
	if rally.foot_fault:
		return {"id": &"foot_fault", "against": rally.served_by}
	if rally.handling_fault:
		return {"id": &"double_contact", "against": rally.struck_by}
	if arena.net_toucher != Sides.Team.NONE:
		return {"id": &"net_touch", "against": arena.net_toucher}
	if arena.centre_line_crosser != Sides.Team.NONE:
		return {"id": &"centre_line", "against": arena.centre_line_crosser}
	if rally.was_in:
		return {"id": &"in", "against": Sides.Team.NONE}
	if rally.was_touched:
		return {"id": &"touch", "against": Sides.Team.NONE}
	return {"id": &"out", "against": Sides.Team.NONE}
