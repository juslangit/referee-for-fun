class_name MenuCamera
extends Camera3D

## What sits behind the menus.
##
## The front of the game used to be the umpire's own view with a dark sheet over it,
## which reads as a paused match rather than as a title screen — you are looking at the
## chair you have not sat down in yet, and half the frame is the back of a player's head.
##
## This drifts slowly round the hall instead, high and wide, so the menus sit over the
## building rather than over the game. Slow enough that it is not a camera move, only a
## room that will not quite hold still: a full turn takes about four minutes, which
## nobody watches to the end and everybody notices.

## How far out it sits, how high, and what it looks at.
##
## The radius has to keep it inside the building. The hall is not centred on the court —
## it runs from -13.5 to +27 along X to hold the second court — so a wide circle round
## the origin leaves the room on one side and photographs the outside of a wall.
const RADIUS := 12.6
const HEIGHT := 7.6
const LOOKING_AT := Vector3(1.5, 0.9, 0.0)

## It sweeps back and forth across one side rather than going all the way round. Half a
## circuit of a badminton hall is the back of a stand, and the other half is the court —
## there is no reason to spend a minute of the title screen looking at the wrong one.
## Over the near stand on the far side, looking back across the crowd at the court. It
## is the angle every broadcast opens on, and it puts the people in the foreground where
## the menu card is not covering them — the first attempt looked down at an empty floor
## with everything worth seeing hidden behind the panel.
const CENTRE_ANGLE := -PI * 0.5
const SWEEP := 0.44
const SWEEP_SECONDS := 54.0

## How far it rises and falls, and how long that takes.
const BOB := 0.55
const BOB_SECONDS := 23.0

var _clock := 0.0


func _ready() -> void:
	fov = 58.0
	_place()


func _process(delta: float) -> void:
	if not current:
		return
	_clock += delta
	_place()


func _place() -> void:
	var angle := CENTRE_ANGLE + sin(_clock / SWEEP_SECONDS * TAU) * SWEEP
	var rise := sin(_clock / BOB_SECONDS * TAU) * BOB
	global_position = Vector3(
		sin(angle) * RADIUS,
		HEIGHT + rise,
		cos(angle) * RADIUS
	)
	look_at(LOOKING_AT, Vector3.UP)
