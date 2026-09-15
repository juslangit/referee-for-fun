extends Node

## Does the ball stay where it landed while the official is deciding?
##
## Ball stopped simulating after its first bounce until tennis needed the second one.
## Now it keeps going all match, which is right for tennis and is a change every other
## sport inherited — so it is worth knowing how far the ball wanders after the landing
## that the whole call is about, and whether it ever comes to rest at all.

func _ready() -> void:
	for entry in [
		["beach", "res://scenes/beach.tscn", Career.BEACH],
		["indoor", "res://scenes/volleyball.tscn", Career.INDOOR],
		["tennis", "res://scenes/tennis.tscn", Career.TENNIS],
		["table tennis", "res://scenes/table_tennis.tscn", Career.TABLE_TENNIS],
		["takraw", "res://scenes/sepak_takraw.tscn", Career.TAKRAW],
	]:
		await _watch(entry[0], entry[1], entry[2])
	get_tree().quit()


func _watch(name: String, scene: String, sport: StringName) -> void:
	var arena: Node = load(scene).instantiate()
	arena.print_truth_while_testing = false
	add_child(arena)
	await get_tree().physics_frame
	arena.career = Career.new()
	arena.career.sport = sport
	arena.settings.taught_beach = true
	arena.settings.taught_indoor = true
	arena.settings.taught_tennis = true
	arena.settings.taught_table_tennis = true
	arena.settings.taught_takraw = true
	arena.ui.match_requested.emit()
	await get_tree().process_frame
	if arena.pressure.exists():
		arena.ui.briefing_acknowledged.emit()
		await get_tree().process_frame
	arena.begin_match()
	for f in 3:
		await get_tree().process_frame

	var drifts: Array[float] = []
	var speeds: Array[float] = []
	for r in 6:
		arena.start_rally()
		var waited := 0
		while arena._phase != arena.Phase.AWAITING_CALL and waited < 4000:
			await get_tree().physics_frame
			waited += 1
		if arena._phase != arena.Phase.AWAITING_CALL:
			break
		var landing: Vector3 = arena.rally.landing_point
		# Three seconds of an official thinking about it.
		for f in 180:
			await get_tree().physics_frame
		var here: Vector3 = arena._ball.global_position
		drifts.append(Vector2(here.x - landing.x, here.z - landing.z).length())
		speeds.append(arena._ball.linear_velocity.length())
		arena._awaiting_since = Time.get_ticks_msec()
		arena.make_call(&"in" if arena.rally.was_in else &"out")
		var w2 := 0
		while arena._phase == arena.Phase.AWAITING_CALL and w2 < 900:
			await get_tree().process_frame
			w2 += 1

	var worst := 0.0
	var total := 0.0
	for d in drifts:
		worst = maxf(worst, d)
		total += d
	var still := 0.0
	for s in speeds:
		still = maxf(still, s)
	print("%-8s  rallies %d   ball drifts %.2f m on average, worst %.2f m   fastest still moving %.2f m/s" % [
		name, drifts.size(), total / maxf(1.0, float(drifts.size())), worst, still])
	arena.queue_free()
	await get_tree().process_frame
