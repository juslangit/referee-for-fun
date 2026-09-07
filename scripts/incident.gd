class_name Incident
extends RefCounted

## Something one side did wrong during a rally, other than putting the shuttle out.
##
## Every incident has to satisfy two conditions or it has no business existing. It
## needs a **truth**, so the game knows whether the umpire is lying about it. And it
## needs to be **visible**, so the player has something to judge. An offence nobody
## can see is not a decision, it is a coin toss, and the game already has a perfectly
## good source of those in the line calls.
##
## So each kind below is given something to look at: the net shakes, the shuttle
## sticks to the racket for a moment, it gets struck twice, a player lunges over the
## net and back. How plainly that read is what `visibility` records, and it is the
## same currency the line calls use — the difference between getting away with a lie
## and not.

enum Kind {
	NONE,
	## A player or their racket touched the net while the shuttle was in play.
	NET_TOUCH,
	## The shuttle was caught and slung rather than struck.
	CARRY,
	## The same side hit it twice in succession.
	DOUBLE_HIT,
	## A player reached over the net, or otherwise got in the opponent's way.
	OBSTRUCTION,
}

## What happened.
var kind := Kind.NONE

## Which side did it. They lose the rally if it is called.
var by := Sides.Team.NONE

## How plainly the hall saw it, from 0 to 1. A racket brushing the net cord is
## nearly invisible; a player falling into the net is not.
var visibility := 0.0

## Where on court it happened, for anything that wants to point at it.
var at := Vector3.ZERO


func _init(what := Kind.NONE, who := Sides.Team.NONE, how_visible := 0.0, where := Vector3.ZERO) -> void:
	kind = what
	by = who
	visibility = how_visible
	at = where


func happened() -> bool:
	return kind != Kind.NONE


## What the umpire would announce.
static func label(what: Kind) -> String:
	match what:
		Kind.NET_TOUCH: return "NET TOUCH"
		Kind.CARRY: return "CARRY"
		Kind.DOUBLE_HIT: return "DOUBLE HIT"
		Kind.OBSTRUCTION: return "OBSTRUCTION"
		_: return "NOTHING"


## A short description of what the hall would have seen, used for the reckoning and
## for our own testing. Never shown while the rally is live.
func describe() -> String:
	if not happened():
		return "nothing happened"
	return "%s by %s, %.2f visible" % [label(kind), Sides.label(by), visibility]
