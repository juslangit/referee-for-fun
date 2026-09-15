class_name Scoreboard
extends RefCounted

## Rally-point scoring, for all three sports.
##
## Every rally is worth a point to somebody — there is no such thing as a rally that
## does not count, which is exactly why the official's word matters on every single
## one of them.
##
## Badminton's numbers are the defaults. The two volleyballs set their own, and one of
## the things they set is the rule badminton has no equivalent of: **the last set of a
## match is played to a shorter target than the rest of it.** A beach third set is to
## 15 rather than 21, and an indoor fifth set is to 15 rather than 25.

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

## What the last set is played to, when a sport shortens it. Zero means every set is
## played to the same target, which is badminton.
var decider_target := 0

var points := {Sides.Team.RED: 0, Sides.Team.BLUE: 0}
var games := {Sides.Team.RED: 0, Sides.Team.BLUE: 0}
var is_over := false
var winner := Sides.Team.NONE

## Every finished game or set's points, in order, for reading a result out: "25–21, 22–25".
var finished_sets: Array[Dictionary] = []


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
	finished_sets.append(points.duplicate())
	game_won.emit(team)

	if games[team] >= games_needed:
		is_over = true
		winner = team
		match_won.emit(team)
		return

	points[Sides.Team.RED] = 0
	points[Sides.Team.BLUE] = 0


## What this particular set is played to.
##
## The last one is shorter in both volleyballs, and "the last one" means the set played
## when both sides are one away from winning the match — not the fifth set by counting,
## because a match that reaches 2-2 and a match that reaches 2-0 are different lengths.
func target_now() -> int:
	if decider_target <= 0:
		return target
	var needed := games_needed - 1
	if games[Sides.Team.RED] == needed and games[Sides.Team.BLUE] == needed:
		return decider_target
	return target


## True once this set is the last one. The crowd is told, because a fifth set is a
## different room from a second one.
func is_the_decider() -> bool:
	return decider_target > 0 and target_now() == decider_target


## A game is won at the target with two clear points, or outright at the cap. Without
## the cap a close game could run forever, which is why badminton has one.
func _has_won_game(team: Sides.Team) -> bool:
	var mine: int = points[team]
	var theirs: int = points[Sides.opponent(team)]
	if mine >= cap:
		return true
	return mine >= target_now() and mine - theirs >= 2


## True once a game is close enough that the next few points decide it. Used to make
## the crowd pay closer attention.
func is_tense() -> bool:
	var red: int = points[Sides.Team.RED]
	var blue: int = points[Sides.Team.BLUE]
	return maxi(red, blue) >= target_now() - 2
