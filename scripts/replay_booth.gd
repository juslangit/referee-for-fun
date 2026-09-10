class_name ReplayBooth
extends Node3D

## The worst calls of the match, played back once it is over.
##
## Styled on the ball-tracking replay television uses for a line call: the players are
## gone, the court is empty, and the ball's path draws itself across it in slow motion
## before the picture cuts to where it came down. That look is honest as well as familiar.
## The game records exactly where the ball went and never recorded how anybody moved, so a
## replay with the players in it would show them frozen in whatever they were doing at the
## final whistle. The reconstruction shows what the game actually knows.
##
## Third worst first and the worst last, because the last thing seen before the result is
## the thing that is remembered.
##
## It is never called "Hawk-Eye" on screen. That is somebody's trademark, and this game
## carries no licensed names.

## How much slower than life the flight plays, and the limits either side. A smash lasts a
## quarter of a second and would be a flicker at any honest slow motion; a lob lasts three
## and would take eight.
const SLOW := 0.4
const SHORTEST := 1.8
const LONGEST := 4.0

## How long the close view stays up before moving on by itself.
const HOLD := 4.5

## A layer of its own. The ball, its trail and its mark are drawn larger than life so they
## read from a camera ten metres away, and the overhead picture must never see that — it
## draws the court layer only, where a ball of the true size sits on the true spot. The
## close view is the one picture in this game that has to be exact.
const REPLAY_LAYER := 16

const TRACK := Color(1.0, 0.86, 0.22)
const TRAIL := Color(1.0, 0.86, 0.22, 0.55)
const MARK := Color(0.98, 0.34, 0.26, 0.85)

var arena: OfficiatedMatch

## How big the ball really is, and how much floor the overhead picture covers. Both read
## off the sport, so a table tennis ball is not framed like a volleyball.
var ball_radius := 0.1
var close_view_metres := 1.12

var _camera: Camera3D
var _close: ShuttleCam
var _big_ball: MeshInstance3D
var _trail: MultiMeshInstance3D
var _mark: MeshInstance3D
var _true_ball: MeshInstance3D
var _dot_every := 1
var _dot_size := 0.03

var _playing := false
var _next := false
var _stop := false


func _ready() -> void:
	# A walk-out ends the match from the pause menu. Nothing here may stall because the
	# tree happened to be paused when it began.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_read_the_sport()
	_build()
	arena.ui.replay_next.connect(func() -> void: _next = true)
	arena.ui.replay_skip_all.connect(func() -> void: _stop = true)


## The overhead picture of one call, as a still. The worst call's is the front-page photo.
##
## Taken before the replay starts rather than during it, so that a player who skips every
## replay still gets a paper with a picture in it.
func photograph(moment: Dictionary) -> Texture2D:
	_clear_the_court()
	_put_down(moment["landing"])
	for i in 3:
		await get_tree().process_frame
	# Headless has no pictures to take, and asking for one is an error rather than an
	# empty image.
	if DisplayServer.get_name() == "headless":
		return null
	var image := _close.viewport.get_texture().get_image()
	if image == null or image.is_empty():
		return null
	return ImageTexture.create_from_image(image)


## Plays every call handed to it, in the order handed. SPACE, ENTER or a click moves on;
## ESC or the button stops the lot.
func play(moments: Array) -> void:
	_clear_the_court()
	_camera.current = true
	_playing = true
	_stop = false
	for i in moments.size():
		if _stop:
			break
		await _show(moments[i], moments.size() - i, moments.size())
	_playing = false
	arena.ui.hide_replay()


## What each place in the countdown is called. `place` is 1 for the worst.
static func title(place: int) -> String:
	match place:
		1: return "YOUR WORST CALL"
		2: return "SECOND WORST"
	return "THIRD WORST"


func _show(moment: Dictionary, place: int, of: int) -> void:
	var landing: Vector3 = moment["landing"]
	var path: PackedVector3Array = moment["path"].duplicate()
	if path.is_empty():
		path.append(landing)

	_true_ball.visible = false
	_mark.visible = false
	arena.ui.show_replay(title(place), "%d OF %d" % [of - place + 1, of], moment["said_line"])
	var look := _frame(path)
	_lay_the_trail(path)
	# The path's last point is where the underside touched, and the ball is drawn from its
	# middle, so it ends the flight sitting on the floor rather than half through it.
	path[path.size() - 1] = landing + Vector3.UP * _big_ball.scale.x

	# First what you said, while the ball flies. SPACE here skips to the answer rather
	# than past it: the flight is the build-up, and the answer is the point.
	var shown := 0.0
	if path.size() > 1:
		var lasted := float(path.size() - 1) / float(Engine.physics_ticks_per_second)
		shown = clampf(lasted / SLOW, SHORTEST, LONGEST)
	_next = false
	var t := 0.0
	while t < shown and not _next and not _stop:
		await get_tree().process_frame
		t += get_process_delta_time()
		_fly_to(path, t / shown, look)
	_fly_to(path, 1.0, look)
	if _stop:
		return

	# Then what was true, and where it came down.
	_put_down(landing)
	await get_tree().process_frame
	arena.ui.show_replay_close_up(_close.texture())
	arena.ui.set_replay_truth(moment["truth_line"])
	_next = false
	var held := 0.0
	while held < HOLD and not _next and not _stop:
		await get_tree().process_frame
		held += get_process_delta_time()


## Points the camera at this flight, side-on and from above, and returns what it looks at.
##
## Side-on because that is the angle that shows an arc, and from the side away from the
## umpire's chair so the chair is never in the foreground. Framed from the flight itself
## rather than from the court, so the same code frames a clear across a badminton hall and
## a push across a table tennis table.
func _frame(path: PackedVector3Array) -> Vector3:
	var landing := path[path.size() - 1]
	var start := path[0]
	var top := landing.y
	for point in path:
		top = maxf(top, point.y)

	var flat := Vector3(landing.x - start.x, 0.0, landing.z - start.z)
	var span := flat.length()
	var along := flat / span if span > 0.3 else Vector3.BACK
	var side := Vector3(along.z, 0.0, -along.x)
	# The chair stands on +x in every sport.
	if side.x > 0.0:
		side = -side

	var rise := top - landing.y
	var extent := maxf(maxf(span, rise * 1.6), 1.5)
	var middle := (start + landing) * 0.5
	middle.y = landing.y

	# Far enough back to fit the whole arc in, across and up, and never high. The first
	# version climbed with the distance and ended up in the roof of the arena, looking
	# down at the court through the lighting truss with the top of every clear cut off.
	var away := clampf(maxf(span * 0.75, rise * 1.5) + 1.5, 2.6, 10.0)
	var height := minf(away * 0.35 + 0.8, 4.5)
	var spot := middle + side * away - along * span * 0.12 + Vector3.UP * height

	# And never through a wall. Table tennis is played inside barriers with a black drape
	# half a metre behind them, and a camera that backed out past it filmed the back of a
	# curtain for the whole replay.
	var room: Vector2 = arena.replay_room()
	spot.x = clampf(spot.x, -room.x, room.x)
	spot.z = clampf(spot.z, -room.y, room.y)
	_camera.global_position = spot
	var look := middle.lerp(landing, 0.25)
	look.y = landing.y + rise * 0.45
	_camera.look_at(look, Vector3.UP)

	# Big enough to follow at this distance, and never smaller than the real thing.
	var size := clampf(extent * 0.010, ball_radius * 1.4, 0.15)
	_big_ball.scale = Vector3.ONE * size
	_mark.scale = Vector3(size * 1.4, 1.0, size * 1.4)
	_dot_size = size * 0.4
	return look


func _lay_the_trail(path: PackedVector3Array) -> void:
	var dots := _trail.multimesh
	_dot_every = maxi(1, path.size() / 90)
	var count := (path.size() - 1) / _dot_every + 1
	dots.instance_count = count
	for d in count:
		var at := path[mini(d * _dot_every, path.size() - 1)]
		dots.set_instance_transform(d, Transform3D(Basis.from_scale(Vector3.ONE * _dot_size), at))
	dots.visible_instance_count = 0


## Moves the ball `f` of the way along its path, lays the trail behind it, and lets the
## camera drift a little after it.
func _fly_to(path: PackedVector3Array, f: float, look: Vector3) -> void:
	var last := path.size() - 1
	var at := clampf(f, 0.0, 1.0) * float(last)
	var i := mini(int(at), last)
	var j := mini(i + 1, last)
	var here := path[i].lerp(path[j], at - float(i))
	_big_ball.global_position = here
	var dots := _trail.multimesh
	dots.visible_instance_count = mini(i / _dot_every + 1, dots.instance_count)
	_camera.look_at(look.lerp(here, 0.2), Vector3.UP)


## Puts the ball down where it really landed: the big one and its mark for the camera in
## the hall, and one of the true size for the overhead picture.
func _put_down(landing: Vector3) -> void:
	_mark.global_position = landing + Vector3.UP * 0.004
	_mark.visible = true
	_true_ball.global_position = landing + Vector3.UP * ball_radius
	_true_ball.visible = true
	_close.aim_at(landing)


## Empties the court: the players and line judges go, and so do the real ball and its dent.
func _clear_the_court() -> void:
	for player in arena.players:
		if is_instance_valid(player):
			player.visible = false
	for judge in arena.line_judges:
		if is_instance_valid(judge):
			judge.visible = false
	var ball: Node3D = arena.ball_in_play()
	if ball != null and is_instance_valid(ball):
		ball.visible = false
	arena.clear_the_mark()
	arena.ui.hide_close_cam()
	arena.ui.hide_review()


## The size of the thing that lands, and the framing each sport gave its own close camera.
## A shuttle is judged by its cork, not its skirt.
func _read_the_sport() -> void:
	var ball = arena.ball_in_play()
	if ball is Shuttle:
		ball_radius = Shuttle.CORK_RADIUS
	elif ball is Ball:
		ball_radius = ball.radius
	var own = arena.ball_cam
	if own == null:
		own = arena.get("shuttle_cam")
	if own != null:
		close_view_metres = own.view_metres


func _build() -> void:
	_camera = Camera3D.new()
	_camera.name = "ReplayCamera"
	_camera.fov = 56.0
	add_child(_camera)

	_close = ShuttleCam.new()
	_close.name = "ReplayCloseUp"
	_close.view_metres = close_view_metres
	add_child(_close)

	var unit := SphereMesh.new()
	unit.radius = 1.0
	unit.height = 2.0
	unit.radial_segments = 20
	unit.rings = 10

	_big_ball = _instance(unit, TRACK, REPLAY_LAYER)

	var dots := MultiMesh.new()
	dots.transform_format = MultiMesh.TRANSFORM_3D
	dots.mesh = unit
	_trail = MultiMeshInstance3D.new()
	_trail.name = "Trail"
	_trail.multimesh = dots
	_trail.material_override = _paint(TRAIL)
	_trail.layers = REPLAY_LAYER
	_trail.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_trail)

	var disc := CylinderMesh.new()
	disc.top_radius = 1.0
	disc.bottom_radius = 1.0
	disc.height = 0.004
	disc.radial_segments = 28
	_mark = _instance(disc, MARK, REPLAY_LAYER)
	_mark.visible = false

	var true_size := SphereMesh.new()
	true_size.radius = ball_radius
	true_size.height = ball_radius * 2.0
	_true_ball = _instance(true_size, TRACK, Ball.COURT_LAYER)
	_true_ball.visible = false


func _instance(mesh: Mesh, colour: Color, layer: int) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = _paint(colour)
	instance.layers = layer
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(instance)
	return instance


## Flat and unlit, so it reads the same in a dark arena as on a sunlit beach.
static func _paint(colour: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = colour
	if colour.a < 1.0:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return material


func _unhandled_input(event: InputEvent) -> void:
	if not _playing:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE:
			_stop = true
			get_viewport().set_input_as_handled()
		elif event.keycode in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER]:
			_next = true
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		_next = true
