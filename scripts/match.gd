extends Node3D

## One match: the court, the umpire, and the loop of rally, call, point.
##
## The shape of the loop is the umpire's real job. Whistle to start the rally, watch
## it, then say what happened. The game already knows what happened. It waits to
## hear what you say about it.

## Eye height of a seated umpire. The chair seat is at 1.55 m, so this is roughly
## where their head is — a little above the top of the net, which is 1.524 m. That
## is not an accident: it is why the umpire, and only the umpire, can see the net
## cord from level.
const EYE_HEIGHT := 2.32

## How far outside the sideline the chair stands. Must match Court.CHAIR_OFFSET.
const CHAIR_OFFSET := 0.9

## How high the hall lights hang, and how bright each one is.
const LIGHT_HEIGHT := 7.4
const LIGHT_ENERGY := 1.7

## Where a serve is struck from, and how high.
const SERVE_DISTANCE := 3.0
const SERVE_HEIGHT := 2.45

## How often a shot is aimed within a few centimetres of a line, and how far either
## side of it. See _pick_target for why this bias exists at all.
const CLOSE_CALL_CHANCE := 0.60
const CLOSE_CALL_DRIFT := 0.09

## How often a shot is simply a bad one that sails clearly out, and how far past the
## line it goes. These are the rallies where the whole hall can see the answer.
const BAD_SHOT_CHANCE := 0.16
const BAD_SHOT_MIN := 0.30
const BAD_SHOT_MAX := 1.30

enum Phase {
	## Choosing who you want to win.
	PRE_MATCH,
	## Waiting for the umpire to start the rally.
	READY,
	## The shuttle is in the air.
	IN_FLIGHT,
	## The shuttle has landed. The hall is waiting for you to say something.
	AWAITING_CALL,
	## Taken off the match. Nothing more to do.
	REMOVED,
}

## How often the hall mutters something between rallies once it has stopped
## trusting the umpire.
const AMBIENT_CHANCE := 0.45

## While developing, the truth of each rally is printed to the console. This must be
## off before anyone plays it — the player learning where the shuttle really landed
## would remove the only interesting decision in the game.
@export var print_truth_while_testing := true

var court: Court
var camera: UmpireCamera
var ui: RefereeUI

## What really happened in the rally being played right now, and what was said about
## it. Never shown to the player.
var rally: Rally

## Who the player privately decided should win. Nothing on screen ever says this.
var favoured := Sides.Team.NONE

## How much the hall doubts you. Never displayed — you find out by reading the room.
var suspicion: Suspicion

var serving := Sides.Team.RED
var score := {Sides.Team.RED: 0, Sides.Team.BLUE: 0}

var _phase := Phase.PRE_MATCH
var _shuttle: Shuttle


func _ready() -> void:
	# Deliberately no randomize() here. Godot already seeds the generator randomly at
	# startup, and calling it again would throw away any seed a test had set — which
	# would mean two umpires could never be compared over the same run of rallies.
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

	ui = RefereeUI.new()
	ui.name = "RefereeUI"
	ui.favour_chosen.connect(_on_favour_chosen)
	add_child(ui)

	suspicion = Suspicion.new()
	suspicion.warning_issued.connect(_on_warning_issued)
	suspicion.removed_from_match.connect(_on_removed_from_match)


# --- the loop ------------------------------------------------------------------

func _on_favour_chosen(team: Sides.Team) -> void:
	favoured = team
	ui.hide_pre_match()
	camera.set_active(true)
	_enter_ready()


func _unhandled_input(event: InputEvent) -> void:
	match _phase:
		Phase.READY:
			if event.is_action_pressed(&"ui_accept") or _is_key(event, KEY_SPACE):
				_start_rally()
		Phase.AWAITING_CALL:
			if event is InputEventMouseButton and event.pressed:
				if event.button_index == MOUSE_BUTTON_LEFT:
					_make_call(&"in")
				elif event.button_index == MOUSE_BUTTON_RIGHT:
					_make_call(&"out")
			elif _is_key(event, KEY_L):
				_make_call(&"let")


func _enter_ready() -> void:
	if suspicion.is_removed:
		return
	_phase = Phase.READY
	_update_score()
	ui.set_prompt("SPACE  whistle to start the rally")

	# The hall gets on with having an opinion whether or not anything just happened.
	if randf() < AMBIENT_CHANCE:
		ui.react(Crowd.ambient(suspicion.mood), 3.2)


func _start_rally() -> void:
	var from := Vector3(
		randf_range(-1.6, 1.6),
		SERVE_HEIGHT,
		Sides.half_sign(serving) * SERVE_DISTANCE
	)
	var target := _pick_target(Sides.half_sign(Sides.opponent(serving)))

	if serve(from, target, randf_range(30.0, 44.0), serving) == null:
		return

	_phase = Phase.IN_FLIGHT
	ui.set_prompt("watch it")


func _on_shuttle_landed(point: Vector3) -> void:
	rally.record_landing(point)
	_phase = Phase.AWAITING_CALL
	ui.set_prompt("LEFT CLICK  in        RIGHT CLICK  out        L  let")


func _make_call(id: StringName) -> void:
	var call := CallBook.get_call(id)
	if call == null:
		return

	rally.record_call(call)
	var winner := rally.point_goes_to()

	if winner != Sides.Team.NONE:
		score[winner] += 1
		# In badminton the side that wins the rally serves the next one.
		serving = winner
		ui.announce("%s   ·   POINT %s" % [call.label, Sides.label(winner)], Sides.colour(winner))
	else:
		ui.announce("%s   ·   PLAY IT AGAIN" % call.label, Color(0.85, 0.85, 0.80))

	# The hall makes up its mind about what it just saw. The player is told nothing
	# except how the room reacted — which is the whole of the feedback they get.
	suspicion.register(rally)
	ui.react(Crowd.react_to_call(rally.visibility(), suspicion.mood))

	if print_truth_while_testing:
		print("[truth, testing only] %s  |  suspicion %.3f lean %+.2f" % [
			rally.describe(), suspicion.level, suspicion.lean
		])

	_enter_ready()


func _on_warning_issued() -> void:
	ui.show_banner("THE TOURNAMENT REFEREE HAS BEEN CALLED")
	ui.react("the tournament referee walks to the side of the court and sits down", 5.0)


func _on_removed_from_match() -> void:
	_phase = Phase.REMOVED
	camera.set_active(false)
	ui.set_prompt("")
	ui.show_ending("YOU HAVE BEEN REMOVED FROM THE MATCH", _reckoning())


## The only place in the game where the truth is allowed on screen. The match is
## over, so there is nothing left to judge and nothing left to protect.
func _reckoning() -> String:
	var lines := []
	lines.append("%d wrong calls, %d of which decided the rally." % [
		suspicion.wrong_calls, suspicion.stolen_rallies
	])

	if absf(suspicion.lean) < 0.15:
		lines.append("They went both ways. You were not bent. You were just bad at this.")
	else:
		var helped := Sides.Team.BLUE if suspicion.lean > 0.0 else Sides.Team.RED
		lines.append("Almost every one of them helped %s." % Sides.label(helped))
		if helped == favoured:
			lines.append("Which is who you wanted to win. Everyone worked that out before you did.")
		else:
			lines.append("Which is not even who you wanted to win.")

	lines.append("")
	lines.append("Final score  RED %d — %d BLUE" % [score[Sides.Team.RED], score[Sides.Team.BLUE]])
	return "\n".join(lines)


func _update_score() -> void:
	ui.set_score(score[Sides.Team.RED], score[Sides.Team.BLUE], serving)


# --- hitting the shuttle -------------------------------------------------------

## Hits a shuttle from `from` so that it lands on `target`, and starts recording a
## new rally. `angle` decides the kind of shot: low is a drive, high is a clear.
func serve(from: Vector3, target: Vector3, angle := 36.0, striker := Sides.Team.NONE) -> Shuttle:
	var velocity := ShotSolver.solve(from, target, angle, Court.MAT_THICKNESS)
	if velocity == Vector3.ZERO:
		push_warning("No shot at %.0f degrees reaches %v from %v" % [angle, target, from])
		return null

	if is_instance_valid(_shuttle):
		_shuttle.queue_free()

	rally = Rally.new(striker, true)
	_shuttle = Shuttle.new()
	_shuttle.name = "Shuttle"
	add_child(_shuttle)
	_shuttle.landed.connect(_on_shuttle_landed)
	_shuttle.launch(from, velocity)
	return _shuttle


## Picks where the shuttle is aimed, in the half given by `half` (+1 or -1 along Z).
##
## Most shots are aimed within a few centimetres of a line. This is deliberate and
## it is not how badminton is really played: honest shot selection puts most
## shuttles well inside the court, where there is nothing to judge and the umpire
## has no decision to make. The close calls have to be manufactured, or the job is
## boring and the player never gets to choose whether to lie.
func _pick_target(half: float) -> Vector3:
	var roll := randf()

	# A shot that is simply bad, sailing well past the line. These matter as much as
	# the close ones: they are the rallies where everybody in the hall already knows
	# the answer, so calling one of them IN is not a lie the umpire can hide behind.
	# Without them there would be no dangerous calls at all, only safe ones, and
	# cheating would carry no risk worth thinking about.
	if roll < BAD_SHOT_CHANCE:
		var over := randf_range(BAD_SHOT_MIN, BAD_SHOT_MAX)
		if randf() < 0.45:
			var wide := CourtSpec.HALF_WIDTH_DOUBLES * (1.0 if randf() < 0.5 else -1.0)
			return Vector3(wide + over * signf(wide), 0.0, half * randf_range(2.0, 6.0))
		return Vector3(randf_range(-2.8, 2.8), 0.0, half * (CourtSpec.HALF_LENGTH + over))

	# A shot played safely into the middle of the court, where there is nothing to
	# judge and the umpire simply confirms what everyone saw.
	if roll > BAD_SHOT_CHANCE + CLOSE_CALL_CHANCE:
		return Vector3(randf_range(-2.3, 2.3), 0.0, half * randf_range(2.6, 5.6))

	var drift := randf_range(-CLOSE_CALL_DRIFT, CLOSE_CALL_DRIFT)

	if randf() < 0.5:
		# Along a sideline, a whisker in or a whisker out.
		var side := CourtSpec.HALF_WIDTH_DOUBLES * (1.0 if randf() < 0.5 else -1.0)
		return Vector3(side + drift * signf(side), 0.0, half * randf_range(2.2, 6.2))

	# Along the back line, just short or just long.
	return Vector3(randf_range(-2.8, 2.8), 0.0, half * (CourtSpec.HALF_LENGTH + drift))


func _is_key(event: InputEvent, keycode: Key) -> bool:
	return event is InputEventKey and event.pressed and not event.echo and event.keycode == keycode


# --- the hall ------------------------------------------------------------------

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
