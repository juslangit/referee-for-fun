class_name VolleyCallBook
extends RefCounted

## Everything the indoor referee can say.
##
## Beach volleyball's book, plus four calls that only exist because six people rotate.
## Those four are a different kind of call from anything else in this game: their truth
## is a matter of record rather than of judgement, so they are the only calls a referee
## can be *certain* about — and, for the same reason, the only ones a referee can be
## certainly wrong about.

static var _calls: Dictionary = {}


static func _build() -> void:
	if not _calls.is_empty():
		return

	var ball_in := CallType.new(
		&"in", "IN", "In. Point.", CallType.Outcome.POINT_TO_STRIKER)
	ball_in.judges_the_landing = true
	ball_in.asserts_in = true

	var ball_out := CallType.new(
		&"out", "OUT", "Out.", CallType.Outcome.POINT_TO_RECEIVER)
	ball_out.judges_the_landing = true
	ball_out.asserts_in = false

	var touch := CallType.new(
		&"touch", "TOUCH", "Touched. Point.", CallType.Outcome.POINT_TO_STRIKER)
	touch.judges_the_touch = true
	touch.severity = 1.1

	var faults: Array[CallType] = [
		_fault(&"net_touch", "NET TOUCH", "Fault. Touched the net.", 1.0),
		_fault(&"centre_line", "CENTRE LINE", "Fault. Over the line.", 0.9),
		_fault(&"four_hits", "FOUR HITS", "Fault. Four touches.", 1.0),
		_fault(&"double_contact", "DOUBLE", "Fault. Double contact.", 0.9),
		_fault(&"lift", "LIFT", "Fault. Held.", 0.9),
		_fault(&"foot_fault", "FOOT FAULT", "Fault. Foot over the line.", 0.8),
	]

	# The four that need a lineup kept in somebody's head.
	var positional: Array[CallType] = [
		_positional(&"rotation_fault", "OUT OF ROTATION",
			"Fault. Out of rotation.", 1.3),
		_positional(&"wrong_server", "WRONG SERVER",
			"Fault. Wrong server.", 1.2),
		_positional(&"back_row_attack", "BACK ROW ATTACK",
			"Fault. Back row attack.", 1.1),
		_positional(&"libero_fault", "LIBERO",
			"Fault. Illegal action by the libero.", 1.1),
	]

	for call in [ball_in, ball_out, touch] + faults + positional:
		_calls[call.id] = call


static func _fault(id: StringName, label: String, announcement: String,
		severity: float) -> CallType:
	var call := CallType.new(
		id, label, announcement, CallType.Outcome.POINT_AGAINST_THE_OFFENDER)
	call.judges_conduct = true
	call.severity = severity
	return call


## A claim about where somebody was standing. Heavier than a ball fault of the same
## shape, because there is no close call to hide behind: a lineup is written down.
static func _positional(id: StringName, label: String, announcement: String,
		severity: float) -> CallType:
	var call := _fault(id, label, announcement, severity)
	call.judges_position = true
	return call


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
