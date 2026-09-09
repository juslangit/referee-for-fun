class_name TennisRally
extends RefCounted

## What really happened in one tennis point, and what the umpire said about it.
##
## Tennis puts more between the umpire and the point than any other sport in this game,
## because a point does not begin with one serve. It begins with a first serve, and if
## that misses there is a second, and if that misses too the point is over without a
## rally — so **the umpire is making calls before the point has properly started**, and
## the price of each one depends on which serve it was.
##
## A fault on the first serve costs the server nothing but a second chance. The same
## call on the second serve is the point. That asymmetry is not a detail: a bent umpire
## who wants to help somebody calls their opponent's second serves out, and one who
## wants to be careful about it calls first serves instead.

## Verdicts are Rally.Verdict, deliberately, rather than an enum of this class's own.
##
## Every sport in this game hands `verdict() as int` to Suspicion, which reads it back as
## a Rally.Verdict — so a class with its own enum in a different order silently reports
## every wrong call as a correct one. That is not a hypothetical: BeachRally had exactly
## that, ordered CORRECT, WRONG, NO_CALL, and for a fortnight neither volleyball charged
## anything at all for a lie. The cast is silent and the compiler cannot help.

## Above this many metres past a line, nobody in the building is in any doubt.
const BLATANT_MARGIN := 0.55

## What a fabricated fault costs before any weighting. Nothing happened at all.
const FABRICATION_VISIBILITY := 0.62

# --- where it came down ---------------------------------------------------------

var landing_point := Vector3.ZERO
var was_in := false
var margin := 0.0

## Whether the singles or the doubles lines are live.
var doubles := false

## The side that hit it last, and the side it was heading to.
var struck_by := Sides.Team.NONE
var receiving := Sides.Team.NONE

# --- the serve ------------------------------------------------------------------

## Whether the point is still in its service, and which serve it is: 1 or 2.
var is_a_serve := false
var serve_number := 1

## Whether the serve actually landed in the correct box. A serve that misses is a
## fault, and two of them in a row is the point.
var serve_was_good := false

## Whether the serve clipped the net cord on its way over.
##
## The one call in tennis decided by a sound. If a serve touches the tape and still
## lands good it is a let and is played again; if it touches and misses it is simply a
## fault. Nobody in the stand can be sure they heard it. The umpire is a metre away.
var clipped_the_cord := false
var cord_visibility := 0.0

## The server's foot on or over the baseline at contact.
var foot_fault := false
var foot_fault_visibility := 0.0

# --- during the point -----------------------------------------------------------

## The ball bounced twice before anybody reached it, and who lost it by that.
var not_up_by := Sides.Team.NONE

## A player or their racket touched the net while the ball was live.
var net_toucher := Sides.Team.NONE

## Somebody hit the ball before it had crossed to their side.
var reached_over_by := Sides.Team.NONE

## How plainly each of those read. They happen fast and close, which is where the lies
## in this game live.
var incident_visibility := 0.0

var is_settled := false

## What the line judge on that line said, if this venue has any. The spine writes these
## on before the call is priced, and agreeing with a judge who has just got it wrong is
## the cheapest lie available in any sport in this game.
var line_judge_called := false
var line_judge_said_in := false

# --- what the umpire said -------------------------------------------------------

var call: CallType = null
var call_against := Sides.Team.NONE
var seconds_to_call := 0.0


func record_landing(point: Vector3, defending: Sides.Team) -> void:
	landing_point = point
	receiving = defending
	was_in = TennisSpec.is_in(point, doubles)
	margin = TennisSpec.margin(point, doubles)
	is_settled = true


## A serve is judged against a different set of lines from every other ball, so it is
## recorded separately: `into` is the sign of the receiver's half and `court` the sign
## of the service box it was aimed at.
##
## `was_in` and `margin` then mean "was the serve good" and "by how much", because that
## is the only question anybody is asking about a serve. Measuring a serve against the
## court instead would report a ball a centimetre past the service line as five metres
## inside the baseline — the most obviously good call of the match, and a fault.
func record_serve_landing(point: Vector3, defending: Sides.Team,
		into: float, court: float) -> void:
	landing_point = point
	receiving = defending
	is_a_serve = true
	serve_was_good = TennisSpec.is_a_good_serve(point, into, court)
	was_in = serve_was_good
	margin = TennisSpec.serve_margin(point, into, court)
	is_settled = true


func record_call(made: CallType, against := Sides.Team.NONE) -> void:
	call = made
	call_against = against


## Who the point goes to, given what the umpire said.
##
## A tennis call does not always award a point, and that is the whole difference between
## this sport and the other three. A fault called on a **first** serve costs the server
## a serve and nothing else, and a let costs nobody anything — so both of those come
## back as NOBODY, and the match plays the delivery again rather than scoring it.
func point_goes_to() -> Sides.Team:
	if call == null:
		return Sides.Team.NONE
	if call.outcome == CallType.Outcome.REPLAY:
		return Sides.Team.NONE
	if is_a_serve and serve_number == 1 and calls_a_service_fault():
		return Sides.Team.NONE
	match call.outcome:
		CallType.Outcome.POINT_TO_STRIKER:
			return struck_by
		CallType.Outcome.POINT_TO_RECEIVER:
			return receiving
		CallType.Outcome.POINT_AGAINST_THE_OFFENDER:
			return Sides.opponent(call_against)
		_:
			return Sides.Team.NONE


## Whether what the umpire said amounts to "that serve was a fault".
##
## Two different calls say it: OUT, which is a claim about the ball, and FOOT FAULT,
## which is a claim about the server's feet. They cost the same thing, which is why they
## are asked together rather than separately.
func calls_a_service_fault() -> bool:
	if call == null or not is_a_serve:
		return false
	if call.id == &"foot_fault":
		return call_against == struck_by
	return call.judges_the_landing and not call.asserts_in


## What the umpire's call means for the next delivery, which is a separate question
## from who won the point. These are read by the match rather than by the pricing: the
## **call** decides what happens next, not the truth, which is the point of the game.
func call_means_replay() -> bool:
	return call != null and call.outcome == CallType.Outcome.REPLAY


func call_means_a_second_serve() -> bool:
	return is_a_serve and serve_number == 1 and calls_a_service_fault()


## Who should have had it.
##
## In the order the rules apply. A let wipes the point out before anything else can be
## said about it; a foot fault happened before the ball was struck; and only then does
## what the ball did matter.
func rightful_winner() -> Sides.Team:
	if is_a_serve and clipped_the_cord and serve_was_good:
		# A let. Nobody wins it, and the calling code replays the serve.
		return Sides.Team.NONE
	if foot_fault:
		return _fault_outcome()
	if net_toucher != Sides.Team.NONE:
		return Sides.opponent(net_toucher)
	if reached_over_by != Sides.Team.NONE:
		return Sides.opponent(reached_over_by)
	if not_up_by != Sides.Team.NONE:
		return Sides.opponent(not_up_by)

	if is_a_serve:
		if serve_was_good:
			# The serve was good and the point went on; whatever the ball did later
			# decides it in the ordinary way.
			return struck_by if was_in else receiving
		return _fault_outcome()

	return struck_by if was_in else receiving


## What a service fault costs, which depends entirely on which serve it was.
func _fault_outcome() -> Sides.Team:
	# A fault on the first serve costs a second serve rather than the point, so nobody
	# wins it yet. On the second it is a double fault and the point is gone.
	if serve_number >= 2:
		return receiving
	return Sides.Team.NONE


## Whether this point has to be played again from the start.
func is_a_let() -> bool:
	return is_a_serve and clipped_the_cord and serve_was_good


## Whether the official has publicly contradicted the line judge, or hidden behind them.
func overrules_line_judge() -> bool:
	if call == null or not call.judges_the_landing or not line_judge_called:
		return false
	return call.asserts_in != line_judge_said_in


func echoes_line_judge() -> bool:
	if call == null or not call.judges_the_landing or not line_judge_called:
		return false
	return call.asserts_in == line_judge_said_in


func verdict() -> Rally.Verdict:
	if call == null:
		return Rally.Verdict.NO_CALL
	# A let is not a call among others: it wipes the point out before anything else can
	# be said about it. Anything other than LET on a serve that clipped the cord and
	# landed good is wrong, and stating that here matters — on a *first* serve both a
	# denied let and an honest fault come back as NOBODY, so comparing outcomes alone
	# would score taking a man's first serve off him as correct.
	if is_a_let():
		return Rally.Verdict.CORRECT if call.id == &"let" else Rally.Verdict.WRONG
	# A fault is right only if that offence happened and the right side did it.
	if call.judges_conduct:
		return Rally.Verdict.CORRECT if _the_claimed_fault_happened() else Rally.Verdict.WRONG
	return Rally.Verdict.CORRECT if point_goes_to() == rightful_winner() else Rally.Verdict.WRONG


func _the_claimed_fault_happened() -> bool:
	if call == null:
		return false
	match call.id:
		&"let":
			return is_a_let()
		&"foot_fault":
			return foot_fault and struck_by == call_against
		&"not_up":
			return not_up_by != Sides.Team.NONE and not_up_by == call_against
		&"touched_net":
			return net_toucher != Sides.Team.NONE and net_toucher == call_against
		&"through_the_net":
			return reached_over_by != Sides.Team.NONE and reached_over_by == call_against
	return true


## How plainly wrong the call was.
func visibility() -> float:
	if call == null:
		return 0.0

	if call.judges_conduct and not _the_claimed_fault_happened():
		return FABRICATION_VISIBILITY * call.severity

	# A let denied, or invented. Judged by how plainly the cord was clipped, which for
	# a graze is nothing at all — this is tennis's version of the block touch.
	if call.id == &"let" or (is_a_let() and call.judges_the_landing):
		return cord_visibility

	if call.judges_conduct:
		if call.id == &"foot_fault":
			return foot_fault_visibility
		return incident_visibility

	if call.judges_the_landing:
		return clampf(absf(margin) / BLATANT_MARGIN, 0.0, 1.0)

	return 0.5


func changed_the_result() -> bool:
	return verdict() == Rally.Verdict.WRONG and point_goes_to() != rightful_winner()


func describe() -> String:
	var what := "serve %d" % serve_number if is_a_serve else "rally ball"
	return "%s landed %s (%.3f m %s)%s -> %s, called %s, %s" % [
		what,
		"IN" if was_in else "OUT",
		absf(margin),
		"inside" if margin >= 0.0 else "outside",
		"  clipped the cord" if clipped_the_cord else "",
		Sides.label(rightful_winner()),
		call.label if call != null else "nothing",
		"CORRECT" if verdict() == Rally.Verdict.CORRECT else "WRONG",
	]
