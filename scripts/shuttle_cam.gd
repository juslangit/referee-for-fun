class_name ShuttleCam
extends Node3D

## A camera on the line, of the kind used for television. It is shown to the player
## in the corner of the screen once the shuttle has landed.
##
## The important thing about it is where it stands. It sits **on the line itself**,
## a few metres back and barely above the floor, looking straight down it — which is
## exactly where a real line camera goes, and it means the picture is honest without
## being helpful. A shuttle that missed by a metre is unmissable. One that missed by
## two centimetres is about two pixels off the line in a small picture, and no amount
## of squinting will settle it.
##
## That is not a trick played on the player. It is the same problem the umpire has
## from the chair, and the camera only takes away the easy excuses.

## Deliberately small. A bigger picture would resolve the close ones and hand the
## player the answer the whole game is built on withholding.
const WIDTH := 384
const HEIGHT := 216

## How far back down the line the camera sits, and how low to the floor.
##
## Close enough that the shuttle is easy to find in the picture, which it was not at
## three metres — a white shuttle against a white line at that range is impossible to
## pick out. Moving nearer does not give the close calls away: what makes them hard
## is that the camera is looking *along* the line, so a shuttle two centimetres off
## it is a couple of pixels off it at any distance you like.
const DISTANCE := 2.35
const EYE_HEIGHT := 0.36

const FIELD_OF_VIEW := 32.0

## The line camera draws the court and the shuttle and nothing else. A camera this
## low spends most of a match looking at somebody's legs, and a picture of a player's
## shin settles no line call at all. Leaving people out is the same choice a
## television replay makes, and it changes nothing about how hard the close ones are
## to read — that comes from where the camera stands, not from what is in the way.
const COURT_ONLY := 1

var viewport: SubViewport
var camera: Camera3D


func _ready() -> void:
	viewport = SubViewport.new()
	viewport.name = "ShuttleCamViewport"
	viewport.size = Vector2i(WIDTH, HEIGHT)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.handle_input_locally = false
	add_child(viewport)

	camera = Camera3D.new()
	camera.name = "LineCamera"
	camera.fov = FIELD_OF_VIEW
	camera.cull_mask = COURT_ONLY
	camera.current = true
	viewport.add_child(camera)

	# Look at the same court everyone else is looking at, rather than an empty one.
	viewport.world_3d = get_viewport().find_world_3d()


func texture() -> ViewportTexture:
	return viewport.get_texture()


## Puts the camera on whichever line the shuttle came closest to, looking along it.
func aim_at(point: Vector3) -> void:
	var slack_x := CourtSpec.HALF_WIDTH_DOUBLES - absf(point.x)
	var slack_z := CourtSpec.HALF_LENGTH - absf(point.z)

	var eye: Vector3
	if absf(slack_x) <= absf(slack_z):
		# Nearest a sideline: sit on that line, back towards the near end.
		var line_x := CourtSpec.HALF_WIDTH_DOUBLES * signf(point.x)
		var back := signf(point.z) if not is_zero_approx(point.z) else 1.0
		eye = Vector3(line_x, EYE_HEIGHT, point.z + back * DISTANCE)
	else:
		# Nearest a back line: sit on that line, off to one side.
		var line_z := CourtSpec.HALF_LENGTH * signf(point.z)
		var side := signf(point.x) if not is_zero_approx(point.x) else 1.0
		eye = Vector3(point.x + side * DISTANCE, EYE_HEIGHT, line_z)

	camera.global_position = eye
	camera.look_at(point + Vector3(0.0, 0.035, 0.0), Vector3.UP)
