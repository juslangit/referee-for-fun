class_name BeachCallBook
extends RefCounted

## Everything the beach referee can say.
##
## Same shape as the badminton book, and the same rule decides what belongs in it: a
## call goes here when it has both a truth to be checked against and a verdict on the
## rally. What is different is the balance of the book. Badminton's calls are nearly all
## about a place — where the shuttle was — and can be settled afterwards by a camera.
## Half of these are about a moment instead, and no camera settles them.

static var _calls: Dictionary = {}


static func _build() -> void:
	if not _calls.is_empty():
		return

	# --- the ball came down ------------------------------------------------------
	var ball_in := CallType.new(
		&"in", "IN", "In. Point.", CallType.Outcome.POINT_TO_STRIKER)
	ball_in.judges_the_landing = true
	ball_in.asserts_in = true

	var ball_out := CallType.new(
		&"out", "OUT", "Out.", CallType.Outcome.POINT_TO_RECEIVER)
	ball_out.judges_the_landing = true
	ball_out.asserts_in = false

	# --- and the call that makes this sport worth refereeing ---------------------
	#
	# TOUCH says: it went out, but you put a finger on it, so it is your point lost
	# and not theirs. The signal is a hand brushed across the fingertips of the other,
	# and it is the most argued-about gesture in the sport.
	var touch := CallType.new(
		&"touch", "TOUCH", "Touched. Point.", CallType.Outcome.POINT_TO_STRIKER)
	touch.judges_the_touch = true
	touch.severity = 1.1

	# --- faults ------------------------------------------------------------------
	var faults: Array[CallType] = [
		_fault(&"net_touch", "NET TOUCH", "Fault. Touched the net.", 1.0),
		_fault(&"centre_line", "CENTRE LINE", "Fault. Under the net.", 0.9),
		_fault(&"four_hits", "FOUR HITS", "Fault. Four touches.", 1.0),
		_fault(&"double_contact", "DOUBLE", "Fault. Double contact.", 0.9),
		_fault(&"lift", "LIFT", "Fault. Held.", 0.9),
		_fault(&"foot_fault", "FOOT FAULT", "Fault. Foot on the line.", 0.8),
	]

	for call in [ball_in, ball_out, touch] + faults:
		_calls[call.id] = call


static func _fault(id: StringName, label: String, announcement: String,
		severity: float) -> CallType:
	var call := CallType.new(
		id, label, announcement, CallType.Outcome.POINT_AGAINST_THE_OFFENDER)
	call.judges_conduct = true
	call.severity = severity
	return call


## Every call that accuses somebody, in the order they appear on the referee's panel.
static func faults() -> Array:
	_build()
	var found := []
	for call in _calls.values():
		if call.judges_conduct:
			found.append(call)
	return found


static func get_call(id: StringName) -> CallType:
	_build()
	return _calls.get(id)


static func all() -> Array:
	_build()
	return _calls.values()


# Still to come:
#   antenna        — the ball passing outside an antenna. The truth is already recorded
#                    on the rally; it needs a signal of its own and a place on the panel.
#   back-row and rotation faults — indoor only, and the reason indoor is the harder of
#                    the two sports to build. Beach has neither.
#
# DOUBLE and LIFT are listed separately here rather than as one "ball handling" call
# because a referee signals them differently — two fingers for a double contact, an
# open palm turned up for a lift — and a player who has been told which one they did
# argues about a different thing. They share a recorded truth and differ only in what
# is claimed about it, which is why both read `handling_fault`.
