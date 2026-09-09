class_name Ball
extends RigidBody3D

## A beach volleyball, and the source of truth for where it came down.
##
## Same contract as the shuttlecock — launch it, watch it, and it emits `landed` with
## the exact point at which its underside crossed the sand — but almost nothing else
## about it is the same. A shuttlecock is five grams of cork and feathers with more
## drag than any object in sport: hit it hard and it decelerates so violently that its
## path is a hook rather than an arc. A volleyball is 260 grams and nearly a foot
## across, and it flies close to a parabola. **That difference is the whole reason the
## two sports feel different from the chair**: a shuttle's landing is decided in the
## last quarter-second of its flight, while a volleyball's has been obvious to
## everybody in the stand since it left the attacker's hand.
##
## Which is exactly why the interesting beach call is not the line. It is the touch.

signal landed(point: Vector3)

## FIVB: 260 to 280 grams, 66 to 68 cm around. These are the defaults; a subclass sets
## its own before _ready runs, which is how the tennis ball exists without a second copy
## of the flight code.
const MASS := 0.270
const RADIUS := 0.1055

var mass_kg := MASS
var radius := RADIUS

## Drag. Far gentler than a shuttlecock's, but not nothing — a served ball loses a
## noticeable amount of speed over sixteen metres, and a float serve wanders because of
## it. Expressed as the speed at which drag balances gravity, the same as the shuttle,
## so the two are tuned in the same language.
const TERMINAL_VELOCITY := 31.0

var terminal_velocity := TERMINAL_VELOCITY

## Bounce off the sand. A volleyball does bounce, unlike a shuttlecock, and the bounce
## is part of how a beach point reads: the ball lands, kicks up sand, and everybody
## looks at the mark. It is cosmetic for volleyball — the landing point is recorded on
## the way down, before any of it — and it is not cosmetic at all for tennis, where the
## second bounce is a call.
const SAND_BOUNCE := 0.32

var bounce := SAND_BOUNCE

## How many times it has hit the ground since it was launched. Volleyball never asks;
## tennis asks constantly, because a ball that bounces twice before it is reached is the
## point over.
var bounces := 0

## Below this the ball is treated as at rest and stops being pushed around.
const REST_SPEED := 0.05

## How long the ball is allowed to carry on after the point is over.
##
## It is not stopped the instant it lands, because the bounce is how a landing reads —
## the ball hits, the sand kicks up, and everybody looks at the mark. It is stopped a
## moment later, because a ball nobody is playing any more should not still be crossing
## the court while the official decides.
const SETTLE_SECONDS := 1.1

var settle_seconds := SETTLE_SECONDS

## How quickly the ball is brought to a stop after that, per physics tick, and the
## speed below which it is simply put down.
const SETTLE_DAMPING := 0.80
const SETTLE_REST_SPEED := 1.2

## The layer the ball is drawn on. Stated, not defaulted, because the overhead camera
## draws this layer and nothing else, and the ball is the one thing it exists to show.
const COURT_LAYER := 1

var has_landed := false
var landing_point := Vector3.ZERO
var landing_speed := 0.0

## Whether the point is over and the ball is being taken out of play, and how much is
## left of the moment it is given to bounce first.
##
## Two fields rather than one signed countdown, deliberately. A single float that used
## its sign to mean "not stopping" runs its expiry branch for exactly one tick — the tick
## it crosses zero — and is then indistinguishable from a live ball, so the damping below
## was applied once and never again. Beach and indoor happened to be slow enough for that
## one tick to be enough. Tennis was not, and stayed 14 m from its own mark.
var _stopping := false
var _settling := 0.0

## The height the sand is at. Set by the court.
var floor_height := 0.0

var _drag_factor := 0.0
var _previous_bottom := Vector3.ZERO


func _ready() -> void:
	mass = mass_kg
	gravity_scale = 1.0
	continuous_cd = true
	# The only drag on this ball is the one modelled below.
	#
	# Godot combines a body's own damping with the world's `default_linear_damp`, which
	# is 0.1 out of the box, and the solver that aims every shot knows nothing about it.
	# On a shuttlecock that is invisible — its own drag is so violent that a tenth of a
	# unit either way changes nothing — but a volleyball has six times the terminal
	# velocity and stays up for two seconds, and the unmodelled damping was taking a
	# metre and a quarter off a serve aimed at the end line. Against 60 mm of tape.
	linear_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	linear_damp = 0.0
	angular_damp_mode = RigidBody3D.DAMP_MODE_REPLACE
	angular_damp = 0.0
	contact_monitor = false
	can_sleep = false
	# Drag balances gravity at terminal velocity: k v² = m g.
	_drag_factor = (mass_kg * 9.81) / (terminal_velocity * terminal_velocity)
	_build_body()
	_build_collision()
	_draw_on_court_layer()


func launch(from: Vector3, velocity: Vector3) -> void:
	has_landed = false
	bounces = 0
	_stopping = false
	_settling = 0.0
	landing_point = Vector3.ZERO
	freeze = false
	global_position = from
	linear_velocity = velocity
	angular_velocity = Vector3.ZERO
	_previous_bottom = _bottom()


## The ball keeps being simulated after it has landed, which it did not used to.
##
## Volleyball never asks anything of a ball after the first bounce, so this returned
## early and saved the work. Tennis asks constantly: a point ends when the ball bounces
## **twice**, and with the drag and the landing check switched off after the first one
## the second could never be detected. A scripted not-up simply hung the match — the
## ball sat there with `bounces` stuck at one and nothing ever ended the point.
##
## Nothing about volleyball changes: the truth is taken on the way down, on the first
## bounce, and whatever the ball does afterwards cannot reach it.
func _physics_process(delta: float) -> void:
	_settle(delta)
	var velocity := linear_velocity
	var speed := velocity.length()
	if speed > REST_SPEED:
		apply_central_force(-_drag_factor * speed * velocity)

	_check_for_landing()


## The underside of the ball, which is what touches the sand.
##
## A volleyball is 21 cm across, so the difference between its centre and its contact
## point is more than five times the width of the tape it is being judged against.
## Reading the centre would put every close call a whole ball-radius out.
func _bottom() -> Vector3:
	return global_position - Vector3(0.0, radius, 0.0)


## Where the underside crossed the sand, rather than wherever the ball happened to be
## at the end of a physics tick.
##
## The same solve as the shuttlecock's, and needed for the same reason: a spiked ball
## travels at 25 m/s, which is 20 cm between ticks at 120 Hz. Against a 6 cm line that
## is the difference between in and out, decided by nothing but frame timing.
func _check_for_landing() -> void:
	var bottom := _bottom()
	var previous := _previous_bottom
	_previous_bottom = bottom

	if previous.y <= floor_height or bottom.y > floor_height:
		return

	var crossing := 1.0
	if not is_equal_approx(previous.y, bottom.y):
		crossing = clampf((previous.y - floor_height) / (previous.y - bottom.y), 0.0, 1.0)

	var contact := previous.lerp(bottom, crossing)
	bounces += 1
	# Only the first bounce is the landing. Everything after it is the ball still
	# moving, which volleyball ignores and tennis has to keep watching: the second
	# bounce is what ends a point.
	if bounces > 1:
		_bounce_again()
		return
	landing_point = Vector3(contact.x, floor_height, contact.z)
	landing_speed = linear_velocity.length()
	has_landed = true

	# Unlike the shuttle this is not frozen on contact: a volleyball bounces, the sand
	# kicks up, and everybody looks at where it hit. The truth was taken on the way
	# down, so whatever it does now is decoration and cannot change the call.
	global_position = landing_point + Vector3(0.0, radius, 0.0)
	_bounce_again()
	landed.emit(landing_point)


## The point is over: give the ball a moment and then stop it where it lies.
##
## Needed because the ball is simulated for as long as the match lasts now, and nothing
## used to end that. On sand it hardly mattered — a volleyball off dry sand keeps about a
## third of its speed and is at rest inside two metres. A tennis ball keeps nearly three
## quarters of it off a hard court, and measured, it was **13.6 m from the mark on
## average and still travelling at 10.6 m/s** three seconds after the point ended. The
## official was being asked to judge a landing while the ball sailed out of the stadium.
func let_it_settle(seconds := -1.0) -> void:
	if freeze:
		return
	_stopping = true
	_settling = seconds if seconds >= 0.0 else settle_seconds


func _settle(delta: float) -> void:
	if not _stopping:
		return
	if _settling > 0.0:
		_settling -= delta
		return

	# Once the moment is up the ball is taken out of the point rather than switched off.
	#
	# Waiting for it to be near the floor and freezing it there does not work on a fast
	# ball: at 120 Hz a tennis ball falling at 11 m/s moves 9 cm a tick and the ball is
	# 6.7 cm across, so it steps straight over its own resting height and bounces away
	# again. Measured, that left it 13 m from the mark and still going. Damping it hard
	# instead kills any speed in about a tenth of a second, which reads as a ball losing
	# its life rather than as a dropped frame.
	linear_velocity *= SETTLE_DAMPING
	angular_velocity *= SETTLE_DAMPING
	if linear_velocity.length() > SETTLE_REST_SPEED:
		return
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	freeze = true
	_stopping = false


## Kicks it back up off the ground, keeping some of the speed it arrived with.
func _bounce_again() -> void:
	global_position.y = maxf(global_position.y, floor_height + radius)
	linear_velocity = Vector3(
		linear_velocity.x * bounce,
		absf(linear_velocity.y) * bounce,
		linear_velocity.z * bounce)


## Ends the flight wherever the ball is, for the case where it has come to rest against
## something — wedged under the net, most likely. A rally that never finishes is worse
## than one that finishes oddly.
func force_landing() -> void:
	if has_landed:
		return
	var bottom := _bottom()
	landing_point = Vector3(bottom.x, floor_height, bottom.z)
	landing_speed = linear_velocity.length()
	has_landed = true
	freeze = true
	landed.emit(landing_point)


func _build_body() -> void:
	var view := MeshInstance3D.new()
	view.name = "Ball"
	var sphere := SphereMesh.new()
	sphere.radius = radius
	sphere.height = radius * 2.0
	sphere.radial_segments = 24
	sphere.rings = 12
	view.mesh = sphere

	# The blue, yellow and white of a beach ball, in one colour: the panels would need
	# a texture, and at the size this appears on screen a clean cream reads better than
	# a striped sphere sampled down to twelve pixels.
	var skin := StandardMaterial3D.new()
	skin.albedo_color = Color(0.97, 0.94, 0.80)
	skin.roughness = 0.65
	view.material_override = skin
	add_child(view)


func _build_collision() -> void:
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = radius
	shape.shape = sphere
	add_child(shape)


func _draw_on_court_layer(node: Node = self) -> void:
	if node is VisualInstance3D:
		(node as VisualInstance3D).layers = COURT_LAYER
	for child in node.get_children():
		_draw_on_court_layer(child)
