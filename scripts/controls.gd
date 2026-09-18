class_name Controls
extends RefCounted

## Every verb the umpire has, in one place, for the keyboard, the mouse and the pad.
##
## Until 2026-09-18 the game had **no input actions at all**. Six match scripts each
## compared `event.keycode` against a hard-coded `KEY_` constant, so the same verb was
## spelled out separately in every sport — SPACE to serve appeared twelve times, F for
## the fault panel six — and nothing could be rebound or reached from a controller,
## because there was nothing to rebind and nothing to map a button to.
##
## The actions are installed at run time rather than written into `project.godot`. Two
## reasons. Rebinding has to happen at run time anyway, so this is the same code path
## rather than a second one; and every check in `dev/checks` loads a match scene directly
## rather than booting the game, so an action that only existed in the project settings
## would be there for a player and missing for the ninety-odd scenes that drive the game
## without one. `ensure()` is idempotent and is called from both.
##
## What each verb is, and why it is bound the way it is:
##
##   pause          ESC, and Start on a pad. The one verb that must never be rebound to
##                  something a player cannot find again, so it is not offered.
##   serve          SPACE. The most-pressed key in the game, so it gets the pad's A.
##   call_in/out    the mouse buttons, because pointing at the floor and saying what
##                  happened there is the gesture the whole game is built on. On a pad
##                  they are the shoulders: left and right, like the two sides of a court.
##   let            L. Badminton, tennis and table tennis.
##   touch          T. Both volleyballs and sepak takraw.
##   faults         F, the panel that names an offence.
##   service_court  W, badminton's service court error, and the only verb one sport has
##                  entirely to itself.

## What a verb is set to when it has been displaced and not yet given a new key. Stored
## rather than left blank, because "no key" and "never changed" must not look the same.
const UNBOUND := 0


## The default binding for every verb. `keys` and `buttons` are lists so that a verb can
## answer to more than one thing without the rebinding screen having to know that.
const DEFAULTS := {
	&"ref_pause": {"keys": [KEY_ESCAPE], "buttons": [JOY_BUTTON_START], "label": "Pause", "fixed": true},
	&"ref_serve": {"keys": [KEY_SPACE], "buttons": [JOY_BUTTON_A], "label": "Serve"},
	&"ref_call_in": {"mouse": [MOUSE_BUTTON_LEFT], "buttons": [JOY_BUTTON_LEFT_SHOULDER], "label": "Call IN"},
	&"ref_call_out": {"mouse": [MOUSE_BUTTON_RIGHT], "buttons": [JOY_BUTTON_RIGHT_SHOULDER], "label": "Call OUT"},
	&"ref_let": {"keys": [KEY_L], "buttons": [JOY_BUTTON_Y], "label": "Let"},
	&"ref_touch": {"keys": [KEY_T], "buttons": [JOY_BUTTON_Y], "label": "Touch"},
	&"ref_faults": {"keys": [KEY_F], "buttons": [JOY_BUTTON_X], "label": "Fault panel"},
	&"ref_service_court": {"keys": [KEY_W], "buttons": [JOY_BUTTON_B], "label": "Service court"},
}

## The order the rebinding screen lists them in: most-pressed first, and the one that
## cannot be changed left off the end rather than shown greyed out.
const ORDER := [&"ref_serve", &"ref_call_in", &"ref_call_out", &"ref_let", &"ref_touch",
	&"ref_faults", &"ref_service_court"]


## Puts every action into the InputMap if it is not there already, and applies whatever
## the player has changed. Safe to call as often as you like.
static func ensure(settings: Settings = null) -> void:
	for action: StringName in DEFAULTS:
		if not InputMap.has_action(action):
			InputMap.add_action(action, 0.2)
			_fit(action, DEFAULTS[action])
	if settings != null:
		apply(settings)


## The player's own bindings over the top of the defaults.
static func apply(settings: Settings) -> void:
	for action: StringName in DEFAULTS:
		if DEFAULTS[action].get("fixed", false):
			continue
		var chosen: int = int(settings.bindings.get(String(action), -1))
		if chosen < 0:
			continue
		_fit(action, DEFAULTS[action], chosen)


## Whether any verb is currently without a key, which the settings screen has to say out
## loud rather than leave the player to discover mid-rally.
static func unbound(settings: Settings) -> Array[StringName]:
	var loose: Array[StringName] = []
	for action in ORDER:
		if int(settings.bindings.get(String(action), -1)) == int(UNBOUND):
			loose.append(action)
	return loose


## Rebinds one verb to one key, keeps it, and reports what it displaced — two verbs on
## the same key is the one way a rebinding screen can leave somebody unable to referee.
static func rebind(settings: Settings, action: StringName, keycode: Key) -> StringName:
	var clash := &""
	for other: StringName in DEFAULTS:
		if other == action or DEFAULTS[other].get("fixed", false):
			continue
		if _key_of(settings, other) == keycode:
			clash = other
			# Left with *no* key, recorded explicitly rather than by forgetting.
			#
			# The first version erased the binding, which sent the displaced verb back to
			# its default — and its default is the very key that was just taken off it. So
			# the settings screen went on saying "Fault panel: F" while F served, and the
			# fault panel could not be opened at all. A verb that has lost its key has to
			# say so and be given a new one.
			settings.bindings[String(other)] = int(UNBOUND)
			_fit(other, DEFAULTS[other], int(UNBOUND))
	settings.bindings[String(action)] = int(keycode)
	_fit(action, DEFAULTS[action], keycode)
	settings.save()
	return clash


## What this verb currently answers to on the keyboard.
static func _key_of(settings: Settings, action: StringName) -> Key:
	var chosen: int = int(settings.bindings.get(String(action), -1))
	if chosen >= 0:
		return chosen as Key  # UNBOUND is 0, which is KEY_NONE, and reads as "—"
	var keys: Array = DEFAULTS[action].get("keys", [])
	return (keys[0] if not keys.is_empty() else KEY_NONE) as Key


## For the settings screen: the key this verb is on, spelled the way a player reads it.
static func spelling(settings: Settings, action: StringName) -> String:
	var key := _key_of(settings, action)
	if key == KEY_NONE:
		var mouse: Array = DEFAULTS[action].get("mouse", [])
		if not mouse.is_empty():
			return "Left click" if int(mouse[0]) == MOUSE_BUTTON_LEFT else "Right click"
		return "—"
	return OS.get_keycode_string(key)


## Puts the events on an action: the default ones, with `instead` replacing the key if a
## player has chosen one. The pad and mouse bindings are never rebound here — a pad has
## its own conventions and the mouse buttons are the game's core gesture.
static func _fit(action: StringName, spec: Dictionary, instead := -1) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action, 0.2)
	InputMap.action_erase_events(action)
	var keys: Array = spec.get("keys", [])
	if instead == int(UNBOUND):
		keys = []
	elif instead > 0:
		keys = [instead]
	for key in keys:
		# Both spellings of the same key, deliberately.
		#
		# `physical_keycode` is the right one for a player: it follows the position of the
		# key on the board, so a verb stays where the hand expects it on AZERTY or Dvorak.
		# But an event that carries only a logical `keycode` — which is what synthetic
		# input looks like, and so every check in this project that presses a key — does
		# not match a physical binding at all. Binding only the physical one took ESC away
		# from the pause menu and `_menuflow` caught it. Binding both costs nothing.
		var physical := InputEventKey.new()
		physical.physical_keycode = key as Key
		InputMap.action_add_event(action, physical)
		var logical := InputEventKey.new()
		logical.keycode = key as Key
		InputMap.action_add_event(action, logical)
	for button in spec.get("mouse", []):
		var click := InputEventMouseButton.new()
		click.button_index = button as MouseButton
		InputMap.action_add_event(action, click)
	for button in spec.get("buttons", []):
		var pad := InputEventJoypadButton.new()
		pad.button_index = button as JoyButton
		InputMap.action_add_event(action, pad)


## Back to how it shipped.
static func reset(settings: Settings) -> void:
	settings.bindings.clear()
	settings.save()
	for action: StringName in DEFAULTS:
		_fit(action, DEFAULTS[action])
