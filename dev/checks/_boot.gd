extends Node

## Does the game open the way a game opens?
##
##   godot --headless --path . res://dev/checks/_boot.tscn
##
## The project used to start straight on `match.tscn`, whose `_ready()` builds the hall in
## one blocking go — 1,326 ms measured, during which the window exists and is blank. There
## was no boot splash either. Luqman asked for "a proper loading screen and starting
## screen like every game out there" and chose splash, loading, press-any-key, menu.
##
## What is checked here is the order and the handover, because those are what a later
## change can silently break: that something is on screen before the hall is built, that
## the card genuinely waits rather than falling through, that the menu is **not** showing
## underneath it, and that a key press hands the keyboard to a menu with a button focused.
##
## The one thing this cannot check is whether it looks right. It did not, first time —
## the menu behind the card drew a second logo and a second tagline through it — and only
## a picture said so. `dev/looks/_bootshot` takes that picture.

var _failures: Array[String] = []


func _expect(ok: bool, what: String) -> void:
	print("   %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures.append(what)


func _ready() -> void:
	_the_project_starts_here()
	await _the_sequence_runs()

	print("")
	if _failures.is_empty():
		print("PASS  the game opens on a loading screen and waits for a key")
	else:
		for failure in _failures:
			print("FAIL  " + failure)
	get_tree().quit()


## The settings, not the code: a boot scene nothing starts on is not a boot scene, and a
## splash nobody configured leaves the first moment black.
func _the_project_starts_here() -> void:
	print("=== what the project is set to do")
	# Typed by hand: `get_setting()` returns Variant, and `:=` off a Variant is a parse
	# error in this project — which does not fail a check, it stops the script loading and
	# leaves the scene spinning until the frame cap. Same trap as `_indoorbugs` (D-069).
	var main: String = str(ProjectSettings.get_setting("application/run/main_scene", ""))
	_expect(main == "res://scenes/boot.tscn", "the game starts on the boot scene (%s)" % main)
	var splash: String = str(ProjectSettings.get_setting("application/boot_splash/image", ""))
	_expect(not splash.is_empty(), "there is a boot splash before any script runs (%s)" % splash)
	_expect(ResourceLoader.exists(splash), "and the image it names exists")


func _the_sequence_runs() -> void:
	print("=== the sequence")
	var boot: Node = load("res://scenes/boot.tscn").instantiate()
	add_child(boot)
	await get_tree().process_frame

	# Before the hall is built there must already be something drawn, or the loading
	# screen is not doing the one job it exists for.
	var screen := boot.find_child("BootScreen", true, false) as Control
	_expect(screen != null and screen.visible, "a loading screen is up immediately")
	_expect(boot.find_child("BootBar", true, false) != null, "with a progress bar on it")

	var waited := 0
	while not boot.is_waiting() and waited < 1200:
		await get_tree().process_frame
		waited += 1
	_expect(boot.is_waiting(), "the title card comes up and waits (%d frames)" % waited)
	if not boot.is_waiting():
		return

	# The hall is built by now and the card is over it. The menu must not be.
	var hall: Node = boot.get_node_or_null("Match")
	if hall == null:
		for child in boot.get_children():
			if child is OfficiatedMatch:
				hall = child
	_expect(hall != null, "the hall is built and standing behind the card")
	if hall != null:
		_expect(not hall.ui._main_menu.visible,
			"and the menu is NOT showing through it — it draws the same logo")
	_expect(get_viewport().gui_get_focus_owner() == null,
		"nothing holds the keyboard, so any key reaches the card")

	# Any key. A mouse move must not count, or the card dismisses itself.
	var drift := InputEventMouseMotion.new()
	drift.relative = Vector2(12, 12)
	Input.parse_input_event(drift)
	await get_tree().process_frame
	_expect(boot.is_waiting(), "moving the mouse does not dismiss it")

	var press := InputEventKey.new()
	press.keycode = KEY_SPACE
	press.pressed = true
	Input.parse_input_event(press)
	await get_tree().create_timer(0.6).timeout
	_expect(not boot.is_waiting(), "a key press dismisses it")
	if hall != null:
		_expect(hall.ui._main_menu.visible, "and the menu is up behind it")
	var held := get_viewport().gui_get_focus_owner()
	_expect(held != null and held is Button,
		"with a button focused, so the keyboard works straight away (%s)" % [
			(held as Button).text if held is Button else "nothing"])
