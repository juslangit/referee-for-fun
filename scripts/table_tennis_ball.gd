class_name TableTennisBall
extends Ball

## A table tennis ball: 2.7 grams and 40 mm across, and unlike anything else in this game.
##
## It is the lightest object here by a factor of two — a shuttlecock is nearly double its
## mass — and it is very nearly hollow, so **air matters more to it than to any other ball
## in the project**. Its terminal velocity is about 9 m/s against a tennis ball's 30, which
## is why a smash that leaves the bat at 25 m/s arrives much slower, and why the ball can
## be hit as hard as it is over a table two and a half metres long.
##
## It also bounces higher than anything else here relative to how fast it arrives, which
## is the whole reason the sport works on a surface this small.

## ITTF: 2.7 g, 40 mm diameter.
const TT_MASS := 0.0027
const TT_RADIUS := 0.02

## Terminal velocity, in still air. Low, because there is almost nothing to it.
const TT_TERMINAL := 9.0

## Off a tabletop. Higher than any other surface in this game.
const TABLE_BOUNCE := 0.89

## It settles almost at once — there is no momentum in 2.7 grams — so it is given less
## grace than the others before being taken out of play.
const SETTLE_AT_ONCE := 0.5


func _init() -> void:
	mass_kg = TT_MASS
	radius = TT_RADIUS
	terminal_velocity = TT_TERMINAL
	bounce = TABLE_BOUNCE
	settle_seconds = SETTLE_AT_ONCE


func _build_body() -> void:
	var view := MeshInstance3D.new()
	view.name = "Ball"
	var sphere := SphereMesh.new()
	sphere.radius = radius
	sphere.height = radius * 2.0
	sphere.radial_segments = 16
	sphere.rings = 8
	view.mesh = sphere

	# White or orange; white is what a dark table is played on.
	var celluloid := StandardMaterial3D.new()
	celluloid.albedo_color = Color(0.97, 0.97, 0.94)
	celluloid.roughness = 0.55
	view.material_override = celluloid
	add_child(view)


## The one thing about this ball that is not just "smaller and lighter".
##
## Every other surface in this game **is** the floor, so a ball that lands out still
## lands on something and rolls to a stop there. A table is 76 cm up and 1.5 m wide, and
## a ball that misses it does not bounce at hip height in mid-air — it falls the rest of
## the way to the ground. So a landing outside the table drops the ball's own floor to
## the real one and lets it carry on down.
##
## The *truth* is untouched by this. The call is decided by where the underside crossed
## the plane of the tabletop, which is recorded before any of this runs, exactly as an
## out ball is in the other four sports.
func _bounce_again() -> void:
	if floor_height > 0.0 and not TableTennisSpec.is_in(global_position):
		floor_height = 0.0
		return
	super._bounce_again()


func launch(from: Vector3, velocity: Vector3) -> void:
	# Back onto the table for the next stroke, wherever the last one ended up.
	floor_height = TableTennisSpec.HEIGHT
	super.launch(from, velocity)
