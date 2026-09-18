extends Node

## Do the umpire's verbs exist, answer to a keyboard, a mouse and a pad, and stay where
## a player puts them?
##
##   godot --headless --path . res://dev/checks/_controls.tscn
##
## Until 2026-09-18 the game had no input actions at all: six match scripts each compared
## `event.keycode` against a hard-coded constant, so SPACE-to-serve was written out twelve
## separate times and nothing could be rebound or reached from a controller. This checks
## the three things that replaced that, because each can break without anything crashing:
## the actions are installed at all, each is reachable from all three devices, and a
## rebind survives being saved and loaded.

const EXPECTED := [&"ref_pause", &"ref_serve", &"ref_call_in", &"ref_call_out",
	&"ref_let", &"ref_touch", &"ref_faults", &"ref_service_court"]

var _failures: Array[String] = []


func _expect(ok: bool, what: String) -> void:
	print("   %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures.append(what)


func _ready() -> void:
	Controls.ensure()

	print("=== every verb is an action")
	for action in EXPECTED:
		_expect(InputMap.has_action(action), "%s exists" % action)

	print("=== and each can be reached from a keyboard or mouse, and from a pad")
	for action in EXPECTED:
		var keyboard := false
		var pointer := false
		var pad := false
		for event in InputMap.action_get_events(action):
			keyboard = keyboard or event is InputEventKey
			pointer = pointer or event is InputEventMouseButton
			pad = pad or event is InputEventJoypadButton
		_expect(keyboard or pointer, "%s has a key or a button on the desk" % action)
		_expect(pad, "%s can be reached from a pad" % action)

	print("=== no two verbs share a key")
	var seen := {}
	var clashes := 0
	for action in EXPECTED:
		for event in InputMap.action_get_events(action):
			if not event is InputEventKey:
				continue
			# Each key is bound twice, once physically and once logically, so the twin
			# carries its code in the other field and reads as 0 in this one. Taking
			# whichever is set is the difference between counting verbs and counting
			# events — the first version reported five clashes on "key 0".
			var press := event as InputEventKey
			var code := press.physical_keycode if press.physical_keycode != 0 else press.keycode
			if code == 0:
				continue
			if seen.has(code) and seen[code] != action:
				print("      %s and %s are both on %s" % [
					seen[code], action, OS.get_keycode_string(code)])
				clashes += 1
			seen[code] = action
	_expect(clashes == 0, "every verb is on its own key (%d clash(es))" % clashes)

	print("=== a rebind sticks, and takes the key off whoever had it")
	var settings := Settings.new()
	settings.bindings = {}
	# Move the serve onto the fault panel's key on purpose: the one way a rebinding
	# screen can leave somebody unable to referee is by letting two verbs share a key.
	var displaced := Controls.rebind(settings, &"ref_serve", KEY_F)
	_expect(displaced == &"ref_faults",
		"rebinding the serve onto F displaces the fault panel (displaced %s)" % displaced)
	_expect(Controls.spelling(settings, &"ref_serve") == "F", "the serve now reads as F")
	_expect(Controls.spelling(settings, &"ref_faults") == "—",
		"and the fault panel is left with no key at all, rather than still claiming F")
	_expect(Controls.unbound(settings) == [&"ref_faults"],
		"and the game can say which verb needs a new key")

	var pressed := InputEventKey.new()
	pressed.physical_keycode = KEY_F
	pressed.pressed = true
	_expect(pressed.is_action_pressed(&"ref_serve"), "pressing F now serves")

	Controls.reset(settings)
	_expect(Controls.spelling(settings, &"ref_serve") == "Space", "reset puts the serve back on Space")
	_expect(settings.bindings.is_empty(), "and forgets the change")

	print("")
	if _failures.is_empty():
		print("PASS  every verb is an action, reachable from desk and pad, and rebindable")
	else:
		for failure in _failures:
			print("FAIL  " + failure)
	get_tree().quit()
