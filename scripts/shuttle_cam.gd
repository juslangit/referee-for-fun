class_name ShuttleCam
extends Node3D

## A camera looking straight down at the spot where the shuttle came to rest, shown to
## the player in the corner of the screen. Close, square, and orthographic, so the
## shuttle's position against the line is exact rather than a matter of perspective.
##
## This replaced a camera that sat on the line itself, barely above the floor, looking
## down it — a real television line camera, and honest without being helpful: a shuttle
## two centimetres out was about two pixels off the line and no amount of squinting
## would settle it. That was deliberate, and Luqman asked for the opposite: a close
## view from above where you can see exactly where it landed.
##
## It changes what the game is about, and for the better, I think. The question stops
## being "can you tell?" and becomes "you can tell, and you are going to say something
## else anyway" — which is the harder version of the same choice, and the one the rest
## of the game was already built to price.
##
## Orthographic on purpose. A perspective lens above a shuttle sitting beside a line
## makes the near edge of the line look wider than the far edge, and the whole point of
## the picture is that it does not lie about distances.

## Big enough to read. The old picture was small deliberately; this one is not, because
## a picture you have to squint at is exactly what it is here to replace.
const WIDTH := 440
const HEIGHT := 440

## How much of the floor the frame covers, in metres, and how high the camera hovers.
##
## A shade over a metre. Wide enough that the nearest line is still in shot for any call
## worth arguing about — half a metre either side of the shuttle — and no wider, because
## every centimetre of extra floor makes the shuttle itself smaller, and the shuttle is
## what the picture is for. At this framing a two-centimetre miss is about eight pixels
## of clear green between the shuttle and the line.
const VIEW_METRES := 1.12
const HOVER := 3.0

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
	camera.name = "OverheadCamera"
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = VIEW_METRES
	# The court and the shuttle and nothing else. Directly above a landing, a player
	# standing over the shuttle would otherwise be the entire picture — which settles no
	# line call at all, and is the same choice a television replay makes.
	camera.cull_mask = COURT_ONLY
	camera.near = 0.05
	camera.far = HOVER + 1.0
	camera.current = true
	viewport.add_child(camera)

	# Look at the same court everyone else is looking at, rather than an empty one.
	viewport.world_3d = get_viewport().find_world_3d()


func texture() -> ViewportTexture:
	return viewport.get_texture()


## Hangs the camera directly over the shuttle, looking straight down.
##
## Always the same height and always the same framing, however far out the shuttle went.
## The old camera backed away from a shuttle that had missed by a lot, on the grounds
## that an obvious call does not need magnifying. This one does not: a picture whose
## scale changes shot to shot teaches the player to read the zoom level instead of the
## line, and the zoom level would be telling them the answer.
func aim_at(point: Vector3) -> void:
	camera.global_position = Vector3(point.x, HOVER, point.z)
	# Looking down, with the far end of the court at the top of the picture, so the
	# view is oriented the same way every time rather than spinning with the landing.
	camera.look_at(Vector3(point.x, 0.0, point.z), Vector3.FORWARD)
