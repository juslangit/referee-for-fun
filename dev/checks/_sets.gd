extends Node

## Is the last set shorter than the rest of them?
##
## Beach plays a third set to 15 and indoor a fifth set to 15, while every other set in
## both sports runs to 21 and 25. The scoreboard had one target for a whole match, so
## both sports were playing their deciding set at full length — which anybody who
## watches volleyball would notice, and nobody who only reads the code would.

func _ready() -> void:
	_run("badminton", 21, 0, 2)
	_run("beach", 21, 15, 2)
	_run("indoor", 25, 15, 3)
	get_tree().quit()


func _run(sport: String, target: int, decider: int, needed: int) -> void:
	print("=== %s: sets to %d, %s, first to %d sets" % [
		sport, target,
		"decider to %d" % decider if decider > 0 else "no shorter decider", needed])

	var board := Scoreboard.new(false)
	board.target = target
	board.cap = 9999
	board.games_needed = needed
	board.decider_target = decider

	# Sets are won alternately, so the match goes 1-0, 1-1, 2-1, 2-2 and reaches its
	# last one. Driving it any other way finishes early and never tests the decider,
	# which is what the first version of this did.
	var to := Sides.Team.RED
	var set_number := 0
	while not board.is_over and set_number < 8:
		set_number += 1
		print("  set %d is played to %-3d%s" % [
			set_number, board.target_now(),
			"   <- the decider" if board.is_the_decider() else ""])
		var had: int = board.games[to]
		while board.games[to] == had and not board.is_over:
			board.award(to)
		to = Sides.opponent(to)

	print("  match over after %d sets, %d-%d" % [
		set_number, board.games[Sides.Team.RED], board.games[Sides.Team.BLUE]])
	print()
