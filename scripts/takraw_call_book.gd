class_name TakrawCallBook
extends RefCounted

## Everything the sepak takraw referee can say.
##
## Same shape as the volleyball books, and the same rule decides what belongs in it: a call
## goes here when it has a truth to be checked against and a verdict on the rally. The words
## are ISTAF's where ISTAF has words — the referee's calls are spoken, not whistled, and there
## is no whistle in regu at all (Law of the Game 2024; the Thai referee manual's call list).

static var _calls: Dictionary = {}


static func _build() -> void:
	if not _calls.is_empty():
		return

	var ball_in := CallType.new(&"in", "IN", "In. Point.", CallType.Outcome.POINT_TO_STRIKER)
	ball_in.judges_the_landing = true
	ball_in.asserts_in = true

	var ball_out := CallType.new(&"out", "OUT", "Out.", CallType.Outcome.POINT_TO_RECEIVER)
	ball_out.judges_the_landing = true
	ball_out.asserts_in = false

	# Out, but off the blocker's back or legs: their point lost, not the attacker's.
	var touch := CallType.new(
		&"touch", "TOUCH", "Touched the block. Point.", CallType.Outcome.POINT_TO_STRIKER)
	touch.judges_the_touch = true
	touch.severity = 1.1

	var faults: Array[CallType] = [
		_fault(&"service_fault", "SERVICE FAULT", "Fault. The server's foot.", 0.9),
		_fault(&"inside_fault", "INSIDE FAULT", "Fault. Moved before the serve.", 0.8),
		_fault(&"arm", "ARM", "Fault. Arm.", 1.1),
		_fault(&"net_touch", "NET", "Fault. Net.", 1.0),
		_fault(&"crossing", "CROSSING", "Fault. Into the other court.", 0.9),
		_fault(&"four_touches", "FOUR TOUCHES", "Fault. Four touches.", 1.0),
	]

	for call in [ball_in, ball_out, touch] + faults:
		_calls[call.id] = call


static func _fault(id: StringName, label: String, announcement: String,
		severity: float) -> CallType:
	var call := CallType.new(id, label, announcement, CallType.Outcome.POINT_AGAINST_THE_OFFENDER)
	call.judges_conduct = true
	call.severity = severity
	return call


## Every call that accuses somebody, in the order they appear on the fault panel: the serve
## first, because it happens first.
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
