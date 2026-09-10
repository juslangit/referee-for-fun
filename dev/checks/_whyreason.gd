extends Node

## Does every fall in reputation come with a reason, and does any of them give the
## truth away?
##
## Two separate questions, and the second is the one worth a scene of its own. The
## whole game rests on the player never being told whether a call was right, so a
## sentence that leaks it would not fail anything — it would simply make the game less
## interesting, quietly, in a way no other check looks at. So the wording is asserted
## here against a list of words that could only appear if a reason had started
## describing the landing rather than the room.

## Words no reason may contain. Matched whole, so "in front of everybody" is fine and
## "that was in" would not be.
const NEVER_SAYS := [
	"wrong", "right", "correct", "incorrect", "truth", "true", "actually",
	"margin", "centimetre", "centimetres", "cm", "mistake", "error", "lie",
	"landed", "inside", "outside",
]


func _ready() -> void:
	var bad := 0
	bad += _every_charge_explains_itself()
	bad += _no_reason_gives_the_truth_away()
	bad += _recovery_says_nothing()
	print("")
	if bad == 0:
		print("every fall has a reason, and none of them says whether you were right")
	else:
		print("%d PROBLEM(S)" % bad)
	get_tree().quit()


## Every route that charges the umpire must leave a sentence behind. A charge with no
## reason puts the meter up with an empty panel beside it, which reads as a bug.
func _every_charge_explains_itself() -> int:
	print("every charge leaves a reason")
	var bad := 0

	var cases := {
		"a plainly wrong call": func(s: Suspicion) -> float:
			return s.register_judgement(Rally.Verdict.WRONG, 0.8, -1.0, 1.0, 0.5),
		"a wrong call echoing the line judge": func(s: Suspicion) -> float:
			return s.register_judgement(Rally.Verdict.WRONG, 0.6, -1.0, 1.0, 0.5, true),
		"a wrong call overruling the line judge": func(s: Suspicion) -> float:
			return s.register_judgement(Rally.Verdict.WRONG, 0.6, -1.0, 1.0, 0.5, false, true),
		"a correct call, overruling": func(s: Suspicion) -> float:
			return s.register_judgement(Rally.Verdict.CORRECT, 0.0, 0.0, 1.0, 0.5, false, true),
		"a correct call, dithered over": func(s: Suspicion) -> float:
			return s.register_judgement(Rally.Verdict.CORRECT, 0.0, 0.0, 1.0, 9.0),
		"a service court error invented": func(s: Suspicion) -> float:
			return s.register_service_court(false, true),
		"a service court error missed": func(s: Suspicion) -> float:
			return s.register_service_court(true, false),
		"a yellow card for nothing": func(s: Suspicion) -> float:
			return s.register_card(Sides.Team.RED, false),
		"a red card for nothing": func(s: Suspicion) -> float:
			return s.register_card(Sides.Team.RED, true),
		"caught on review": func(s: Suspicion) -> float:
			return s.register_review_judgement(0.7, -1.0, true),
	}

	for name: String in cases:
		var s := Suspicion.new()
		var charge: float = cases[name].call(s)
		var ok := charge > 0.0 and not s.last_reason.strip_edges().is_empty()
		if not ok:
			bad += 1
		print("   %-38s charge %+.3f  %s%s" % [
			name, charge, s.last_reason, "" if ok else "   <-- NO REASON"])
	return bad


## The pattern is the most expensive thing in the file and the hardest for a player to
## work out on their own, so it must be the sentence that wins when it is running.
func _no_reason_gives_the_truth_away() -> int:
	print("")
	print("no reason says whether the call was right")
	var bad := 0
	var said: Array[String] = []

	var s := Suspicion.new()
	# Lean hard one way, then keep going that way, to bring the pattern line out.
	for i in 6:
		s.register_judgement(Rally.Verdict.WRONG, 0.7, -1.0, 1.0, 0.5)
		if not said.has(s.last_reason):
			said.append(s.last_reason)

	print("   six wrong calls, all the same way, said:")
	for reason: String in said:
		print("      %s" % reason)
		bad += _check_wording(reason)
	# The pattern is the most expensive thing in the file and the only one a player
	# cannot read off the noise in the hall, so it must be what a run of one-way calls
	# actually says. If this stops holding, the note has gone back to describing single
	# calls and the game has lost the lesson it most wants to teach.
	if not said.has(Suspicion.WHY_PATTERN % "RED"):
		print("   <-- six one-way lies never produced the pattern line")
		bad += 1

	# And every constant, not only the ones this scene happened to trigger.
	for text: String in [
		Suspicion.WHY_HESITATED, Suspicion.WHY_OVERRULED,
		Suspicion.WHY_PATTERN % "RED", Suspicion.WHY_ROOM, Suspicion.WHY_ECHOED,
		Suspicion.WHY_CARD, Suspicion.WHY_FALSE_SERVICE,
		Suspicion.WHY_MISSED_SERVICE, Suspicion.WHY_REVIEW,
	]:
		bad += _check_wording(text)

	if bad == 0:
		print("   all %d clean" % 9)
	return bad


func _check_wording(text: String) -> int:
	var words := text.to_lower().replace(",", " ").replace(".", " ").split(" ", false)
	for word: String in words:
		if NEVER_SAYS.has(word.trim_suffix("'s")):
			print("   LEAKS \"%s\":  %s" % [word, text])
			return 1
	return 0


## A number going up must leave nothing behind, or the next fall would borrow it.
func _recovery_says_nothing() -> int:
	print("")
	print("a rise leaves no reason lying about")
	var s := Suspicion.new()
	s.register_judgement(Rally.Verdict.WRONG, 0.8, -1.0, 1.0, 0.5)
	var after_a_lie := s.last_reason
	s.register_judgement(Rally.Verdict.CORRECT, 0.0, 0.0, 1.0, 0.5)
	var after_honesty := s.last_reason
	print("   after a lie      \"%s\"" % after_a_lie)
	print("   after an honest call  \"%s\"" % after_honesty)
	if after_honesty.is_empty():
		return 0
	print("   <-- a correct call left the old sentence in place")
	return 1
