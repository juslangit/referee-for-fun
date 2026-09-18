class_name Settings
extends RefCounted

## What the player has chosen about how the game behaves, and where it is kept.
##
## Written to user:// rather than into the project, because it belongs to whoever is
## sitting at the machine and not to the game. Everything here is applied the moment it
## changes and again on the next launch — a setting you have to restart for is a setting
## people assume is broken.

const PATH := "user://settings.cfg"

## Where a check or a look keeps its settings instead. Harnesses mark lessons as seen and
## change volumes, and until 2026-09-15 they did it to the player's own file.
const DEV_PATH := "user://dev_settings.cfg"


static func path() -> String:
	return DEV_PATH if is_a_dev_run() else PATH


## True when Godot was launched straight into a scene under res://dev/ — a check or a
## look, never the game. Those scenes play whole matches, and every match saves, so
## anything they write goes to a separate file rather than over the player's career
## and settings. The game itself, from the editor or from a build, is never launched
## with a dev scene on its command line.
static func is_a_dev_run() -> bool:
	for arg in OS.get_cmdline_args():
		if arg.begins_with("res://dev/"):
			return true
	return false

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

## Whether the player has been shown how to referee. Kept with the settings rather than
## with the career, because it is a fact about the person at the keyboard: starting a
## second career does not make you forget what a carry is.
## Whether the player has been shown each sport's lesson. Per sport, because knowing
## what a carry looks like tells you nothing whatever about a block touch.
var taught := false
var taught_beach := false
var taught_indoor := false
var taught_tennis := false
var taught_table_tennis := false
var taught_takraw := false

## Which key each verb has been moved to, as action name -> keycode. Empty means the
## game's own defaults, which live in `Controls.DEFAULTS` rather than here: a binding
## only appears in this dictionary once somebody has deliberately changed it, so a
## default that is improved later reaches everybody who never touched it.
var bindings := {}


static func load_or_default() -> Settings:
	var settings := Settings.new()
	var file := ConfigFile.new()
	if file.load(path()) != OK:
		# A check with no settings of its own is somebody who has been taught every sport.
		# That is what the player's file said when every check was written, and the checks
		# still assume it: with the lessons unseen, beach opened on its lesson, and
		# `_everysound` pressed the lesson's BACK, left the scene and hung. A check about
		# the lesson turns it off itself (`dev/looks/_teach`).
		if is_a_dev_run():
			settings.taught = true
			settings.taught_beach = true
			settings.taught_indoor = true
			settings.taught_tennis = true
			settings.taught_table_tennis = true
			settings.taught_takraw = true
		return settings
	settings.master = file.get_value("audio", "master", settings.master)
	settings.crowd = file.get_value("audio", "crowd", settings.crowd)
	settings.effects = file.get_value("audio", "effects", settings.effects)
	settings.sensitivity = file.get_value("look", "sensitivity", settings.sensitivity)
	settings.fullscreen = file.get_value("window", "fullscreen", settings.fullscreen)
	settings.bindings = file.get_value("controls", "bindings", {})
	settings.taught = file.get_value("player", "taught", settings.taught)
	settings.taught_beach = file.get_value("player", "taught_beach", settings.taught_beach)
	settings.taught_indoor = file.get_value(
		"player", "taught_indoor", settings.taught_indoor)
	settings.taught_tennis = file.get_value(
		"player", "taught_tennis", settings.taught_tennis)
	settings.taught_table_tennis = file.get_value(
		"player", "taught_table_tennis", settings.taught_table_tennis)
	settings.taught_takraw = file.get_value("player", "taught_takraw", settings.taught_takraw)
	return settings


func save() -> void:
	var file := ConfigFile.new()
	file.set_value("audio", "master", master)
	file.set_value("audio", "crowd", crowd)
	file.set_value("audio", "effects", effects)
	file.set_value("look", "sensitivity", sensitivity)
	file.set_value("window", "fullscreen", fullscreen)
	file.set_value("player", "taught", taught)
	file.set_value("player", "taught_beach", taught_beach)
	file.set_value("player", "taught_indoor", taught_indoor)
	file.set_value("player", "taught_table_tennis", taught_table_tennis)
	file.set_value("player", "taught_tennis", taught_tennis)
	file.set_value("player", "taught_takraw", taught_takraw)
	file.set_value("controls", "bindings", bindings)
	file.save(path())


## Makes the world match these settings. Safe to call as often as you like.
func apply() -> void:
	ensure_buses()
	# The verbs, and whatever the player has moved them to.
	Controls.ensure(self)
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
