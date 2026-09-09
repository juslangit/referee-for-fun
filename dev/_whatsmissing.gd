extends Node

## Luqman reported three things after playing: no line judge calls in tennis, no
## reputation meter in volleyball, and line judges that should speak in every sport.
## This checks all four sports for both, rather than guessing from the code.

func _ready() -> void:
	print("%-10s %7s %8s %9s %10s %9s" % [
		"sport", "judges", "visible", "watched", "spoke", "meter"])
	for entry in [
		["badminton", "res://scenes/match.tscn", Career.BADMINTON],
		["beach", "res://scenes/beach.tscn", Career.BEACH],
		["indoor", "res://scenes/volleyball.tscn", Career.INDOOR],
		["tennis", "res://scenes/tennis.tscn", Career.TENNIS],
	]:
		await _check(entry[0], entry[1], entry[2])
	get_tree().quit()


func _check(name: String, scene: String, sport: StringName) -> void:
	var arena: Node = load(scene).instantiate()
	arena.print_truth_while_testing = false
	add_child(arena)
	await get_tree().physics_frame

	arena.career = Career.new()
	arena.career.sport = sport
	arena.career.reputation = 0.80
	arena.settings.taught = true
	arena.settings.taught_beach = true
	arena.settings.taught_indoor = true
	arena.settings.taught_tennis = true

	var badminton := name == "badminton"
	if badminton:
		arena._on_match_requested()
		if arena.pressure.exists():
			arena.ui.hide_briefing()
	else:
		arena.ui.match_requested.emit()
		await get_tree().process_frame
		if arena.pressure.exists():
			arena.ui.briefing_acknowledged.emit()
			await get_tree().process_frame
	arena.begin_match()
	for f in 4:
		await get_tree().process_frame

	var judges: Array = arena.line_judges
	var visible := 0
	for judge in judges:
		if judge.visible:
			visible += 1

	var watched := 0
	var spoke := 0
	var meter := 0
	for r in 6:
		if badminton:
			arena._start_rally()
		else:
			arena.start_rally()
		var waited := 0
		while arena._phase != arena.Phase.AWAITING_CALL and waited < 4000:
			await get_tree().physics_frame
			waited += 1
		if arena._phase != arena.Phase.AWAITING_CALL:
			break
		if arena.get("_judge_called"):
			watched += 1

		# A whole second of the official thinking, which is when a flag goes up. Counted
		# per rally rather than cumulatively — the first version broke out of this loop
		# the moment `spoke` was non-zero, which after the first rally was immediately,
		# so it could never report more than one.
		var said_something := false
		for f in 90:
			await get_tree().physics_frame
			for judge in judges:
				if judge.visible and judge._bubble != null and judge._bubble.visible:
					said_something = true
					break
			if arena.ui._judge_plate != null and arena.ui._judge_plate.visible:
				said_something = true
			if said_something:
				break
		if said_something:
			spoke += 1

		# And a blatant lie, which must move the meter.
		var rally = arena.rally
		arena._awaiting_since = Time.get_ticks_msec()
		if badminton:
			arena._make_call(&"in" if not rally.was_in else &"out")
		else:
			arena.make_call(&"in" if not rally.was_in else &"out")
		# Sampled for a fixed stretch rather than "while the phase is still awaiting a
		# call". judge() has no await in it unless somebody challenges, so it runs to
		# completion before make_call even returns — and the first version of this loop
		# found the phase already moved on and never looked at the meter once.
		for f in 40:
			await get_tree().process_frame
			if arena.ui._meter != null and arena.ui._meter.visible:
				meter += 1
				break
		if arena._phase == arena.Phase.REMOVED:
			break

	print("%-10s %7d %8d %9d %10d %10d" % [
		name, judges.size(), visible, watched, spoke, meter])
	arena.queue_free()
	await get_tree().process_frame
