extends Node

## Can every menu be worked without a mouse?
##
##   godot --headless --path . res://dev/checks/_keyboard.tscn
##
## Until 2026-09-17 no menu in this game could be. That was never a missing feature so
## much as a missing first step: the theme has had a lit `focus` stylebox and a white
## `font_focus_color` for Button since `_style_buttons()` was written, and Godot moves
## focus on the arrow keys and presses on `ui_accept` with no help at all. **Nothing ever
## took focus**, and with nothing focused the arrow keys have nowhere to start.
##
## So what is checked here is the first step and the last one: that opening a menu leaves
## a real button focused, and that closing it lets go again. The second half matters more
## than it looks. `match.gd` starts a rally on SPACE in `Phase.READY`, and a focused
## Button eats `ui_accept` before `_unhandled_input` sees it — a button left focused
## behind a match would swallow the serve key, which would present as the serve key
## having stopped working rather than as a focus bug.

var _failures: Array[String] = []


func _expect(ok: bool, what: String) -> void:
	print("   %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures.append(what)


func _ready() -> void:
	var hall: Node = load("res://scenes/match.tscn").instantiate()
	hall.print_truth_while_testing = false
	add_child(hall)
	await get_tree().physics_frame
	hall.career = Career.new()
	hall.career.matches_refereed = 5
	hall.career.history.append({
		"sport": Career.BADMINTON, "venue": "School hall", "doubles": true, "asked": true,
		"suspicion": 0.2, "change": 0.05, "reputation": 0.8, "removed": false,
	})
	hall.settings.taught = true
	var ui: RefereeUI = hall.ui

	await _every_menu_starts_focused(hall, ui)
	await _arrows_move_between_buttons(hall, ui)
	await _the_keyboard_goes_back_to_the_match(hall, ui)
	await _only_one_button_is_ever_lit(hall, ui)

	print("")
	if _failures.is_empty():
		print("PASS  one selected button, moved by the keyboard or the pointer alike")
	else:
		for failure in _failures:
			print("FAIL  " + failure)
	get_tree().quit()


## Opening a menu must leave something focused, or the arrow keys do nothing at all.
func _every_menu_starts_focused(hall: Node, ui: RefereeUI) -> void:
	print("=== every menu opens with a button already focused")
	var menus := [
		["the title screen", func() -> void: ui.show_main_menu(hall.career)],
		["WHICH SPORT?", func() -> void: ui.show_sport_menu()],
		["one a side or two", func() -> void: ui.show_format_menu(Career.BADMINTON)],
		["the career screen", func() -> void: ui.show_career(hall.career)],
		["every match so far", func() -> void: ui.show_history(hall.career)],
		["the lesson", func() -> void: ui.show_teaching(Career.BADMINTON)],
		["the settings", func() -> void: ui.show_settings(hall.settings, false)],
		["the pause menu", func() -> void: ui.show_pause_menu(true)],
	]
	for menu: Array in menus:
		ui.hide_menus()
		var open: Callable = menu[1]
		open.call()
		await get_tree().process_frame
		var held := get_viewport().gui_get_focus_owner()
		var name: String = menu[0]
		var on_it := held != null and held is Button
		_expect(on_it, "%s focuses a button (%s)" % [
			name, "\"%s\"" % (held as Button).text if on_it else "nothing"])
		if on_it:
			_expect(not (held as Button).disabled and (held as Button).is_visible_in_tree(),
				"%s focuses one that can actually be pressed" % name)
			# And not the way out, unless leaving is genuinely all the screen offers.
			# On the lesson this was BACK on page 1 of 7, so a player on a keyboard who
			# pressed the obvious key left before reading anything.
			var others := 0
			for node in _panel_of(ui, name).find_children("*", "Button", true, false):
				var button := node as Button
				if button.visible and not button.disabled and not button.text in RefereeUI.WAYS_OUT:
					others += 1
			if others > 0:
				_expect(not (held as Button).text in RefereeUI.WAYS_OUT,
					"%s does not start on the way out (%d other buttons on it)" % [name, others])


## And the arrow keys have to reach the others. Godot works the neighbours out from the
## layout, so this is really checking that the buttons are in a container it can read.
func _arrows_move_between_buttons(hall: Node, ui: RefereeUI) -> void:
	print("=== the arrow keys move between them")
	ui.hide_menus()
	ui.show_main_menu(hall.career)
	await get_tree().process_frame

	var first := get_viewport().gui_get_focus_owner() as Button
	if first == null:
		_expect(false, "something is focused to move from")
		return
	var seen: Array[String] = [first.text]
	var here := first
	for step in 4:
		var next := here.find_valid_focus_neighbor(SIDE_BOTTOM)
		if next == null:
			break
		next.grab_focus()
		await get_tree().process_frame
		here = get_viewport().gui_get_focus_owner() as Button
		if here == null:
			break
		seen.append(here.text)
	print("   down the title screen: %s" % " -> ".join(seen))
	_expect(seen.size() == 5, "down reaches all five title buttons (reached %d)" % seen.size())
	_expect(seen[seen.size() - 1] == "QUIT", "and ends on QUIT (ended on %s)" % seen[seen.size() - 1])


## The panel a named screen lives in, so its buttons can be counted.
func _panel_of(ui: RefereeUI, name: String) -> Control:
	match name:
		"the title screen": return ui._main_menu
		"WHICH SPORT?": return ui._sport_menu
		"one a side or two": return ui._format_menu
		"the career screen": return ui._career_panel
		"every match so far": return ui._history_panel
		"the lesson": return ui._teaching
		"the settings": return ui._settings_menu
		"the pause menu": return ui._pause_menu
	return ui._main_menu


## Pointing at a button has to *be* selecting it, or the pointer and the keyboard each
## light one and the screen shows two selected buttons. That is what Luqman caught on
## 2026-09-17: "when i hover at a button, only that button is hover".
func _only_one_button_is_ever_lit(hall: Node, ui: RefereeUI) -> void:
	print("=== only one button is lit, whichever way you move")
	ui.hide_menus()
	ui.show_main_menu(hall.career)
	await _settled()
	_expect(_lit(ui) == ["PLAY"], "the title screen opens with PLAY alone lit (%s)" % _lit(ui))

	# Down two on the keyboard.
	var here := get_viewport().gui_get_focus_owner() as Button
	for step in 2:
		var next := here.find_valid_focus_neighbor(SIDE_BOTTOM)
		if next == null:
			break
		next.grab_focus()
		await _settled()
		here = get_viewport().gui_get_focus_owner() as Button
	_expect(_lit(ui) == ["HOW TO REFEREE"],
		"arrowing down moves the light rather than adding to it (%s)" % _lit(ui))

	# And now the pointer, onto a different button from the one the keyboard is on. This
	# is the exact state that used to light two.
	var quit := _named(ui, "QUIT")
	_expect(quit != null, "there is a QUIT button to point at")
	if quit == null:
		return
	quit.mouse_entered.emit()
	await _settled()
	_expect(_lit(ui) == ["QUIT"],
		"pointing at another button takes the light with it (%s)" % _lit(ui))
	_expect(get_viewport().gui_get_focus_owner() == quit,
		"and the keyboard is now on the one being pointed at, so the two agree")


## Every button that is not fully at rest. `lit` is the 0-to-1 the tween writes.
func _lit(ui: RefereeUI) -> Array[String]:
	var on: Array[String] = []
	for node in ui._main_menu.find_children("*", "Button", true, false):
		var button := node as Button
		if float(button.get_meta(&"lit", 0.0)) > 0.01:
			on.append(button.text)
	return on


func _named(ui: RefereeUI, text: String) -> Button:
	for node in ui._main_menu.find_children("*", "Button", true, false):
		if (node as Button).text == text:
			return node as Button
	return null


## Past the end of the fade, so nothing is read mid-tween.
func _settled() -> void:
	await get_tree().create_timer(0.4).timeout


## The important half. A button still holding focus behind a match would eat the serve.
func _the_keyboard_goes_back_to_the_match(hall: Node, ui: RefereeUI) -> void:
	print("=== and the match gets the keyboard back")
	ui.show_career(hall.career)
	await get_tree().process_frame
	_expect(get_viewport().gui_get_focus_owner() != null, "a button holds focus on the career screen")

	ui.hide_menus()
	await get_tree().process_frame
	_expect(get_viewport().gui_get_focus_owner() == null,
		"and nothing holds it once the menus are down")

	ui.show_pause_menu(true)
	await get_tree().process_frame
	_expect(get_viewport().gui_get_focus_owner() != null, "the pause menu takes it")
	ui.hide_pause_menu()
	await get_tree().process_frame
	_expect(get_viewport().gui_get_focus_owner() == null, "and gives it back on resume")
