class_name Scoreboard
extends RefCounted

## Badminton scoring, rally point.
##
## Every rally is worth a point to somebody — there is no such thing as a rally that
## does not count, which is exactly why the umpire's word matters on every single
## one of them.

signal game_won(team: Sides.Team)
signal match_won(team: Sides.Team)

## A quick game: first to 11, and a match is that one game.
const QUICK_TARGET := 11
const QUICK_CAP := 15

## A real match: games to 21, best of three.
const FULL_TARGET := 21
const FULL_CAP := 30

var target := FULL_TARGET

## Where the two-clear-points rule stops applying and the next point simply wins.
var cap := FULL_CAP

var games_needed := 2

var points := {Sides.Team.RED: 0, Sides.Team.BLUE: 0}
var games := {Sides.Team.RED: 0, Sides.Team.BLUE: 0}
var is_over := false
var winner := Sides.Team.NONE


func _init(quick := false) -> void:
	if quick:
		target = QUICK_TARGET
		cap = QUICK_CAP
		games_needed = 1
	else:
		target = FULL_TARGET
		cap = FULL_CAP
		games_needed = 2


func award(team: Sides.Team) -> void:
	if is_over or team == Sides.Team.NONE:
		return

	points[team] += 1
	if not _has_won_game(team):
		return

	games[team] += 1
	game_won.emit(team)

	if games[team] >= games_needed:
		is_over = true
		winner = team
		match_won.emit(team)
		return

	points[Sides.Team.RED] = 0
	points[Sides.Team.BLUE] = 0


## A game is won at the target with two clear points, or outright at the cap. Without
## the cap a close game could run forever, which is why badminton has one.
func _has_won_game(team: Sides.Team) -> bool:
	var mine: int = points[team]
	var theirs: int = points[Sides.opponent(team)]
	if mine >= cap:
		return true
	return mine >= target and mine - theirs >= 2


## True once a game is close enough that the next few points decide it. Used to make
## the crowd pay closer attention.
func is_tense() -> bool:
	var red: int = points[Sides.Team.RED]
	var blue: int = points[Sides.Team.BLUE]
	return maxi(red, blue) >= target - 2
