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

## Where they stand when the shuttle is not their problem.
var home := Vector3.ZERO

## Whether they are currently going after the shuttle.
var chasing := false

var _destination := Vector3.ZERO
var _lunge_left := 0.0
var _lunge_spot := Vector3.ZERO

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
	Models.dress_player(model)
	_racket = model.get_meta("racket", null)
	if _racket != null:
		_racket_rest = _racket.rotation


## Takes a swing. Called when this player plays a shot, so the racket moves at the
## moment the shuttle does.
func swing() -> void:
	_swing_left = SWING_SECONDS


## Bob, lean and swing. All of it moves the whole figure, because the figure is a
## single static mesh with no skeleton to pose.
func _animate(delta: float, running: bool) -> void:
	if _figure == null:
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
	_animate(delta, travelled > MOVING_THRESHOLD)

	# Facing the way they are running.
	var heading := moved - here
	if heading.length() > 0.0005:
		rotation.y = atan2(heading.x, heading.y) + PI


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
	var model := Models.player(Sides.colour(team))
	if model != null:
		add_child(model)
		_figure = model
		_settle_when_posed(model)
	else:
		Figure.standing(self, Sides.colour(team), true)

	# Facing across the net, towards whoever they are playing.
	rotation.y = 0.0 if Sides.half_sign(team) > 0.0 else PI
