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

	var faults: Array[CallType] = [
		_fault(&"net_touch", "NET TOUCH", "Fault. Touched the net.", Incident.Kind.NET_TOUCH, 1.0),
		_fault(&"carry", "CARRY", "Fault. Carried.", Incident.Kind.CARRY, 1.0),
		_fault(&"double_hit", "DOUBLE HIT", "Fault. Double hit.", Incident.Kind.DOUBLE_HIT, 1.0),
		_fault(&"obstruction", "OBSTRUCTION", "Fault. Obstruction.", Incident.Kind.OBSTRUCTION, 1.2),
		# The three service faults. Heavier than a rally fault of the same visibility,
		# because a serve is the one moment when everybody is still and looking at one
		# person: there is nowhere for a wrong call to hide.
		_fault(&"serve_too_high", "SERVICE — ABOVE 1.15", "Fault. Above one fifteen.",
			Incident.Kind.SERVICE_TOO_HIGH, 1.15),
		_fault(&"serve_racket_up", "SERVICE — RACKET UP", "Fault. Racket not down.",
			Incident.Kind.SERVICE_RACKET_UP, 1.15),
		_fault(&"serve_feet", "SERVICE — FOOT MOVED", "Fault. Foot moved.",
			Incident.Kind.SERVICE_FEET, 1.1),
	]

	for call in [shuttle_in, shuttle_out, let_call] + faults:
		_calls[call.id] = call


## A call that accuses one side of an offence. Unlike a line call it is not a claim
## about the shuttle at all, so it is judged against what actually happened in the
## rally — and, crucially, it has to name somebody.
static func _fault(
	id: StringName,
	label: String,
	announcement: String,
	claims: Incident.Kind,
	severity: float
) -> CallType:
	var call := CallType.new(id, label, announcement, CallType.Outcome.POINT_AGAINST_THE_OFFENDER)
	call.judges_conduct = true
	call.claims = claims
	call.severity = severity
	return call


## Every call that accuses somebody of something, in the order they appear on the
## umpire's panel.
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


#
# Two things the umpire can say are deliberately not in this book.
#
# The service court error is one, and it is built — see Arena._call_service_court. It
# is not a call in the sense this file means, because it decides nothing: under Law
# 12.2 the error is corrected and the existing score stands, so there is no Outcome to
# give it. A rally that had one still has to be judged on the line afterwards like any
# other, which is exactly why it cannot *be* the rally's call. It lives outside the
# book and is priced by Suspicion.register_service_court instead.
#
# Yellow and red cards are the other, and for the opposite reason. A card is not a judgement
# about anything that happened — it is a punishment the umpire simply decides to
# hand out — so it has no truth to be checked against and does not belong among the
# calls. Match issues them directly.
#
# So the rule for this file is narrower than "everything an umpire can say": a call
# belongs here when it has both a truth to be checked against and a verdict on the
# rally. A service court error has the first and not the second; a card has neither.
