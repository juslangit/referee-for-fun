extends Node

## Does the title screen offer the five things it should, and does PLAY actually arrive
## at the sport menu?
##
##   godot --headless --path . res://dev/checks/_titlescreen.tscn
##
## The second question is the one this check exists for. Until 2026-09-17 the "WHICH
## SPORT?" screen was built, finished and **unreachable**: `play_requested` was emitted
## only by `_open()`, which is the *back* navigation, so the only way to land on that
## screen was to have already been past it. Six sport tiles on the title screen were
## doing its job in its place, and nothing anywhere noticed, because no check in this
## project had ever pressed a button on the title screen.
##
## So this presses them, and follows PLAY through the match's own handler rather than
## calling `show_sport_menu()` directly — calling it directly is what would have hidden
## the fault, since the screen always worked. It was the route to it that did not exist.

const WANTED := ["PLAY", "CAREER", "HOW TO REFEREE", "SETTINGS", "QUIT"]

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
	hall.settings.taught = true
	var ui: RefereeUI = hall.ui

	await _the_screen_offers_five_things(hall, ui)
	await _play_reaches_the_sport_menu(hall, ui)
	await _career_leaves_the_title_screen(hall, ui)

	print("")
	if _failures.is_empty():
		print("PASS  the title screen offers five things and PLAY reaches the sports")
	else:
		for failure in _failures:
			print("FAIL  " + failure)
	get_tree().quit()


func _the_screen_offers_five_things(hall: Node, ui: RefereeUI) -> void:
	print("=== what is on the title screen")
	ui.show_main_menu(hall.career)
	await get_tree().process_frame

	var labels := _button_labels(ui._main_menu)
	print("   %s" % ", ".join(labels))
	for wanted in WANTED:
		_expect(labels.has(wanted), "the title screen offers %s" % wanted)
	_expect(labels.size() == WANTED.size(),
		"and offers nothing else (%d buttons)" % labels.size())

	# The sports moved out on 2026-09-17. A card back on this screen means the two menus
	# have started duplicating each other again.
	var cards := 0
	for card in ui._main_menu.find_children("Sport_*", "Button", true, false):
		cards += 1
	_expect(cards == 0, "and no sport cards are left on it (%d found)" % cards)


## Through the match's own handler, because the route is the thing being checked.
func _play_reaches_the_sport_menu(hall: Node, ui: RefereeUI) -> void:
	print("=== PLAY")
	ui.show_main_menu(hall.career)
	await get_tree().process_frame

	var play := _button_named(ui._main_menu, "PLAY")
	if play == null:
		_expect(false, "there is a PLAY button to press")
		return
	play.pressed.emit()
	await get_tree().process_frame

	_expect(ui._sport_menu.visible, "PLAY arrives at WHICH SPORT?")
	_expect(not ui._main_menu.visible, "and the title screen goes away behind it")

	var cards := ui._sport_menu.find_children("Sport_*", "Button", true, false)
	_expect(cards.size() == SPORTS_EXPECTED,
		"with all %d sports on it (%d found)" % [SPORTS_EXPECTED, cards.size()])

	# And back again, so the two screens are not a one-way trip.
	var home := _button_named(ui._sport_menu, "MAIN MENU")
	_expect(home != null, "WHICH SPORT? offers a way back to the title screen")
	if home != null:
		home.pressed.emit()
		await get_tree().process_frame
		_expect(ui._main_menu.visible, "and MAIN MENU returns to it")


## CAREER has to put the title screen away itself — `_on_career_screen_requested()` only
## raises the career panel. The old career tile did this and a plain button has to too.
func _career_leaves_the_title_screen(hall: Node, ui: RefereeUI) -> void:
	print("=== CAREER")
	ui.show_main_menu(hall.career)
	await get_tree().process_frame

	var career := _button_named(ui._main_menu, "CAREER")
	if career == null:
		_expect(false, "there is a CAREER button to press")
		return
	career.pressed.emit()
	await get_tree().process_frame

	_expect(ui._career_panel.visible, "CAREER opens the career screen")
	_expect(not ui._main_menu.visible, "and the title screen does not stay up underneath it")


const SPORTS_EXPECTED := 6


func _button_labels(root: Node) -> Array[String]:
	var found: Array[String] = []
	for node in root.find_children("*", "Button", true, false):
		found.append((node as Button).text)
	return found


func _button_named(root: Node, text: String) -> Button:
	for node in root.find_children("*", "Button", true, false):
		if (node as Button).text == text:
			return node as Button
	return null
