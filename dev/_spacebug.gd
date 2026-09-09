extends Node

## Why does SPACE stop starting rallies?
##
## Calling start_rally() directly works every time, so the fault is somewhere in the
## input path a real player goes through and a harness does not. This presses the actual
## key, and reports what had keyboard focus when it did.

func _ready() -> void:
	var arena: Node = load("res://scenes/volleyball.tscn").instantiate()
	arena.print_truth_while_testing = false
	add_child(arena)
	await get_tree().physics_frame

	arena.career = Career.new()
	arena.career.sport = Career.INDOOR
	arena.settings.taught_indoor = true
	arena.ui.match_requested.emit()
	await get_tree().process_frame
	if arena.pressure.exists():
		arena.ui.briefing_acknowledged.emit()
		await get_tree().process_frame
	arena.begin_match()
	for f in 4:
		await get_tree().process_frame

	for attempt in 4:
		print("attempt %d: phase %d, focus held by: %s" % [
			attempt + 1, arena._phase, _focused()])
		await _press_space()
		print("   after SPACE, phase is %d %s" % [
			arena._phase,
			"(a rally started)" if arena._phase == arena.Phase.IN_PLAY else "— NOTHING HAPPENED"])
		if arena._phase != arena.Phase.IN_PLAY:
			break

		var waited := 0
		while arena._phase == arena.Phase.IN_PLAY and waited < 4000:
			await get_tree().physics_frame
			waited += 1
		# Call it the way a player does: an actual click.
		await _click()
		var settle := 0
		while arena._phase == arena.Phase.AWAITING_CALL and settle < 600:
			await get_tree().process_frame
			settle += 1
	get_tree().quit()


func _focused() -> String:
	var owner := get_viewport().gui_get_focus_owner()
	if owner == null:
		return "nobody"
	return "%s (%s)" % [owner.name, owner.get_class()]


func _press_space() -> void:
	var down := InputEventKey.new()
	down.keycode = KEY_SPACE
	down.physical_keycode = KEY_SPACE
	down.pressed = true
	Input.parse_input_event(down)
	await get_tree().process_frame
	await get_tree().process_frame


func _click() -> void:
	var down := InputEventMouseButton.new()
	down.button_index = MOUSE_BUTTON_LEFT
	down.pressed = true
	down.position = Vector2(400, 300)
	Input.parse_input_event(down)
	await get_tree().process_frame
	await get_tree().process_frame
