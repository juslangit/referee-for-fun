class_name WorstCalls
extends RefCounted

## The calls from one match most worth showing again, kept with everything needed to show
## them after the rally they came from has gone.
##
## "Worst" means most plainly wrong, measured by the same `visibility()` that prices every
## penalty in the game. Not the most expensive and not the most recent: the replay is there
## to show the player what the hall saw, and visibility is exactly that number. When two are
## equally plain, the one that changed who won the rally goes first.
##
## Everything is copied out of the rally the moment the call is made, rather than kept as a
## reference to it. The rally is replaced by the next serve, and a review can sit between
## the call and the point — reading a rally after an await is the crash this project has
## already had once.

## How many are kept. Three is a countdown; five would be a highlights package with the
## result screen waiting behind it.
const KEPT := 3

var moments: Array[Dictionary] = []


## Keeps this call if it was wrong and is among the worst so far.
func consider(rally, path: PackedVector3Array) -> void:
	if rally == null or rally.call == null:
		return
	if rally.verdict() != Rally.Verdict.WRONG:
		return

	var gave: Sides.Team = rally.point_goes_to()
	var deserved: Sides.Team = rally.rightful_winner()
	var truth: String = rally.what_really_happened()
	moments.append({
		"path": path,
		"landing": rally.landing_point,
		"seen": float(rally.visibility()),
		"changed": bool(rally.changed_the_result()),
		"called": call_words(rally),
		"truth": truth,
		"said_line": what_you_said(rally, gave),
		"truth_line": what_was_true(truth, deserved),
	})
	moments.sort_custom(_plainer)
	while moments.size() > KEPT:
		moments.pop_back()


func _plainer(a: Dictionary, b: Dictionary) -> bool:
	if not is_equal_approx(a["seen"], b["seen"]):
		return a["seen"] > b["seen"]
	return a["changed"] and not b["changed"]


func is_empty() -> bool:
	return moments.is_empty()


## The single worst call of the match, or an empty dictionary if every call was right.
func worst() -> Dictionary:
	return {} if moments.is_empty() else moments[0]


## The order they are shown in: the least bad of the three first, the worst last.
func countdown() -> Array:
	var shown := moments.duplicate()
	shown.reverse()
	return shown


## The call as it was made, naming whoever it was made against.
static func call_words(rally) -> String:
	if rally.call_against == Sides.Team.NONE:
		return rally.call.label
	return "%s ON %s" % [rally.call.label, Sides.label(rally.call_against)]


## The top line of the replay caption: what you said, and what it did.
static func what_you_said(rally, gave: Sides.Team) -> String:
	var said := "YOU CALLED  %s" % call_words(rally)
	if gave != Sides.Team.NONE:
		return "%s   ·   POINT %s" % [said, Sides.label(gave)]
	# A call that awarded nothing is not "point to nobody". In tennis a fault on a first
	# serve is a second serve; everywhere else it means the rally was played again.
	if rally.has_method("call_means_a_second_serve") and rally.call_means_a_second_serve():
		return "%s   ·   SECOND SERVE" % said
	return "%s   ·   PLAYED AGAIN" % said


## The bottom line: what really happened, and whose point it should have been.
static func what_was_true(truth: String, deserved: Sides.Team) -> String:
	if deserved == Sides.Team.NONE:
		return truth
	return "%s   ·   %s'S POINT" % [truth, Sides.label(deserved)]
