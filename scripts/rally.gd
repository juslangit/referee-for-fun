class_name Rally
extends RefCounted

## What actually happened in one rally.
##
## This is the truth, and the player never sees it. The game records where the
## shuttle landed, works out whether that was in or out, and keeps it. The player
## then says whatever they like. Comparing the two is the entire game, so the truth
## is written down first and kept somewhere the player's call cannot reach.

## Where the shuttle touched the floor.
var landing_point := Vector3.ZERO

## Whether that point was inside the court.
var was_in := false

## How far it was from the nearest line. Positive is inside, negative is outside.
## This is what decides how obvious a lie would be, not whether it was a lie.
var margin := 0.0

## Whether a shuttle has landed yet in this rally.
var is_settled := false

## Whether this rally is being played as doubles, which widens the court.
var doubles := true


func _init(is_doubles := true) -> void:
	doubles = is_doubles


## Called the moment the shuttle lands. After this, the truth is fixed.
func record_landing(point: Vector3) -> void:
	landing_point = point
	was_in = CourtSpec.is_in(point, doubles)
	margin = CourtSpec.margin(point, doubles)
	is_settled = true


## A one-line description of the truth, for logs and for our own testing only.
## Nothing that reaches the player's screen may ever call this.
func describe() -> String:
	if not is_settled:
		return "rally still in play"
	return "%s by %.3f m at (%.2f, %.2f)" % [
		"IN" if was_in else "OUT",
		absf(margin),
		landing_point.x,
		landing_point.z,
	]
