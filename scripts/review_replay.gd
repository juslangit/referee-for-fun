class_name ReviewReplay
extends Node3D

## A line call under review, played out in the hall the way the broadcast plays it.
##
## Luqman sent a clip of the BWF review on 2026-10-21 and asked for every sport's challenge
## to look like it: the players gone, a wide picture of the empty court, the ball flying
## its path again with a yellow trail behind it while the camera chases it down the
## court, and then a dive to directly over the spot where it came down, close enough that
## the line is a white band across the screen and the mark beside it is the answer.
##
## Until then a review was a card over the court with the overhead still in the middle of
## it. That card stays for touches, which have no landing for a camera to dive to.
##
## The flight is the suspense. The wait before the answer used to be a timer; it is now
## the replay, which is the same wait with something to watch, and it is still not
## skippable.

## How long the wide picture of the empty court holds before the ball moves.
const WIDE_HOLD := 0.8

## How much slower than life the flight plays, and the limits either side, as in the
## replay booth: a smash would be a flicker and a lob would drag.
const SLOW := 0.45
const SHORTEST := 1.3
const LONGEST := 2.6

## How long the camera takes to get from behind the ball to straight over the mark.
const DIVE := 1.5

## How long the label stays blank between OFFICIAL REVIEW and the answer.
const BLANK := 0.3

## How much of the screen's width the mark takes in the last picture. In the broadcast
## it is a dot you could put a finger on, and the line beside it is a broad white band.
const MARK_SHARE := 0.07

## The narrowest and widest the last picture may be, in metres of floor. A cork on its
## own would want a hand's width; a volleyball would want a room.
const NARROWEST := 0.45
const WIDEST := 4.0

## The most flight the replay shows, in seconds of real time. The recorder goes back to
## the last strike, and in a sport where it cannot find one it hands over the rally.
const MOST_FLIGHT := 2.0

## How much nearer the camera creeps while the answer is up, as a share of its height.
const CREEP := 0.22

const FOV := 50.0
const TRAIL := Color(1.0, 0.85, 0.10)
const MARK := Color(0.20, 0.22, 0.21, 0.92)

var arena: OfficiatedMatch

var _camera: Camera3D
var _ghost: Node3D
var _trail: MultiMeshInstance3D
var _mark: MeshInstance3D
var _ball_radius := 0.03

## What was put away for the replay and must come back after it.
var _hidden: Array[Node3D] = []
var _was_current: Camera3D

## Straight over the mark, and where the creep is heading.
var _settled := false
var _creep_to := 0.0
var _landing := Vector3.ZERO


func _ready() -> void:
	_build()


## Plays the empty court, the flight and the dive, and returns with the camera looking
## straight down at the landing. The answer is the caller's to put up.
##
## `margin` is how far from the line it landed, either side. The last picture is widened
## to keep that line in it, as the broadcast always does.
func fly(path: PackedVector3Array, landing: Vector3, margin := 0.0) -> void:
	_read_the_sport()
	_landing = landing
	_settled = false
	_was_current = get_viewport().get_camera_3d()
	_clear_the_court()
	# The path's last point is where the underside touched, and the ball is drawn from
	# its middle, so it ends the flight sitting on the floor rather than half through it.
	var most := int(MOST_FLIGHT * Engine.physics_ticks_per_second)
	path = path.slice(maxi(0, path.size() - most)) if path.size() > most else path.duplicate()
	path[path.size() - 1] = landing + Vector3.UP * _ball_radius
	_dress(path)
	_camera.current = true

	var start := path[0]
	var flat := Vector3(landing.x - start.x, 0.0, landing.z - start.z)
	var span := flat.length()
	var along := flat / span if span > 0.3 else Vector3.FORWARD
	var side := Vector3(along.z, 0.0, -along.x)
	# The chair stands on +x in every sport, and is kept out of the foreground.
	if side.x > 0.0:
		side = -side
	# The last picture is squared to the court, so a line runs straight up the screen or
	# straight across it, as in the broadcast, whatever angle the ball came in at.
	var square := Vector3(signf(along.x), 0.0, 0.0) if absf(along.x) > absf(along.z) \
		else Vector3(0.0, 0.0, signf(along.z))

	# Wide: high, behind the player who hit it and off to one side, so the arc reads as
	# an arc rather than as a line dropping straight down the middle of the picture.
	var back := clampf(span * 0.3 + 2.2, 2.8, 4.8)
	# Never above 3.6 m: higher than that, the camera flew into the scoreboard hung over
	# the badminton court.
	var wide := _in_the_room(start - along * back + side * back * 0.45
		+ Vector3.UP * minf(2.8 + span * 0.18, 3.6))
	# Chasing: low behind the landing and a little off the line of the flight.
	var chase := _in_the_room(landing - along * 2.2 + side * 0.7 + Vector3.UP * 1.3)
	var over := landing + Vector3.UP * _height_for(_close_width(margin))
	var court := start.lerp(landing, 0.6)
	court.y = landing.y

	_camera.global_position = wide
	_camera.look_at(court, Vector3.UP)
	_put_ghost(path, 0.0)
	await _wait(WIDE_HOLD)

	# The flight. The camera keeps the floor in the picture and leans towards the ball
	# rather than staring at it: a lob at the top of its arc would otherwise fill the
	# screen with the crowd.
	var lasted := float(path.size() - 1) / float(Engine.physics_ticks_per_second)
	var shown := clampf(lasted / SLOW, SHORTEST, LONGEST)
	var t := 0.0
	while t < shown:
		t += await _tick()
		var f := clampf(t / shown, 0.0, 1.0)
		var here := _put_ghost(path, f)
		var drift := smoothstep(0.0, 1.0, f)
		# Down late: the camera crosses the court high and drops only once it is over the
		# landing's half. Dropping as it went flew it through the net at tape height.
		var spot := wide.lerp(chase, drift)
		spot.y = lerpf(wide.y, chase.y, pow(drift, 2.4))
		_camera.global_position = spot
		var aim := court.lerp(landing, drift).lerp(here, 0.3 * (1.0 - drift))
		_camera.look_at(aim, Vector3.UP)

	# The ball is down. What is left on the floor is the mark, at its true size.
	_ghost.visible = false
	_mark.global_position = landing + Vector3.UP * 0.003
	_mark.visible = true

	# The dive: the camera comes in over the mark first and drops onto it last, so the
	# end of it is a straight fall towards the floor rather than a swing. The trail goes
	# early: it comes down on top of the mark, and a camera dropping onto the mark would
	# otherwise drop through it.
	var from := chase - landing
	var level := Vector3(from.x, 0.0, from.z)
	t = 0.0
	while t < DIVE:
		t += await _tick()
		var f := clampf(t / DIVE, 0.0, 1.0)
		if f > 0.25:
			_trail.visible = false
		var across := level * (1.0 - smoothstep(0.0, 0.72, f))
		var height := lerpf(from.y, over.y - landing.y, smoothstep(0.0, 1.0, f))
		_camera.global_position = landing + across + Vector3.UP * height
		_turn_towards(landing, square, smoothstep(0.0, 1.0, f))
	_trail.visible = false
	_camera.global_position = over
	_turn_towards(landing, square, 1.0)
	_creep_to = (over.y - landing.y) * (1.0 - CREEP)
	_settled = true


## Puts the court back the way the replay found it.
func finish() -> void:
	_settled = false
	_ghost.visible = false
	_trail.visible = false
	_mark.visible = false
	# The match can end while the answer is up. Whatever took over the screen then, the
	# replay booth or the ending, keeps it, and keeps the court the way it left it.
	if arena._phase == arena.Phase.REMOVED:
		_hidden.clear()
		return
	for thing in _hidden:
		if is_instance_valid(thing):
			thing.visible = true
	_hidden.clear()
	if _camera.current and _was_current != null and is_instance_valid(_was_current):
		_was_current.current = true


func _process(delta: float) -> void:
	if not _settled:
		return
	var above := _camera.global_position.y - _landing.y
	_camera.global_position.y = _landing.y + lerpf(above, _creep_to, 1.0 - exp(-delta * 1.2))


## One frame, and how much of the replay it was worth. A paused game holds the replay
## where it is rather than letting it run on behind the pause menu.
func _tick() -> float:
	await get_tree().process_frame
	return 0.0 if get_tree().paused else get_process_delta_time()


func _wait(seconds: float) -> void:
	var t := 0.0
	while t < seconds:
		t += await _tick()


## Looks at `spot`, turning from upright towards having `square` up the screen as `f`
## goes from 0 to 1. Upright is how the flight was filmed and squared is how the mark is;
## turning between them over the dive keeps the picture from snapping round.
func _turn_towards(spot: Vector3, square: Vector3, f: float) -> void:
	var to := spot - _camera.global_position
	if to.length() < 0.001:
		return
	var squared := Basis.looking_at(to, square)
	if absf(to.normalized().y) > 0.99:
		_camera.global_basis = squared
		return
	var upright := Basis.looking_at(to, Vector3.UP)
	_camera.global_basis = Basis(upright.get_rotation_quaternion().slerp(
		squared.get_rotation_quaternion(), f))


## How much floor the last picture covers: enough for the mark to read as a dot, and
## enough for the line to be in it. Which way the line runs is not known here, so it is
## fitted into the picture's height, the shorter way.
func _close_width(margin: float) -> float:
	var size := get_viewport().get_visible_rect().size
	var aspect := size.x / maxf(size.y, 1.0)
	var for_the_mark := _ball_radius * 2.0 / MARK_SHARE
	var for_the_line := (absf(margin) + 0.08) * 2.0 * aspect
	return clampf(maxf(for_the_mark, for_the_line), NARROWEST, WIDEST)


## How high a camera with this lens hangs to fit `metres` of floor across the screen.
func _height_for(metres: float) -> float:
	var size := get_viewport().get_visible_rect().size
	var aspect := size.x / maxf(size.y, 1.0)
	return metres / (2.0 * tan(deg_to_rad(FOV * 0.5)) * aspect)


## And never through a wall: table tennis is played inside a drape.
func _in_the_room(spot: Vector3) -> Vector3:
	var room: Vector2 = arena.replay_room()
	spot.x = clampf(spot.x, -room.x, room.x)
	spot.z = clampf(spot.z, -room.y, room.y)
	return spot


## Moves the ball `f` of the way along its path, lays the trail behind it, and returns
## where it is. A shuttle flies cork first, so it is turned to face where it is going.
func _put_ghost(path: PackedVector3Array, f: float) -> Vector3:
	var last := path.size() - 1
	var at := clampf(f, 0.0, 1.0) * float(last)
	var i := mini(int(at), last)
	var j := mini(i + 1, last)
	var here := path[i].lerp(path[j], at - float(i))
	_ghost.global_position = here
	_ghost.visible = true
	var heading := path[j] - path[maxi(i - 1, 0)]
	if arena.ball_in_play() is Shuttle and heading.length() > 0.0001:
		var up := Vector3.UP if absf(heading.normalized().y) < 0.98 else Vector3.FORWARD
		_ghost.look_at(here + heading, up)
	_trail.multimesh.visible_instance_count = i + 1
	return here


## The trail laid out along the whole flight and revealed as the ball goes, and a copy of
## the ball itself to fly it.
func _dress(path: PackedVector3Array) -> void:
	var dots := _trail.multimesh
	# Thinner than the ball: at a volleyball's width the trail went past the chasing
	# camera as a yellow wall.
	var thick := maxf(_ball_radius * 0.45, 0.02)
	dots.instance_count = path.size()
	for d in path.size():
		dots.set_instance_transform(d, Transform3D(Basis.from_scale(Vector3.ONE * thick), path[d]))
	dots.visible_instance_count = 0
	_trail.visible = true

	_mark.scale = Vector3(_ball_radius, 1.0, _ball_radius)
	_mark.visible = false
	_copy_the_ball()


## A ball that looks like the real one: its meshes, without its body. The real ball is a
## physics object with a script on it, and a duplicate of that would fall.
func _copy_the_ball() -> void:
	for child in _ghost.get_children():
		child.queue_free()
	var ball: Node3D = arena.ball_in_play()
	if ball == null or not is_instance_valid(ball):
		return
	var into_ball := ball.global_transform.affine_inverse()
	for part in _meshes_in(ball):
		var copy := part.duplicate(0) as GeometryInstance3D
		for child in copy.get_children():
			copy.remove_child(child)
			child.free()
		copy.transform = into_ball * part.global_transform
		copy.visible = true
		_ghost.add_child(copy)


func _meshes_in(node: Node) -> Array[GeometryInstance3D]:
	var found: Array[GeometryInstance3D] = []
	for child in node.get_children():
		if child is GeometryInstance3D:
			found.append(child)
		found.append_array(_meshes_in(child))
	return found


## Empties the court for the replay, and remembers what it put away.
func _clear_the_court() -> void:
	_hidden.clear()
	var away: Array[Node3D] = []
	for player in arena.players:
		away.append(player)
	for judge in arena.line_judges:
		away.append(judge)
	away.append(arena.ball_in_play())
	# And the dent the match leaves where the ball came down, which is drawn for sand and
	# reads as a grey plate the size of a dinner plate from this close. The replay draws
	# its own mark, the size of the ball.
	away.append(arena.get("_landing_mark"))
	for thing in away:
		if thing != null and is_instance_valid(thing) and thing.visible:
			thing.visible = false
			_hidden.append(thing)


## The size of what lands. A shuttle is judged by its cork, not its skirt.
func _read_the_sport() -> void:
	var ball = arena.ball_in_play()
	if ball is Shuttle:
		_ball_radius = Shuttle.CORK_RADIUS
	elif ball is Ball:
		_ball_radius = ball.radius


func _build() -> void:
	_camera = Camera3D.new()
	_camera.name = "ReviewCamera"
	_camera.fov = FOV
	_camera.near = 0.02
	add_child(_camera)

	_ghost = Node3D.new()
	_ghost.name = "Ball"
	_ghost.visible = false
	add_child(_ghost)

	var unit := SphereMesh.new()
	unit.radius = 1.0
	unit.height = 2.0
	unit.radial_segments = 12
	unit.rings = 6
	var dots := MultiMesh.new()
	dots.transform_format = MultiMesh.TRANSFORM_3D
	dots.mesh = unit
	_trail = MultiMeshInstance3D.new()
	_trail.name = "Trail"
	_trail.multimesh = dots
	_trail.material_override = ReplayBooth._paint(TRAIL)
	_trail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_trail.visible = false
	add_child(_trail)

	var disc := CylinderMesh.new()
	disc.top_radius = 1.0
	disc.bottom_radius = 1.0
	disc.height = 0.002
	disc.radial_segments = 32
	_mark = MeshInstance3D.new()
	_mark.name = "Mark"
	_mark.mesh = disc
	_mark.material_override = ReplayBooth._paint(MARK)
	_mark.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_mark.visible = false
	add_child(_mark)
