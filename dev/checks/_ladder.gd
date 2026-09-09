extends Node

## Feeds hand-built rallies straight into Suspicion, with no shuttle and no physics,
## so the curve can be read directly. Fast enough to run on every change.

func _ready() -> void:
	_ladder("the same lie, over and over, always helping RED", 1.00, true)
	_ladder("mistakes that go both ways", 1.00, false)
	_ladder("tiny lies, always helping RED", 0.03, true)
	get_tree().quit()


func _ladder(title: String, metres_out: float, always_same_way: bool) -> void:
	print("\n--- %s  (%.2f m outside the line) ---" % [title, metres_out])
	print("%-4s %-8s %-7s %-7s %-10s %s" % ["#", "gain", "level", "lean", "mood", "event"])

	var suspicion := Suspicion.new()
	var events: Array[String] = []
	suspicion.warning_issued.connect(func() -> void: events.append("WARNING ISSUED"))
	suspicion.removed_from_match.connect(func() -> void: events.append("REMOVED"))

	for i in range(8):
		if suspicion.is_removed:
			break
		events.clear()

		# Alternate who is helped when the umpire is merely incompetent.
		var striker := Sides.Team.RED
		if not always_same_way and i % 2 == 1:
			striker = Sides.Team.BLUE

		var rally := Rally.new(striker, true)
		rally.record_landing(Vector3(CourtSpec.HALF_WIDTH_DOUBLES + metres_out, 0.01, 3.0))
		rally.record_call(CallBook.get_call(&"in"))

		var gain := suspicion.register(rally)
		print("%-4d %-8.3f %-7.3f %+-7.2f %-10s %s" % [
			i + 1, gain, suspicion.level, suspicion.lean,
			Suspicion.Mood.keys()[suspicion.mood], " ".join(events)
		])

	if suspicion.is_removed and not suspicion.has_been_warned:
		print("  !! removed without ever being warned — this should be impossible")
