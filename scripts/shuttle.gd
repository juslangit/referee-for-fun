class_name Shuttle
extends RigidBody3D

## A shuttlecock, and the reason this game can exist.
##
## A shuttle does not fly like a ball. It leaves the racket very fast, is slowed
## down almost immediately by enormous drag, and then falls nearly straight down at
## a fixed speed. That shape of flight is exactly what makes badminton judgeable
## from a chair — the shuttle drops steeply onto the line instead of skidding
## across it — and it is what produces close calls worth lying about.
##
## Godot's built-in damping is linear, which would give a lazy floating arc. Real
## drag rises with the SQUARE of speed, so a smash is punished hard and a slow drop
## is barely slowed at all. That difference is the whole character of the flight,
## so the drag is applied by hand below.

## Emitted the instant the shuttle touches the floor, with the exact point it hit.
signal landed(point: Vector3)

## A real shuttlecock weighs about 5 grams.
const MASS := 0.005

## How fast a shuttle falls once drag balances gravity — about 6.8 m/s. No matter
## how hard it was hit, it will never come down faster than this. Every drag number
## in this file is derived from it, so this is the one value to tune by feel.
const TERMINAL_VELOCITY := 6.8

## Roughly the radius of the skirt, used for collision with the net and walls.
const RADIUS := 0.033

## How far the tip of the cork sits ahead of the shuttle's centre.
##
## A shuttle always lands cork first, so the cork tip is the part that touches the
## floor and therefore the part that is in or out. Judging from the centre of the
## body instead would misplace the landing by around 5 cm — on a court decided by a
## 4 cm line, that is the difference between a correct call and an accidental lie.
const CORK_TIP_OFFSET := 0.049

## Physics layers. The shuttle deliberately does not collide with the floor: the
## landing point is worked out below, exactly, rather than left to a collision that
## has already destroyed the velocity by the time it can be read.
const LAYER_WORLD := 1
const LAYER_FLOOR := 2
const LAYER_SHUTTLE := 4

## Below this speed the shuttle has effectively stopped and is left alone.
const REST_SPEED := 0.05

var has_landed := false
var landing_point := Vector3.ZERO

## How fast the shuttle was travelling when it hit the floor. Captured at the moment
## of impact rather than sampled from outside, which would always be a frame stale.
var landing_speed := 0.0

## Height of the surface the shuttle will land on — the top of the court mat.
var floor_height := Court.MAT_THICKNESS

var _drag_factor := 0.0
var _previous_tip := Vector3.ZERO


func _ready() -> void:
	mass = MASS
	# A 5 gram object moving at 100 m/s crosses a metre and a half between physics
	# ticks, so it must be swept against geometry rather than teleported through it.
	continuous_cd = true
	can_sleep = false

	# Godot applies a small default linear damping to every rigid body. Left on, it
	# quietly drags the shuttle's fall speed below the terminal velocity declared
	# above — so the flight would no longer match the one number it is tuned by.
	# Replace it with nothing and let the quadratic drag below do all the work.
	collision_layer = LAYER_SHUTTLE
	collision_mask = LAYER_WORLD

	linear_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	linear_damp = 0.0
	angular_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	angular_damp = 0.0
	_build_body()
	_build_collision()

	# Drag force is -k * |v| * v. At terminal velocity that force exactly cancels
	# weight, so k = m * g / v_terminal^2. Deriving it this way means the flight is
	# tuned by naming a fall speed, not by guessing at a drag coefficient.
	var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)
	_drag_factor = MASS * gravity / (TERMINAL_VELOCITY * TERMINAL_VELOCITY)

	_previous_tip = _cork_tip()


## Puts the shuttle in the air and hits it.
func launch(from: Vector3, velocity: Vector3) -> void:
	has_landed = false
	freeze = false
	global_position = from
	linear_velocity = velocity
	if velocity.length_squared() > 0.0:
		_point_cork_first(velocity)
	_previous_tip = _cork_tip()
	angular_velocity = Vector3.ZERO


func _physics_process(_delta: float) -> void:
	if has_landed:
		return

	var velocity := linear_velocity
	var speed := velocity.length()

	if speed > REST_SPEED:
		apply_central_force(-_drag_factor * speed * velocity)
		_point_cork_first(velocity)

	_check_for_landing()


## A shuttle always turns to fly cork first, within a few hundredths of a second of
## being hit. Purely cosmetic, but without it the thing reads as a dart, not a bird.
func _point_cork_first(velocity: Vector3) -> void:
	var direction := velocity.normalized()
	# look_at points the node's -Z down the given direction, and the cork is modelled
	# at -Z. When the shuttle is falling almost straight down, "up" is ambiguous and
	# has to be swapped for another reference — otherwise the shuttle refuses to turn
	# at all and its cork stays pointing sideways, putting the landing point 5 cm off.
	var reference := Vector3.UP if absf(direction.dot(Vector3.UP)) < 0.999 else Vector3.FORWARD
	look_at(global_position + direction, reference)


## The very tip of the cork, in world space. The cork is modelled at -Z and the
## shuttle turns to fly cork first, so -Z is always the leading point.
func _cork_tip() -> Vector3:
	return global_position - global_transform.basis.z * CORK_TIP_OFFSET


## Works out where the cork crossed the floor, rather than where it happened to be
## at the end of a physics tick.
##
## This matters more than it looks. Even at 120 ticks a second a fast shuttle moves
## most of a metre between frames, so simply reading its position on the frame after
## it went through the floor could misplace the landing by that much — in a game
## judged against a 4 cm line, that would be nonsense. So the exact moment the cork
## crossed the floor is solved for, and the position at that moment is the landing.
func _check_for_landing() -> void:
	var tip := _cork_tip()
	var previous := _previous_tip
	_previous_tip = tip

	# Only a crossing counts: the cork was above the floor last frame and is at or
	# below it now.
	if previous.y <= floor_height or tip.y > floor_height:
		return

	var crossing := 1.0
	if not is_equal_approx(previous.y, tip.y):
		crossing = clampf((previous.y - floor_height) / (previous.y - tip.y), 0.0, 1.0)

	var contact := previous.lerp(tip, crossing)
	landing_point = Vector3(contact.x, floor_height, contact.z)
	landing_speed = linear_velocity.length()
	has_landed = true

	# Stop dead. A real shuttle barely bounces, and more importantly the landing
	# point has already been recorded — anything it does afterwards is decoration.
	freeze = true
	global_position += landing_point - contact
	landed.emit(landing_point)


## Ends the flight where the shuttle currently is, whether or not it reached the
## floor. Only for the case where it has come to rest against something — caught in
## the net, most likely — because a rally that never finishes is worse than one that
## finishes oddly.
func force_landing() -> void:
	if has_landed:
		return
	var tip := _cork_tip()
	landing_point = Vector3(tip.x, floor_height, tip.z)
	landing_speed = linear_velocity.length()
	has_landed = true
	freeze = true
	landed.emit(landing_point)


func _build_body() -> void:
	var cork_material := StandardMaterial3D.new()
	cork_material.albedo_color = Color(0.85, 0.80, 0.68)
	var skirt_material := StandardMaterial3D.new()
	skirt_material.albedo_color = Color(0.97, 0.97, 0.95)

	var cork := MeshInstance3D.new()
	cork.name = "Cork"
	var cork_mesh := SphereMesh.new()
	cork_mesh.radius = 0.014
	cork_mesh.height = 0.028
	cork.mesh = cork_mesh
	cork.position = Vector3(0.0, 0.0, -0.035)
	cork.material_override = cork_material
	add_child(cork)

	var skirt := MeshInstance3D.new()
	skirt.name = "Skirt"
	var skirt_mesh := CylinderMesh.new()
	skirt_mesh.top_radius = 0.014
	skirt_mesh.bottom_radius = RADIUS
	skirt_mesh.height = 0.07
	skirt.mesh = skirt_mesh
	# The cylinder is built along Y; tip it so its narrow end points down -Z, level
	# with the cork.
	skirt.rotation = Vector3(deg_to_rad(-90.0), 0.0, 0.0)
	skirt.material_override = skirt_material
	add_child(skirt)


func _build_collision() -> void:
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = RADIUS
	shape.shape = sphere
	add_child(shape)
