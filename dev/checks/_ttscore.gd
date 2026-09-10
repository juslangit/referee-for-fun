extends Node

## Does table tennis count the way table tennis counts?
##
## Arithmetic, checked before anything is built on it — which is how tennis was done and
## the reason its scoring worked first time. The part worth checking is not eleven-by-two;
## it is **the serve**, which passes every two points and then every single point from
## ten-all. Losing track of it is the way an umpire loses a table tennis match.

func _ready() -> void:
	_a_game()
	print()
	_the_serve()
	print()
	_deuce()
	print()
	_a_match()
	get_tree().quit()


func _a_game() -> void:
	print("a game is to eleven, by two")
	var board := TableTennisScore.new(true)
	for i in 10:
		board.award(Sides.Team.RED)
	for i in 3:
		board.award(Sides.Team.BLUE)
	print("   %s   (RED serving)" % board.called_score(Sides.Team.RED))
	board.award(Sides.Team.RED)
	print("   RED takes the eleventh: games %s" % board.games_line())


func _the_serve() -> void:
	print("the serve passes every two points")
	var board := TableTennisScore.new(true)
	var changes: Array[int] = []
	for i in 8:
		board.award(Sides.Team.RED if i % 2 == 0 else Sides.Team.BLUE)
		if board.serve_changes_now():
			changes.append(i + 1)
	print("   after points: %s   (want 2, 4, 6, 8)" % str(changes))


func _deuce() -> void:
	print("and every point from ten-all")
	var board := TableTennisScore.new(true)
	for i in 10:
		board.award(Sides.Team.RED)
		board.award(Sides.Team.BLUE)
	print("   at %s, serve changes every point: %s" % [
		board.called_score(Sides.Team.RED), board.serve_changes_now()])
	board.award(Sides.Team.RED)
	print("   RED goes ahead: %s, changes: %s   (must be true)" % [
		board.called_score(Sides.Team.RED), board.serve_changes_now()])
	board.award(Sides.Team.RED)
	print("   and takes it by two: games %s" % board.games_line())


func _a_match() -> void:
	print("a whole match, best of three")
	var board := TableTennisScore.new(true)
	var games := 0
	while not board.is_over and games < 20:
		var winner := Sides.Team.RED if games % 3 != 1 else Sides.Team.BLUE
		for i in 11:
			board.award(winner)
		games += 1
	print("   over after %d games: %s, winner %s" % [
		games, board.games_line(), Sides.label(board.winner)])
