extends Node

## Does tennis count the way tennis counts?
##
## The scoring is the one genuinely new thing tennis brings, and none of it is visible in
## a ball — so it is checked as arithmetic before anything is built on it, the same way
## the volleyball rotation was. Five questions: does a game read 15/30/40, does deuce
## behave, does a set need two clear games, does 6-all become a tiebreak, and does a
## match end after the right number of sets?

func _ready() -> void:
	_a_game()
	print()
	_deuce()
	print()
	_a_set()
	print()
	_a_tiebreak()
	print()
	_a_match()
	_fast4()
	get_tree().quit()


func _a_game() -> void:
	print("one game, RED winning every point")
	var board := TennisScore.new()
	for point in 4:
		print("   %s" % board.called_score(Sides.Team.RED))
		board.award(Sides.Team.RED)
	print("   game to RED: games now %s" % board.games_line())


func _deuce() -> void:
	print("three points each, and what happens next")
	var board := TennisScore.new()
	for point in 3:
		board.award(Sides.Team.RED)
		board.award(Sides.Team.BLUE)
	print("   %s" % board.called_score(Sides.Team.RED))
	board.award(Sides.Team.RED)
	print("   RED takes one: %s" % board.called_score(Sides.Team.RED))
	board.award(Sides.Team.BLUE)
	print("   BLUE takes one back: %s" % board.called_score(Sides.Team.RED))
	board.award(Sides.Team.BLUE)
	print("   BLUE again: %s" % board.called_score(Sides.Team.RED))
	board.award(Sides.Team.BLUE)
	print("   and again — game to BLUE: %s" % board.games_line())


func _a_set() -> void:
	print("a set that has to be won by two")
	var board := TennisScore.new()
	# RED to 5-4 up.
	for game in 5:
		_take_a_game(board, Sides.Team.RED)
	for game in 4:
		_take_a_game(board, Sides.Team.BLUE)
	print("   at %s" % board.games_line())
	_take_a_game(board, Sides.Team.BLUE)
	print("   BLUE levels: %s  (5-5, so nobody has taken it)" % board.games_line())
	_take_a_game(board, Sides.Team.RED)
	_take_a_game(board, Sides.Team.RED)
	print("   RED takes two: %s  (7-5, set RED)" % board.games_line())


func _a_tiebreak() -> void:
	print("six games all")
	var board := TennisScore.new()
	for game in 6:
		_take_a_game(board, Sides.Team.RED)
		_take_a_game(board, Sides.Team.BLUE)
	print("   at %s, tiebreak: %s" % [board.games_line(), board.in_tiebreak])
	print("   the score is now called: %s" % board.called_score(Sides.Team.RED))
	for point in 6:
		board.award(Sides.Team.RED)
		board.award(Sides.Team.BLUE)
	print("   at six each in the tiebreak: %s" % board.called_score(Sides.Team.RED))
	board.award(Sides.Team.RED)
	print("   RED takes one: still going (needs two clear)")
	board.award(Sides.Team.RED)
	print("   RED takes another: %s" % board.games_line())


func _a_match() -> void:
	print("a whole match")
	var board := TennisScore.new()
	var over_after := 0
	# Counted before the signal fires, so the set that ended the match is included.
	board.match_won.connect(func(team: Sides.Team) -> void:
		print("   match to %s after %d sets" % [Sides.label(team), over_after + 1]))
	var to := Sides.Team.RED
	while not board.is_over and over_after < 6:
		var had: int = board.sets[to]
		while board.sets[to] == had and not board.is_over:
			_take_a_game(board, to)
		over_after += 1
		# Alternate so the match goes the distance rather than being a whitewash.
		to = Sides.opponent(to) if over_after == 1 else Sides.Team.RED
	print("   final: %s" % board.games_line())
	print("   sets %d - %d, over: %s" % [
		board.sets[Sides.Team.RED], board.sets[Sides.Team.BLUE], board.is_over])


func _take_a_game(board: TennisScore, team: Sides.Team) -> void:
	var had: int = board.games[team]
	var sets_had: int = board.sets[team]
	while board.games[team] == had and board.sets[team] == sets_had and not board.is_over:
		board.award(team)

## Fast4, which is what the opening venues are played under.
func _fast4() -> void:
	print()
	print("Fast4 — four games, tiebreak at three-all, no advantage")
	var board := TennisScore.new(true)
	print("   a set is %d games, tiebreak at %d, no advantage: %s" % [
		board.games_to_win, board.tiebreak_at, board.no_advantage])

	for i in 3:
		board.award(Sides.Team.RED)
		board.award(Sides.Team.BLUE)
	print("   three points each: %s" % board.called_score(Sides.Team.RED))
	board.award(Sides.Team.RED)
	print("   RED takes the deciding point — game: %s" % board.games_line())

	# Three games each, which under Fast4 is a tiebreak.
	while board.games[Sides.Team.RED] < 3:
		for i in 4:
			board.award(Sides.Team.RED)
	while board.games[Sides.Team.BLUE] < 3:
		for i in 4:
			board.award(Sides.Team.BLUE)
	print("   at three all: %s, tiebreak: %s" % [board.games_line(), board.in_tiebreak])
	for i in 7:
		board.award(Sides.Team.RED)
	print("   RED takes the tiebreak: %s, over: %s" % [board.games_line(), board.is_over])
