extends Node

## Badminton's fair-play check, the same shape as `_beachplay`, `_indoorplay` and
## `_tennisplay` — which badminton did not have.
##
## Written because `_fairplay` began giving wildly different answers run to run: 1.0,
## 3.0, 8.0 and 10.0 strokes a rally from the same code inside an hour, and zero
## offences over forty-five rallies at a rate that should have produced nine. A harness
## that cannot agree with itself cannot certify anything, and a great deal of time went
## into looking for a bug in the game that was never there.
##
## So this drives the match the way a player does and prints what actually happened, one
## rally at a time. `_fairplay` is still worth keeping for its two contrasting umpires,
## but it needs its own repair before it is trusted again.

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
	for f in 4:
		await get_tree().process_frame

	var played := 0
	var strokes := 0
	var with_incident := 0
	var wrong := 0
	print("%4s %8s %10s %-22s %s" % ["#", "strokes", "landed", "incident", "verdict"])
	for r in 20:
		hall.start_rally()
		var w := 0
		while hall._phase != hall.Phase.AWAITING_CALL and w < 3000:
			await get_tree().physics_frame
			w += 1
		if hall._phase != hall.Phase.AWAITING_CALL:
			print("  rally %d never reached a call" % r)
			break

		var rally: Rally = hall.rally
		var kind: String = Incident.Kind.keys()[rally.incident.kind]
		played += 1
		strokes += hall._shots_this_rally
		if rally.incident.happened():
			with_incident += 1

		# The honest umpire: the offence if there was one, otherwise the line.
		hall._awaiting_since = Time.get_ticks_msec()
		if rally.incident.happened():
			hall.make_call(_call_for(rally.incident.kind), rally.incident.by)
		else:
			hall.make_call(&"in" if rally.was_in else &"out")
		var w2 := 0
		while hall._phase == hall.Phase.AWAITING_CALL and w2 < 600:
			await get_tree().process_frame
			w2 += 1

		var verdict: String = Rally.Verdict.keys()[rally.verdict()]
		if rally.verdict() == Rally.Verdict.WRONG:
			wrong += 1
		print("%4d %8d %10s %-22s %s" % [
			r, hall._shots_this_rally, "IN" if rally.was_in else "OUT", kind, verdict])
		if hall.board.is_over or hall._phase == hall.Phase.REMOVED:
			break

	print()
	print("%d rallies, %.1f strokes each, %d carried an incident, %d scored WRONG" % [
		played, float(strokes) / maxf(1.0, played), with_incident, wrong])
	print("suspicion: %.3f   (an honest umpire must pay 0.000)" % hall.suspicion.level)
	get_tree().quit()


func _call_for(kind: Incident.Kind) -> StringName:
	match kind:
		Incident.Kind.NET_TOUCH: return &"net_touch"
		Incident.Kind.CARRY: return &"carry"
		Incident.Kind.DOUBLE_HIT: return &"double_hit"
		Incident.Kind.OBSTRUCTION: return &"obstruction"
		Incident.Kind.SERVICE_TOO_HIGH: return &"serve_too_high"
		Incident.Kind.SERVICE_RACKET_UP: return &"serve_racket_up"
		Incident.Kind.SERVICE_FEET: return &"serve_feet"
	return &"in"
