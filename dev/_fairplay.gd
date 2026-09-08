extends Node

## Play a long match calling nothing but the truth, and see what the game thinks of you.
##
## Luqman reports being marked unfair while calling every in and out correctly. This
## makes exactly that umpire — one who looks at where the shuttle landed, says so, and
## never lies — and reports every rally the game scored as WRONG, with the reason.

func _ready() -> void:
	var arena: Node = load("res://scenes/match.tscn").instantiate()
	add_child(arena)
	await get_tree().physics_frame
	arena.ui.career_screen_requested.emit()
	await get_tree().process_frame
	arena.ui.match_requested.emit()
	await get_tree().process_frame
	arena._on_favour_chosen(Sides.Team.NONE)

	var judged := 0
	var wrong := 0
	var with_offence := 0
	var strokes := 0
	var reasons := {}
	# Where the suspicion came from, so a number that looks bad can be read rather than
	# argued about. This harness runs far slower than real time, so without accounting
	# for it separately the game's hesitation charge — which is measured on the wall
	# clock — turns up in the total and looks like a rules bug.
	var dithered := 0.0
	var missed_courts := 0
	for frame in 60000:
		await get_tree().process_frame
		if arena._phase == arena.Phase.READY:
			arena._start_rally()
			continue
		if arena._phase != arena.Phase.AWAITING_CALL:
			continue

		var rally: Rally = arena.rally
		if arena.service_error != Sides.Team.NONE:
			missed_courts += 1
		var landed_inside := CourtSpec.is_in(rally.landing_point, rally.doubles)
		strokes += arena._shots_this_rally
		if rally.incident.happened():
			with_offence += 1

		# Two umpires, chosen by an environment switch. LINES calls only what it sees
		# on the floor. PERFECT also spots every offence, correctly, every time — an
		# impossible standard, and the point: if even that umpire accrues suspicion,
		# the fault is in the scoring rather than in the player.
		if OS.get_environment("UMPIRE") == "perfect" and rally.incident.happened():
			var names := {
				Incident.Kind.NET_TOUCH: &"net_touch",
				Incident.Kind.CARRY: &"carry",
				Incident.Kind.DOUBLE_HIT: &"double_hit",
				Incident.Kind.OBSTRUCTION: &"obstruction",
			}
			var fault: StringName = names[rally.incident.kind]
			arena._make_call(fault, rally.incident.by)
		else:
			arena._make_call(&"in" if landed_inside else &"out")
		judged += 1
		dithered += Suspicion.hesitation_cost(rally.seconds_to_call) * arena.suspicion.scrutiny

		if rally.verdict() == Rally.Verdict.WRONG:
			wrong += 1
			var why := "landed %s, called %s" % [
				"IN" if landed_inside else "OUT", "IN" if landed_inside else "OUT"]
			if not rally.crossed_the_net:
				why = "shuttle never crossed the net (landed inside: %s)" % landed_inside
			elif rally.incident.happened():
				why = "an offence had already happened: %s" % rally.incident.kind
			reasons[why] = int(reasons.get(why, 0)) + 1

		for f in 18:
			await get_tree().process_frame
		if judged >= 45 or arena.board.is_over:
			break

	print("umpire: %s" % ("PERFECT (calls every fault too)" if OS.get_environment("UMPIRE") == "perfect" else "LINES ONLY (calls in and out correctly)"))
	print("rallies judged: %d   (%.1f strokes each on average)" % [
		judged, float(strokes) / maxf(1.0, float(judged))])
	print("rallies with an offence in them: %d  (%.0f%%)" % [
		with_offence, 100.0 * float(with_offence) / maxf(1.0, float(judged))])
	print("scored WRONG:   %d  (%.0f%%)" % [wrong, 100.0 * float(wrong) / maxf(1.0, float(judged))])
	print("suspicion:      %.3f   (warning at %.2f, removed at %.2f)" % [
		arena.suspicion.level, Suspicion.WARNING_LEVEL, Suspicion.REMOVAL_LEVEL])
	print("   of which the harness's own slowness (hesitation):   %.3f" % dithered)
	print("   service court errors it sat through:                %d, costing %.3f" % [
		missed_courts, missed_courts * Suspicion.MISSED_SERVICE_COURT * arena.suspicion.scrutiny])
	print("   left over, which is what the rules actually charged: %.3f" % (
		arena.suspicion.level - dithered
		- missed_courts * Suspicion.MISSED_SERVICE_COURT * arena.suspicion.scrutiny))
	for why in reasons:
		print("   %-58s %d" % [why, reasons[why]])
	get_tree().quit()
