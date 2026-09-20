extends Node

## Three things Luqman found by playing, all about the pause menu being a menu for
## pausing something.
##
## ESC on the title screen opened it, over a game that was not being played. Leaving a
## match by its MAIN MENU button left it standing over the main menu with every button
## still live, because badminton is the only sport where going to the main menu does not
## change scene — it *is* the main menu — so nothing swept it away.
##
## Seven things had to be true and the check printed all seven with "(must be true)" or
## "(must be false)" beside them, leaving the reader to compare fourteen words. They are
## assertions now, and the run ends on a verdict.

var _failures: Array[String] = []


func _expect(ok: bool, what: String) -> void:
	print("   %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures.append(what)


func _verdict() -> void:
	print("")
	if _failures.is_empty():
		print("PASS  the pause menu pauses a match, and nothing else")
	else:
		for failure in _failures:
			print("FAIL  " + failure)


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
	_expect(not _paused_showing(hall), "ESC on the title screen leaves the pause menu alone")

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
	_expect(_paused_showing(hall), "ESC in a match opens the pause menu")
	_expect(get_tree().paused, "and the match stops while it is up")

	print()
	print("and then MAIN MENU from the pause menu")
	hall.ui.main_menu_requested.emit()
	await get_tree().process_frame
	_expect(not _paused_showing(hall), "leaving by MAIN MENU takes the pause menu down with it")
	_expect(not get_tree().paused, "and lets the tree run again")
	_expect(hall.ui._main_menu.visible, "and the main menu is up behind it")
	print("   phase is %s" % _phase_of(hall))

	_press_escape(hall)
	await get_tree().process_frame
	_expect(not _paused_showing(hall), "ESC on the main menu does not reopen it")
	get_tree().paused = false
	_verdict()
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

