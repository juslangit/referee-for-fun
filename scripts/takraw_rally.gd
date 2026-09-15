class_name TakrawRally
extends BeachRally

## What really happened in one sepak takraw rally, and what the referee said about it.
##
## Built on the beach rally, because the shape of the truth is the same: where the ball came
## down, whether a blocker touched it on its way out, and the faults a person committed while
## it was in the air. What sepak takraw adds is **who may use which part of their body, and
## where the serving side's feet are** — and every one of those is judged in an instant, with
## nothing left on the floor to look at afterwards.
##
## The faults are ISTAF's (Law of the Game 2024, Law 11):
##
## - **Service fault**: the tekong's standing foot leaves the floor before the kick, or steps
##   out of the service circle. In doubles, the server touches the back line or steps in.
## - **Inside fault**: an inside player lifts a foot, or steps on their quarter circle or the
##   centre line, while the ball is thrown. In doubles, the server's partner moves or raises
##   their arms before the serve.
## - **Arm**: the ball touches an arm or a hand. The one rule everybody knows and the one that
##   is hardest to see, because the arms are out for balance on every kick.
## - **Net**: any part of the body or kit touches the net, a post or the referee's chair.
## - **Crossing**: a body goes into the other court over or under the net, other than on the
##   follow-through of a kick.
## - **Four touches**: a side plays the ball more than three times.

## How plainly each fault happened, 0 (nobody else could tell) to 1 (the whole hall saw it).
var service_fault_visibility := 0.0
var inside_fault := false
var inside_fault_visibility := 0.0

## Who touched the ball with an arm, and who played it a fourth time. These are about a
## side rather than about the server, so they carry the team.
var arm_toucher := Sides.Team.NONE
var four_toucher := Sides.Team.NONE

## How plain a net touch or a crossing was. The body at the net is right in front of the
## referee's chair, so these are rarely subtle.
const NET_VISIBILITY := 0.62
const CROSSING_VISIBILITY := 0.48
const FOUR_TOUCHES_VISIBILITY := 0.72


func record_landing(point: Vector3, defending: Sides.Team) -> void:
	landing_point = point
	receiving = defending
	was_in = TakrawSpec.is_in(point)
	margin = TakrawSpec.margin(point)
	is_settled = true


## A fault stops the rally the moment it happens, so everything the ball did afterwards never
## legally occurred. The serve comes first because it happens first.
func rightful_winner() -> Sides.Team:
	if foot_fault or inside_fault:
		return Sides.opponent(served_by)
	if net_toucher != Sides.Team.NONE:
		return Sides.opponent(net_toucher)
	if centre_line_crosser != Sides.Team.NONE:
		return Sides.opponent(centre_line_crosser)
	if arm_toucher != Sides.Team.NONE:
		return Sides.opponent(arm_toucher)
	if four_toucher != Sides.Team.NONE:
		return Sides.opponent(four_toucher)
	if was_in:
		return struck_by
	return struck_by if was_touched else receiving


func _the_claimed_fault_happened() -> bool:
	if call == null:
		return false
	match call.id:
		&"service_fault":
			return foot_fault and served_by == call_against
		&"inside_fault":
			return inside_fault and served_by == call_against
		&"arm":
			return arm_toucher != Sides.Team.NONE and arm_toucher == call_against
		&"net_touch":
			return net_toucher != Sides.Team.NONE and net_toucher == call_against
		&"crossing":
			return centre_line_crosser != Sides.Team.NONE and centre_line_crosser == call_against
		&"four_touches":
			return four_toucher != Sides.Team.NONE and four_toucher == call_against
	return super()


## Which fault decided the rally, if one did, and how plainly it happened.
func _the_fault() -> Dictionary:
	if foot_fault:
		return {"id": &"service_fault", "seen": service_fault_visibility}
	if inside_fault:
		return {"id": &"inside_fault", "seen": inside_fault_visibility}
	if net_toucher != Sides.Team.NONE:
		return {"id": &"net_touch", "seen": NET_VISIBILITY}
	if centre_line_crosser != Sides.Team.NONE:
		return {"id": &"crossing", "seen": CROSSING_VISIBILITY}
	if arm_toucher != Sides.Team.NONE:
		return {"id": &"arm", "seen": handling_visibility}
	if four_toucher != Sides.Team.NONE:
		return {"id": &"four_touches", "seen": FOUR_TOUCHES_VISIBILITY}
	return {}


## What a wrong call cost, by how plainly the truth happened.
##
## A fault that happened and was waved through — the referee called the landing instead — is
## priced by how visible that fault was, not by where the ball came down. The beach rally
## prices it by the margin, which would make ignoring a blatant arm touch free whenever the
## ball happened to land near a line.
func visibility() -> float:
	if call == null:
		return 0.0
	var fault := _the_fault()
	if not fault.is_empty() and not call.judges_conduct and verdict() == Rally.Verdict.WRONG:
		return float(fault["seen"])
	# Calling the right fault against the wrong side is as plain as the fault itself.
	if call.judges_conduct and not fault.is_empty() and call.id == fault["id"] \
			and not _the_claimed_fault_happened():
		return maxf(0.5, float(fault["seen"]))
	return super()


func what_really_happened() -> String:
	if foot_fault:
		return "SERVICE FAULT BY %s" % Sides.label(served_by)
	if inside_fault:
		return "%s MOVED BEFORE THE SERVE" % Sides.label(served_by)
	if net_toucher != Sides.Team.NONE:
		return "%s TOUCHED THE NET" % Sides.label(net_toucher)
	if centre_line_crosser != Sides.Team.NONE:
		return "%s CROSSED INTO THE OTHER COURT" % Sides.label(centre_line_crosser)
	if arm_toucher != Sides.Team.NONE:
		return "THE BALL HIT A %s ARM" % Sides.label(arm_toucher)
	if four_toucher != Sides.Team.NONE:
		return "%s PLAYED IT FOUR TIMES" % Sides.label(four_toucher)
	if was_in:
		return "IT WAS IN BY %s" % Rally.distance_words(margin)
	if was_touched:
		return "IT WENT OUT OFF A %s BLOCK" % Sides.label(receiving)
	return "IT WAS OUT BY %s" % Rally.distance_words(margin)


func describe() -> String:
	var fault := _the_fault()
	return "landed %s (%.3f m %s the line)%s%s -> %s, called %s, %s" % [
		"IN" if was_in else "OUT",
		absf(margin),
		"inside" if margin >= 0.0 else "outside",
		"  touched (%.2f)" % touch_visibility if was_touched else "  clean",
		"  fault %s" % fault["id"] if not fault.is_empty() else "",
		Sides.label(rightful_winner()),
		call.label if call != null else "nothing",
		"CORRECT" if verdict() == Rally.Verdict.CORRECT else "WRONG",
	]
