extends Node

## Does every sport slow down on the landing that ends a rally, and always come back?
##
## `Engine.time_scale` belongs to the whole engine, so the dangerous failure is not a
## slow-down that never happens but one that never ends: a match left at a third of the
## speed, a pause menu crawling, the title screen after a match running slow. Each of the
## ways out is asserted in every sport — waiting it out, calling during it, pausing
## during it, and the match being freed during it.

const SLOW_ENOUGH := 0.5
## Wall-clock seconds to wait for the ease back, with room over HOLD + EASE (0.65 s).
const BACK_BY := 1.2

var _problems: Array[String] = []


func _ready() -> void:
	for entry in [
		["badminton", "res://scenes/match.tscn", Career.BADMINTON],
		["beach", "res://scenes/beach.tscn", Career.BEACH],
		["indoor", "res://scenes/volleyball.tscn", Career.INDOOR],
		["tennis", "res://scenes/tennis.tscn", Career.TENNIS],
		["table tennis", "res://scenes/table_tennis.tscn", Career.TABLE_TENNIS],
		["takraw", "res://scenes/sepak_takraw.tscn", Career.TAKRAW],
	]:
		await _check(entry[0], entry[1], entry[2])
	if not is_equal_approx(Engine.time_scale, 1.0):
		_problems.append("the engine was left at %.2f after every match was freed" % Engine.time_scale)
	print("PASS" if _problems.is_empty() else "FAIL:\n   " + "\n   ".join(_problems))
	get_tree().quit()


func _check(name: String, scene: String, sport: StringName) -> void:
	var arena: Node = load(scene).instantiate()
	arena.print_truth_while_testing = false
	add_child(arena)
	await get_tree().physics_frame
	arena.career = Career.new()
	arena.career.sport = sport
	for flag in ["taught", "taught_beach", "taught_indoor", "taught_tennis", "taught_table_tennis",
			"taught_takraw"]:
		arena.settings.set(flag, true)
	arena.ui.match_requested.emit()
	await get_tree().process_frame
	if arena.pressure.exists():
		arena.ui.briefing_acknowledged.emit()
		arena.ui.hide_briefing()
		await get_tree().process_frame
	arena.begin_match()
	for f in 4:
		await get_tree().process_frame
	print("=== %s" % name)

	# 1. Left alone, it slows and comes back by itself.
	if not await _to_a_landing(arena, name):
		arena.queue_free()
		return
	var at_landing := Engine.time_scale
	var since := Time.get_ticks_msec()
	while Time.get_ticks_msec() - since < int(BACK_BY * 1000.0):
		await get_tree().process_frame
	print("   at the landing %.2f, %.1f s later %.2f" % [at_landing, BACK_BY, Engine.time_scale])
	if at_landing > SLOW_ENOUGH:
		_problems.append("%s: no slow-down at the landing (%.2f)" % [name, at_landing])
	if not is_equal_approx(Engine.time_scale, 1.0):
		_problems.append("%s: still at %.2f %.1f s after the landing" % [name, Engine.time_scale, BACK_BY])
	await _call(arena)

	# 2. Pausing during it gives the menu full speed.
	if await _to_a_landing(arena, name):
		arena.pause_the_match()
		print("   paused during it: %.2f" % Engine.time_scale)
		if not is_equal_approx(Engine.time_scale, 1.0):
			_problems.append("%s: the pause menu runs at %.2f" % [name, Engine.time_scale])
		arena.ui.resume_requested.emit()
		await get_tree().process_frame
		await _call(arena)

	# 3. A call made during it ends it.
	if await _to_a_landing(arena, name):
		arena.make_call(&"in")
		await get_tree().process_frame
		var left: bool = arena._phase != arena.Phase.AWAITING_CALL
		print("   called during it: phase left the call %s, speed %.2f" % [left, Engine.time_scale])
		if left and not is_equal_approx(Engine.time_scale, 1.0):
			_problems.append("%s: a call did not end the slow-down (%.2f)" % [name, Engine.time_scale])
		await _call(arena)

	# 4. The match is freed during it.
	if await _to_a_landing(arena, name):
		arena.queue_free()
		await get_tree().process_frame
		print("   freed during it: %.2f" % Engine.time_scale)
		if not is_equal_approx(Engine.time_scale, 1.0):
			_problems.append("%s: freeing the match left the engine at %.2f" % [name, Engine.time_scale])
	else:
		arena.queue_free()
	await get_tree().process_frame


func _to_a_landing(arena: Node, name: String) -> bool:
	var waited := 0
	while arena._phase != arena.Phase.READY and waited < 3000:
		await get_tree().process_frame
		waited += 1
	if arena.board.is_over or arena._phase == arena.Phase.REMOVED:
		return false
	arena.start_rally()
	waited = 0
	while arena._phase != arena.Phase.AWAITING_CALL and waited < 6000:
		await get_tree().physics_frame
		waited += 1
	if arena._phase != arena.Phase.AWAITING_CALL:
		_problems.append("%s: a rally never reached a call" % name)
		return false
	return true


## Any call at all, to move the match on. `in` exists in every sport's book, and `out`
## where a sport answers `in` with nothing.
func _call(arena: Node) -> void:
	if arena._phase == arena.Phase.AWAITING_CALL:
		arena.make_call(&"in")
	var since := Time.get_ticks_msec()
	while arena._phase == arena.Phase.AWAITING_CALL and Time.get_ticks_msec() - since < 3000:
		await get_tree().process_frame
	if arena._phase == arena.Phase.AWAITING_CALL:
		arena.make_call(&"out")
		for f in 30:
			await get_tree().process_frame
