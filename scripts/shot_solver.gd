class_name ShotSolver
extends RefCounted

## Works out how hard to hit a shuttle so that it lands on a chosen spot.
##
## This exists because of a problem with simulating badminton honestly: if the
## players just hit the shuttle as well as they can, most rallies end nowhere near
## a line, and the umpire's job is boring. Close calls are the game, so they have to
## be manufactured — the players will secretly aim at chosen points, some of them
## sitting right on the paint, and this is what turns that intent into a velocity.
##
## The flight is worked out by running the same drag model the real shuttle uses,
## in a plain loop with no physics engine involved, and searching for the launch
## speed whose flight lands the right distance away. Slower than a formula, but
## quadratic drag has no tidy closed form and this stays honest to the real flight.

## Speeds worth searching between, in m/s. The upper end is well past a smash.
const MIN_SPEED := 1.0
const MAX_SPEED := 140.0

## How finely the search narrows in on an answer.
const SEARCH_STEPS := 40

## The simulated flight deliberately runs at the engine's own physics rate rather
## than something finer. A "more accurate" simulation would be worse here: what is
## wanted is not the true flight of a real shuttlecock, but the flight this game's
## physics will actually produce, integration error and all. Matching the step is
## what turns an approximate aim into an accurate one.
static func _step() -> float:
	var rate: float = ProjectSettings.get_setting("physics/common/physics_ticks_per_second", 60)
	return 1.0 / rate


## Returns the launch velocity that sends a shuttle from `from` onto `target`, or
## Vector3.ZERO if the target cannot be reached at this angle.
##
## `launch_angle_deg` is how steeply the shot goes up. A low angle is a drive or a
## smash, a high angle is a clear or a lift. Two different angles will usually both
## reach the same spot — which is what lets the same target be attacked in
## completely different ways.
static func solve(from: Vector3, target: Vector3, launch_angle_deg: float, floor_height := 0.0) -> Vector3:
	var flat := Vector2(target.x - from.x, target.z - from.z)
	var distance := flat.length()
	if distance < 0.001:
		return Vector3.ZERO

	var height := from.y - floor_height
	var angle := deg_to_rad(launch_angle_deg)

	var speed := _search_speed(distance, height, angle)
	if speed <= 0.0:
		return Vector3.ZERO

	var direction := flat.normalized()
	return Vector3(
		direction.x * speed * cos(angle),
		speed * sin(angle),
		direction.y * speed * cos(angle)
	)


## Narrows in on the launch speed that carries the shuttle exactly `distance` before
## it reaches the floor. Range grows with speed, so a straightforward halving search
## finds it.
static func _search_speed(distance: float, height: float, angle: float) -> float:
	if _range_for(MAX_SPEED, height, angle) < distance:
		return -1.0

	var low := MIN_SPEED
	var high := MAX_SPEED
	for i in SEARCH_STEPS:
		var middle := (low + high) * 0.5
		if _range_for(middle, height, angle) < distance:
			low = middle
		else:
			high = middle
	return (low + high) * 0.5


## Flies one shuttle in two dimensions and reports how far it got before landing.
##
## Everything here mirrors Shuttle exactly: the same drag law, the same time step,
## and the same rule that it is the tip of the cork which touches down, not the
## middle of the shuttle. Any of those left out shows up straight away as a shot
## that lands tens of centimetres from where it was aimed.
static func _range_for(speed: float, height: float, angle: float) -> float:
	var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)
	var drag := gravity / (Shuttle.TERMINAL_VELOCITY * Shuttle.TERMINAL_VELOCITY)
	var step := _step()

	var position := Vector2(0.0, height)
	var velocity := Vector2(cos(angle), sin(angle)) * speed
	var tip := _cork_tip_of(position, velocity)
	var previous_tip := tip

	# A shuttle is spent long before this, so the cap only guards against a shot
	# aimed so steeply it never comes down.
	var time := 0.0
	while tip.y > 0.0 and time < 20.0:
		previous_tip = tip
		var acceleration := Vector2(0.0, -gravity) - velocity * velocity.length() * drag
		velocity += acceleration * step
		position += velocity * step
		tip = _cork_tip_of(position, velocity)
		time += step

	if tip.y > 0.0:
		return -1.0

	# Land exactly on the floor rather than a step past it.
	var crossing := 1.0
	if not is_equal_approx(previous_tip.y, tip.y):
		crossing = clampf(previous_tip.y / (previous_tip.y - tip.y), 0.0, 1.0)
	return lerpf(previous_tip.x, tip.x, crossing)


## How high the shuttle will be after travelling `along` metres horizontally.
##
## Needed because a shot can start out aimed comfortably over the net and still hit
## it. A straight line from the racket to the target clears the tape easily on a
## lofted drop, but the shuttle does not travel in a straight line — it arcs, and on
## a gentle shot the arc has already begun falling by the time it reaches the net.
## The only honest way to know is to fly it and look.
static func height_after(start_height: float, speed: float, angle_deg: float, along: float) -> float:
	var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)
	var drag := gravity / (Shuttle.TERMINAL_VELOCITY * Shuttle.TERMINAL_VELOCITY)
	var step := _step()
	var angle := deg_to_rad(angle_deg)

	var position := Vector2(0.0, start_height)
	var velocity := Vector2(cos(angle), sin(angle)) * speed
	var previous := position

	var time := 0.0
	while position.x < along and time < 20.0:
		previous = position
		var acceleration := Vector2(0.0, -gravity) - velocity * velocity.length() * drag
		velocity += acceleration * step
		position += velocity * step
		time += step

	if position.x < along:
		return -1.0

	var crossing := 1.0
	if not is_equal_approx(previous.x, position.x):
		crossing = clampf((along - previous.x) / (position.x - previous.x), 0.0, 1.0)
	return lerpf(previous.y, position.y, crossing)


## The cork tip leads the shuttle along its direction of travel.
static func _cork_tip_of(position: Vector2, velocity: Vector2) -> Vector2:
	if velocity.length_squared() <= 0.0:
		return position
	return position + velocity.normalized() * Shuttle.CORK_TIP_OFFSET
