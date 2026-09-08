class_name Challenge
extends RefCounted

## The review system, and the only moment in this game where the truth is put on a screen
## in front of everybody.
##
## Everything else the umpire does is deniable. A shuttle two centimetres out called IN is
## a matter of opinion; the crowd mutters, the line judge shrugs, and the rally moves on.
## A review ends that. The hall watches the landing from directly overhead, at a size
## nobody can argue with, and then either the umpire was right or they were not.
##
## The important design choice here is that players sometimes challenge a call that was
## correct. If a review only ever happened when the umpire had lied, then the word
## CHALLENGE would be a verdict announced in advance and there would be nothing to find
## out. It has to be a threat that might come to nothing — otherwise being challenged is
## the punishment, rather than being caught.

## Reviews each side gets per game. As in the real sport: unsuccessful ones are spent,
## and a successful challenge is handed back.
const PER_GAME := 2

## How likely a side is to review a call that genuinely went against them. They are more
## willing the more obvious it was — a shuttle a metre out called IN is not something a
## player lets go.
const WRONGED_BASE := 0.34
const WRONGED_PER_VISIBILITY := 0.52

## And how likely they are to review a call that was perfectly correct. Small, and
## largest on the calls that were closest — those are the ones where a player genuinely
## could not tell, and where they will spend a review finding out they were wrong.
const MISTAKEN_MOST := 0.16

## Below this margin a player cannot really tell either, in metres.
const DOUBT_RANGE := 0.28

## How much more willing a side is to review when they have a reason to distrust this
## particular umpire — a grudge, or a call of yours that already cost them a rally. It
## is the mechanical half of somebody having your name: they stop giving you the
## benefit of the doubt, and the close ones you used to get away with go on a screen.
const WATCHING_YOU := 0.22

var left := {Sides.Team.RED: PER_GAME, Sides.Team.BLUE: PER_GAME}

## The side that is watching the umpire closely, if either is.
var watching := Sides.Team.NONE


func reset() -> void:
	left = {Sides.Team.RED: PER_GAME, Sides.Team.BLUE: PER_GAME}


func remaining(team: Sides.Team) -> int:
	return int(left.get(team, 0))


## Whether this rally can be reviewed at all.
##
## Line calls only. A review looks at where the shuttle landed, which settles nothing
## about a net touch or a carry — those are the umpire's word against the hall's, and in
## the real sport they are not reviewable either.
func reviewable(rally: Rally) -> bool:
	if rally == null or rally.call == null or not rally.is_settled:
		return false
	if not rally.call.judges_the_landing:
		return false
	return rally.crossed_the_net


## Who, if anybody, asks for the review. The side the call went against, if they have a
## review left and they believe in it enough to spend one.
func challenger(rally: Rally) -> Sides.Team:
	if not reviewable(rally):
		return Sides.Team.NONE

	var lost := Sides.opponent(rally.point_goes_to())
	if lost == Sides.Team.NONE or remaining(lost) <= 0:
		return Sides.Team.NONE

	var wrong := rally.verdict() == Rally.Verdict.WRONG
	var chance := 0.0
	if wrong:
		chance = WRONGED_BASE + rally.visibility() * WRONGED_PER_VISIBILITY
	else:
		# Right call, and they think it was not. Only on the close ones — nobody spends a
		# review on a shuttle that was plainly a metre out.
		var certainty := clampf(absf(rally.margin) / DOUBT_RANGE, 0.0, 1.0)
		chance = MISTAKEN_MOST * (1.0 - certainty)

	if lost == watching:
		chance += WATCHING_YOU

	return lost if randf() < chance else Sides.Team.NONE


## Spends the review, unless it was a good one. A challenge that overturns the call is
## given back, which is what makes a player with one review left still dangerous.
func settle(team: Sides.Team, overturned: bool) -> void:
	if overturned:
		return
	left[team] = maxi(0, remaining(team) - 1)
