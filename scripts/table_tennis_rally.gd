class_name TableTennisRally
extends RefCounted

## What really happened in one table tennis point, and what the umpire said about it.
##
## The sport's own call is the **edge**. A ball that clips the top edge of the table is
## in; one that clips the vertical side a centimetre below it is out. They sound almost
## identical, they happen at twenty metres a second, and the umpire sits level with the
## surface — which makes them the only person in the room with any claim to know. It is
## table tennis's version of the beach block touch, and it is priced the same way: cheap
## to lie about when nobody could tell, ruinous when everybody could.
##
## The second thing worth refereeing here is the **service law**, and it is the strictest
## in any of these five sports. The ball must sit on an open flat palm, be thrown up at
## least 16 cm, and stay visible to the receiver from the moment it leaves the hand. A
## hidden serve is the oldest cheat in the sport and the umpire is the only one placed to
## see it — the receiver, by definition, cannot.

## Verdicts are Rally.Verdict, deliberately. Every sport hands `verdict() as int` to
## Suspicion, which reads it back as one — see BeachRally for what a second enum cost.

## Above this the edge was plain to everybody. Small, because everything in this sport is.
const BLATANT_EDGE := 0.05

## What a fabricated fault costs before any weighting.
const FABRICATION_VISIBILITY := 0.62

# --- where it came down ---------------------------------------------------------

var landing_point := Vector3.ZERO
var was_in := false
var margin := 0.0

## Whether it came down within a hair of the edge, and how plainly it was on rather than
## off. Only meaningful when it did.
var clipped_the_edge := false
var edge_visibility := 0.0

var struck_by := Sides.Team.NONE
var receiving := Sides.Team.NONE
var served_by := Sides.Team.NONE

# --- the serve ------------------------------------------------------------------

## Whether the point is still in its service. There is no second serve in this sport: a
## serve that misses is simply the point, which is why the service law bites so hard.
var is_a_serve := false
var serve_was_good := false

## The serve clipped the net and landed good anyway — a let, played again.
var clipped_the_net := false
var net_visibility := 0.0

## The service law, and which part of it was broken.
var illegal_service := false
var service_visibility := 0.0
var service_fault := &""

# --- during the point -----------------------------------------------------------

var double_bounce_by := Sides.Team.NONE
var touched_the_table_by := Sides.Team.NONE
var volleyed_by := Sides.Team.NONE
var incident_visibility := 0.0

var is_settled := false

## What the line judge said. Table tennis has no line judges — the umpire is close enough
## that nobody else is needed — but the spine writes these on every rally and the pricing
## reads them, so they are here and always say nothing.
var line_judge_called := false
var line_judge_said_in := false

# --- what the umpire said -------------------------------------------------------

var call: CallType = null
var call_against := Sides.Team.NONE
var seconds_to_call := 0.0


func record_landing(point: Vector3, defending: Sides.Team) -> void:
	landing_point = point
	receiving = defending
	was_in = TableTennisSpec.is_in(point)
	margin = TableTennisSpec.margin(point)
	clipped_the_edge = TableTennisSpec.on_the_edge(point)
	if clipped_the_edge:
		# How plainly it was on rather than off: a ball dead on the corner is a coin
		# toss, one two centimetres clear of it is not.
		edge_visibility = clampf(absf(margin) / BLATANT_EDGE, 0.0, 1.0)
	is_settled = true


func record_call(made: CallType, against := Sides.Team.NONE) -> void:
	call = made
	call_against = against


func point_goes_to() -> Sides.Team:
	if call == null:
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


## Who should have had it, in the order the rules apply.
func rightful_winner() -> Sides.Team:
	# A let wipes the point out before anything else can be said about it.
	if is_a_let():
		return Sides.Team.NONE
	if illegal_service:
		return Sides.opponent(served_by)
	if volleyed_by != Sides.Team.NONE:
		return Sides.opponent(volleyed_by)
	if touched_the_table_by != Sides.Team.NONE:
		return Sides.opponent(touched_the_table_by)
	if double_bounce_by != Sides.Team.NONE:
		return Sides.opponent(double_bounce_by)
	if is_a_serve and not serve_was_good:
		return receiving
	return struck_by if was_in else receiving


func is_a_let() -> bool:
	return is_a_serve and clipped_the_net and serve_was_good


func verdict() -> Rally.Verdict:
	if call == null:
		return Rally.Verdict.NO_CALL
	# A let is not a call among others: it takes the point away from nobody, so anything
	# else said about it is wrong however the point would have gone.
	if is_a_let():
		return Rally.Verdict.CORRECT if call.id == &"let" else Rally.Verdict.WRONG
	if call.judges_conduct:
		return Rally.Verdict.CORRECT if _the_claimed_fault_happened() else Rally.Verdict.WRONG
	return Rally.Verdict.CORRECT if point_goes_to() == rightful_winner() else Rally.Verdict.WRONG


func _the_claimed_fault_happened() -> bool:
	if call == null:
		return false
	match call.id:
		&"let":
			return is_a_let()
		&"illegal_service":
			return illegal_service and served_by == call_against
		&"double_bounce":
			return double_bounce_by != Sides.Team.NONE and double_bounce_by == call_against
		&"touched_the_table":
			return (touched_the_table_by != Sides.Team.NONE
				and touched_the_table_by == call_against)
		&"volley":
			return volleyed_by != Sides.Team.NONE and volleyed_by == call_against
	return true


## How plainly wrong the call was.
func visibility() -> float:
	if call == null:
		return 0.0

	if call.judges_conduct and not _the_claimed_fault_happened():
		return FABRICATION_VISIBILITY * call.severity

	if call.id == &"let" or (is_a_let() and call.judges_the_landing):
		return net_visibility

	if call.judges_conduct:
		if call.id == &"illegal_service":
			return service_visibility
		return incident_visibility

	if call.judges_the_landing:
		# The edge, which is the whole sport. A ball on the corner is nobody's to know;
		# one plainly on or plainly off is everybody's.
		if clipped_the_edge:
			return edge_visibility
		return clampf(absf(margin) / (BLATANT_EDGE * 4.0), 0.0, 1.0)

	return 0.5


func overrules_line_judge() -> bool:
	return false


func echoes_line_judge() -> bool:
	return false


func changed_the_result() -> bool:
	return verdict() == Rally.Verdict.WRONG and point_goes_to() != rightful_winner()


func describe() -> String:
	var what := "serve" if is_a_serve else "rally ball"
	return "%s landed %s (%.3f m %s)%s -> %s, called %s, %s" % [
		what,
		"IN" if was_in else "OUT",
		absf(margin),
		"on" if margin >= 0.0 else "off",
		"  ON THE EDGE" if clipped_the_edge else "",
		Sides.label(rightful_winner()),
		call.label if call != null else "nothing",
		"CORRECT" if verdict() == Rally.Verdict.CORRECT else "WRONG",
	]
