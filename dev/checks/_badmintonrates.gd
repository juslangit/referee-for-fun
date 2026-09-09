extends Node

## Do badminton's offences still get rolled, and are the rolls still reached?
##
## Written during the move onto the shared spine, because **a refactor that quietly stops
## rolling offences looks exactly like a refactor that went perfectly**: the honest umpire
## scores zero wrong calls either way, and zero is what the fairness check is looking for.
## The only way to tell the difference is to count the events.
##
## The dice are counted directly rather than by playing eighty rallies. A match takes
## minutes and answers the question with one noisy sample; ten thousand rolls answer it
## exactly, in no time, and a short match afterwards confirms the rolls are reached at
## all — which is the other half, and the half a refactor actually breaks.

const ROLLS := 10000


func _ready() -> void:
	var hall: Node = load("res://scenes/match.tscn").instantiate()
	hall.print_truth_while_testing = false
	add_child(hall)
	await get_tree().physics_frame
	hall.career = Career.new()
	hall.career.sport = Career.BADMINTON
	hall.settings.taught = true
	hall._on_match_requested()
	if hall.pressure.exists():
		hall.ui.hide_briefing()
	hall.begin_match()
	for f in 3:
		await get_tree().process_frame

	# One rally first, so there is a shuttle in the world. `_roll_for_offence` reads the
	# shuttle's position to place the incident, and before the first serve there is no
	# shuttle — which is not a bug in the roll, only in asking it a question out of turn.
	hall.start_rally()
	var settling := 0
	while hall._phase != hall.Phase.AWAITING_CALL and settling < 3000:
		await get_tree().physics_frame
		settling += 1

	print("the dice, %d rolls each" % ROLLS)
	_count_service_faults(hall)
	_count_offences(hall)
	hall._phase = hall.Phase.READY

	print()
	print("and whether a real rally reaches them")
	var rallies := 0
	var with_something := 0
	for r in 25:
		hall.start_rally()
		var waited := 0
		while hall._phase != hall.Phase.AWAITING_CALL and waited < 3000:
			await get_tree().physics_frame
			waited += 1
		if hall._phase != hall.Phase.AWAITING_CALL:
			break
		rallies += 1
		if hall.rally.incident.happened():
			with_something += 1
		hall._awaiting_since = Time.get_ticks_msec()
		hall.make_call(&"in" if hall.rally.was_in else &"out")
		var w := 0
		while hall._phase == hall.Phase.AWAITING_CALL and w < 600:
			await get_tree().process_frame
			w += 1
		if hall.board.is_over or hall._phase == hall.Phase.REMOVED:
			break
	print("   %d rallies played, %d carried an offence" % [rallies, with_something])
	print("   (at %.1f%% a rally that is about %.1f expected — a small sample either way,"
		% [100.0 * BadmintonMatch.SERVICE_FAULT_CHANCE, rallies * BadmintonMatch.SERVICE_FAULT_CHANCE])
	print("    which is exactly why the dice above are counted separately)")
	get_tree().quit()


func _count_service_faults(hall: Node) -> void:
	var got := {}
	for i in ROLLS:
		hall.rally = Rally.new(Sides.Team.RED, true)
		var kind = hall._roll_for_a_service_fault()
		var name: String = Incident.Kind.keys()[kind]
		got[name] = int(got.get(name, 0)) + 1
	var faults := ROLLS - int(got.get("NONE", 0))
	print("   service faults: %d of %d  (%.2f%%, wanted %.2f%%)" % [
		faults, ROLLS, 100.0 * faults / ROLLS, 100.0 * BadmintonMatch.SERVICE_FAULT_CHANCE])
	for name in got:
		if name != "NONE":
			print("      %-22s %d" % [name, got[name]])


func _count_offences(hall: Node) -> void:
	var player: Player = hall.players[0]
	var got := {}
	for i in ROLLS:
		hall.rally = Rally.new(Sides.Team.RED, true)
		var kind = hall._roll_for_offence(player)
		var name: String = Incident.Kind.keys()[kind]
		got[name] = int(got.get(name, 0)) + 1
	var offences := ROLLS - int(got.get("NONE", 0))
	print("   rally offences: %d of %d  (%.2f%%, wanted %.2f%%)" % [
		offences, ROLLS, 100.0 * offences / ROLLS, 100.0 * BadmintonMatch.INCIDENT_CHANCE])
	for name in got:
		if name != "NONE":
			print("      %-22s %d" % [name, got[name]])
