class_name CallType
extends RefCounted

## One thing an umpire is allowed to say.
##
## Calls are described as data rather than written as branches in a big match
## statement, because badminton has a long rulebook and all of it is eventually
## going in: service faults, lets, net touches, carries, double hits, obstruction,
## and misconduct cards. Every one of those is a new way to cheat, and none of them
## should require rewriting how calls work.

## What a call does to the rally.
enum Outcome {
	## The side that hit the shuttle wins the rally.
	POINT_TO_STRIKER,
	## The side that received it wins the rally.
	POINT_TO_RECEIVER,
	## Nobody wins. The point is played again.
	REPLAY,
}

## Short name used in code and saved data.
var id: StringName

## What the player sees on screen.
var label: String

## What the umpire announces out loud.
var announcement: String

## What this call does to the rally.
var outcome: Outcome

## Whether this call is a claim about where the shuttle landed.
##
## Only line calls can be checked against the recorded landing. A service fault or a
## net touch is a claim about something else entirely, and each of those will need
## its own recorded truth before the game can tell whether the umpire lied about it.
var judges_the_landing := false

## For a line call, what it asserts: true means "the shuttle was in".
var asserts_in := false

## How seriously a wrong call of this kind is taken, before any weighting for how
## obvious it was. A fabricated card is a far bigger deal than a generous line call.
var severity := 1.0


func _init(
	call_id: StringName,
	call_label: String,
	call_announcement: String,
	call_outcome: Outcome
) -> void:
	id = call_id
	label = call_label
	announcement = call_announcement
	outcome = call_outcome
