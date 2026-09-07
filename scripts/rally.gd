class_name Rally
extends RefCounted

## One rally: what actually happened, and what the umpire said happened.
##
## Those are two separate things and this class keeps them separate on purpose. The
## truth is written down the moment the shuttle lands. The call is written down
## afterwards, when the player decides what to say. Comparing the two is the entire
## game, so nothing is allowed to collapse them into one value.
##
## The player must never see the truth. Nothing that draws to the screen may read
## `describe()`, `was_in`, or `margin`.

## How far outside the line a shuttle has to land before an umpire calling it IN
## looks ridiculous. Used to turn a distance into how visible a wrong call was.
##
## Three quarters of a metre is roughly the point at which everyone in the hall can
## see it without needing to be near the line. Anything past that is equally absurd,
## so it caps there.
const BLATANT_MARGIN := 0.75

## How visible a let called over a completed rally is. Not measured from the
## landing, because a let is not a claim about where the shuttle went — it is a
## claim that something interfered, and everyone can see that nothing did.
const LET_VISIBILITY := 0.35

enum Verdict {
	## The player has not said anything yet.
	NO_CALL,
	## The call matches what really happened.
	CORRECT,
	## The call contradicts what really happened.
	WRONG,
	## The call is not a claim about the landing, so the landing cannot judge it.
	UNVERIFIABLE,
}

# --- the truth -----------------------------------------------------------------

## Where the shuttle touched the floor.
var landing_point := Vector3.ZERO

## Whether that point was inside the court.
var was_in := false

## How far it was from the nearest line. Positive is inside, negative is outside.
## This decides how obvious a lie would be, not whether it was a lie.
var margin := 0.0

## Whether the shuttle has landed yet.
var is_settled := false

## Which side hit the shuttle. If it lands in, they win the rally.
var struck_by := Sides.Team.NONE

## Whether this rally is being played as doubles, which widens the court.
var doubles := true

# --- what the umpire said ------------------------------------------------------

## The call the player made, once they have made one.
var call: CallType = null


func _init(striker := Sides.Team.NONE, is_doubles := true) -> void:
	struck_by = striker
	doubles = is_doubles


## Called the moment the shuttle lands. After this the truth is fixed.
func record_landing(point: Vector3) -> void:
	landing_point = point
	was_in = CourtSpec.is_in(point, doubles)
	margin = CourtSpec.margin(point, doubles)
	is_settled = true


## Called when the player finally says something.
func record_call(made: CallType) -> void:
	call = made


## Who the rally was awarded to, according to the call that was actually made.
func point_goes_to() -> Sides.Team:
	if call == null:
		return Sides.Team.NONE
	match call.outcome:
		CallType.Outcome.POINT_TO_STRIKER:
			return struck_by
		CallType.Outcome.POINT_TO_RECEIVER:
			return Sides.opponent(struck_by)
		_:
			return Sides.Team.NONE


## Who should have won the rally, if the truth had been told.
func rightful_winner() -> Sides.Team:
	if not is_settled:
		return Sides.Team.NONE
	return struck_by if was_in else Sides.opponent(struck_by)


func verdict() -> Verdict:
	if call == null:
		return Verdict.NO_CALL
	if not call.judges_the_landing:
		return Verdict.UNVERIFIABLE
	return Verdict.CORRECT if call.asserts_in == was_in else Verdict.WRONG


## How plainly visible the wrongdoing was, from 0 to 1.
##
## This is the difference between getting away with it and not. A shuttle two
## centimetres out, called in, is almost invisible — nobody in the hall can be sure.
## The same call on a shuttle a metre out is an outrage. The game has to be able to
## tell those apart, or every lie would cost the same and there would be no skill in
## choosing which ones to tell.
func visibility() -> float:
	match verdict():
		Verdict.WRONG:
			return clampf(absf(margin) / BLATANT_MARGIN, 0.0, 1.0)
		Verdict.UNVERIFIABLE:
			# A let called over a rally that plainly finished is its own kind of
			# obvious, and does not depend on where the shuttle landed.
			return LET_VISIBILITY if is_settled else 0.0
		_:
			return 0.0


## How much this call should cost the umpire: how visible it was, weighted by how
## seriously this kind of call is taken.
func deception() -> float:
	if call == null:
		return 0.0
	return visibility() * call.severity


## Whether the call changed who won the rally.
func changed_the_result() -> bool:
	if call == null or not is_settled:
		return false
	return point_goes_to() != rightful_winner()


## A one-line description of the truth, for our own testing only. Nothing that
## reaches the player's screen may ever call this.
func describe() -> String:
	if not is_settled:
		return "rally still in play"
	var text := "%s by %.3f m at (%.2f, %.2f)" % [
		"IN" if was_in else "OUT",
		absf(margin),
		landing_point.x,
		landing_point.z,
	]
	if call != null:
		text += "  |  called %s -> %s (visibility %.2f)" % [
			call.label,
			Verdict.keys()[verdict()],
			visibility(),
		]
	return text
