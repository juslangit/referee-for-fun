extends Node

## Does an indoor match play, and does an honest referee survive it?
##
## The same question every sport in this game has had to answer, and the hardest one to
## answer here: indoor volleyball has four calls whose truth is a matter of record
## rather than of judgement, and a referee who knows all four must never be punished for
## saying so.

func _ready() -> void:
	var arena: Node = load("res://scenes/volleyball.tscn").instantiate()
	arena.print_truth_while_testing = false
	add_child(arena)
	await get_tree().physics_frame

	arena.career = Career.new()
	arena.career.sport = Career.INDOOR
	arena.settings.taught_indoor = true
	arena.ui.match_requested.emit()
	await get_tree().process_frame
	if arena.pressure.exists():
		arena.ui.briefing_acknowledged.emit()
		await get_tree().process_frame
	for f in 3:
		await get_tree().process_frame

	var judged := 0
	var wrong := 0
	var landed_in := 0
	var contacts := 0
	var positional := 0
	var kinds := {}
	var margins: Array[float] = []

	for frame in 40000:
		await get_tree().process_frame
		if arena._phase == arena.Phase.READY:
			arena.start_rally()
			continue
		if arena._phase != arena.Phase.AWAITING_CALL:
			continue

		var rally: VolleyRally = arena.rally
		contacts += rally.contacts
		if rally.was_in:
			landed_in += 1
		margins.append(rally.margin)

		var truth := _truth(rally, arena)
		kinds[truth.id] = int(kinds.get(truth.id, 0)) + 1
		if VolleyCallBook.get_call(truth.id).judges_position:
			positional += 1

		arena._awaiting_since = Time.get_ticks_msec()
		arena.make_call(truth.id, truth.against)

		var waited := 0
		while arena._phase == arena.Phase.AWAITING_CALL and waited < 900:
			await get_tree().process_frame
			waited += 1

		if rally.verdict() == Rally.Verdict.WRONG:
			wrong += 1
			print("   WRONG: %s" % rally.describe())

		judged += 1
		if judged >= 30 or arena.board.is_over or arena._phase == arena.Phase.REMOVED:
			break

	print("referee: %s" % ("watches the ball only" if OS.get_environment("WATCHING") == "no"
		else "knows the whole rulebook"))
	print("rallies judged:  %d" % judged)
	print("touches a rally: %.1f" % [float(contacts) / maxf(1.0, float(judged))])
	print("landed in:       %d  (%.0f%%)" % [
		landed_in, 100.0 * float(landed_in) / maxf(1.0, float(judged))])
	print("calls about where people were standing: %d" % positional)
	print("what was called:")
	for id in kinds:
		print("   %-18s %d" % [id, kinds[id]])
	print("scored WRONG:    %d   (must be 0)" % wrong)
	print("suspicion:       %.3f  (warning %.2f)" % [
		arena.suspicion.level, Suspicion.WARNING_LEVEL])

	if margins.size() > 0:
		var near: Array[float] = []
		for m in margins:
			near.append(absf(m))
		near.sort()
		var within := 0
		for n in near:
			if n < 0.25:
				within += 1
		print("closest call:    %.3f m from the line" % near[0])
		print("within 25 cm of a line: %d of %d" % [within, judged])
	get_tree().quit()


## What a referee would say. `WATCHING=no` gives one who judges the ball perfectly and
## never once looks at where the six of them are standing — the comparison that says
## whether the rotation is worth keeping track of.
func _truth(rally: VolleyRally, arena: Node) -> Dictionary:
	if OS.get_environment("WATCHING") == "no":
		return _ball_only(rally, arena)
	if rally.wrong_server_by != Sides.Team.NONE:
		return {"id": &"wrong_server", "against": rally.wrong_server_by}
	if rally.rotation_fault_by != Sides.Team.NONE:
		return {"id": &"rotation_fault", "against": rally.rotation_fault_by}
	if rally.libero_fault_by != Sides.Team.NONE:
		return {"id": &"libero_fault", "against": rally.libero_fault_by}
	if rally.back_row_attack_by != Sides.Team.NONE:
		return {"id": &"back_row_attack", "against": rally.back_row_attack_by}
	if not rally.inside_the_antennae:
		return {"id": &"antenna", "against": rally.struck_by}
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


## The same referee with their eyes on the ball and nowhere else.
func _ball_only(rally: VolleyRally, arena: Node) -> Dictionary:
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
