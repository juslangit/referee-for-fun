extends Node

## The first thing the game does, and the only scene the project starts on.
##
## Until 2026-09-17 the project started straight on `match.tscn`, which builds the hall,
## the court, the stands and everybody in them inside its `_ready()`. Measured, that is
## 206 ms to read the scene off disk and **1,326 ms to build it** — the better part of two
## seconds during which the window exists and is blank, because nothing can draw while
## `_ready()` is running. There was no boot splash either, so the very first moment was a
## black rectangle.
##
## Luqman asked for "a proper loading screen and starting screen like every game out
## there", and chose the full sequence:
##
##   1. the boot splash    drawn by the engine itself, before any script runs
##   2. this loading screen, with a bar and the step it is on
##   3. a title card that waits for a key
##   4. the menu
##
## ### Why this sits on top rather than in the middle
##
## The obvious way to write this is to have the boot scene own the match and hand over
## when it is ready. That would mean `match.gd._ready()` no longer opening the menu, which
## would mean every one of the ninety-odd checks that loads `match.tscn` and expects a
## menu would have to learn the new order. So the match is left exactly as it was — it
## still builds itself and still opens its own menu — and everything here is drawn on a
## CanvasLayer *above* it. The player never sees the menu it opened, because this is in
## front of it until they press a key.
##
## The one thing that has to be handled rather than ignored: the menu underneath is real,
## and since 2026-09-17 it focuses a button when it opens. A focused Button eats
## `ui_accept`, so "press any key" would have pressed PLAY on its way through. Focus is
## taken off it while the card is up and given back after.

const LOAD_SHARE := 0.55   ## how much of the bar the threaded read is worth

## What the bar says it is doing. The second one is where the time actually goes, and it
## is named honestly rather than split into invented steps: `match.tscn` builds in a
## single blocking `_ready()`, so the bar genuinely does stop there.
const READING := "Reading the hall"
const BUILDING := "Building the hall"
const READY := "Ready"

var _layer: CanvasLayer
var _screen: Control
var _ground: ColorRect
var _bar: ProgressBar
var _step: Label
var _press: Label
var _card: Control
var _loading: Control
var _hall: Node
var _waiting := false
var _pulse := 0.0


func _ready() -> void:
	_build_screen()
	await _load_the_hall()
	_show_the_card()


# --- the screen -------------------------------------------------------------------

func _build_screen() -> void:
	_layer = CanvasLayer.new()
	_layer.name = "Boot"
	# Above everything the match puts up, including its own menu.
	_layer.layer = 100
	add_child(_layer)

	_screen = Control.new()
	_screen.name = "BootScreen"
	_screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	# Nothing underneath is clickable until this is gone.
	_screen.mouse_filter = Control.MOUSE_FILTER_STOP
	_layer.add_child(_screen)

	# Opaque while there is nothing behind it worth seeing, and it does not stay that way
	# — see `_show_the_card()`.
	_ground = ColorRect.new()
	_ground.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ground.color = Color(0.043, 0.051, 0.066)
	_ground.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_screen.add_child(_ground)

	var middle := VBoxContainer.new()
	middle.set_anchors_preset(Control.PRESET_FULL_RECT)
	middle.alignment = BoxContainer.ALIGNMENT_CENTER
	middle.add_theme_constant_override("separation", 26)
	middle.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_screen.add_child(middle)

	var logo := TextureRect.new()
	logo.name = "BootLogo"
	logo.texture = load(RefereeUI.TITLE_LOGO)
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo.custom_minimum_size = Vector2(0, 120)
	logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	middle.add_child(logo)

	var tagline := UiTheme.label(
		"You are the umpire. The game knows the truth. You do not have to tell it.",
		UiTheme.BODY, UiTheme.MUTED)
	tagline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	middle.add_child(tagline)

	# --- what is on screen while it loads.
	_loading = VBoxContainer.new()
	_loading.name = "Loading"
	_loading.add_theme_constant_override("separation", 12)
	middle.add_child(_loading)

	var bar_row := HBoxContainer.new()
	bar_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_loading.add_child(bar_row)
	_bar = ProgressBar.new()
	_bar.name = "BootBar"
	_bar.custom_minimum_size = Vector2(460, 10)
	_bar.min_value = 0.0
	_bar.max_value = 1.0
	_bar.value = 0.0
	_bar.show_percentage = false
	var track := StyleBoxFlat.new()
	track.bg_color = Color(1.0, 1.0, 1.0, 0.10)
	var fill := StyleBoxFlat.new()
	fill.bg_color = UiTheme.ACCENT
	_bar.add_theme_stylebox_override("background", track)
	_bar.add_theme_stylebox_override("fill", fill)
	bar_row.add_child(_bar)

	_step = UiTheme.label(READING, UiTheme.SMALL, UiTheme.MUTED)
	_step.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_loading.add_child(_step)

	# --- and what replaces it when there is nothing left to wait for.
	_card = VBoxContainer.new()
	_card.name = "TitleCard"
	_card.visible = false
	_card.add_theme_constant_override("separation", 0)
	middle.add_child(_card)
	var breath := Control.new()
	breath.custom_minimum_size = Vector2(0, 34)
	breath.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.add_child(breath)
	_press = UiTheme.label("PRESS ANY KEY", UiTheme.HEADING, UiTheme.CHALK, UiTheme.heavy())
	_press.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_card.add_child(_press)


# --- the loading ------------------------------------------------------------------

## Reading the file is threaded and reports real progress. Building it is not, and
## pretending otherwise would be the one dishonest thing this screen could do.
func _load_the_hall() -> void:
	var path := "res://scenes/match.tscn"
	ResourceLoader.load_threaded_request(path, "", true)
	var progress: Array[float] = []
	while true:
		var state := ResourceLoader.load_threaded_get_status(path, progress)
		if state == ResourceLoader.THREAD_LOAD_LOADED:
			break
		if state == ResourceLoader.THREAD_LOAD_FAILED or state == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			_step.text = "Could not read the hall"
			return
		_bar.value = (progress[0] if not progress.is_empty() else 0.0) * LOAD_SHARE
		await get_tree().process_frame
	_bar.value = LOAD_SHARE

	# Say what is about to happen, and let a frame go by *before* starting the work that
	# stops frames happening at all. Without this the player reads "Reading the hall" for
	# the whole of the build and then sees "Ready" flash.
	#
	# Two process frames rather than `RenderingServer.frame_post_draw`, which was the first
	# attempt and is a trap: with nothing being drawn — a headless run, and so every check
	# that would ever exercise this — that signal never fires at all and the whole opening
	# sequence waits for it for ever. The game's way in must not hang on something that
	# can fail to happen. `_boot` caught it by timing out after 1,200 frames.
	_step.text = BUILDING
	await get_tree().process_frame
	await get_tree().process_frame

	var scene: PackedScene = ResourceLoader.load_threaded_get(path)
	_hall = scene.instantiate()
	add_child(_hall)
	await get_tree().process_frame

	_bar.value = 1.0
	_step.text = READY


# --- the title card ---------------------------------------------------------------

## The hall is standing by the time this runs — it was built two steps ago. Holding an
## opaque rectangle over it would throw away the one thing that makes a title card look
## like a game's title card rather than a dialog box, so the black lifts and the court
## comes through behind the type. Not all the way: the shade that is left is what keeps
## the logo readable, and it matches the ramp the main menu draws over the same view.
##
## The menu has to be put away first, and finding that out was the whole point of looking
## at a picture of this rather than trusting that it worked. `match.gd._ready()` opens the
## title screen, which draws the same logo and the same tagline this card does — so the
## first time the black lifted, the shot came back with **two logos, two taglines and
## five ghost buttons** showing through PRESS ANY KEY. Nothing was broken and nothing
## errored; it simply looked terrible, which no check would ever have said.
##
## `hide_main_menu()` rather than `hide_menus()`, because the latter also brings the match
## HUD up, and takes the focus with it so that a focused button cannot eat the key press
## this card is waiting for.
func _show_the_card() -> void:
	_loading.visible = false
	_card.visible = true
	_waiting = true
	if _hall != null and _hall.ui != null:
		_hall.ui.hide_main_menu()
	var lift := create_tween()
	lift.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	lift.tween_property(_ground, "color:a", 0.62, 0.45)


func _process(delta: float) -> void:
	if not _waiting:
		return
	# A slow breath rather than a blink: it should read as the game waiting for you, not
	# as something flashing for attention.
	_pulse += delta * 2.2
	_press.modulate.a = 0.45 + 0.55 * (0.5 + 0.5 * sin(_pulse))


func _unhandled_input(event: InputEvent) -> void:
	if not _waiting:
		return
	if not _is_a_press(event):
		return
	get_viewport().set_input_as_handled()
	_begin()


## Any key, any button, any pad — but only the moment it goes down, and not the mouse
## simply moving across the card.
func _is_a_press(event: InputEvent) -> bool:
	if event is InputEventKey and event.pressed and not event.echo:
		return true
	if event is InputEventMouseButton and event.pressed:
		return true
	if event is InputEventJoypadButton and event.pressed:
		return true
	return false


## Out of the way, and hand the keyboard to the menu that has been sitting underneath
## this the whole time.
func _begin() -> void:
	_waiting = false
	var fade := create_tween()
	fade.tween_property(_screen, "modulate:a", 0.0, 0.22)
	await fade.finished
	_layer.visible = false
	_screen.visible = false
	if _hall != null and _hall.ui != null:
		_hall.ui.show_main_menu(_hall.career)


## Whether the card is still waiting to be dismissed. For the checks.
func is_waiting() -> bool:
	return _waiting
