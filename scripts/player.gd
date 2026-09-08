class_name Player
extends Node3D

## One athlete. Deliberately simple: they run to where they think the shuttle is
## going, and if they get there in time they hit it back.
##
## They are not trying to play good badminton. Their whole job is to produce rallies
## that end somewhere worth judging — which mostly means getting to the shuttle so
## the rally continues, and occasionally deciding a shot is going out and letting it
## drop. That last decision is the one that makes the umpire's job interesting: a
## player who stands and watches a shuttle land is staking the rally on your call.

const BODY_HEIGHT := 1.78
const BODY_RADIUS := 0.22

## People are drawn on their own visual layer so the line camera can leave them out.
## A camera at knee height on the line spends most of its life looking at somebody's
## legs, which is true to life and completely useless for judging a line.
const PEOPLE_LAYER := 2

## Highest and lowest a shuttle can be and still be hit. The top of the range is an
## overhead smash; the bottom is a scrambling lift off the floor.
const HIGHEST_STRIKE := 2.85
const LOWEST_STRIKE := 0.28

## How fast they cover the court, in metres per second.
@export var speed := 4.0

## How far from the shuttle they can still reach it, racket included.
@export var reach := 0.95

## How far the player has to move in a second before they look like they are running.
const MOVING_THRESHOLD := 0.35

## How the players are animated.
##
## The models are static meshes, so this moves the whole figure rather than posing a
## skeleton: a run cycle's worth of bob and lean, and a racket swing when a shot is
## played. It is not a substitute for a rigged character — nobody's knees bend — but a
## figure that dips as it runs, leans into the run and swings when it hits reads as
## alive, and one that glides along at a constant height does not.
const BOB_HEIGHT := 0.055
const BOB_SPEED := 11.0
const RUN_LEAN := 0.17
const LEAN_SPEED := 2.4
const SWING_SECONDS := 0.34
const SWING_SWEEP := 2.3

var team := Sides.Team.NONE

## Whether this athlete plays a sport with a racket in it. Beach volleyball players
## carry nothing, and a volleyball player holding a badminton racket is a funnier bug
## than it is a small one.
var volleyball := false

## Where they stand when the shuttle is not their problem.
var home := Vector3.ZERO

## Whether they are currently going after the shuttle.
var chasing := false

var _destination := Vector3.ZERO
var _lunge_left := 0.0
var _lunge_spot := Vector3.ZERO

## The clips on the forged character, and which one is playing.
var _animator: AnimationPlayer
var _clip := ""
var _one_shot := false

## Clips that run until something else interrupts them, as opposed to shots.
const LOOPING := ["idle", "ready", "run", "walk", "tired", "argue", "vb_ready"]

## The figure and the racket in its hand.
var _figure: Node3D
var _racket: Node3D
var _racket_rest := Vector3.ZERO
var _bob := 0.0
var _lean := 0.0
var _swing_left := 0.0


func setup(for_team: Sides.Team, home_position: Vector3) -> void:
	team = for_team
	home = home_position
	position = home_position
	_destination = home_position
	_build_body()


## Sized once it is in the tree, where a model's real dimensions are knowable, and
## dressed afterwards — the bib does not scale with the model, so measuring it as part
## of the figure set a floor the fit could never get under.
func _settle_when_posed(model: Node3D) -> void:
	await get_tree().process_frame
	if not is_instance_valid(model):
		return
	Models.settle(model)
	Models.dress_player(model, not volleyball)
	_take_up_racket(model)


## Picks up the racket, if this sport has one. Asking for the meta unconditionally is
## an error rather than a null once nobody is carrying anything.
func _take_up_racket(model: Node3D) -> void:
	if not model.has_meta("racket"):
		return
	_racket = model.get_meta("racket")
	if _racket != null:
		_racket_rest = _racket.rotation


## Finds the clips and sets the looping ones to loop. Downloaded animations arrive
## set to play once, and so do these — the exporter has no way of knowing which of a
## run cycle and a smash is meant to repeat.
func _set_up_clips(model: Node3D) -> void:
	_animator = Models.animator(model)
	if _animator == null:
		return
	for clip in _animator.get_animation_list():
		if String(clip) in LOOPING:
			Models.make_looping(_animator, clip)
	_animator.animation_finished.connect(_on_clip_finished)
	_play("idle")


func _play(clip: String, one_shot := false) -> void:
	if _animator == null or clip.is_empty():
		return
	# A shot in progress is not interrupted by the player wandering back to position.
	if _one_shot and not one_shot:
		return
	if clip == _clip and not one_shot:
		return
	if not _animator.has_animation(clip):
		return
	_clip = clip
	_one_shot = one_shot
	_animator.play(clip, 0.14)


func _on_clip_finished(_clip_name: StringName) -> void:
	_one_shot = false
	_clip = ""


## Takes a swing. `overhead` picks a smash over a groundstroke, so the shot on screen
## matches the shot the rally logic actually played.
func swing(overhead := false) -> void:
	_swing_left = SWING_SECONDS
	if overhead:
		_play("smash", true)
	else:
		_play("forehand" if randf() < 0.65 else "backhand", true)


# --- volleyball ------------------------------------------------------------------
#
# The three touches of a rally, plus the block. They are one-shot clips like the
# badminton shots, and they carry the vb_ prefix so that the two sports can live in one
# exported character without arguing over the word "serve".

## The first touch: the ball is dug up off the sand, forearms together, low.
func dig() -> void:
	_play("vb_dig", true)


## The second: put up for somebody else to hit. Not called `set`, which is a keyword.
func set_the_ball() -> void:
	_play("vb_set", true)


## The third, and the only one anybody watches.
func spike() -> void:
	_play("vb_spike", true)


## Both arms up over the net, which is where the touch call is decided.
func block() -> void:
	_play("vb_block", true)


func serve_the_ball() -> void:
	_play("vb_serve", true)


## Winning the point.
func celebrate() -> void:
	_play("celebrate", true)


## Turning on the chair after a call that went against them. The only time anybody in
## this game looks at the umpire.
func argue() -> void:
	_play("argue", true)


## Bob, lean and swing. All of it moves the whole figure, because the figure is a
## single static mesh with no skeleton to pose.
func _animate(delta: float, running: bool) -> void:
	if _figure == null:
		return
	# The forged characters have real animation. Bobbing and leaning them on top of
	# their own run cycle would just make them seasick.
	if _animator != null:
		return

	if running:
		_bob += delta * BOB_SPEED
	_figure.position.y = absf(sin(_bob)) * BOB_HEIGHT if running else 0.0

	_lean = move_toward(_lean, RUN_LEAN if running else 0.0, delta * LEAN_SPEED)
	_figure.rotation.x = -_lean

	if _swing_left <= 0.0 or _racket == null:
		return
	_swing_left -= delta
	# One smooth sweep through and back, rather than a snap.
	var through := 1.0 - clampf(_swing_left / SWING_SECONDS, 0.0, 1.0)
	_racket.rotation.x = _racket_rest.x - sin(through * PI) * SWING_SWEEP


func _physics_process(delta: float) -> void:
	var aim := _destination
	if _lunge_left > 0.0:
		_lunge_left -= delta
		aim = _lunge_spot

	var here := Vector2(position.x, position.z)
	var there := Vector2(aim.x, aim.z)
	var moved := here.move_toward(there, speed * delta)
	position = Vector3(moved.x, 0.0, moved.y)

	var travelled := here.distance_to(moved) / maxf(delta, 0.0001)
	var running := travelled > MOVING_THRESHOLD
	_animate(delta, running)
	if _animator != null:
		_play("run" if running else ("ready" if chasing else "idle"))

	# Facing the way they are running. The Meshy characters look down their own +Z, so
	# the angle is the heading itself — measured off the rig's headfront bone rather
	# than assumed, because the last two models faced the other way and everybody spent
	# the match running backwards.
	var heading := moved - here
	if heading.length() > 0.0005:
		rotation.y = atan2(heading.x, heading.y)


## Go after the shuttle, to the spot they believe it will land.
func chase(point: Vector3) -> void:
	chasing = true
	_destination = Vector3(point.x, 0.0, point.z)


## Decide the shuttle is going out and stand and watch it. This is a gamble on the
## umpire, and the player has no idea who the umpire wants to win.
func stand_off() -> void:
	chasing = false


## Throws the player at a spot for a moment, overriding wherever they were going.
## Used to send them reaching over the net, which is what obstruction looks like.
func lunge(spot: Vector3, seconds := 0.7) -> void:
	_lunge_spot = Vector3(spot.x, 0.0, spot.z)
	_lunge_left = seconds


func go_home() -> void:
	chasing = false
	_destination = home


## Whether the shuttle is close enough, and at a sensible height, to be hit.
func can_strike(shuttle_position: Vector3) -> bool:
	if not chasing:
		return false
	if shuttle_position.y > HIGHEST_STRIKE or shuttle_position.y < LOWEST_STRIKE:
		return false
	var gap := Vector2(shuttle_position.x - position.x, shuttle_position.z - position.z)
	return gap.length() <= reach


## How far they still have to run to reach a point.
func distance_to(point: Vector3) -> float:
	return Vector2(point.x - position.x, point.z - position.z).length()


func _build_body() -> void:
	# A real athlete if the downloaded assets are there, and the boxes in figure.gd
	# if they are not. The fallback is not decoration: a game that will not start
	# because a model is missing is worse than a game with a box in it.
	var model := Models.player(team)
	if model != null:
		add_child(model)
		_figure = model
		if Models.is_forged(model):
			# Already the right size and the right way up. Dress it and go.
			Models.dress_player(model, not volleyball)
			_take_up_racket(model)
			_set_up_clips(model)
		else:
			_settle_when_posed(model)
	else:
		Figure.standing(self, Sides.colour(team), true)

	# Facing across the net, towards whoever they are playing.
	rotation.y = PI if Sides.half_sign(team) > 0.0 else 0.0
