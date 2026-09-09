class_name TennisBall
extends Ball

## A tennis ball: 57 grams, 6.7 cm across, and it bounces like nothing else in this game.
##
## The other two balls in this project are treated as things that arrive somewhere. A
## shuttlecock stops dead; a volleyball's bounce is decoration over a landing already
## recorded. A tennis ball's bounce is **part of the rules** — a point ends when it
## bounces twice — so this one is asked to keep bouncing and to remember how often.
##
## It is also far lighter and far faster than the volleyball, which changes the flight
## more than the numbers suggest: a serve leaves the racket at over 50 m/s and is
## noticeably slowed by the air before it arrives, which is why the drag model matters
## here even more than it did on the sand.

## ITF: 56.0 to 59.4 grams, 6.54 to 6.86 cm in diameter.
const TENNIS_MASS := 0.058
const TENNIS_RADIUS := 0.0335

## Terminal velocity for a tennis ball is about 30 m/s in still air — close to the
## volleyball's by coincidence, because it is far lighter and far smaller at once.
const TENNIS_TERMINAL := 30.0

## How much of its speed survives a bounce on a hard court. Higher than sand by a long
## way, which is the whole reason a rally happens after the ball has landed.
const HARD_COURT_BOUNCE := 0.72


func _init() -> void:
	mass_kg = TENNIS_MASS
	radius = TENNIS_RADIUS
	terminal_velocity = TENNIS_TERMINAL
	bounce = HARD_COURT_BOUNCE


func _build_body() -> void:
	var view := MeshInstance3D.new()
	view.name = "Ball"
	var sphere := SphereMesh.new()
	sphere.radius = radius
	sphere.height = radius * 2.0
	sphere.radial_segments = 20
	sphere.rings = 10
	view.mesh = sphere

	var felt := StandardMaterial3D.new()
	felt.albedo_color = Color(0.83, 0.94, 0.20)
	felt.roughness = 0.95
	view.material_override = felt
	add_child(view)
