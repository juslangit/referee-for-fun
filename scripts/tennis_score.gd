class_name TennisScore
extends Scoreboard

## Tennis scoring, which is unlike anything else in this game.
##
## Every other sport here counts points until somebody has enough of them. Tennis counts
## points into games, games into sets and sets into a match, and it does the first of
## those in a language of its own — fifteen, thirty, forty — that stopped meaning
## anything numerical several centuries ago.
##
## It matters to get right because **the score is what makes a tennis call expensive**.
## A wrong call at 40-0 costs a point nobody will remember. The same call at deuce in a
## tiebreak at 6-all in the third is the match, and the player, the crowd and the
## umpire all know it while it is happening. A game that counted tennis points as
## 1-2-3-4 would still work and would have thrown that away.
##
## It extends Scoreboard so the shared match spine keeps working: `points` holds the
## raw point count of the current game, `games` the games in the current set. What is
## added is `sets`, the tiebreak, and a way to say "40".

signal set_won(team: Sides.Team)

## What the four point counts are called. Past three, a game is decided by the margin
## rather than the count, so there is nothing left to name.
const CALLED := ["0", "15", "30", "40"]

## Games needed to win a set, and the margin required.
const GAMES_TO_WIN := 6
const GAMES_MARGIN := 2

## Where a set stops being about games and becomes a tiebreak.
const TIEBREAK_AT := 6

## The short format the opening venues are played under: **Fast4**, which is a real
## thing rather than a convenience invented here — four games to a set, a tiebreak at
## three-all, and no advantage, so a game standing at deuce is settled by one point.
##
## It exists because tennis's own scoring made the first match on the ladder three times
## longer than any other sport's. Measured, a full set took 80 calls and seven and a half
## minutes, against 29 calls for beach and 26 for indoor — a tutorial nobody would sit
## through. Every other sport shortens its first venue; tennis had nothing to shorten
## except the number of sets, and one set is already the whole match.
const FAST4_GAMES := 4
const FAST4_TIEBREAK_AT := 3

## Points to win a tiebreak, by two.
const TIEBREAK_TARGET := 7

var sets := {Sides.Team.RED: 0, Sides.Team.BLUE: 0}
var sets_needed := 2

# `finished_sets` is Scoreboard's; tennis fills it with each set's games rather than points.

## The format this match is played under. Full tennis at the venues that deserve it,
## Fast4 at the ones you are still learning on.
var games_to_win := GAMES_TO_WIN
var tiebreak_at := TIEBREAK_AT

## Whether a game standing at deuce is decided by a single point rather than by two
## clear. Real, and used in Fast4 and in most doubles.
var no_advantage := false

## Whether the current game is a tiebreak, which is scored in plain numbers — the one
## part of a tennis match that counts the way everything else in this game does.
var in_tiebreak := false


func _init(quick := false) -> void:
	# Nothing from Scoreboard's own targets applies; tennis decides everything by
	# margin. `target` is left alone so anything reading it gets a sane number.
	sets_needed = 1 if quick else 2
	games_needed = sets_needed
	if quick:
		games_to_win = FAST4_GAMES
		tiebreak_at = FAST4_TIEBREAK_AT
		no_advantage = true


## One point to somebody.
func award(team: Sides.Team) -> void:
	if is_over or team == Sides.Team.NONE:
		return

	points[team] += 1
	if not _has_won_game(team):
		return

	points[Sides.Team.RED] = 0
	points[Sides.Team.BLUE] = 0
	games[team] += 1
	in_tiebreak = games[Sides.Team.RED] == tiebreak_at and games[Sides.Team.BLUE] == tiebreak_at

	if not _has_won_set(team):
		return

	sets[team] += 1
	finished_sets.append(games.duplicate())
	games[Sides.Team.RED] = 0
	games[Sides.Team.BLUE] = 0
	in_tiebreak = false
	set_won.emit(team)
	# The spine listens to game_won for "a scoring unit ended, hand the challenges
	# back", and in tennis that unit is a set rather than a game.
	game_won.emit(team)

	if sets[team] >= sets_needed:
		is_over = true
		winner = team
		match_won.emit(team)


## A game is won at four points with two clear, or a tiebreak at seven with two clear.
##
## The "four points" is the part that reads oddly written down and is why the scoreboard
## says 40 rather than 3: the fourth point wins unless the other side also has three, in
## which case the game goes on until somebody is two ahead. Deuce is not a special rule,
## it is just what having three each is called.
func _has_won_game(team: Sides.Team) -> bool:
	var mine: int = points[team]
	var theirs: int = points[Sides.opponent(team)]
	var needed := TIEBREAK_TARGET if in_tiebreak else 4
	# No-advantage: three-all is a deciding point, so the fourth wins it outright.
	var margin := 1 if (no_advantage and not in_tiebreak and mine >= 4 and theirs >= 3) else 2
	return mine >= needed and mine - theirs >= margin


func _has_won_set(team: Sides.Team) -> bool:
	var mine: int = games[team]
	var theirs: int = games[Sides.opponent(team)]
	# A tiebreak game settles the set outright, 7-6 — or 4-3 under Fast4.
	if mine == tiebreak_at + 1 and theirs == tiebreak_at:
		return true
	return mine >= games_to_win and mine - theirs >= GAMES_MARGIN


## What the umpire would call this score, from the serving side's point of view.
##
## "Deuce" and "advantage" are not extra rules, they are the names for three-all and for
## being one clear afterwards — which is why they only appear once both sides are past
## thirty.
func called_score(serving: Sides.Team) -> String:
	var receiving := Sides.opponent(serving)
	var mine: int = points[serving]
	var theirs: int = points[receiving]

	if in_tiebreak:
		return "%d - %d" % [mine, theirs]

	if mine >= 3 and theirs >= 3:
		if mine == theirs:
			# Under no-advantage there is nothing after deuce, so it is worth saying so:
			# the next point is the game, and everybody on court knows it.
			return "DECIDING POINT" if no_advantage else "DEUCE"
		return "ADVANTAGE %s" % Sides.label(serving if mine > theirs else receiving)

	if mine == theirs:
		return "%s ALL" % CALLED[mini(mine, 3)]
	return "%s - %s" % [CALLED[mini(mine, 3)], CALLED[mini(theirs, 3)]]


## The games and sets, the way a scoreboard shows them.
func games_line() -> String:
	return "%d - %d      sets %d - %d" % [
		games[Sides.Team.RED], games[Sides.Team.BLUE],
		sets[Sides.Team.RED], sets[Sides.Team.BLUE]]


## True once a game is close enough that the next point or two decides it.
func is_tense() -> bool:
	var red: int = points[Sides.Team.RED]
	var blue: int = points[Sides.Team.BLUE]
	if in_tiebreak:
		return maxi(red, blue) >= TIEBREAK_TARGET - 2
	# Game point, or deuce and beyond, which is every point from there on.
	return maxi(red, blue) >= 3
