extends Node3D

## Assembles one match: the court, the lighting, and the umpire in the chair.
##
## Built in code rather than laid out by hand in the editor, so that every number
## that matters is written down somewhere readable instead of buried in a scene file.

## Eye height of a seated umpire. The chair seat is at 1.55 m, so this is roughly
## where their head is — a little above the top of the net, which is 1.524 m. That
## is not an accident: it is why the umpire, and only the umpire, can see the net
## cord from level.
const EYE_HEIGHT := 2.32

## How far outside the sideline the chair stands. Must match Court.CHAIR_OFFSET.
const CHAIR_OFFSET := 0.9

## While developing, the truth of each rally is printed to the console. This must be
## off before anyone plays it — the player learning where the shuttle really landed
## would remove the only interesting decision in the game.
@export var print_truth_while_testing := true

var court: Court
var camera: UmpireCamera

## What really happened in the rally being played right now. Written when the
## shuttle lands, and never shown to the player.
var rally: Rally

var _shuttle: Shuttle


func _ready() -> void:
	_build_environment()

	court = Court.new()
	court.name = "Court"
	add_child(court)

	camera = UmpireCamera.new()
	camera.name = "UmpireCamera"
	camera.position = Vector3(CourtSpec.HALF_WIDTH_DOUBLES + CHAIR_OFFSET, EYE_HEIGHT, 0.0)
	camera.fov = 82.0
	camera.current = true
	add_child(camera)


## How high the hall lights hang, and how bright each one is.
const LIGHT_HEIGHT := 7.4
const LIGHT_ENERGY := 1.7


func _build_environment() -> void:
	# A sports hall is lit from above by a grid of lamps, not by the sun. The sun
	# here is only doing one job: casting a single clean shadow direction so the net
	# and the posts sit on the floor instead of floating over it.
	var key := DirectionalLight3D.new()
	key.name = "KeyLight"
	key.rotation = Vector3(deg_to_rad(-62.0), deg_to_rad(28.0), 0.0)
	key.light_energy = 0.55
	key.shadow_enabled = true
	add_child(key)

	_build_hall_lights()

	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.07, 0.08, 0.10)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.55, 0.58, 0.62)
	environment.ambient_light_energy = 0.30
	environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC

	var world := WorldEnvironment.new()
	world.name = "WorldEnvironment"
	world.environment = environment
	add_child(world)


## The overhead lamp grid, two rows down the length of the hall.
func _build_hall_lights() -> void:
	for x in [-2.6, 2.6]:
		for z in [-4.6, 0.0, 4.6]:
			var lamp := OmniLight3D.new()
			lamp.name = "HallLight"
			lamp.position = Vector3(x, LIGHT_HEIGHT, z)
			lamp.light_energy = LIGHT_ENERGY
			lamp.omni_range = 22.0
			lamp.omni_attenuation = 0.6
			lamp.light_color = Color(1.0, 0.98, 0.93)
			add_child(lamp)


## Hits a shuttle from `from` so that it lands on `target`, and starts recording a
## new rally. `angle` decides the kind of shot: low is a drive, high is a clear.
func serve(from: Vector3, target: Vector3, angle := 36.0) -> Shuttle:
	var velocity := ShotSolver.solve(from, target, angle, Court.MAT_THICKNESS)
	if velocity == Vector3.ZERO:
		push_warning("No shot at %.0f degrees reaches %v from %v" % [angle, target, from])
		return null

	if is_instance_valid(_shuttle):
		_shuttle.queue_free()

	rally = Rally.new(true)
	_shuttle = Shuttle.new()
	_shuttle.name = "Shuttle"
	add_child(_shuttle)
	_shuttle.landed.connect(_on_shuttle_landed)
	_shuttle.launch(from, velocity)
	return _shuttle


func _on_shuttle_landed(point: Vector3) -> void:
	rally.record_landing(point)
	if print_truth_while_testing:
		print("[truth, testing only] ", rally.describe())


# --- temporary, for testing the shuttle by hand -------------------------------
# Enter hits a shuttle at a target that is usually right on a line. This goes away
# once the players exist and are choosing their own shots.

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ENTER:
			serve(Vector3(0.0, 2.6, -4.5), _test_target(), randf_range(30.0, 44.0))


## Picks somewhere to aim. Most of the time it goes within a few centimetres of a
## line, because a shuttle landing in the middle of the court asks the umpire
## nothing. This bias is the reason the game has anything to judge at all.
func _test_target() -> Vector3:
	var near_the_line := randf() < 0.75
	if not near_the_line:
		return Vector3(randf_range(-2.4, 2.4), 0.0, randf_range(2.6, 5.4))

	var drift := randf_range(-0.08, 0.08)
	if randf() < 0.5:
		# Somewhere along a sideline.
		var side := CourtSpec.HALF_WIDTH_DOUBLES if randf() < 0.5 else -CourtSpec.HALF_WIDTH_DOUBLES
		return Vector3(side + drift * signf(side), 0.0, randf_range(2.2, 6.2))

	# Somewhere along the back line.
	return Vector3(randf_range(-2.8, 2.8), 0.0, CourtSpec.HALF_LENGTH + drift)
