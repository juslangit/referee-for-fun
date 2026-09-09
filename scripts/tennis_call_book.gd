class_name TennisCallBook
extends RefCounted

## Everything the tennis umpire can say.
##
## The shape is familiar — a line call, some faults, and one call about a thing nobody
## else could have noticed — but the weights are tennis's own. A fault here is often not
## a lost point at all: on a first serve it costs a second serve, which is why the same
## call is cheap early in a point and enormous late in one.

static var _calls: Dictionary = {}


static func _build() -> void:
	if not _calls.is_empty():
		return

	var ball_in := CallType.new(
		&"in", "IN", "In. Play on.", CallType.Outcome.POINT_TO_STRIKER)
	ball_in.judges_the_landing = true
	ball_in.asserts_in = true

	var ball_out := CallType.new(
		&"out", "OUT", "Out.", CallType.Outcome.POINT_TO_RECEIVER)
	ball_out.judges_the_landing = true
	ball_out.asserts_in = false

	# The one decided by a sound.
	#
	# A serve that touches the tape and still lands good is played again. Nobody in the
	# stand can be sure they heard it; the umpire is a metre from the net. It is
	# tennis's version of the block touch, and the only call in the sport that takes a
	# point away from nobody.
	var let_call := CallType.new(
		&"let", "LET", "Let. First serve.", CallType.Outcome.REPLAY)
	let_call.judges_conduct = true
	let_call.severity = 0.9

	var faults: Array[CallType] = [
		_fault(&"foot_fault", "FOOT FAULT", "Foot fault.", 1.0),
		_fault(&"not_up", "NOT UP", "Not up.", 1.0),
		_fault(&"touched_net", "TOUCHED THE NET", "Touched the net.", 1.0),
		_fault(&"through_the_net", "THROUGH THE NET", "Through the net.", 1.1),
	]

	for call in [ball_in, ball_out, let_call] + faults:
		_calls[call.id] = call


static func _fault(id: StringName, label: String, announcement: String,
		severity: float) -> CallType:
	var call := CallType.new(
		id, label, announcement, CallType.Outcome.POINT_AGAINST_THE_OFFENDER)
	call.judges_conduct = true
	call.severity = severity
	return call


## What goes on the fault panel: the things you point at somebody for.
##
## The net cord is deliberately not among them. It is a conduct call in the sense that
## it judges an event rather than a landing, so it came back from a plain
## `judges_conduct` filter — and the panel then asked the umpire to point at a player
## and accuse them of a let, which is not a thing anybody does. A let takes the point
## away from nobody. It has the L key of its own and that is the whole of it.
static func faults() -> Array:
	_build()
	var found := []
	for call in _calls.values():
		if call.judges_conduct and call.id != &"let":
			found.append(call)
	return found


static func get_call(id: StringName) -> CallType:
	_build()
	return _calls.get(id)


static func all() -> Array:
	_build()
	return _calls.values()


# Still to come:
#   hindrance — a player putting their opponent off. Left out on purpose for now: it has
#               no physical trace whatsoever, so it would need a manifestation invented
#               for it rather than observed, and the block touch already occupies that
#               ground better.
