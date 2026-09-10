class_name FlightRecorder
extends Node

## The ball's path through the current rally, kept so the end of the match can show it
## again.
##
## Nothing looks at this while a match is on. It exists for the replay of the worst calls
## at the final whistle, and a replay needs the flight rather than just the landing. Every
## ball in the game records its landing exactly; the path up to it was never kept, because
## until now nothing needed it.
##
## It is a node of its own, with its own `_physics_process`, rather than a few lines inside
## each sport's. Badminton's `_physics_process` does not call up to the spine, and neither
## does its `_ready` — a line added in either place would have worked in four sports and
## silently done nothing in the fifth, which is the shape of both the `current_rally` bug
## and the `chair_camera` bug. The spine makes this the first time any rally is put in
## play, so every sport gets one without having to remember to.

## How much flight is kept. The replay only ever wants the last shot or two, so this is a
## ceiling on memory for a rally that goes on and on, not a choice about what to show.
const KEEP_SECONDS := 20.0

## How a strike or a bounce is told apart from ordinary flight: by what it does to the
## ball's velocity in one physics tick. Drag slows a ball and gravity bends its path, but
## neither turns it through twenty degrees in a hundred-and-twentieth of a second, and
## neither speeds it up by a metre and a half a second.
const TURNED_DEGREES := 20.0
const SPED_UP := 1.5

## A ball that moves further than this in one tick was picked up and put somewhere else.
## That is the start of a different flight, not part of this one.
const TELEPORTED := 2.0

## The shortest stretch worth replaying. A smash from the net lands in a quarter of a
## second, which on its own is a flicker, so the shot before it comes as well.
const SHORTEST_REPLAY := 0.6

enum Break { NONE, STRUCK, MOVED }

## The match being recorded. Untyped, because every sport's match is a different class
## and all this needs is the phase and the ball.
var arena: Node

var _points := PackedVector3Array()
var _was_in_play := false


func _physics_process(_delta: float) -> void:
	if arena == null:
		return
	var in_play: bool = arena._phase == arena.Phase.IN_PLAY
	# A fresh rally is a fresh recording. Watched for here, on the phase every sport
	# already sets, rather than cleared by each sport's serve.
	if in_play and not _was_in_play:
		_points.clear()
	_was_in_play = in_play
	if not in_play:
		return

	var ball: Node3D = arena.ball_in_play()
	if ball == null or not is_instance_valid(ball):
		return
	_points.append(ball.global_position)

	var kept := int(KEEP_SECONDS * Engine.physics_ticks_per_second)
	if _points.size() > kept:
		_points = _points.slice(_points.size() - kept)


## The last shot of the rally, ending exactly where the ball came down.
##
## Cut at the landing, because a ball bounces on for a beat before it is taken out of play
## and that is not part of the call. Then back to the last strike or bounce before it, so
## the replay starts where this shot started rather than at the serve.
func path_to(landing: Vector3) -> PackedVector3Array:
	var count := _points.size()
	if count == 0:
		return PackedVector3Array([landing])

	var end := count - 1
	var nearest := INF
	for i in count:
		var gap := _points[i].distance_squared_to(landing)
		if gap <= nearest:
			nearest = gap
			end = i

	var shortest := int(SHORTEST_REPLAY * Engine.physics_ticks_per_second)
	var start := 0
	var i := end
	while i >= 1:
		var found := _break_at(i)
		if found == Break.MOVED:
			start = i
			break
		if found == Break.STRUCK and end - i >= shortest:
			start = i - 1
			break
		i -= 1

	var path := _points.slice(start, end + 1)
	path.append(landing)
	return path


## Whether something other than flight happened to the ball between tick `i - 1` and
## tick `i`.
func _break_at(i: int) -> Break:
	var step := _points[i] - _points[i - 1]
	if step.length() > TELEPORTED:
		return Break.MOVED
	if i < 2:
		return Break.NONE

	var hz := float(Engine.physics_ticks_per_second)
	var before := (_points[i - 1] - _points[i - 2]) * hz
	var after := step * hz
	if after.length() - before.length() > SPED_UP:
		return Break.STRUCK
	if before.length() > 0.5 and after.length() > 0.5 \
			and rad_to_deg(before.angle_to(after)) > TURNED_DEGREES:
		return Break.STRUCK
	return Break.NONE
