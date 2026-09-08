class_name Suspicion
extends RefCounted

## How much the hall doubts the umpire.
##
## This is the price of cheating, and it is deliberately never shown to the player.
## There is no bar on screen. You find out how much trouble you are in by reading the
## room — the crowd, the players, a coach getting to his feet — which means you are
## always guessing, exactly as you would be in the chair.
##
## The interesting rule here is the second one. A wrong call costs something on its
## own, but a wrong call that leans the same way as all your previous wrong calls
## costs far more. **It is not being wrong that gets an umpire caught. It is being
## wrong in the same direction every time.** An umpire who makes mistakes both ways
## looks incompetent. One whose mistakes all help the same team looks bought.

signal level_changed(level: float)
signal mood_changed(mood: Mood)
signal warning_issued()
signal removed_from_match()

## What a single visibly wrong call costs, at its most obvious.
const IMMEDIATE_WEIGHT := 0.45

## What it costs on top of that when the call leans the way your errors always lean.
## Larger than the immediate cost, because the pattern is the damning part.
const PATTERN_WEIGHT := 0.90

## What a wrong call costs when the line judge said the same thing.
##
## Standing behind the official who is standing right there halves it. This is the
## most useful thing the line judge does for a bent umpire: wait for them to get one
## wrong, agree with them, and the blame is shared.
const COVER_FROM_LINE_JUDGE := 0.5

## What a wrong call costs when it contradicts the line judge. The hall has just
## watched two officials disagree, and yours is the one that decided the rally.
const OVERRULE_PENALTY := 1.6

## What overruling the line judge costs even when the umpire turns out to be right.
## Small, but never nothing — the hall cannot see that you were right.
const OVERRULE_ON_ITS_OWN := 0.03

## How long the umpire may take before the hall starts wondering what the delay is
## for. Generous — a second or two to be sure of a close one is normal.
const THINKING_TIME := 2.5

## What each further second of standing there costs, and the most one call's worth of
## dithering can cost on its own.
const HESITATION_PER_SECOND := 0.02
const MAX_HESITATION := 0.12

## What a card costs. A card is not a judgement that can be right or wrong — nothing
## happened — so it is priced directly instead of through a verdict. A yellow is an
## insult; a red takes a point off somebody for no reason at all, in front of a hall
## that watched them do nothing.
const YELLOW_CARD_VISIBILITY := 0.70
const RED_CARD_VISIBILITY := 0.95
const YELLOW_CARD_SEVERITY := 1.2
const RED_CARD_SEVERITY := 1.9

## How much trust one correct call wins back. Small on purpose: it takes a long run
## of honest calls to undo a bad one, so cheating has to be paced.
const RECOVERY_PER_CORRECT_CALL := 0.012

## How much the memory of your leaning fades with each correct call.
const LEAN_FADE_PER_CORRECT_CALL := 0.02

## Where the tournament referee is called, and where you are taken off the match.
const WARNING_LEVEL := 0.80
const REMOVAL_LEVEL := 1.0

## Where a call lands when it was bad enough to end the match but the umpire had not
## been warned yet. See the clamp in register() for why this exists.
const HELD_AT_WARNING := REMOVAL_LEVEL - 0.001

enum Mood {
	## Nobody is paying the umpire any attention. This is what a good umpire gets.
	SETTLED,
	## Something is off, and people have started noticing each other noticing.
	MURMURING,
	## Open complaint. Booing, shouting, players querying calls.
	RESTLESS,
	## The hall has decided you are bent, and is telling you so.
	HOSTILE,
	## The tournament referee has been called. One more and you are gone.
	WARNED,
	## Removed from the match.
	REMOVED,
}

## How closely this particular hall is watching. A school gym barely notices; an
## international final examines everything. Everything suspicion charges is
## multiplied by it, so the same lie is nearly free at the bottom of the ladder and
## career-ending at the top.
var scrutiny := 1.0

var level := 0.0

## The highest this ever got during the match. The level itself comes back down as the
## umpire referees straight, which is right for the crowd and wrong for anybody keeping
## notes — the appointments panel remembers the worst it saw, not how it ended.
var peak := 0.0

## Which way your wrong calls lean. Negative favours RED, positive favours BLUE.
var lean := 0.0

var mood := Mood.SETTLED
var has_been_warned := false
var is_removed := false

## Every wrong call so far, for the end-of-match reckoning.
var wrong_calls := 0
var stolen_rallies := 0


## Feeds one completed call in, and returns how much suspicion it cost.
func register(rally: Rally) -> float:
	if is_removed:
		return 0.0

	var verdict := rally.verdict()

	var dithering := hesitation_cost(rally.seconds_to_call)

	if verdict == Rally.Verdict.CORRECT:
		var conspicuous := dithering
		if rally.overrules_line_judge():
			conspicuous += OVERRULE_ON_ITS_OWN
		if conspicuous <= 0.0:
			_recover()
			_settle_mood()
			return 0.0
		conspicuous *= scrutiny
		level = clampf(level + conspicuous, 0.0, REMOVAL_LEVEL)
		level_changed.emit(level)
		_settle_mood()
		return conspicuous

	if verdict == Rally.Verdict.NO_CALL:
		return 0.0

	var visibility := rally.visibility()
	if visibility <= 0.0:
		return 0.0

	wrong_calls += 1
	if rally.changed_the_result():
		stolen_rallies += 1

	# Which way this particular call leaned, and whether that is the same way the
	# umpire has been leaning all match.
	var direction := _direction_favoured(rally)
	var reinforcing := maxf(0.0, direction * lean)

	var gain := visibility * (IMMEDIATE_WEIGHT + reinforcing * PATTERN_WEIGHT) * rally.call.severity

	if rally.echoes_line_judge():
		gain *= COVER_FROM_LINE_JUDGE
	elif rally.overrules_line_judge():
		gain = gain * OVERRULE_PENALTY + OVERRULE_ON_ITS_OWN

	gain = (gain + dithering) * scrutiny
	var target := level + gain

	# Nobody is thrown off the court without being told once. A call outrageous
	# enough to clear the whole scale in one go still stops at the warning, so the
	# umpire always gets their one clear chance to referee straight — and the
	# removal, when it comes, is for what they did *after* being told.
	if level < WARNING_LEVEL and target >= REMOVAL_LEVEL:
		target = HELD_AT_WARNING

	level = clampf(target, 0.0, REMOVAL_LEVEL)
	lean = clampf(lean + direction * visibility, -1.0, 1.0)

	level_changed.emit(level)
	_settle_mood()
	return gain


## What being caught on a review costs, on top of what the wrong call already cost.
##
## Deliberately heavy, and with a floor. Everything else in this system is priced by how
## visible the mistake was, because an umpire can hide behind a shuttle that was only two
## centimetres out — nobody in the hall can be sure. A review removes that. The landing
## has been put on a screen at a size nobody can argue with, so the two-centimetre lie and
## the blatant one are now equally undeniable; what still differs is how brazen it looks.
##
## At the national championship (scrutiny 1.25) a narrow lie caught on review costs about
## 0.38 and a flagrant one about 0.94. One of the latter puts an umpire at the warning by
## itself, which is the intended weight: the hall has watched you do it.
const CAUGHT_ON_REVIEW := 0.30
const CAUGHT_PER_VISIBILITY := 0.45

## And what surviving one is worth. Small — being right is the job, not an achievement —
## but it is the only thing in the game that buys trust back faster than time does.
const VINDICATED := 0.05


## Folds a review's outcome into the umpire's standing. Called after register(), which has
## already priced the call itself.
func register_review(rally: Rally, overturned: bool) -> float:
	if is_removed:
		return 0.0

	if not overturned:
		# The hall asked, and the answer was that the umpire was right. Nothing is proved
		# about the rest of the match, but the room settles.
		level = maxf(0.0, level - VINDICATED)
		lean = move_toward(lean, 0.0, LEAN_FADE_PER_CORRECT_CALL)
		level_changed.emit(level)
		_settle_mood()
		return -VINDICATED

	var gain := (CAUGHT_ON_REVIEW + rally.visibility() * CAUGHT_PER_VISIBILITY) * scrutiny
	var target := level + gain

	# The same mercy as anywhere else: nobody is removed without having been told once.
	if level < WARNING_LEVEL and target >= REMOVAL_LEVEL:
		target = HELD_AT_WARNING

	level = clampf(target, 0.0, REMOVAL_LEVEL)
	lean = clampf(lean + _direction_favoured(rally) * 0.5, -1.0, 1.0)
	level_changed.emit(level)
	_settle_mood()
	return gain


## What standing there thinking about it costs.
##
## Nothing at all for the first couple of seconds, then a steady drip. It is capped,
## because hesitation is a bad look rather than a crime — the aim is to make a long
## silence uncomfortable, not to end careers with it.
static func hesitation_cost(seconds: float) -> float:
	var dithering := seconds - THINKING_TIME
	if dithering <= 0.0:
		return 0.0
	return minf(dithering * HESITATION_PER_SECOND, MAX_HESITATION)


## A card handed out for nothing. Priced like a wrong call, and leaning the same way
## as the rest of your errors makes it far worse — as it should, because a card is
## the least deniable thing an umpire can do.
func register_card(against: Sides.Team, red: bool) -> float:
	if is_removed or against == Sides.Team.NONE:
		return 0.0

	wrong_calls += 1
	if red:
		stolen_rallies += 1

	var seen := RED_CARD_VISIBILITY if red else YELLOW_CARD_VISIBILITY
	var weight := RED_CARD_SEVERITY if red else YELLOW_CARD_SEVERITY

	# A card leans against whoever received it, which is to say it helps the other.
	var direction := 1.0 if Sides.opponent(against) == Sides.Team.BLUE else -1.0
	var reinforcing := maxf(0.0, direction * lean)

	var gain := seen * (IMMEDIATE_WEIGHT + reinforcing * PATTERN_WEIGHT) * weight * scrutiny
	var target := level + gain
	if level < WARNING_LEVEL and target >= REMOVAL_LEVEL:
		target = HELD_AT_WARNING

	level = clampf(target, 0.0, REMOVAL_LEVEL)
	lean = clampf(lean + direction * seen, -1.0, 1.0)
	level_changed.emit(level)
	_settle_mood()
	return gain


func _recover() -> void:
	if level <= 0.0 and is_zero_approx(lean):
		return
	level = maxf(0.0, level - RECOVERY_PER_CORRECT_CALL)
	lean = move_toward(lean, 0.0, LEAN_FADE_PER_CORRECT_CALL)
	level_changed.emit(level)


## +1 if the call helped BLUE, -1 if it helped RED, 0 if it helped nobody.
func _direction_favoured(rally: Rally) -> float:
	var gained := rally.point_goes_to()
	var deserved := rally.rightful_winner()
	if gained == deserved or gained == Sides.Team.NONE:
		# A let takes the rally away from whoever had earned it, so it leans against
		# them rather than towards anyone.
		if rally.call != null and rally.call.outcome == CallType.Outcome.REPLAY:
			return -1.0 if deserved == Sides.Team.BLUE else 1.0
		return 0.0
	return 1.0 if gained == Sides.Team.BLUE else -1.0


func _settle_mood() -> void:
	peak = maxf(peak, level)

	var next := mood

	if level >= REMOVAL_LEVEL:
		next = Mood.REMOVED
	elif level >= WARNING_LEVEL:
		next = Mood.WARNED
	elif level >= 0.55:
		next = Mood.HOSTILE
	elif level >= 0.33:
		next = Mood.RESTLESS
	elif level >= 0.14:
		next = Mood.MURMURING
	else:
		next = Mood.SETTLED

	# The tournament referee is only ever called once, and once the hall has turned
	# hostile it does not politely go back to murmuring because of one good call.
	if next == mood:
		return
	mood = next
	mood_changed.emit(mood)

	if mood == Mood.WARNED and not has_been_warned:
		has_been_warned = true
		warning_issued.emit()
	elif mood == Mood.REMOVED and not is_removed:
		is_removed = true
		removed_from_match.emit()
