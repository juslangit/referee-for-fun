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
## Since 2026-10-21 each one is played exactly as a review is played during the match
## (`ReviewReplay`): the wide shot, the chase down the court and the dive onto the mark,
## with the same pill, reading BALL TRACKING and then the answer. Luqman asked for the
## review to look like the BWF broadcast, and two different replays in one game would have
## been one too many.
##
## Third worst first and the worst last, because the last thing seen before the result is
## the thing that is remembered.
##
## It is never called "Hawk-Eye" on screen. That is somebody's trademark, and this game
## carries no licensed names.

## How long the answer stays up before moving on by itself.
const HOLD := 4.5

## Kept for `ReviewReplay` and anything else that wants the booth's flat paint.
const TRACK := Color(1.0, 0.86, 0.22)

var arena: OfficiatedMatch

## How big the ball really is, and how much floor the overhead picture covers. Both read
## off the sport, so a table tennis ball is not framed like a volleyball.
var ball_radius := 0.1
var close_view_metres := 1.12

## The front-page photograph's camera and the ball it photographs.
var _close: ShuttleCam
var _true_ball: MeshInstance3D
var _replay: ReviewReplay

var _playing := false
var _flying := false
var _next := false
var _stop := false


func _ready() -> void:
	# A walk-out ends the match from the pause menu. Nothing here may stall because the
	# tree happened to be paused when it began.
	process_mode = Node.PROCESS_MODE_ALWAYS
	_read_the_sport()
	_build()
	arena.ui.replay_next.connect(_on_next)
	arena.ui.replay_skip_all.connect(_on_stop)


## The overhead picture of one call, as a still. The worst call's is the front-page photo.
##
## Taken before the replay starts rather than during it, so that a player who skips every
## replay still gets a paper with a picture in it.
func photograph(moment: Dictionary) -> Texture2D:
	# The overhead camera exists only for as long as the photograph takes. Left standing
	# beside the replay's camera, the main picture stopped updating — the whole flight
	# played behind a frozen frame of the hall (found 2026-10-21).
	_close = ShuttleCam.new()
	_close.name = "ReplayCloseUp"
	_close.view_metres = close_view_metres
	add_child(_close)
	_clear_the_court()
	_put_down(moment["landing"])
	for i in 3:
		await get_tree().process_frame
	var photo: Texture2D = null
	# Headless has no pictures to take, and asking for one is an error rather than an
	# empty image.
	if DisplayServer.get_name() != "headless":
		var image := _close.viewport.get_texture().get_image()
		if image != null and not image.is_empty():
			photo = ImageTexture.create_from_image(image)
	_true_ball.visible = false
	_close.queue_free()
	_close = null
	await get_tree().process_frame
	return photo


## Plays every call handed to it, in the order handed. SPACE, ENTER or a click moves on;
## ESC or the button stops the lot.
func play(moments: Array) -> void:
	_true_ball.visible = false
	_playing = true
	_stop = false
	for i in moments.size():
		if _stop:
			break
		await _show(moments[i], moments.size() - i, moments.size())
	_playing = false
	_replay.finish()
	arena.ui.hide_replay()


## What each place in the countdown is called. `place` is 1 for the worst.
static func title(place: int) -> String:
	match place:
		1: return "YOUR WORST CALL"
		2: return "SECOND WORST"
	return "THIRD WORST"


## The word on the pill once the ball is down: the answer to the line, or, for a call
## that was wrong about something other than the line, that it was wrong.
static func pill_word(truth: String) -> String:
	for word in ["IT WAS IN", "IT LANDED", "IT CLIPPED"]:
		if truth.begins_with(word):
			return "IN"
	for word in ["IT WAS OUT", "IT MISSED"]:
		if truth.begins_with(word):
			return "OUT"
	return "WRONG CALL"


func _show(moment: Dictionary, place: int, of: int) -> void:
	var landing: Vector3 = moment["landing"]
	var path: PackedVector3Array = moment["path"]
	# A flight needs two points. A call kept without one still gets its dive, from a
	# metre above the mark.
	if path.size() < 2:
		path = PackedVector3Array([landing + Vector3.UP, landing])

	arena.ui.show_replay(title(place), "%d OF %d" % [of - place + 1, of], moment["said_line"])

	# First what you said, while the ball flies. SPACE here skips to the answer rather
	# than past it: the flight is the build-up, and the answer is the point.
	_next = false
	_flying = true
	_replay.hurry = false
	await _replay.fly(path, landing, float(moment.get("margin", 0.0)))
	_flying = false
	if _stop:
		return

	# Then what was true.
	arena.ui.flip_replay_pill(pill_word(String(moment.get("truth", ""))))
	if arena.sound != null:
		arena.sound.review_flip()
	arena.ui.set_replay_truth(moment["truth_line"])
	_next = false
	var held := 0.0
	while held < HOLD and not _next and not _stop:
		await get_tree().process_frame
		held += get_process_delta_time()


func _on_next() -> void:
	_next = true
	if _flying:
		_replay.hurry = true


func _on_stop() -> void:
	_stop = true
	if _flying:
		_replay.hurry = true


## Puts the ball down where it really landed, for the overhead picture.
func _put_down(landing: Vector3) -> void:
	_true_ball.global_position = landing + Vector3.UP * ball_radius
	_true_ball.visible = true
	_close.aim_at(landing)


## Takes the real ball and its dent off the court for the photograph. The players are left
## where they are: the photograph's camera draws the court layer only and never sees them,
## and the replay that follows puts them away and brings them back itself.
func _clear_the_court() -> void:
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
	_replay = ReviewReplay.new()
	_replay.name = "ReviewReplay"
	_replay.arena = arena
	_replay.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_replay)

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
			_on_stop()
			get_viewport().set_input_as_handled()
		elif event.keycode in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER]:
			_on_next()
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		_on_next()
