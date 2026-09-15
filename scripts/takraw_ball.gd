class_name TakrawBall
extends Ball

## A sepak takraw ball: woven synthetic fibre, twelve holes, 170 to 180 grams and 41 to 43 cm
## round for men (ISTAF Law 4). About 13.4 cm across — a grapefruit, not a football.
##
## It is hollow and full of holes, so it drags far more than its weight suggests and slows
## visibly over a spike. The terminal speed is worked out rather than measured: 175 g over a
## 13.4 cm disc at a drag coefficient of about 0.8 (a perforated sphere) settles near 16 m/s.
## Nobody has published a wind-tunnel figure for a takraw ball; if one turns up, this number
## is the one to change.

const TAKRAW_MASS := 0.175
const TAKRAW_RADIUS := TakrawSpec.BALL_RADIUS
const TAKRAW_TERMINAL := 16.0

## Off a synthetic sports mat. Lively, but a woven ball gives a little on impact.
const MAT_BOUNCE := 0.45


func _init() -> void:
	mass_kg = TAKRAW_MASS
	radius = TAKRAW_RADIUS
	terminal_velocity = TAKRAW_TERMINAL
	bounce = MAT_BOUNCE


## Yellow, as on television. The weave would need a texture, and at the size the ball is on
## screen a clean yellow with a slightly rough finish reads better than a pattern sampled down
## to a dozen pixels.
func _build_body() -> void:
	var view := MeshInstance3D.new()
	view.name = "Ball"
	var sphere := SphereMesh.new()
	sphere.radius = radius
	sphere.height = radius * 2.0
	sphere.radial_segments = 20
	sphere.rings = 10
	view.mesh = sphere

	var weave := StandardMaterial3D.new()
	weave.albedo_color = Color(0.98, 0.80, 0.12)
	weave.roughness = 0.85
	view.material_override = weave
	add_child(view)


## The flight, for the shot solver to aim with.
static func flight() -> ShotSolver.Flight:
	return ShotSolver.Flight.new(TAKRAW_TERMINAL, TAKRAW_RADIUS, false)
