class_name TableTennisCallBook
extends RefCounted

## Everything the table tennis umpire can say.
##
## Two things make this book different from the other four. There is **no second serve**:
## a serve that misses is the point, so the service calls here are as expensive as any
## call in the game rather than a warning. And the umpire is **alone** — table tennis has
## no line judges at all, because at this size nobody else is close enough to be useful.
## Every truth in the sport passes through one person, which is the most dangerous
## arrangement in this whole project for anybody minded to lie.

static var _calls: Dictionary = {}


static func _build() -> void:
	if not _calls.is_empty():
		return

	var ball_in := CallType.new(
		&"in", "IN", "In.", CallType.Outcome.POINT_TO_STRIKER)
	ball_in.judges_the_landing = true
	ball_in.asserts_in = true

	var ball_out := CallType.new(
		&"out", "OUT", "Out.", CallType.Outcome.POINT_TO_RECEIVER)
	ball_out.judges_the_landing = true
	ball_out.asserts_in = false

	# The one decided by a sound, as it is in tennis and beach volleyball.
	#
	# A serve that touches the net and lands good is played again. It changes the score
	# by nothing, which is what makes it the cheapest lie available and the reason it is
	# priced by how plainly the net moved rather than by what the point was worth.
	var let_call := CallType.new(
		&"let", "LET", "Let. Serve again.", CallType.Outcome.REPLAY)
	let_call.judges_conduct = true
	let_call.severity = 0.9

	var faults: Array[CallType] = [
		# The strictest law in any of these five sports: flat open palm, 16 cm of throw,
		# and visible to the receiver the whole way. The receiver cannot see a hidden
		# serve by definition — only the umpire can.
		_fault(&"illegal_service", "ILLEGAL SERVICE", "Illegal service.", 1.1),
		_fault(&"double_bounce", "TWO BOUNCES", "Two bounces.", 1.0),
		_fault(&"touched_the_table", "TOUCHED THE TABLE", "Free hand on the table.", 1.0),
		_fault(&"volley", "STRUCK IN THE AIR", "Struck before the bounce.", 1.0),
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
## The let is left out for the same reason it is in tennis — it takes the point away
## from nobody, so asking the umpire to choose a player to accuse of one makes no sense.
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
