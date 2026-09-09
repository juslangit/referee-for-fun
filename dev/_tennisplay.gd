extends Node

## Does a tennis point play, and does an honest umpire survive one?
##
## The question every sport in this game has had to answer, and the one with the most
## ways to fail here: a tennis point has a first serve, a second serve, a let that is
## nobody's fault, and a rally in which the ball lands over and over. An umpire who
## always says the true thing must pay nothing for any of it.

func _ready() -> void:
	var court: Node = load("res://scenes/tennis.tscn").instantiate()
	court.print_truth_while_testing = false
	add_child(court)
	await get_tree().physics_frame

	court.career = Career.new()
	court.career.sport = Career.TENNIS
	court.settings.taught_tennis = true
	court.ui.match_requested.emit()
	await get_tree().process_frame
	if court.pressure.exists():
		court.ui.briefing_acknowledged.emit()
		await get_tree().process_frame
	for f in 3:
		await get_tree().process_frame

	var judged := 0
	var wrong := 0
	var serves := 0
	var seconds := 0
	var lets := 0
	var good_serves := 0
	var kinds := {}
	var margins: Array[float] = []
	var stalled := 0

	for frame in 400000:
		await get_tree().process_frame
		if court._phase == court.Phase.READY:
			court.start_rally()
			stalled = 0
			continue
		if frame % 1200 == 0:
			print("    ... frame %d, phase %d, judged %d, beat %d, aimed %s, letting %s, landed %s, bounces %d" % [
				frame, court._phase, judged, court._beat, court._aimed_to_end,
				court._letting_it_go, court._ball.has_landed, court._ball.bounces])
		if court._phase != court.Phase.AWAITING_CALL:
			stalled += 1
			if stalled > 2000:
				print("STALLED in phase %d after %d judged" % [court._phase, judged])
				break
			continue
		stalled = 0

		var rally: TennisRally = court.rally
		if rally.is_a_serve:
			serves += 1
			if rally.serve_number == 2:
				seconds += 1
			if rally.serve_was_good:
				good_serves += 1
			if rally.is_a_let():
				lets += 1
		margins.append(rally.margin)

		var truth := _truth(rally)
		kinds[truth.id] = int(kinds.get(truth.id, 0)) + 1

		court._awaiting_since = Time.get_ticks_msec()
		court.make_call(truth.id, truth.against)

		var waited := 0
		while court._phase == court.Phase.AWAITING_CALL and waited < 900:
			await get_tree().process_frame
			waited += 1

		if rally.verdict() == Rally.Verdict.WRONG:
			wrong += 1
			print("   WRONG: %s" % rally.describe())
			print("      serve=%s n=%d good=%s cord=%s foot=%s notup=%s net=%s over=%s | goes=%s rightful=%s | call=%s against=%s conduct=%s land=%s in=%s" % [
				rally.is_a_serve, rally.serve_number, rally.serve_was_good,
				rally.clipped_the_cord, rally.foot_fault,
				Sides.label(rally.not_up_by), Sides.label(rally.net_toucher),
				Sides.label(rally.reached_over_by),
				Sides.label(rally.point_goes_to()), Sides.label(rally.rightful_winner()),
				rally.call.id, Sides.label(rally.call_against),
				rally.call.judges_conduct, rally.call.judges_the_landing,
				rally.call.asserts_in])

		judged += 1
		if judged >= 400 or court.board.is_over or court._phase == court.Phase.REMOVED:
			break

	var close := 0
	for m in margins:
		if absf(m) <= 0.25:
			close += 1

	print("points judged:   %d" % judged)
	print("of which serves: %d   (second serves %d, lets %d, good %d)" % [
		serves, seconds, lets, good_serves])
	print("within 25 cm of a line: %d  (%.0f%%)" % [
		close, 100.0 * float(close) / maxf(1.0, float(margins.size()))])
	print("what was called:")
	for id in kinds:
		print("   %-18s %d" % [id, kinds[id]])
	print("score:           %s   %s" % [
		court.board.called_score(court.serving), court.board.games_line()])
	print("suspicion:       %.3f   (an honest umpire must pay 0.000)" % court.suspicion.level)
	print("scored WRONG:    %d   (must be 0)" % wrong)
	get_tree().quit()


## What an umpire who saw everything would say. The order is the order the rules apply
## in, which is the same order TennisRally.rightful_winner uses.
func _truth(rally: TennisRally) -> Dictionary:
	if rally.is_a_let():
		return {"id": &"let", "against": rally.struck_by}
	if rally.foot_fault:
		return {"id": &"foot_fault", "against": rally.struck_by}
	if rally.net_toucher != Sides.Team.NONE:
		return {"id": &"touched_net", "against": rally.net_toucher}
	if rally.reached_over_by != Sides.Team.NONE:
		return {"id": &"through_the_net", "against": rally.reached_over_by}
	if rally.not_up_by != Sides.Team.NONE:
		return {"id": &"not_up", "against": rally.not_up_by}
	if rally.is_a_serve:
		return {"id": &"in" if rally.serve_was_good else &"out", "against": Sides.Team.NONE}
	return {"id": &"in" if rally.was_in else &"out", "against": Sides.Team.NONE}
