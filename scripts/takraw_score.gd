class_name TakrawScore
extends Scoreboard

## Sepak takraw's scoring, as ISTAF has played it since 1 February 2024 (Law of the Game
## 2024, Laws 10 and 12).
##
## Rally points, sets to 15, best of three — and the one rule that makes it unlike every
## other sport in this game: **there is no two-point margin.** At 14-14 the referee announces
## "setting up to seventeen points", and whoever reaches 17 first wins the set. Before that,
## 15 wins it (15-13 at the closest); after it 16-14 does not, and 17-16 does.
##
## The service alternates after every point whoever wins it, which is the match's business
## rather than the board's — see TakrawMatch.award_the_point.
##
## A quick match, at the bottom of the ladder, is one set played the same way.

const SET_TARGET := 15
const SETTING_AT := 14
const SET_UP_TO := 17

## True once this set reached 14-14. The referee says so out loud, once.
var set_up := false


func _init(quick := false) -> void:
	super(quick)
	target = SET_TARGET
	cap = SET_UP_TO
	decider_target = 0
	games_needed = 1 if quick else 2


func award(team: Sides.Team) -> void:
	if is_over or team == Sides.Team.NONE:
		return
	var sets_before: int = games[Sides.Team.RED] + games[Sides.Team.BLUE]
	super(team)
	# A new set starts level, and not set up.
	if games[Sides.Team.RED] + games[Sides.Team.BLUE] != sets_before:
		set_up = false
	elif points[Sides.Team.RED] == SETTING_AT and points[Sides.Team.BLUE] == SETTING_AT:
		set_up = true


## Won at 15 while the other side has 13 or fewer, or at 17 once it has been set up. Never
## by a margin: the whole point of the 2024 rule is that sets end.
func _has_won_game(team: Sides.Team) -> bool:
	var mine: int = points[team]
	var theirs: int = points[Sides.opponent(team)]
	if set_up or (mine >= SETTING_AT and theirs >= SETTING_AT):
		return mine >= SET_UP_TO
	return mine >= SET_TARGET


func target_now() -> int:
	return SET_UP_TO if set_up else SET_TARGET


func is_tense() -> bool:
	return maxi(points[Sides.Team.RED], points[Sides.Team.BLUE]) >= SET_TARGET - 2
