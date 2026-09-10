extends Node

## Three things Luqman found by playing, all about the pause menu being a menu for
## pausing something.
##
## ESC on the title screen opened it, over a game that was not being played. Leaving a
## match by its MAIN MENU button left it standing over the main menu with every button
## still live, because badminton is the only sport where going to the main menu does not
## change scene — it *is* the main menu — so nothing swept it away.

func _ready() -> void:
	var hall: Node = load("res://scenes/match.tscn").instantiate()
	hall.print_truth_while_testing = false
	add_child(hall)
	await get_tree().physics_frame
	hall.career = Career.new()
	hall.career.sport = Career.BADMINTON
	hall.settings.taught = true
	await get_tree().process_frame

	print("on the title screen")
	_press_escape(hall)
	await get_tree().process_frame
	print("   phase is %s" % _phase_of(hall))
	print("   ESC opened the pause menu: %s   (must be false)" % _paused_showing(hall))

	print()
	print("in a match")
	hall._on_match_requested()
	if hall.pressure.exists():
		hall.ui.hide_briefing()
	hall.begin_match()
	for f in 3:
		await get_tree().process_frame
	_press_escape(hall)
	await get_tree().process_frame
	print("   phase is %s" % _phase_of(hall))
	print("   ESC opened the pause menu: %s   (must be true)" % _paused_showing(hall))
	print("   the tree is paused: %s   (must be true)" % get_tree().paused)

	print()
	print("and then MAIN MENU from the pause menu")
	hall.ui.main_menu_requested.emit()
	await get_tree().process_frame
	print("   the pause menu is still up: %s   (must be false)" % _paused_showing(hall))
	print("   the tree is still paused: %s   (must be false)" % get_tree().paused)
	print("   the main menu is up: %s   (must be true)" % hall.ui._main_menu.visible)
	print("   phase is %s" % _phase_of(hall))

	_press_escape(hall)
	await get_tree().process_frame
	print("   ESC opens it again from there: %s   (must be false)" % _paused_showing(hall))
	get_tree().paused = false
	get_tree().quit()


func _press_escape(hall: Node) -> void:
	var event := InputEventKey.new()
	event.keycode = KEY_ESCAPE
	event.pressed = true
	hall._unhandled_input(event)


func _paused_showing(hall: Node) -> bool:
	return hall.ui._pause_menu != null and hall.ui._pause_menu.visible


func _phase_of(hall: Node) -> String:
	return OfficiatedMatch.Phase.keys()[hall._phase]
