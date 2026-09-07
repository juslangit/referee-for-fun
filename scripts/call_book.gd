class_name CallBook
extends RefCounted

## Every call the umpire can currently make.
##
## Three for now. The rest of the badminton rulebook is listed at the bottom of this
## file and will be added here as each one gets something to be judged against —
## adding a call means adding an entry, not changing how calling works.

static var _calls: Dictionary = {}


static func _build() -> void:
	if not _calls.is_empty():
		return

	var shuttle_in := CallType.new(
		&"in",
		"IN",
		"In!",
		CallType.Outcome.POINT_TO_STRIKER
	)
	shuttle_in.judges_the_landing = true
	shuttle_in.asserts_in = true

	var shuttle_out := CallType.new(
		&"out",
		"OUT",
		"Out!",
		CallType.Outcome.POINT_TO_RECEIVER
	)
	shuttle_out.judges_the_landing = true
	shuttle_out.asserts_in = false

	# A let wipes the rally out and replays it. It is the quietest way to cheat in
	# the game: nobody loses a point, so nobody is angry, but a rally the favoured
	# team was losing simply stops having happened.
	var let_call := CallType.new(
		&"let",
		"LET",
		"Let. Play a let.",
		CallType.Outcome.REPLAY
	)
	let_call.severity = 0.6

	for call in [shuttle_in, shuttle_out, let_call]:
		_calls[call.id] = call


static func get_call(id: StringName) -> CallType:
	_build()
	return _calls.get(id)


static func all() -> Array:
	_build()
	return _calls.values()


# Still to come, each needing its own recorded truth before the game can tell
# whether the umpire was lying about it:
#   service fault  — racket head above the hand, shuttle above the waist, feet moving
#   net touch      — player or racket touching the net during play
#   carry / sling  — shuttle held and thrown rather than struck
#   double hit     — two strokes in succession by the same side
#   obstruction    — invading the opponent's side or distracting them
#   wrong court    — serving from or receiving in the wrong service court
#   yellow card    — a warning for misconduct
#   red card       — a fault awarded for misconduct
