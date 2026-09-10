class_name TableTennisScore
extends Scoreboard

## Table tennis scoring: to eleven, by two, and the serve changes hands every two points.
##
## The scoring itself is the simplest in this game — plain numbers, no fifteen-thirty-forty
## — and the part worth building is the **serve**. It passes to the other side every two
## points, and from ten-all it passes every single point. An umpire who loses track of
## whose serve it is has lost track of the match, and the players will tell them so.
##
## That makes it the third sport here whose real difficulty is bookkeeping rather than
## eyesight, alongside indoor volleyball's rotation and badminton's service courts.

signal set_won(team: Sides.Team)

const GAME_TARGET := 11
const GAME_MARGIN := 2

## Where the serve starts changing every point instead of every two.
const DEUCE_AT := 10

## How many points one side keeps the serve for, before and after deuce.
const SERVES_EACH := 2
const SERVES_EACH_AT_DEUCE := 1


func _init(quick := false) -> void:
	# Best of three at the venues you are learning on, best of five after that. Real
	# table tennis is best of five or seven; three is this game's tutorial length.
	games_needed = 2 if quick else 3
	target = GAME_TARGET
	cap = 9999


func award(team: Sides.Team) -> void:
	if is_over or team == Sides.Team.NONE:
		return
	points[team] += 1
	if not _has_won_game(team):
		return

	points[Sides.Team.RED] = 0
	points[Sides.Team.BLUE] = 0
	games[team] += 1
	set_won.emit(team)
	# The spine listens to game_won for "a scoring unit ended, hand the challenges back".
	game_won.emit(team)

	if games[team] >= games_needed:
		is_over = true
		winner = team
		match_won.emit(team)


func _has_won_game(team: Sides.Team) -> bool:
	var mine: int = points[team]
	var theirs: int = points[Sides.opponent(team)]
	return mine >= GAME_TARGET and mine - theirs >= GAME_MARGIN


## Whether the serve passes to the other side after the point just played.
##
## Every two points, and every point once both sides have reached ten. Worked out from
## the running total rather than kept as a counter, so it cannot drift out of step with
## the score it is supposed to follow.
func serve_changes_now() -> bool:
	var played: int = points[Sides.Team.RED] + points[Sides.Team.BLUE]
	if points[Sides.Team.RED] >= DEUCE_AT and points[Sides.Team.BLUE] >= DEUCE_AT:
		return true
	return played % SERVES_EACH == 0


## How the umpire calls it: the server's score first, always.
func called_score(serving: Sides.Team) -> String:
	return "%d - %d" % [points[serving], points[Sides.opponent(serving)]]


func games_line() -> String:
	return "%d - %d" % [games[Sides.Team.RED], games[Sides.Team.BLUE]]


## True once the next point or two could take the game.
func is_tense() -> bool:
	return maxi(points[Sides.Team.RED], points[Sides.Team.BLUE]) >= GAME_TARGET - 2
