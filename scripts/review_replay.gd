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

## How much longer than wide the skid gets per unit of flatness, and its limit.
const SKID_PER_FLATNESS := 0.35
const LONGEST_SKID := 2.4

## How far above the floor the mark is drawn. It is also drawn over the floor whatever the
## depth says: at 3 mm it fought the court's own surface and came out as a broken star.
const MARK_LIFT := 0.006

## The cut to the hall's big screen (2026-10-21): from this far into the flight to its
## end, the picture is the screen in the hall with the replay playing on it, and then it
## cuts back for the dive. Only where the venue has a screen.
const SCREEN_FROM := 0.45
const FEED_SIZE := Vector2i(960, 540)

const FOV := 50.0
const TRAIL := Color(1.0, 0.85, 0.10)
const MARK := Color(0.20, 0.22, 0.21, 0.92)

var arena: OfficiatedMatch

var _camera: Camera3D
var _ghost: Node3D
var _trail: MultiMeshInstance3D
var _mark: MeshInstance3D
var _ball_radius := 0.03

## Set to run what is left of the replay straight to the mark. A review never sets it —
## its wait is the point — but the replays at the final whistle take SPACE.
var hurry := false

## What was put away for the replay and must come back after it.
var _hidden: Array[Node3D] = []
var _was_current: Camera3D

## Straight over the mark, and where the creep is heading.
var _settled := false
var _creep_to := 0.0
var _landing := Vector3.ZERO

## The replay on the hall's screen: a second camera that copies this one, rendering into
## a picture put up on the screen, and a camera in the hall looking at the screen.
var _feed: SubViewport
var _feed_camera: Camera3D
var _hall: Camera3D


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
	# Played several times over at the final whistle: the camera to go back to is the
	# one from before the first, not this one.
	var showing := get_viewport().get_camera_3d()
	if showing != _camera:
		_was_current = showing
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
	var on_screen := _open_the_feed()
	await _wait(WIDE_HOLD)

	# The flight. The camera keeps the floor in the picture and leans towards the ball
	# rather than staring at it: a lob at the top of its arc would otherwise fill the
	# screen with the crowd.
	_sound("review_flight")
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
		# The second half of the flight as the hall sees it, up on the screen.
		if on_screen:
			if f >= SCREEN_FROM and f < 1.0 and not hurry:
				_hall.current = true
			else:
				_camera.current = true
	_camera.current = true

	# The ball is down. What is left on the floor is the mark, at its true size.
	_ghost.visible = false
	_lay_the_mark(path, landing)

	# The dive: the camera comes in over the mark first and drops onto it last, so the
	# end of it is a straight fall towards the floor rather than a swing. The trail goes
	# early: it comes down on top of the mark, and a camera dropping onto the mark would
	# otherwise drop through it.
	_sound("review_dive")
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


## Puts the replay up on the venue's big screen and frames a shot of it from the floor.
## Returns whether there is a screen to cut to.
##
## The screen picked is the one nearest the middle of the court — the cube hung over an
## arena floor where there is one — because the shot of it is taken from beside the court,
## looking up, and a screen on a far wall is a smudge from there.
func _open_the_feed() -> bool:
	var event = arena.event_dressing()
	if event == null:
		return false
	var best: Dictionary = {}
	var nearest := INF
	for spot: Dictionary in event.screens():
		var node: Node3D = spot["node"]
		if not is_instance_valid(node) or not node.is_visible_in_tree():
			continue
		var away := Vector2(node.global_position.x, node.global_position.z).length()
		if away < nearest:
			nearest = away
			best = spot
	if best.is_empty():
		return false

	if _feed == null:
		_feed = SubViewport.new()
		_feed.name = "ScreenFeed"
		_feed.size = FEED_SIZE
		_feed.handle_input_locally = false
		add_child(_feed)
		_feed.world_3d = get_viewport().find_world_3d()
		_feed_camera = Camera3D.new()
		_feed_camera.fov = FOV
		_feed_camera.near = 0.02
		_feed.add_child(_feed_camera)
		_feed_camera.current = true
	_feed.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	event.show_feed(_feed.get_texture())

	var screen: Node3D = best["node"]
	var size: Vector2 = best["size"]
	var facing := screen.global_basis.z.normalized()
	var across := screen.global_basis.x.normalized()
	var spot := screen.global_position + facing * size.x * 1.3 + across * size.x * 0.3
	spot.y = maxf(screen.global_position.y - size.y * 1.2, 1.5)
	_hall.global_position = _in_the_room(spot)
	_hall.look_at(screen.global_position, Vector3.UP)
	return true


func _close_the_feed() -> void:
	if _feed == null:
		return
	var event = arena.event_dressing()
	if event != null:
		event.show_feed(null)
	_feed.queue_free()
	_feed = null
	_feed_camera = null


## Asks the hall's sound for `what`, if this match has any sound.
func _sound(what: String) -> void:
	var hall = arena.get("sound")
	if hall != null and is_instance_valid(hall):
		hall.call(what)


## Puts the court back the way the replay found it.
func finish() -> void:
	_settled = false
	_close_the_feed()
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
	if _feed_camera != null:
		_feed_camera.global_transform = _camera.global_transform
	if not _settled:
		return
	var above := _camera.global_position.y - _landing.y
	_camera.global_position.y = _landing.y + lerpf(above, _creep_to, 1.0 - exp(-delta * 1.2))


## One frame, and how much of the replay it was worth. A paused game holds the replay
## where it is rather than letting it run on behind the pause menu.
func _tick() -> float:
	await get_tree().process_frame
	if hurry:
		return INF
	if get_tree().paused and process_mode != Node.PROCESS_MODE_ALWAYS:
		return 0.0
	return get_process_delta_time()


func _wait(seconds: float) -> void:
	var t := 0.0
	while t < seconds:
		t += await _tick()


## The mark the ball left: a dot for a ball that came down steeply, and an oval skid
## drawn out along its path for one that came in low and fast, as ball tracking draws
## it. How long is how flat it arrived: the ratio of its speed along the floor to its
## speed into it.
func _lay_the_mark(path: PackedVector3Array, landing: Vector3) -> void:
	var last := path.size() - 1
	var arriving := path[last] - path[maxi(last - 3, 0)]
	var along := Vector3(arriving.x, 0.0, arriving.z)
	var down := maxf(-arriving.y, 0.0001)
	var skid := clampf(1.0 + along.length() / down * SKID_PER_FLATNESS, 1.0, LONGEST_SKID)
	var basis := Basis.IDENTITY
	if along.length() > 0.0001:
		basis = Basis.looking_at(along.normalized(), Vector3.UP)
	_mark.global_transform = Transform3D(
		basis * Basis.from_scale(Vector3(_ball_radius, 1.0, _ball_radius * skid)),
		landing + Vector3.UP * MARK_LIFT)
	_mark.visible = true


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

	_hall = Camera3D.new()
	_hall.name = "HallCamera"
	_hall.fov = FOV
	add_child(_hall)

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
	# Faded out close to the lens. The camera chases the ball down the court, so the
	# trail goes past it, and a dot a hand's width from the lens was a yellow blob across
	# a third of the picture.
	var trail_paint := ReplayBooth._paint(TRAIL)
	trail_paint.distance_fade_mode = BaseMaterial3D.DISTANCE_FADE_PIXEL_ALPHA
	trail_paint.distance_fade_min_distance = 0.5
	trail_paint.distance_fade_max_distance = 1.4
	_trail.material_override = trail_paint
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
	var dent := ReplayBooth._paint(MARK)
	dent.no_depth_test = true
	dent.render_priority = 1
	_mark.material_override = dent
	_mark.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_mark.visible = false
	add_child(_mark)
