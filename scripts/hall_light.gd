class_name HallLight
extends Node3D

## The rig that makes a hall read as televised sport: a dark bowl with the court burning
## in the middle of it.
##
## Badminton has had this since the venues were built, buried inside `Venue` along with
## the sponsor boards, the second court and the officials' table. Every other sport wrote
## its own lighting instead — one `DirectionalLight3D` at nearly double energy over an
## ambient of 1.2 — which is a room with the strip lights on. It lights the back wall as
## brightly as the court, gives the players no shadow to stand on, and leaves the eye
## nothing to be drawn to.
##
## Luqman played the game on 2026-09-16 and asked for sepak takraw and volleyball to be
## lit "like in badminton", so the rig lives here, where more than one sport can reach it.
##
## Four pieces, each with a job:
##
## * A **dark environment.** Ambient falls from 1.2 to about 0.15, so nothing in the hall
##   is lit except by a lamp that is really in the scene.
## * **Haze**, and volumetric fog so the beams have something to land on. Thin enough to
##   see the far line through, because a hall you cannot see the far line in is a hall you
##   cannot referee in.
## * A **barely-there sun**, at a fifth of the energy the flat rigs used. It is not there
##   to light anything. It is there to put one clean shadow direction under the net, the
##   posts and the players, so they sit on the floor rather than float over it.
## * **Truss and lamps** over the court, with real spotlights in four of the fittings
##   aimed down at the middle of it.
##
## Everything is a multiple of the court being lit, so one rig fits takraw's 13.4 m court
## and volleyball's 18 m one without a second set of numbers. The multiples are
## badminton's own, read off `Venue`: a 4.4 m truss spread over a 3.05 m half width, an
## 11.0 m truss run and lamps reaching 9.0 m over a 6.70 m half length, hung at 8.1 m in
## a 9.0 m hall.
##
## The rungs of the ladder come from `Venue.TIERS` rather than a copy of them, so a
## school hall and a final differ by the same amounts in every sport, and changing what a
## promotion looks like stays a one-file job.
##
## `Venue` still holds its own copy of the rig rather than calling in here. Badminton was
## not part of what Luqman asked for, and its lighting is welded to the rest of its
## dressing; unpicking the two is a separate job for when somebody is looking at
## badminton on purpose.

## How high the truss hangs as a fraction of the hall, and how far the two runs of it
## stand either side of the centre line as a multiple of the court's half width.
## What the energy is multiplied by now the cone is wider. A spotlight is measured by
## what lands on what it points at, so opening the cone from 34 to 52 degrees spreads the
## same energy over roughly 1.4 times the floor — without this the middle of the court
## floods and the white lines blow out.
const WIDER_CONE_KEEPS_ITS_BRIGHTNESS := 0.72


const TRUSS_HEIGHT_OF_HALL := 0.90
const TRUSS_SPREAD_OF_HALF_WIDTH := 1.443

## How far the truss runs, and how far the outermost lamps reach, as multiples of the
## court's half length. The truss overshoots the court because a run that stops at the
## baseline reads as a gantry rather than a roof.
const TRUSS_RUN_OF_HALF_LENGTH := 1.642
const LAMP_REACH_OF_HALF_LENGTH := 1.343

## Where a lamp points, along the court, as a multiple of the half length. The beams
## converge: the far ones are aimed well inside the baseline so the light pools over the
## middle rather than spilling into the stands.
const LAMP_AIM_OF_HALF_LENGTH := 0.448

## How far under the truss a lamp hangs.
const LAMP_DROP := 0.45

## Two facing pairs carry real light. Twelve shadow-casting spotlights over a hall full
## of people costs more than the rest of the game together; four lights sharing the same
## total brightness cannot be told apart from the chair. See `Venue` for the measurement.
const REAL_LAMP_PAIRS := 2

## The court this rig is lighting, in metres. Set before `light()` is called.
var half_width := 3.05
var half_length := 6.70
var hall_height := 9.0

## How hard the lamps burn, against badminton's. Lamp energy alone does not decide how
## bright a court looks — what it is bouncing off does. Badminton is played on a dark
## green mat and volleyball on sprung maple, which returns nearly three times as much of
## the light that lands on it, so the same beams that light a badminton court properly
## blow a volleyball court out to a flat orange with no lines left in it. This is the
## floor's reflectance taken back out, so every sport can be lit by the same rig without
## every sport having to be the same colour.
var court_light_scale := 1.0

var tier := Venue.Tier.REGIONAL

var _environment: WorldEnvironment
var _sun: DirectionalLight3D


## Lights the hall for one rung of the ladder. Safe to call again — a career moves
## between venues, and everything the last call made is thrown away first.
func light(which: Venue.Tier) -> void:
	tier = which
	for child in get_children():
		# Detached before being freed, not merely queued. `queue_free` happens at the end
		# of the frame, so the old WorldEnvironment and the new one would both be in the
		# world at once, and which of the two the renderer picks is a coin toss.
		remove_child(child)
		child.queue_free()

	var spec: Dictionary = Venue.TIERS[tier]
	_build_air(spec)
	_build_truss()
	_build_lamps(spec)


# --- the air --------------------------------------------------------------------

## The hall light and the light on the court, which are two different things. This is the
## hall: dark, cool, and hazy enough for a beam to show in it.
func _build_air(spec: Dictionary) -> void:
	_environment = WorldEnvironment.new()
	_environment.name = "Air"
	var air := Environment.new()
	air.background_mode = Environment.BG_COLOR
	air.background_color = spec["ambient_tint"] * 0.35
	air.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	air.ambient_light_color = spec["ambient_tint"]
	air.ambient_light_energy = spec["ambient"]
	air.fog_enabled = true
	air.fog_light_color = Color(0.42, 0.48, 0.62)
	air.fog_density = 0.005
	air.fog_sky_affect = 0.0

	air.volumetric_fog_enabled = true
	air.volumetric_fog_density = 0.013
	air.volumetric_fog_albedo = Color(0.72, 0.78, 0.92)
	air.volumetric_fog_length = 42.0
	_environment.environment = air
	add_child(_environment)

	_sun = DirectionalLight3D.new()
	_sun.name = "HallLight"
	_sun.rotation = Vector3(deg_to_rad(-58.0), deg_to_rad(34.0), 0.0)
	_sun.light_energy = 0.22 if tier == Venue.Tier.SCHOOL else 0.14
	_sun.shadow_enabled = true
	add_child(_sun)


# --- the roof -------------------------------------------------------------------

func _build_truss() -> void:
	var runs := Node3D.new()
	runs.name = "Truss"
	add_child(runs)

	var spread := half_width * TRUSS_SPREAD_OF_HALF_WIDTH
	var run := half_length * TRUSS_RUN_OF_HALF_LENGTH
	for side in [1.0, -1.0]:
		for section in [-1.0, 0.0, 1.0]:
			var piece := Props.node(Props.TRUSS, 0.80)
			if piece == null:
				return
			piece.position = Vector3(
				side * spread, hall_height * TRUSS_HEIGHT_OF_HALL, section * run)
			# The truss model runs along its own X, and a court is long along Z.
			piece.rotation.y = PI * 0.5
			runs.add_child(piece)


## Lamps hanging under the truss, four of them with a real spotlight inside aimed at the
## middle of the court. Fittings without light in them are stage dressing; these are what
## is actually lighting the rally.
func _build_lamps(spec: Dictionary) -> void:
	var count: int = spec["lamps"]
	if count <= 0:
		return

	var lights := Node3D.new()
	lights.name = "Lamps"
	add_child(lights)

	var spread := half_width * TRUSS_SPREAD_OF_HALF_WIDTH
	var reach := half_length * LAMP_REACH_OF_HALF_LENGTH
	var aim := half_length * LAMP_AIM_OF_HALF_LENGTH
	var height := hall_height * TRUSS_HEIGHT_OF_HALL - LAMP_DROP

	var energy: float = spec["court_light"] * court_light_scale
	var lit := _lamps_with_light_in_them(count)
	# The same light on the court in total, from fewer places.
	var brighter := float(count) / float(lit.size())
	for i in count:
		var side := 1.0 if i % 2 == 0 else -1.0
		var along := (float(i / 2) / maxf(1.0, float(count / 2 - 1)) - 0.5) * 2.0
		var where := Vector3(side * spread, height, along * reach)

		var fitting := Props.node(Props.LAMP, 0.55)
		if fitting != null:
			fitting.position = where
			lights.add_child(fitting)

		if not i in lit:
			continue
		var beam := SpotLight3D.new()
		beam.name = "Beam"
		beam.position = where
		beam.look_at_from_position(where, Vector3(0.0, 0.0, along * aim), Vector3.UP)
		beam.light_energy = energy * brighter * WIDER_CONE_KEEPS_ITS_BRIGHTNESS
		beam.light_color = Color(1.0, 0.98, 0.94)
		# The throw has to clear the drop from the truss to the floor, which is longer in
		# a volleyball hall than a takraw one, or the far corner of the pool goes out.
		beam.spot_range = height * 2.8
		# A wider cone, asked for on 2026-09-18: "the light radius at court in the game is
		# too small, make it bigger."
		#
		# At 34 degrees a lamp hung at 8.1 m throws a pool about 5.5 m across, so four of
		# them lit a stripe down the middle and left the tramlines and the corners in the
		# dark — on a court 13.4 m long for takraw and 18 m for volleyball. Judging a
		# landing in a corner you cannot see is not a difficulty, it is a broken game.
		# At 52 the same lamp covers about 8.5 m and the pools meet.
		#
		# The energy comes down as the cone opens. A spotlight's brightness is per unit of
		# what it hits, so widening the cone without touching the energy floods the middle
		# of the court and blows the white lines out. The 0.72 is the ratio of the areas,
		# so the court keeps the light it had and simply spreads it further.
		beam.spot_angle = 52.0
		beam.spot_angle_attenuation = 0.7
		# One facing pair casts shadows, for the reason in REAL_LAMP_PAIRS.
		beam.shadow_enabled = i == lit[0] or i == lit[1]
		lights.add_child(beam)


## Which fittings have a real light in them: two facing pairs, the same distance either
## side of the net.
func _lamps_with_light_in_them(count: int) -> Array:
	var pairs := count / 2
	if pairs <= REAL_LAMP_PAIRS:
		return range(count)
	var near := floori(float(pairs - 1) * 0.25 + 0.5)
	var far := pairs - 1 - near
	return [near * 2, near * 2 + 1, far * 2, far * 2 + 1]
