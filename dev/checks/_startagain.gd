extends Node

## Can a living career be ended on purpose?
##
##   godot --headless --path . res://dev/checks/_startagain.tscn
##
## START AGAIN used to be drawn only in `show_career()`'s `is_over` branch, so a career
## that was still alive had no reset anywhere in the game. The only way out was to quit
## and delete `career.json` by hand, which is not a thing a player can be expected to
## find. The signal was wired in `match.gd` and `officiated_match.gd` the whole time;
## only the button was missing.
##
## The interesting part is not that the button exists — it is that it takes **two**
## presses on a living career and **one** on a dead one, which is the whole reason the
## button is safe to add. A single press on nine matches' work would be a worse bug than
## the missing button was. So this presses once and insists nothing happened, then
## presses again and insists it did.
##
## The game's own handler is unhooked first, and that is not tidiness. `match.gd` answers
## `career_restart_requested` with `get_tree().reload_current_scene()`, so pressing the
## button for real tears the scene tree down underneath this check. The first draft left
## it connected, every assertion after the second press ran against a freed tree — and it
## still printed PASS, because a torn-down tree fails silently rather than loudly. A check
## that reports success after the thing it was inspecting has been destroyed is worse than
## no check at all. So the reload is disconnected and only the signal is watched.

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
	hall.settings.taught = true

	await _living_career_takes_two_presses(hall)
	await _dead_career_still_takes_one(hall)

	print("")
	if not is_inside_tree() or get_tree() == null:
		# Belt and braces, after the first draft printed PASS from a freed tree.
		print("FAIL  the scene tree was torn down before the check finished")
		return
	if _failures.is_empty():
		print("PASS  a living career can be ended on purpose, and not by accident")
	else:
		for failure in _failures:
			print("FAIL  " + failure)
	get_tree().quit()


## Nine matches, a rung climbed, and a reputation worth protecting from a stray cursor.
func _living_career_takes_two_presses(hall: Node) -> void:
	print("=== a career that is still alive")
	var career := Career.new()
	career.matches_refereed = 9
	career.tier = 2
	career.reputation = 0.267
	career.is_over = false
	hall.career = career

	var ui: RefereeUI = hall.ui
	_unhook_the_reload(hall, ui)
	ui.show_career(career)
	await get_tree().process_frame

	var wipe := _start_again_button(ui)
	_expect(wipe != null, "a living career offers START AGAIN at all")
	if wipe == null:
		return
	_expect(wipe.text == "START AGAIN", "it reads START AGAIN before it is touched")

	# One press must be harmless. This is the assertion the button exists to earn.
	var fired := {"count": 0}
	ui.career_restart_requested.connect(func() -> void: fired["count"] += 1)
	wipe.pressed.emit()
	await get_tree().process_frame
	_expect(fired["count"] == 0, "one press does not restart anything")
	_expect(wipe.text != "START AGAIN", "one press changes the button instead")
	_expect("9" in wipe.text, "and the second press names what is about to go (%s)" % wipe.text)

	wipe.pressed.emit()
	await get_tree().process_frame
	_expect(fired["count"] == 1, "the second press asks for the restart, exactly once")

	# Leaving and coming back is a cancel, because the screen is rebuilt each time.
	ui.show_career(career)
	await get_tree().process_frame
	var again := _start_again_button(ui)
	_expect(again != null and again.text == "START AGAIN",
		"leaving the screen and returning disarms it")


## The screen that already had the button keeps it, and keeps it at one press — there is
## nothing left to lose by then, so a confirmation would only be in the way.
func _dead_career_still_takes_one(hall: Node) -> void:
	print("=== a career that is over")
	var career := Career.new()
	career.matches_refereed = 12
	career.times_removed = 3
	career.is_over = true
	hall.career = career

	var ui: RefereeUI = hall.ui
	_unhook_the_reload(hall, ui)
	ui.show_career(career)
	await get_tree().process_frame

	var wipe := _start_again_button(ui)
	_expect(wipe != null, "a dead career still offers START AGAIN")
	if wipe == null:
		return

	var fired := {"count": 0}
	ui.career_restart_requested.connect(func() -> void: fired["count"] += 1)
	wipe.pressed.emit()
	await get_tree().process_frame
	_expect(fired["count"] == 1, "and one press is enough for it")


## `match.gd` reloads the whole scene on this signal, which would take this check with it.
## Watching the signal is the point here; what the match then does about it is the game's
## business and not this check's.
func _unhook_the_reload(hall: Node, ui: RefereeUI) -> void:
	var reload := Callable(hall, "_on_career_restart_requested")
	if ui.career_restart_requested.is_connected(reload):
		ui.career_restart_requested.disconnect(reload)


## The button by what it says rather than by where it sits, so moving it about the
## screen does not quietly turn this check into one that passes on nothing.
func _start_again_button(ui: RefereeUI) -> Button:
	var found: Array[Button] = []
	_collect(ui._career_panel, found)
	for button in found:
		if button.text.begins_with("START AGAIN") or button.text.begins_with("SURE?"):
			return button
	return null


func _collect(node: Node, into: Array[Button]) -> void:
	if node == null:
		return
	if node is Button:
		into.append(node as Button)
	for child in node.get_children():
		_collect(child, into)
