extends Node

## Checks the rest of the rulebook: whether an offence is judged the way a line call
## is, what inventing one costs, and what a card costs. No physics — these are all
## questions about the rules, not about flight.

func _ready() -> void:
	_judging()
	_cards()
	get_tree().quit()


func _judging() -> void:
	print("--- judging an offence ---")
	print("%-46s %-11s %-6s %s" % ["situation", "verdict", "seen", "point to"])

	_case("net touch by RED, called on RED", Incident.Kind.NET_TOUCH, Sides.Team.RED, 0.60,
		&"net_touch", Sides.Team.RED)
	_case("net touch by RED, called on BLUE", Incident.Kind.NET_TOUCH, Sides.Team.RED, 0.60,
		&"net_touch", Sides.Team.BLUE)
	_case("net touch by RED, called a carry", Incident.Kind.NET_TOUCH, Sides.Team.RED, 0.60,
		&"carry", Sides.Team.RED)
	_case("nothing happened, net touch invented", Incident.Kind.NONE, Sides.Team.NONE, 0.0,
		&"net_touch", Sides.Team.RED)
	_case("obvious net touch by RED, ignored, called IN", Incident.Kind.NET_TOUCH, Sides.Team.RED, 0.80,
		&"in", Sides.Team.NONE)
	_case("faint carry by RED, ignored, called IN", Incident.Kind.CARRY, Sides.Team.RED, 0.18,
		&"carry_ignored", Sides.Team.NONE)


func _case(
	label: String,
	kind: Incident.Kind,
	by: Sides.Team,
	seen: float,
	call_id: StringName,
	against: Sides.Team
) -> void:
	var rally := Rally.new(Sides.Team.RED, true)
	# Landed comfortably inside, so a call of IN describes the landing correctly.
	rally.record_landing(Vector3(1.0, 0.01, 3.0))
	if kind != Incident.Kind.NONE:
		rally.incident = Incident.new(kind, by, seen, Vector3(1.0, 0.0, 0.5))

	var id := call_id
	if id == &"carry_ignored":
		id = &"in"
	rally.record_call(CallBook.get_call(id), against)

	print("%-46s %-11s %-6.2f %s" % [
		label,
		Rally.Verdict.keys()[rally.verdict()],
		rally.visibility(),
		Sides.label(rally.point_goes_to()),
	])


func _cards() -> void:
	print("\n--- what a card costs ---")
	for red in [false, true]:
		var suspicion := Suspicion.new()
		var events: Array[String] = []
		suspicion.warning_issued.connect(func() -> void: events.append("WARNED"))
		suspicion.removed_from_match.connect(func() -> void: events.append("REMOVED"))
		print("  %s cards, one after another:" % ("RED" if red else "YELLOW"))
		for i in range(4):
			if suspicion.is_removed:
				break
			events.clear()
			var gain := suspicion.register_card(Sides.Team.BLUE, red)
			print("    #%d  +%.3f  level %.3f  lean %+.2f  %-10s %s" % [
				i + 1, gain, suspicion.level, suspicion.lean,
				Suspicion.Mood.keys()[suspicion.mood], " ".join(events)
			])
