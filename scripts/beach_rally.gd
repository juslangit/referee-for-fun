class_name BeachRally
extends RefCounted

## What really happened in one beach volleyball rally, and what the referee said about it.
##
## The same contract as the badminton Rally — the game records the truth, the referee
## records a claim, and the gap between them is what everything downstream is priced on
## — but the truth it holds is a different shape, because the interesting question in
## this sport is not where the ball landed.
##
## **In badminton the truth is small. Here it is invisible.**
##
## A shuttle two centimetres out is a fact nobody in the hall can quite resolve, but it
## is at least a fact about a place, and a camera pointed at that place settles it. A
## block touch is not. The ball leaves the attacker's hand, passes within a few
## centimetres of four outstretched fingers, and lands well outside the court. Whether
## it grazed one of them on the way decides who gets the point, and the only person in
## the building with any claim to know is standing on the stand.
##
## So this rally records two truths rather than one. Where the ball came down, which
## decides IN and OUT as it always has. And whether it was touched, which decides
## whether landing out was the attacker's mistake or the blocker's.

## Verdicts are Rally.Verdict, deliberately, rather than an enum of this class's own.
##
## This file had its own — CORRECT, WRONG, NO_CALL — and the badminton one is ordered
## NO_CALL, CORRECT, WRONG, UNVERIFIABLE. Both volleyballs hand `verdict() as int` to
## Suspicion, which reads it as a Rally.Verdict, so **every wrong call arrived as
## "correct" and every correct one as "no call"**: neither sport ever charged anything
## for a lie at the moment it was told. Two enums that mean the same thing and disagree
## about the numbers are a bug waiting behind every cast, so there is now one.

## Above this the ball plainly deflected — it changed direction, everybody saw it, and
## claiming otherwise is not a close call but a lie. Below it, the referee is genuinely
## the only one who might know.
const OBVIOUS_TOUCH := 0.55

## How far outside the antenna counts as beyond argument. Tighter than the line margin
## because the rod is a fixed object a metre from the referee's face: a ball that misses
## it by half a metre is not a close call to anybody in the stand either.
const BLATANT_ANTENNA := 0.50

## How far outside the lines counts as beyond argument, in metres. A ball landing this
## far out and given IN is the beach equivalent of badminton's blatant margin.
const BLATANT_MARGIN := 1.10

## What a fabricated fault costs before any weighting. Nothing happened at all, so
## there is no close call to hide behind.
const FABRICATION_VISIBILITY := 0.62

# --- where it came down ---------------------------------------------------------

var landing_point := Vector3.ZERO

## Whether the ball landed inside the lines. The line counts as in.
var was_in := false

## How far from the nearest line, in metres. Positive inside, negative outside. This is
## what decides how obvious the truth was, and therefore what lying about it costs.
var margin := 0.0

## Whether it crossed the net inside the antennae. A ball passing outside one is out
## however cleanly it lands, which is the only vertical boundary in the sport.
var inside_the_antennae := true

## How far inside the antenna the ball crossed, in metres. Negative outside. What makes
## this call the referee's and nobody else's is that it is judged **in the air, at the
## net, side on** — there is no mark to walk over and look at afterwards, which is what
## settles every other line in this sport.
var antenna_margin := 0.0

# --- who touched it -------------------------------------------------------------

## The side that last touched the ball before it came down.
var struck_by := Sides.Team.NONE

## The side the ball was heading into — the side defending the half it landed in.
var receiving := Sides.Team.NONE

## Who served. Not the same as `receiving`, and confusing the two is a bug this file
## already had: `receiving` is whoever was defending the *last attack*, which after a
## few exchanges is as likely as not to be the serving side itself. A foot fault is
## about the serve, so it needs the server.
var served_by := Sides.Team.NONE

## Whether a blocker got a finger to it on its way out. **The hidden truth of this
## sport.** Only meaningful when the ball landed outside the court: a touched ball that
## goes out is the blocker's mistake, an untouched one is the attacker's.
var was_touched := false

## How plainly that touch happened, from 0 (a fingernail, nobody could tell) to 1 (a
## clear deflection that changed the ball's direction in front of everybody).
var touch_visibility := 0.0

## How many times the side in possession hit it. Four is a fault.
var contacts := 0

## The ball-handling truth: whether the set that went up was genuinely double-contacted
## or held, and how plainly.
var handling_fault := false
var handling_visibility := 0.0

## Whether the server's foot was over the line at contact.
var foot_fault := false

## Who touched the net, and who put a foot fully under it. Copied off the match when
## the call is made: these are things a person did rather than things the ball did, so
## the match watches for them, but the rally is what has to weigh them.
var net_toucher := Sides.Team.NONE
var centre_line_crosser := Sides.Team.NONE

var is_settled := false

# --- what the line judge said ---------------------------------------------------

## Whether the line judge on that line gave a call, and what it was.
##
## The most useful thing a line judge does for a bent official is stand there and be
## wrong: agree with their mistake and the blame is shared with somebody in plain sight.
## Contradict them and the venue has just watched two officials disagree, with only one
## call deciding the rally.
var line_judge_called := false
var line_judge_said_in := false

# --- what the referee said ------------------------------------------------------

var call: CallType = null
var call_against := Sides.Team.NONE
var seconds_to_call := 0.0


func record_landing(point: Vector3, defending: Sides.Team) -> void:
	landing_point = point
	receiving = defending
	was_in = BeachSpec.is_in(point)
	margin = BeachSpec.margin(point)
	is_settled = true


## Whether the official contradicted the line judge in public.
func overrules_line_judge() -> bool:
	if call == null or not call.judges_the_landing or not line_judge_called:
		return false
	return call.asserts_in != line_judge_said_in


## Whether they simply said what the line judge said. A wrong call made this way is a
## shared mistake rather than a suspicious one.
func echoes_line_judge() -> bool:
	if call == null or not call.judges_the_landing or not line_judge_called:
		return false
	return call.asserts_in == line_judge_said_in


func record_call(made: CallType, against := Sides.Team.NONE) -> void:
	call = made
	call_against = against


## Who the point goes to, given what the referee said. Volleyball is rally-point, so
## every rally scores for somebody.
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


## Who should have had it.
##
## The order here is the order the rules apply in, and it is not arbitrary. A fault
## that happened during the rally beats anything the ball did afterwards, because the
## rally should have stopped when the fault happened — the ball's landing never legally
## occurred. Then the antennae, then the touch, then the line.
func rightful_winner() -> Sides.Team:
	# A fault stops the rally the moment it happens, so everything the ball did
	# afterwards never legally occurred. Only one of these is ever set — see
	# BeachMatch._roll_for_one_fault for why two would be worse than none.
	if foot_fault:
		return Sides.opponent(served_by)
	if net_toucher != Sides.Team.NONE:
		return Sides.opponent(net_toucher)
	if centre_line_crosser != Sides.Team.NONE:
		return Sides.opponent(centre_line_crosser)
	if handling_fault:
		return Sides.opponent(_handler())
	if contacts > 3:
		return Sides.opponent(struck_by)
	if not inside_the_antennae:
		return receiving
	if was_in:
		return struck_by
	# Landed out. Whose mistake that was is the whole question.
	return struck_by if was_touched else receiving


## Which side committed the handling fault — whoever was in possession.
func _handler() -> Sides.Team:
	return struck_by


func verdict() -> Rally.Verdict:
	if call == null:
		return Rally.Verdict.NO_CALL

	# A fault is right only if that offence happened and the right side did it.
	#
	# This cannot be left to the outcome, and that was the first version's mistake.
	# Comparing only who ended up with the point scores an *invented* fault as correct
	# whenever the lie happens to award the rally to the side that deserved it anyway —
	# which for a fault against the losing side is most of the time. Badminton has
	# always guarded this; the beach rally did not, and indoor inherited the gap along
	# with four new calls to make it with.
	if call.judges_conduct:
		return Rally.Verdict.CORRECT if _the_claimed_fault_happened() else Rally.Verdict.WRONG

	return Rally.Verdict.CORRECT if point_goes_to() == rightful_winner() else Rally.Verdict.WRONG


## How plainly wrong the call was, from 0 (nobody could tell) to 1 (the whole venue saw).
##
## Every wrong call in this game is priced by this number, and getting it right for the
## touch is the single most important judgement in the beach sport. A touch call is
## **cheap to lie about when the deflection was slight and ruinous when it was not** —
## which is exactly the real incentive, and the reason a referee under pressure gives
## the marginal ones and not the obvious ones.
func visibility() -> float:
	if call == null:
		return 0.0

	# A fault invented out of nothing. Nobody has to judge a distance: it did not happen.
	if call.judges_conduct and not _the_claimed_fault_happened():
		return FABRICATION_VISIBILITY * call.severity

	# The antenna, claimed or denied. Priced by how far outside the rod the ball went:
	# a hand's width is the referee's word against nobody's, and a metre is a thing the
	# whole beach watched happen.
	if call.id == &"antenna" or (not inside_the_antennae and call.judges_the_landing):
		return clampf(absf(antenna_margin) / BLATANT_ANTENNA, 0.0, 1.0)

	# A touch claimed or denied. What the room could see is the deflection itself.
	if call.judges_the_touch:
		if was_touched:
			# Denying a touch that happened: as visible as the deflection was.
			return touch_visibility
		# Inventing one: the ball flew straight past four fingers and everybody watched
		# it do so. There is a floor under this, because there was nothing there at all.
		return maxf(0.45, 1.0 - touch_visibility)

	if call.judges_the_landing:
		# Saying OUT about a ball that really was out, when the thing that decided the
		# rally was the touch nobody mentioned. The landing was called correctly; the
		# error is the deflection left unsaid, so that is what it is priced by.
		#
		# Pricing this one by the margin — as the first version did — is exactly
		# backwards. A ball that catches a whole hand is pushed *further* out, so the
		# more obvious the deflection, the further from the line it lands. That made a
		# barely-there touch and a blatant one both read as maximum visibility, and one
		# denied touch at a world tour final took a referee straight off the match.
		if not was_in and was_touched and not call.asserts_in:
			return touch_visibility

		# Otherwise the line, priced as it always has been: by how far out it was.
		return clampf(absf(margin) / BLATANT_MARGIN, 0.0, 1.0)

	return 0.5


func _the_claimed_fault_happened() -> bool:
	if call == null:
		return false
	match call.id:
		&"antenna":
			return not inside_the_antennae and struck_by == call_against
		&"four_hits":
			return contacts > 3 and struck_by == call_against
		&"double_contact", &"lift":
			return handling_fault and struck_by == call_against
		&"foot_fault":
			return foot_fault and served_by == call_against
		&"net_touch":
			return net_toucher != Sides.Team.NONE and net_toucher == call_against
		&"centre_line":
			return centre_line_crosser != Sides.Team.NONE \
				and centre_line_crosser == call_against
	# Net touch and centre line are recorded on the match rather than here, and are
	# folded in by the caller before the verdict is taken.
	return true


func changed_the_result() -> bool:
	return verdict() == Rally.Verdict.WRONG and point_goes_to() != rightful_winner()


func describe() -> String:
	return "landed %s (%.3f m %s the line)%s%s -> %s, called %s, %s" % [
		"IN" if was_in else "OUT",
		absf(margin),
		"inside" if margin >= 0.0 else "outside",
		"  touched (%.2f)" % touch_visibility if was_touched else "  clean",
		"  %d contacts" % contacts,
		Sides.label(rightful_winner()),
		call.label if call != null else "nothing",
		"CORRECT" if verdict() == Rally.Verdict.CORRECT else "WRONG",
	]
