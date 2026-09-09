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

	# --- and three that happen before the rally has properly begun ---------------
	#
	# A service fault is not like the four above. Those are things that go wrong in the
	# middle of a rally, in a scramble, when nobody was quite watching. A serve is the
	# one moment in badminton when everything stops, both players are still, and the
	# whole hall is looking at one person doing one thing slowly. So these are the most
	# *watched* offences in the game and among the easiest to see — which is exactly
	# why a real match gives them their own official, sitting at the side of the court
	# with nothing else to do.

	## The shuttle was struck above 1.15 m. Since 2018 that is a fixed height rather
	## than the server's waist, precisely so that it can be judged rather than argued.
	SERVICE_TOO_HIGH,
	## The shaft of the racket was not pointing downwards at the moment of contact.
	SERVICE_RACKET_UP,
	## A foot moved, or left the floor, between the start of the service and the hit.
	SERVICE_FEET,
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


## Whether this is one of the three things that can go wrong with a serve.
func is_a_service_fault() -> bool:
	return kind in [Kind.SERVICE_TOO_HIGH, Kind.SERVICE_RACKET_UP, Kind.SERVICE_FEET]


## What the umpire would announce.
static func label(what: Kind) -> String:
	match what:
		Kind.NET_TOUCH: return "NET TOUCH"
		Kind.CARRY: return "CARRY"
		Kind.DOUBLE_HIT: return "DOUBLE HIT"
		Kind.OBSTRUCTION: return "OBSTRUCTION"
		Kind.SERVICE_TOO_HIGH: return "SERVICE ABOVE 1.15"
		Kind.SERVICE_RACKET_UP: return "SERVICE RACKET UP"
		Kind.SERVICE_FEET: return "SERVICE FOOT MOVED"
		_: return "NOTHING"


## A short description of what the hall would have seen, used for the reckoning and
## for our own testing. Never shown while the rally is live.
func describe() -> String:
	if not happened():
		return "nothing happened"
	return "%s by %s, %.2f visible" % [label(kind), Sides.label(by), visibility]
