class_name UiSound
extends Node

## The menus, heard: a tick when the pointer comes onto a button and a click when it is
## pressed.
##
## Every button in the game is built in code, in a dozen places across the menus, the
## career ladder, the settings sheet, the fault panel and the paper. Wiring a sound into
## each would mean remembering it in the next one too. So this watches the tree instead
## and takes every button as it arrives — including the ones a screen builds later.

const HOVER := "res://assets/audio/ui/ui_hover.ogg"
const PRESS := "res://assets/audio/ui/ui_press.ogg"

## Quieter than anything on court. A menu that clicks loudly is a menu that feels cheap.
const HOVER_DB := -24.0
const PRESS_DB := -12.0

## Everything this has played, counted, for `dev/checks/_everysound`.
var heard := {}

var _hover: AudioStreamPlayer
var _press: AudioStreamPlayer


func _ready() -> void:
	# Menus are used while the match is paused, which is exactly when the rest of the
	# tree is not running.
	process_mode = Node.PROCESS_MODE_ALWAYS
	Settings.ensure_buses()
	_hover = _player(HOVER, HOVER_DB)
	_press = _player(PRESS, PRESS_DB)
	get_tree().node_added.connect(_take)
	_take_all(get_parent())


func _player(path: String, level: float) -> AudioStreamPlayer:
	var player := AudioStreamPlayer.new()
	player.name = path.get_file().get_basename()
	if ResourceLoader.exists(path):
		player.stream = load(path)
	player.volume_db = level
	player.bus = Settings.EFFECTS_BUS
	player.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(player)
	return player


func _take_all(node: Node) -> void:
	_take(node)
	for child in node.get_children():
		_take_all(child)


## Only the buttons of the screen this belongs to. A development scene can hold two
## matches at once, and each should click for its own.
func _take(node: Node) -> void:
	var button := node as BaseButton
	if button == null or button.pressed.is_connected(_on_press):
		return
	if not get_parent().is_ancestor_of(button):
		return
	button.mouse_entered.connect(_on_hover.bind(button))
	button.pressed.connect(_on_press)


func _on_hover(button: BaseButton) -> void:
	if button.disabled or not button.is_visible_in_tree():
		return
	heard[&"hover"] = int(heard.get(&"hover", 0)) + 1
	if _hover.stream != null:
		_hover.play()


func _on_press() -> void:
	heard[&"press"] = int(heard.get(&"press", 0)) + 1
	if _press.stream != null:
		_press.play()
