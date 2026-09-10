class_name VolleyRally
extends BeachRally

## What really happened in one indoor volleyball rally.
##
## Everything BeachRally records is still true here — where the ball came down, whether
## a blocker touched it on the way out, how many times a side hit it, whether a set was
## clean — because those are the same sport. What indoor adds is a whole second kind of
## truth that has nothing to do with the ball at all:
##
##   **Where six people were standing at the moment of service**, and whether that
##   matched an order fixed at the start of the set. Nobody can see this by watching the
##   ball. The referee either kept track or did not.
##
## That is the difference between the two versions of this sport, from the chair. Beach
## asks you to judge things you can see and cannot be sure about. Indoor asks you to
## judge things that are perfectly certain if you were paying attention twenty seconds
## ago, and unknowable if you were not.

## The side standing in the wrong rotational order when the serve was struck.
var rotation_fault_by := Sides.Team.NONE

## The side whose wrong player served. A different fault from standing wrongly, and the
## commoner one: a lineup can be correct and still have the wrong person hit the ball.
var wrong_server_by := Sides.Team.NONE

## The side whose back-row player took off in front of the attack line and hit the ball
## down from above the tape. The one positional fault that happens in mid-air, in front
## of everybody, rather than quietly before the whistle.
var back_row_attack_by := Sides.Team.NONE

## The libero broke one of the three things a libero may not do: attack above the net,
## serve, or hand-set from the front zone for somebody to attack.
var libero_fault_by := Sides.Team.NONE
var libero_did := &""


## Where the ball came down, judged against the indoor court.
##
## This override is not a detail. `record_landing` is inherited from the beach rally,
## and the beach court is 16 by 8 against this one's 18 by 9 — so without it every
## landing in the sport would be measured against a rectangle a metre too small in each
## direction, and a referee calling correctly would be told they had lied. It is the
## same shape as the bug that judged doubles serves by the back line.
func record_landing(point: Vector3, defending: Sides.Team) -> void:
	landing_point = point
	receiving = defending
	was_in = VolleySpec.is_in(point)
	margin = VolleySpec.margin(point)
	is_settled = true


## Who should have won the point.
##
## The order matters and is the order the rules apply in. A service fault happened
## before the ball was struck, so it beats everything the ball did afterwards; a
## positional fault is judged at the moment of service, so it comes next; and the ball's
## own story only decides anything if the rally was legal enough to have one.
func rightful_winner() -> Sides.Team:
	if wrong_server_by != Sides.Team.NONE:
		return Sides.opponent(wrong_server_by)
	if rotation_fault_by != Sides.Team.NONE:
		return Sides.opponent(rotation_fault_by)
	if libero_fault_by != Sides.Team.NONE:
		return Sides.opponent(libero_fault_by)
	if back_row_attack_by != Sides.Team.NONE:
		return Sides.opponent(back_row_attack_by)
	return super()


func _the_claimed_fault_happened() -> bool:
	if call == null:
		return false
	match call.id:
		&"rotation_fault":
			return rotation_fault_by != Sides.Team.NONE and rotation_fault_by == call_against
		&"wrong_server":
			return wrong_server_by != Sides.Team.NONE and wrong_server_by == call_against
		&"back_row_attack":
			return back_row_attack_by != Sides.Team.NONE \
				and back_row_attack_by == call_against
		&"libero_fault":
			return libero_fault_by != Sides.Team.NONE and libero_fault_by == call_against
	return super()


## How plainly wrong the call was.
##
## The positional faults are priced differently from everything else in either sport,
## and deliberately so. A line call is a matter of millimetres nobody can be sure about;
## a rotation is a matter of record. Six people were either standing in the right order
## or they were not, and half the hall — both benches, certainly — knows which.
##
## So **inventing a rotation fault is the least deniable thing a referee can do**, and
## missing one is a good deal more forgivable than missing a ball that bounced a metre
## out in front of everybody.
const POSITIONAL_VISIBILITY := 0.72


func visibility() -> float:
	if call == null:
		return 0.0

	# Claiming one that did not happen. There is no close call to hide behind: a lineup
	# is a matter of record, and both benches have it written down.
	if call.judges_position:
		if _the_claimed_fault_happened():
			return 0.0
		return POSITIONAL_VISIBILITY * call.severity

	# Saying anything else at all when a positional fault is what decided the rally.
	#
	# This has to be priced as a missed rotation and not as whatever the ball did,
	# for the same reason a denied touch is priced by the deflection: how far out the
	# ball happened to land says nothing about how visible the real fault was. A
	# rotation fault missed while the ball drops a metre out would otherwise read as
	# a blatant lie about the line, and one missed on a ball that landed cleanly in
	# would read as nothing at all — both wrong, and in opposite directions.
	if _a_positional_fault_happened():
		return POSITIONAL_VISIBILITY

	return super()


## Whether anything about where people were standing decided this rally.
func _a_positional_fault_happened() -> bool:
	return (wrong_server_by != Sides.Team.NONE
		or rotation_fault_by != Sides.Team.NONE
		or libero_fault_by != Sides.Team.NONE
		or back_row_attack_by != Sides.Team.NONE)


## The four positional faults come before anything the ball did, as they do in
## `rightful_winner`; after them the rally is the beach rally's story.
func what_really_happened() -> String:
	if wrong_server_by != Sides.Team.NONE:
		return "THE WRONG %s PLAYER SERVED" % Sides.label(wrong_server_by)
	if rotation_fault_by != Sides.Team.NONE:
		return "%s WERE OUT OF ROTATION" % Sides.label(rotation_fault_by)
	if libero_fault_by != Sides.Team.NONE:
		return "LIBERO FAULT BY %s" % Sides.label(libero_fault_by)
	if back_row_attack_by != Sides.Team.NONE:
		return "BACK-ROW ATTACK BY %s" % Sides.label(back_row_attack_by)
	return super()


func describe() -> String:
	var extra := ""
	if wrong_server_by != Sides.Team.NONE:
		extra = "  wrong server (%s)" % Sides.label(wrong_server_by)
	elif rotation_fault_by != Sides.Team.NONE:
		extra = "  out of rotation (%s)" % Sides.label(rotation_fault_by)
	elif libero_fault_by != Sides.Team.NONE:
		extra = "  libero %s (%s)" % [libero_did, Sides.label(libero_fault_by)]
	elif back_row_attack_by != Sides.Team.NONE:
		extra = "  back row attack (%s)" % Sides.label(back_row_attack_by)
	return super() + extra
