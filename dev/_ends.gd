extends Node

## Do the players change ends, and does the truth follow them?
##
## The second half is the part worth testing. Swapping which end a side stands at is
## easy; what matters is that everything that means "whose half is this" swaps with them
## — where a serve must land, which side is defending, whose point it is — while
## everything physical stays put, because the umpire's chair and the line judges' corners
## do not move when the players walk past each other.

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
	court.begin_match()
	for f in 3:
		await get_tree().process_frame

	print("the rule: ends change after the first, third, fifth game of a set")
	print("%8s %8s %10s %10s %12s" % ["games", "swapped", "RED at", "BLUE at", "who defends -Z"])
	_report(court)
	for game in 6:
		# Win a whole game for RED, one point at a time.
		for point in 4:
			court.award_the_point(Sides.Team.RED)
		_report(court)

	print()
	print("what stays put while they walk")
	var judge_halves := []
	for judge in court.line_judges:
		judge_halves.append("%s at z %+.1f" % [Sides.label(judge.watches), judge.position.z])
	print("   line judges: %s" % ", ".join(judge_halves))
	print("   the chair:   x %+.2f, and it has not moved" % court.camera.position.x)

	print()
	print("a serve is judged into the box the server is actually facing")
	for swapped in [false, true]:
		court._ends_swapped = swapped
		court.serving = Sides.Team.RED
		var into: float = court.end_of(Sides.opponent(Sides.Team.RED))
		var stands: float = court.end_of(Sides.Team.RED)
		print("   swapped %-5s  RED stands at z %+.0f and serves into z %+.0f" % [
			swapped, stands, into])
	get_tree().quit()


func _report(court: Node) -> void:
	var played: int = court.board.games[Sides.Team.RED] + court.board.games[Sides.Team.BLUE]
	print("%8d %8s %10.0f %10.0f %12s" % [
		played, court._ends_swapped,
		court.end_of(Sides.Team.RED), court.end_of(Sides.Team.BLUE),
		Sides.label(court.side_defending(-5.0))])
