extends Node

## The service court error, from every side.
##
## Four things to establish. That the mistake is actually put on the court rather than
## only recorded in a variable — the player has to be able to *see* it. That calling it
## in time and calling it late do the two different things the law says they do. That
## it can never move the score, which is the whole reason this call is safe to make.
## And that an umpire who watches for it pays nothing, while one who never looks pays
## a little.

func _ready() -> void:
	var arena: Node = load("res://scenes/match.tscn").instantiate()
	arena.print_truth_while_testing = false
	add_child(arena)
	await get_tree().physics_frame
	arena.career = Career.new()
	arena.ui.match_requested.emit()
	await get_tree().process_frame
	arena.begin_match()
	for f in 4:
		await get_tree().process_frame

	_is_it_visible(arena)
	print()
	_the_two_moments(arena)
	print()
	await _a_whole_match(arena, true)
	await _a_whole_match(arena, false)
	get_tree().quit()


## Is the mistake actually on the floor? The offending pair should be stood in each
## other's boxes, which is the only thing the player has to go on.
func _is_it_visible(arena: Node) -> void:
	print("where the four of them are standing")
	print("%-10s %-8s %-9s %-14s %s" % [
		"serving", "score", "error by", "server's box", "receiver's box"])

	for serving in [Sides.Team.RED, Sides.Team.BLUE]:
		for score in [0, 1]:
			for mistaken in [Sides.Team.NONE, serving, Sides.opponent(serving)]:
				arena.serving = serving
				arena.board.points[serving] = score
				var court: float = arena.service_court(serving)
				arena._stand_for_serve(court, mistaken)

				var server: Vector3 = _front(arena, serving)
				var receiver: Vector3 = _front(arena, Sides.opponent(serving))
				var server_right: bool = signf(server.x) == court
				var receiver_right: bool = signf(receiver.x) == -court
				print("%-10s %-8d %-9s %-14s %s" % [
					Sides.label(serving), score, Sides.label(mistaken),
					"correct" if server_right else "WRONG BOX",
					"correct" if receiver_right else "WRONG BOX",
				])


## The player of a pair who is standing up at the front, ready to play the serve.
func _front(arena: Node, team: Sides.Team) -> Vector3:
	var best := Vector3.ZERO
	var nearest := 999.0
	for player in arena.players:
		if player.team != team:
			continue
		if absf(player.home.z) < nearest:
			nearest = absf(player.home.z)
			best = player.home
	return best


## In time the serve is taken again; late the score stands. Neither ever moves a point.
func _the_two_moments(arena: Node) -> void:
	print("what the call does")
	print("%-22s %-11s %-13s %-9s %s" % [
		"", "there was", "positions", "score", "suspicion"])

	for in_time in [true, false]:
		for real in [true, false]:
			arena.serving = Sides.Team.RED
			arena.board.points[Sides.Team.RED] = 0
			arena.board.points[Sides.Team.BLUE] = 0
			arena.suspicion.level = 0.0
			arena.suspicion.wrong_calls = 0
			arena._serve_court = arena.service_court(Sides.Team.RED)
			arena.service_error = Sides.Team.RED if real else Sides.Team.NONE
			arena._service_error_handled = false
			arena._stand_for_serve(arena._serve_court, arena.service_error)

			var before := "%d-%d" % [
				arena.board.points[Sides.Team.RED], arena.board.points[Sides.Team.BLUE]]
			arena._call_service_court(in_time)
			var after := "%d-%d" % [
				arena.board.points[Sides.Team.RED], arena.board.points[Sides.Team.BLUE]]

			var server: Vector3 = _front(arena, Sides.Team.RED)
			var standing_right: bool = signf(server.x) == arena._serve_court
			print("%-22s %-11s %-13s %-9s %+.3f" % [
				("called in time" if in_time else "called late"),
				"an error" if real else "nothing",
				"corrected" if standing_right else "still wrong",
				"%s → %s" % [before, after],
				arena.suspicion.level,
			])


## A match refereed honestly, once by somebody who is watching the service courts and
## once by somebody who never looks at them.
func _a_whole_match(arena: Node, attentive: bool) -> void:
	arena.suspicion.level = 0.0
	arena.suspicion.peak = 0.0
	arena.suspicion.lean = 0.0
	arena.suspicion.wrong_calls = 0
	arena.board = Scoreboard.new(false)
	arena.serving = Sides.Team.RED
	arena.enter_ready()

	var judged := 0
	var errors := 0
	var caught := 0
	var served := 0
	for frame in 20000:
		await get_tree().process_frame
		if arena._phase == arena.Phase.READY:
			if arena.service_error != Sides.Team.NONE:
				errors += 1
				if attentive:
					caught += 1
					arena._call_service_court(true)
			arena.start_rally()
			served += 1
			continue
		if arena._phase != arena.Phase.AWAITING_CALL:
			continue

		var rally: Rally = arena.rally
		# This harness runs slower than real time, so by the time it notices the shuttle
		# has landed the game thinks the umpire has been sitting there for four seconds.
		# Hesitation is not what is being measured here; reset the clock so the number
		# at the end is the service court call and nothing else.
		arena._awaiting_since = Time.get_ticks_msec()
		arena.make_call(&"in" if CourtSpec.is_in(rally.landing_point, rally.doubles) else &"out")
		judged += 1
		for f in 18:
			await get_tree().process_frame
		if judged >= 20 or arena.board.is_over:
			break

	print("%-12s umpire: %2d rallies, %d errors, %d spotted, %d wrong calls, suspicion %.3f" % [
		"attentive" if attentive else "inattentive", judged, errors, caught,
		arena.suspicion.wrong_calls, arena.suspicion.level])
