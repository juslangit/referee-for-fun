class_name Settings
extends RefCounted

## What the player has chosen about how the game behaves, and where it is kept.
##
## Written to user:// rather than into the project, because it belongs to whoever is
## sitting at the machine and not to the game. Everything here is applied the moment it
## changes and again on the next launch — a setting you have to restart for is a setting
## people assume is broken.

const PATH := "user://settings.cfg"

## The audio buses the mixer is split into. Godot ships with only a Master, so these are
## made at startup if they are not already there. Three is enough: the crowd is a bed
## that some people will want quieter without losing the whistle, and everything else is
## an event you need to hear.
const CROWD_BUS := "Crowd"
const EFFECTS_BUS := "Effects"

var master := 0.85
var crowd := 0.75
var effects := 0.90

## Radians of head turn per pixel of mouse movement.
var sensitivity := 0.0022
const SENSITIVITY_MIN := 0.0008
const SENSITIVITY_MAX := 0.0055

var fullscreen := false


static func load_or_default() -> Settings:
	var settings := Settings.new()
	var file := ConfigFile.new()
	if file.load(PATH) != OK:
		return settings
	settings.master = file.get_value("audio", "master", settings.master)
	settings.crowd = file.get_value("audio", "crowd", settings.crowd)
	settings.effects = file.get_value("audio", "effects", settings.effects)
	settings.sensitivity = file.get_value("look", "sensitivity", settings.sensitivity)
	settings.fullscreen = file.get_value("window", "fullscreen", settings.fullscreen)
	return settings


func save() -> void:
	var file := ConfigFile.new()
	file.set_value("audio", "master", master)
	file.set_value("audio", "crowd", crowd)
	file.set_value("audio", "effects", effects)
	file.set_value("look", "sensitivity", sensitivity)
	file.set_value("window", "fullscreen", fullscreen)
	file.save(PATH)


## Makes the world match these settings. Safe to call as often as you like.
func apply() -> void:
	ensure_buses()
	_set_bus("Master", master)
	_set_bus(CROWD_BUS, crowd)
	_set_bus(EFFECTS_BUS, effects)

	DisplayServer.window_set_mode(
		DisplayServer.WINDOW_MODE_FULLSCREEN if fullscreen
		else DisplayServer.WINDOW_MODE_WINDOWED
	)


## Creates the two extra buses if this project has never had them. Done in code rather
## than in a .tscn so that a fresh checkout has a working mixer without anybody opening
## the audio tab in the editor.
static func ensure_buses() -> void:
	for name in [CROWD_BUS, EFFECTS_BUS]:
		if AudioServer.get_bus_index(name) >= 0:
			continue
		AudioServer.add_bus()
		var at := AudioServer.bus_count - 1
		AudioServer.set_bus_name(at, name)
		AudioServer.set_bus_send(at, "Master")


static func _set_bus(name: String, amount: float) -> void:
	var at := AudioServer.get_bus_index(name)
	if at < 0:
		return
	# Silence at the bottom of the slider rather than a very quiet sound, and a curve
	# that follows how loudness is actually heard instead of the raw number.
	AudioServer.set_bus_mute(at, amount <= 0.001)
	AudioServer.set_bus_volume_db(at, linear_to_db(maxf(amount, 0.0001)))
