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

## Highest and lowest a shuttle can be and still be hit. The top of the range is an
## overhead smash; the bottom is a scrambling lift off the floor.
const HIGHEST_STRIKE := 2.85
const LOWEST_STRIKE := 0.28

## How fast they cover the court, in metres per second.
@export var speed := 4.0

## How far from the shuttle they can still reach it, racket included.
@export var reach := 0.95

var team := Sides.Team.NONE

## Where they stand when the shuttle is not their problem.
var home := Vector3.ZERO

## Whether they are currently going after the shuttle.
var chasing := false

var _destination := Vector3.ZERO


func setup(for_team: Sides.Team, home_position: Vector3) -> void:
	team = for_team
	home = home_position
	position = home_position
	_destination = home_position
	_build_body()


func _physics_process(delta: float) -> void:
	var here := Vector2(position.x, position.z)
	var there := Vector2(_destination.x, _destination.z)
	var moved := here.move_toward(there, speed * delta)
	position = Vector3(moved.x, 0.0, moved.y)


## Go after the shuttle, to the spot they believe it will land.
func chase(point: Vector3) -> void:
	chasing = true
	_destination = Vector3(point.x, 0.0, point.z)


## Decide the shuttle is going out and stand and watch it. This is a gamble on the
## umpire, and the player has no idea who the umpire wants to win.
func stand_off() -> void:
	chasing = false


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
	var mesh := MeshInstance3D.new()
	mesh.name = "Body"
	var capsule := CapsuleMesh.new()
	capsule.radius = BODY_RADIUS
	capsule.height = BODY_HEIGHT
	mesh.mesh = capsule
	mesh.position = Vector3(0.0, BODY_HEIGHT * 0.5, 0.0)

	var material := StandardMaterial3D.new()
	material.albedo_color = Sides.colour(team)
	material.roughness = 0.85
	mesh.material_override = material
	add_child(mesh)
