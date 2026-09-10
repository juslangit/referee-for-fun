extends Node

## Can the player get back out of every menu?
##
## The career screen had no way off it at all: no BACK, no MAIN MENU, and its only exits
## were forward into a match or sideways into the lesson and the history. Somebody who
## opened it to look at the ladder had to referee a whole match to leave. And the
## settings went to the title screen whichever screen had opened them, so opening the
## settings from the career screen quietly threw the career screen away.
##
## Both are the kind of fault that is obvious to a player in five seconds and invisible
## to every other check in this project, because nothing here has ever pressed a button.
## This one presses them.

## Every screen the player can walk to, and how to open it. The title screen is not on
## the list — it is the one screen that is allowed to have no way back.
const SCREENS := [AT_SPORTS, AT_FORMAT, AT_CAREER, AT_HISTORY, AT_TEACHING, AT_SETTINGS]
const AT_SPORTS := &"sports"
const AT_FORMAT := &"format"
const AT_CAREER := &"career"
const AT_HISTORY := &"history"
const AT_TEACHING := &"teaching"
const AT_SETTINGS := &"settings"


func _ready() -> void:
	var hall: Node = load("res://scenes/match.tscn").instantiate()
	hall.print_truth_while_testing = false
	add_child(hall)
	await get_tree().physics_frame
	hall.career = Career.new()
	hall.career.matches_refereed = 4
	hall.career.history.append({
		"sport": Career.BADMINTON, "venue": "School hall", "won": true,
		"removed": false, "wrong": 1, "stolen": 0, "lean": 0.1, "reputation": 0.8,
	})
	hall.settings.taught = true
	var ui: RefereeUI = hall.ui

	var bad := 0
	bad += _every_screen_has_both_buttons(hall, ui)
	bad += await _back_goes_where_you_came_from(hall, ui)

	print("")
	if bad == 0:
		print("every menu can be left, forwards and backwards")
	else:
		print("%d PROBLEM(S)" % bad)
	get_tree().quit()


## The buttons exist, on every screen, spelled the same way.
func _every_screen_has_both_buttons(hall: Node, ui: RefereeUI) -> int:
	print("every menu offers BACK and MAIN MENU")
	var bad := 0
	for screen: StringName in SCREENS:
		_show(hall, ui, screen)
		var labels := _buttons_on(ui, screen)
		var has_back := labels.has("BACK")
		var has_main := labels.has("MAIN MENU")
		print("   %-10s %-5s %-9s   %s" % [
			screen, "BACK" if has_back else "-", "MAIN MENU" if has_main else "-",
			", ".join(labels)])
		if not has_back or not has_main:
			bad += 1
	return bad


## And BACK means the screen you came from, not a screen somebody picked in advance.
##
## The settings are the case that matters: they open from the title screen and from the
## career screen, and going back from them used to mean the title screen either way.
func _back_goes_where_you_came_from(hall: Node, ui: RefereeUI) -> int:
	print("")
	print("BACK returns to the screen you came from")
	var bad := 0

	var journeys := [
		{"walk": [AT_SPORTS, AT_CAREER, AT_SETTINGS], "back_to": AT_CAREER},
		{"walk": [AT_SPORTS, AT_CAREER, AT_HISTORY], "back_to": AT_CAREER},
		{"walk": [AT_SPORTS, AT_CAREER, AT_TEACHING], "back_to": AT_CAREER},
		{"walk": [AT_SETTINGS], "back_to": &"main"},
		{"walk": [AT_SPORTS, AT_FORMAT], "back_to": AT_SPORTS},
		{"walk": [AT_SPORTS], "back_to": &"main"},
		# The loop that a plain push-down stack would have grown for ever.
		{"walk": [AT_SPORTS, AT_CAREER, AT_HISTORY, AT_CAREER], "back_to": AT_SPORTS},
	]
	for journey: Dictionary in journeys:
		ui.show_main_menu(hall.career)
		for step: StringName in journey["walk"]:
			_show(hall, ui, step)
		await get_tree().process_frame
		var landed := ui._trail[ui._trail.size() - 2] if ui._trail.size() >= 2 else &"main"
		var want: StringName = journey["back_to"]
		var route := " -> ".join(PackedStringArray(journey["walk"]))
		print("   main -> %-38s back lands on %s%s" % [
			route, landed, "" if landed == want else "   <-- WANTED %s" % want])
		if landed != want:
			bad += 1
	return bad


func _show(hall: Node, ui: RefereeUI, screen: StringName) -> void:
	match screen:
		AT_SPORTS: ui.show_sport_menu()
		AT_FORMAT: ui.show_format_menu(Career.BADMINTON)
		AT_CAREER: ui.show_career(hall.career)
		AT_HISTORY: ui.show_history(hall.career)
		AT_TEACHING: ui.show_teaching(Career.BADMINTON)
		AT_SETTINGS: ui.show_settings(hall.settings, false)


## Every button label on the panel a screen lives in.
func _buttons_on(ui: RefereeUI, screen: StringName) -> Array[String]:
	var root: Node = null
	match screen:
		AT_SPORTS: root = ui._sport_menu
		AT_FORMAT: root = ui._format_menu
		AT_CAREER: root = ui._career_panel
		AT_HISTORY: root = ui._history_panel
		AT_TEACHING: root = ui._teaching
		AT_SETTINGS: root = ui._settings_menu
	var found: Array[String] = []
	_collect(root, found)
	return found


func _collect(node: Node, into: Array[String]) -> void:
	if node == null:
		return
	if node is Button:
		into.append((node as Button).text)
	for child in node.get_children():
		_collect(child, into)
