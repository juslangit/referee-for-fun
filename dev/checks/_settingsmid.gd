extends Node

## Can you change the volume without walking out of the match?
##
## Until now you could not. The settings sheet was reachable only from the title screen,
## which meant the one moment a player actually discovers the crowd is too loud —
## halfway through a match, with a hall roaring at them — was the one moment they could
## do nothing about it. The only exits from a paused match were WALK OUT, which counts
## the same as being thrown off, and QUIT.
##
## Checked in two sports because they wire it up differently. Badminton reaches the
## sheet from two places and has to send BACK to two different places; every other sport
## has no title screen at all and reaches it only from the pause menu.

func _ready() -> void:
	await _check("badminton", "res://scenes/match.tscn", Career.BADMINTON)
	print()
	await _check("table tennis", "res://scenes/table_tennis.tscn", Career.TABLE_TENNIS)
	print()
	await _from_the_title_screen()
	get_tree().paused = false
	get_tree().quit()


func _check(what: String, scene: String, sport: StringName) -> void:
	print(what)
	var hall: Node = load(scene).instantiate()
	hall.print_truth_while_testing = false
	add_child(hall)
	await get_tree().physics_frame
	hall.career = Career.new()
	hall.career.sport = sport
	hall.settings.taught = true
	hall.settings.taught_table_tennis = true
	hall._on_match_requested()
	if hall.pressure.exists():
		hall.ui.hide_briefing()
	hall.begin_match()
	for f in 3:
		await get_tree().process_frame

	_press_escape(hall)
	await get_tree().process_frame
	print("   paused, pause menu up: %s   (must be true)" % _pause_up(hall))

	hall.ui.settings_requested.emit()
	await get_tree().process_frame
	print("   SETTINGS opens the sheet: %s   (must be true)" % hall.ui.is_settings_open())
	print("   the pause menu is out of the way: %s   (must be false)" % _pause_up(hall))
	print("   the tree is still paused: %s   (must be true)" % get_tree().paused)

	# The sliders have to be usable while the tree is paused, which is what this is for.
	print("   the sheet processes while paused: %s   (must be true)"
		% (hall.ui.process_mode == Node.PROCESS_MODE_ALWAYS))

	# ESC out of the sheet means BACK, not "pause a second time behind it".
	_press_escape(hall)
	await get_tree().process_frame
	print("   ESC closes the sheet: %s   (must be false)" % hall.ui.is_settings_open())
	print("   and the pause menu is back: %s   (must be true)" % _pause_up(hall))
	print("   the tree is still paused: %s   (must be true)" % get_tree().paused)

	# And BACK TO THE MATCH does the same thing from the button.
	hall.ui.settings_requested.emit()
	await get_tree().process_frame
	hall.ui.settings_closed.emit()
	await get_tree().process_frame
	print("   BACK returns to the pause menu: %s   (must be true)" % _pause_up(hall))

	hall.ui.resume_requested.emit()
	await get_tree().process_frame
	print("   RESUME still unpauses: %s   (must be false)" % get_tree().paused)
	hall.queue_free()
	await get_tree().process_frame


## The other route, which must not have changed: from the title screen, BACK goes back
## to the title screen rather than to a pause menu over a match nobody is playing.
func _from_the_title_screen() -> void:
	print("from the title screen")
	var hall: Node = load("res://scenes/match.tscn").instantiate()
	hall.print_truth_while_testing = false
	add_child(hall)
	await get_tree().physics_frame
	hall.career = Career.new()
	await get_tree().process_frame

	hall.ui.settings_requested.emit()
	await get_tree().process_frame
	print("   the sheet is open: %s   (must be true)" % hall.ui.is_settings_open())
	print("   with no pause menu behind it: %s   (must be false)" % _pause_up(hall))

	hall.ui.main_menu_requested.emit()
	await get_tree().process_frame
	print("   BACK reaches the title screen: %s   (must be true)"
		% hall.ui._main_menu.visible)
	print("   and not a pause menu: %s   (must be false)" % _pause_up(hall))
	hall.queue_free()
	await get_tree().process_frame


func _press_escape(hall: Node) -> void:
	var event := InputEventKey.new()
	event.keycode = KEY_ESCAPE
	event.pressed = true
	hall._unhandled_input(event)


func _pause_up(hall: Node) -> bool:
	return hall.ui._pause_menu != null and hall.ui._pause_menu.visible
