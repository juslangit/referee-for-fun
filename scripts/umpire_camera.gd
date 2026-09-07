class_name UmpireCamera
extends Camera3D

## The player's eyes, and the only thing they control directly.
##
## An umpire does not walk. They sit in the chair for the whole match and turn their
## head, which is why there is no movement code here at all — only looking. That
## constraint is the point: you cannot go and inspect where the shuttle landed, so
## you have to judge it from one fixed seat, exactly like the real job.

## How fast the view turns, in radians per pixel of mouse movement.
@export var sensitivity := 0.0022

## Which way the chair faces when the player is looking straight ahead. The chair
## stands on the +X side of the court, so straight ahead is towards -X.
@export var facing_deg := 90.0

## How far the umpire can turn their head to either side before it stops.
@export var yaw_limit_deg := 110.0

## How far up and down they can look.
@export var pitch_min_deg := -70.0
@export var pitch_max_deg := 25.0

## Where the view starts: angled slightly down at the court.
@export var start_pitch_deg := -24.0

var _yaw := 0.0
var _pitch := 0.0
var _looking := false


func _ready() -> void:
	_pitch = deg_to_rad(start_pitch_deg)
	_apply_rotation()
	_set_looking(true)


func _unhandled_input(event: InputEvent) -> void:
	# Escape lets go of the mouse so the window can be left. Clicking takes it back.
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_set_looking(false)
		return

	if event is InputEventMouseButton and event.pressed and not _looking:
		_set_looking(true)
		return

	if event is InputEventMouseMotion and _looking:
		_yaw -= event.relative.x * sensitivity
		_pitch -= event.relative.y * sensitivity
		_yaw = clampf(_yaw, -deg_to_rad(yaw_limit_deg), deg_to_rad(yaw_limit_deg))
		_pitch = clampf(_pitch, deg_to_rad(pitch_min_deg), deg_to_rad(pitch_max_deg))
		_apply_rotation()


func _set_looking(looking: bool) -> void:
	_looking = looking
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if looking else Input.MOUSE_MODE_VISIBLE


func _apply_rotation() -> void:
	rotation = Vector3(_pitch, deg_to_rad(facing_deg) + _yaw, 0.0)
