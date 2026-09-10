extends Node

## Table tennis's fair-play check, the same shape as the other four.
##
## Two things here are asked of no other sport. A point contains **three** landings —
## the serve onto the server's own half, the serve onto the receiver's, and then the
## rally — so this prints which beat the point actually ended on, because a serve that
## never gets over the net is a whole class of bug that looks exactly like a short rally
## from the outside. And it counts **edge balls**, which are the sport's own call and
## the one thing that would silently stop happening if the geometry drifted.

func _ready() -> void:
	var hall: Node = load("res://scenes/table_tennis.tscn").instantiate()
	add_child(hall)
	await get_tree().physics_frame
	hall.career = Career.new()
	hall.career.sport = Career.TABLE_TENNIS
	hall.settings.taught_table_tennis = true
	hall._on_match_requested()
	if hall.pressure.exists():
		hall.ui.hide_briefing()
	hall.begin_match()
	for f in 4:
		await get_tree().process_frame

	var played := 0
	var served := 0
	var on_the_edge := 0
	var lets := 0
	var illegal := 0
	var wrong := 0
	print("%4s %-11s %8s %8s %-20s %s" % [
		"#", "ended on", "landed", "margin", "fault", "verdict"])

	for r in 60:
		hall.start_rally()
		var w := 0
		while hall._phase != hall.Phase.AWAITING_CALL and w < 4000:
			await get_tree().physics_frame
			w += 1
		if hall._phase != hall.Phase.AWAITING_CALL:
			print("  point %d never reached a call" % r)
			break

		var rally: TableTennisRally = hall.rally
		played += 1
		if rally.is_a_serve:
			served += 1
		if rally.clipped_the_edge:
			on_the_edge += 1
		if rally.is_a_let():
			lets += 1
		if rally.illegal_service:
			illegal += 1

		# The honest umpire, in the order the rules apply.
		hall._awaiting_since = Time.get_ticks_msec()
		if rally.is_a_let():
			hall.make_call(&"let", rally.served_by)
		elif rally.illegal_service:
			hall.make_call(&"illegal_service", rally.served_by)
		elif rally.volleyed_by != Sides.Team.NONE:
			hall.make_call(&"volley", rally.volleyed_by)
		elif rally.touched_the_table_by != Sides.Team.NONE:
			hall.make_call(&"touched_the_table", rally.touched_the_table_by)
		elif rally.double_bounce_by != Sides.Team.NONE:
			hall.make_call(&"double_bounce", rally.double_bounce_by)
		else:
			hall.make_call(&"in" if rally.rightful_winner() == rally.struck_by else &"out")

		var w2 := 0
		while hall._phase == hall.Phase.AWAITING_CALL and w2 < 900:
			await get_tree().process_frame
			w2 += 1

		var verdict: String = Rally.Verdict.keys()[rally.verdict()]
		if rally.verdict() == Rally.Verdict.WRONG:
			wrong += 1
		print("%4d %-11s %8s %8.3f %-20s %s" % [
			r,
			"serve" if rally.is_a_serve else "rally",
			"IN" if rally.was_in else "OUT",
			rally.margin,
			_fault_of(rally),
			verdict,
		])
		if hall.board.is_over or hall._phase == hall.Phase.REMOVED:
			break

	print()
	print("%d points: %d decided on the serve, %d on the edge, %d lets, %d illegal serves"
		% [played, served, on_the_edge, lets, illegal])
	print("scored WRONG: %d" % wrong)
	print("suspicion: %.3f   (an honest umpire must pay 0.000)" % hall.suspicion.level)
	print("score: %s   games %s" % [
		hall.board.called_score(hall.serving), hall.board.games_line()])
	get_tree().quit()


func _fault_of(rally: TableTennisRally) -> String:
	if rally.is_a_let():
		return "let"
	if rally.illegal_service:
		return "illegal: %s" % rally.service_fault
	if rally.volleyed_by != Sides.Team.NONE:
		return "struck in the air"
	if rally.touched_the_table_by != Sides.Team.NONE:
		return "hand on the table"
	if rally.double_bounce_by != Sides.Team.NONE:
		return "two bounces"
	return "-"
