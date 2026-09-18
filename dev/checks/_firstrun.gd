extends Node

## What happens to somebody who has never seen this game?
##
##   godot --headless --path . res://dev/checks/_firstrun.tscn
##
## Every other check in this project runs against a career that already exists and a
## player who has already been taught. That is the convenient state, not the common one:
## the state a stranger actually lands in is no save at all, no lesson seen, and no idea
## that they are the umpire rather than a player.
##
## This walks the path a first-timer takes — boot, title card, PLAY, pick a sport, and on
## into a first rally — with a **fresh career and fresh settings**, and asserts that each
## step leads somewhere rather than into a dead end. It exists because the game is about
## to be handed to somebody, and the first five minutes are the only ones most people
## give a game they did not make.

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

	# A stranger: nothing saved, nothing taught, nothing rebound.
	var fresh := Career.start_again()
	var settings := Settings.new()
	hall.career = fresh
	hall.settings = settings
	var ui: RefereeUI = hall.ui

	print("=== the career a stranger starts with")
	_expect(fresh.matches_refereed == 0, "no matches refereed yet")
	_expect(fresh.tier == 0, "they start at the bottom of the ladder (%s)" % fresh.venue()["name"])
	_expect(not settings.taught, "and they have not been shown the badminton lesson")
	_expect(fresh.reputation > 0.5,
		"they begin with a reputation worth losing (%.2f)" % fresh.reputation)

	print("=== the title screen they land on")
	ui.show_main_menu(fresh)
	await get_tree().process_frame
	var labels: Array[String] = []
	for node in ui._main_menu.find_children("*", "Button", true, false):
		labels.append((node as Button).text)
	print("   it offers: %s" % ", ".join(labels))
	_expect(labels.has("PLAY"), "there is a PLAY button, and it is the first thing")
	_expect(labels.size() <= 6, "and not so many choices that the way in is hidden")
	var held := get_viewport().gui_get_focus_owner()
	_expect(held is Button and (held as Button).text == "PLAY",
		"PLAY is already selected, so a keyboard or pad works with no hunting")

	print("=== choosing a sport")
	ui.show_sport_menu()
	await get_tree().process_frame
	var cards := ui._sport_menu.find_children("Sport_*", "Button", true, false)
	_expect(cards.size() == 6, "all six sports are offered (%d)" % cards.size())
	var playable := 0
	for card in cards:
		if not (card as Button).disabled:
			playable += 1
	_expect(playable == 6, "and every one of them can be picked (%d)" % playable)

	print("=== the lesson, which is the only thing that says what the game is")
	ui.show_teaching(Career.BADMINTON)
	await get_tree().process_frame
	_expect(ui._teaching.visible, "a first-timer can be shown how to referee")
	var lesson_buttons := _labels(ui._teaching)
	print("   the lesson offers: %s" % ", ".join(lesson_buttons))
	_expect(not lesson_buttons.is_empty(), "and there is a way out of the lesson")

	print("=== and into a first match")
	ui.hide_menus()
	hall._on_match_requested()
	await get_tree().process_frame
	if hall.pressure.exists():
		ui.briefing_acknowledged.emit()
		await get_tree().process_frame
	_expect(hall._phase == hall.Phase.READY or hall._phase == hall.Phase.MENU,
		"the match is ready to start rather than stuck (phase %d)" % hall._phase)
	hall.begin_match()
	for f in 6:
		await get_tree().physics_frame
	_expect(hall.players.size() >= 2, "there are players on court (%d)" % hall.players.size())
	_expect(hall.board != null and not hall.board.is_over, "and a match to referee")

	print("")
	if _failures.is_empty():
		print("PASS  a stranger can get from the title screen to refereeing a rally")
	else:
		for failure in _failures:
			print("FAIL  " + failure)
	get_tree().quit()


func _labels(root: Node) -> Array[String]:
	var found: Array[String] = []
	for node in root.find_children("*", "Button", true, false):
		var button := node as Button
		if button.visible and not button.text.is_empty():
			found.append(button.text)
	return found
