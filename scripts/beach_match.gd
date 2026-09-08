class_name BeachMatch
extends Node3D

## A beach volleyball match, refereed from the stand beside the net.
##
## The referee spine underneath this is the badminton game's, unchanged: Suspicion,
## Scoreboard, Career, Pressure, Challenge, Crowd and the interface are all shared, and
## the whole reason they were written without naming a shuttlecock is so that this file
## could exist. What is new here is the sport — the court, the ball, four players, and a
## rally made of touches rather than strokes.
##
## **The rally is scripted rather than played.** Two players a side dig, set and attack
## in turn, and each contact is a real flight solved to land on a chosen point, so the
## landing the referee judges is genuine physics and not a number picked in advance.
## Beach volleyball is a game of three touches whose third is aimed, and simulating four
## athletes making honest decisions would produce rallies that end nowhere near a line —
## exactly the problem badminton had, and solved the same way.

enum Phase {
	## Waiting for the referee to whistle the serve.
	READY,
	## The ball is up.
	IN_PLAY,
	## It has come down. The venue is waiting.
	AWAITING_CALL,
	## Taken off the match.
	REMOVED,
}

enum Beat { SERVE, DIG, SET, ATTACK }

## Where the server stands behind their end line.
const SERVE_BEHIND := 1.1
const SERVE_HEIGHT := 2.15

## How high each kind of contact goes up, in degrees. A dig is nearly vertical, a set
## is a high loop, an attack is driven down.
const DIG_ANGLE := 68.0
const SET_ANGLE := 72.0
const ATTACK_ANGLE := -4.0

## Angles a serve may be struck at, flattest first. The first one that actually clears
## the net is used.
##
## A single angle does not work, and this was measured rather than guessed: at 14° a
## serve only clears the 2.43 m net if it is aimed deep, and every shorter serve buries
## itself in the tape. Drag flattens the arc far more than the arithmetic suggests —
## thirteen of the first seventeen rallies died with the ball resting against the net.
const SERVE_ANGLES := [14.0, 20.0, 26.0, 34.0, 42.0, 50.0]

## How much daylight a shot has to show over the tape to count as clearing it.
const NET_CLEARANCE := 0.14

## How high off the sand each contact is made.
##
## Taken from the beat rather than from wherever the ball happens to be, because those
## are different things: the ball arrives at a dig near the sand and is set from
## overhead and spiked from above the net, and launching each contact from the ball's
## own height had players attacking from their knees straight into the net.
const DIG_HEIGHT := 0.55
const SET_HEIGHT := 1.95
const ATTACK_HEIGHT := 2.95

## How close the ball has to get to the next contact point before that player takes it.
const REACH := 0.9

## How often a ball heading past the end line clips the block on its way.
##
## This is the sport's signature moment: a ball going out, past a block, with everything
## resting on whether it was touched — and with nobody in the venue except the referee
## in any position to know.
const BLOCK_TOUCHES := 0.45

## How long the ball may be up before the rally is abandoned. A rally that never ends
## is worse than one that ends oddly.
const RALLY_LIMIT := 22.0

## How often anything at all goes wrong that is not about where the ball landed, and
## which of the four it is when it does.
##
## **One fault per rally, never two.** Rolling each kind independently produced rallies
## with a foot fault *and* a net touch in them, and then the game and the referee
## disagreed about which one decided the point — not because either was wrong, but
## because two faults have an order and nothing here recorded one. Badminton learned the
## neighbouring version of this lesson the hard way: rolling per stroke at seven percent
## put a fault in a third of all rallies and made an honest umpire look bent.
const FAULT_CHANCE := 0.11
const FAULT_KINDS := [&"foot_fault", &"net_touch", &"centre_line", &"handling"]
const FAULT_WEIGHTS := [0.22, 0.30, 0.16, 0.32]

var court: BeachCourt
var camera: UmpireCamera
var ui: RefereeUI

var rally: BeachRally
var suspicion: Suspicion
var board: Scoreboard
var career: Career
var settings: Settings
var sound: Sound

var players: Array[Player] = []
var serving := Sides.Team.RED

## Who the referee privately wants to win, and why they might.
var favoured := Sides.Team.NONE
var pressure := Pressure.new()

var _phase := Phase.READY
var _ball: Ball
var _beat := Beat.SERVE
var _possession := Sides.Team.NONE
var _aim := Vector3.ZERO
var _rally_seconds := 0.0
var _awaiting_since := 0

## Faults recorded on the match rather than on the rally, because they are things a
## person did rather than things the ball did.
var net_toucher := Sides.Team.NONE
var centre_line_crosser := Sides.Team.NONE

@export var print_truth_while_testing := true


func _ready() -> void:
	suspicion = Suspicion.new()
	settings = Settings.load_or_default()
	settings.apply()

	court = BeachCourt.new()
	court.name = "Court"
	add_child(court)

	_ball = Ball.new()
	_ball.name = "Ball"
	_ball.floor_height = BeachCourt.SURFACE_Y
	add_child(_ball)
	_ball.landed.connect(_on_ball_landed)
	_ball.freeze = true

	_build_players()
	_build_camera()
	_build_sky()

	ui = RefereeUI.new()
	ui.name = "UI"
	add_child(ui)
	ui.hide_menus()

	sound = Sound.new()
	sound.name = "Sound"
	add_child(sound)

	suspicion.removed_from_match.connect(func() -> void:
		# Without this the phase never leaves AWAITING_CALL — _enter_ready refuses to
		# arm the next rally once the referee is gone, and the same landing gets judged
		# again and again.
		_phase = Phase.REMOVED
		ui.set_prompt("")
		ui.show_banner("YOU HAVE BEEN TAKEN OFF THE MATCH"))

	board = Scoreboard.new(true)
	career = Career.load_or_start()
	career.sport = Career.BEACH
	suspicion.scrutiny = career.venue()["scrutiny"]
	_enter_ready()


func _build_camera() -> void:
	camera = UmpireCamera.new()
	camera.name = "RefereeCamera"
	# On the stand beside the post, looking down the length of the net. Both halves of
	# the court are then to left and right, which is the whole point of the position.
	camera.position = Vector3(
		BeachSpec.POST_X + BeachCourt.STAND_OFFSET, BeachCourt.EYE_HEIGHT, 0.0)
	# Looking back across the court, the way the badminton chair does: the stand is on
	# the +X side, so the referee faces -X. Setting this to -90 pointed them out to sea.
	camera.facing_deg = 90.0
	camera.start_pitch_deg = -19.0
	camera.fov = 78.0
	camera.cull_mask = camera.cull_mask & ~BeachCourt.STAND_LAYER
	camera.current = true
	add_child(camera)


## Outdoors, so the light comes from a sky rather than from a truss.
func _build_sky() -> void:
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation = Vector3(deg_to_rad(-54.0), deg_to_rad(34.0), 0.0)
	sun.light_energy = 1.2
	sun.shadow_enabled = true
	add_child(sun)

	var world := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var material := ProceduralSkyMaterial.new()
	material.sky_top_color = Color(0.28, 0.52, 0.82)
	material.sky_horizon_color = Color(0.78, 0.84, 0.90)
	material.ground_bottom_color = Color(0.72, 0.62, 0.46)
	material.ground_horizon_color = Color(0.82, 0.76, 0.62)
	sky.sky_material = material
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.75
	world.environment = env
	add_child(world)


func _build_players() -> void:
	for team in [Sides.Team.RED, Sides.Team.BLUE]:
		var side := Sides.half_sign(team)
		for i in 2:
			var player := Player.new()
			player.name = "%s%d" % [Sides.label(team), i]
			player.volleyball = true
			add_child(player)
			player.setup(team, Vector3(
				(1.0 if i == 0 else -1.0) * 1.9, 0.0, side * (3.2 if i == 0 else 5.6)))
			players.append(player)


# --- the rally ------------------------------------------------------------------

func start_rally() -> void:
	if _phase != Phase.READY:
		return
	rally = BeachRally.new()
	net_toucher = Sides.Team.NONE
	centre_line_crosser = Sides.Team.NONE
	_rally_seconds = 0.0

	_roll_for_one_fault()

	_possession = serving
	rally.served_by = serving
	_beat = Beat.SERVE
	rally.contacts = 1

	var side := Sides.half_sign(serving)
	var from := Vector3(
		randf_range(-2.6, 2.6),
		SERVE_HEIGHT,
		side * (BeachSpec.HALF_LENGTH + SERVE_BEHIND))
	# A serve may land anywhere in the opponent's half; there are no service courts.
	# Kept off the net end, because a serve dropped two metres from the tape is a shot
	# nobody plays and one this net height makes nearly impossible to hit.
	var target := _somewhere_in(Sides.opponent(serving), 0.55)
	target.z = Sides.half_sign(Sides.opponent(serving)) * randf_range(
		2.8, BeachSpec.HALF_LENGTH - 0.55)
	_send_over(from, target, SERVE_ANGLES)
	_phase = Phase.IN_PLAY
	sound.whistle()
	ui.set_prompt("watch it")


## At most one thing goes wrong per rally, and this decides whether and which.
func _roll_for_one_fault() -> void:
	if randf() >= FAULT_CHANCE:
		return

	var roll := randf()
	var running := 0.0
	var kind: StringName = FAULT_KINDS[FAULT_KINDS.size() - 1]
	for i in FAULT_KINDS.size():
		running += FAULT_WEIGHTS[i]
		if roll < running:
			kind = FAULT_KINDS[i]
			break

	var culprit := Sides.Team.RED if randf() < 0.5 else Sides.Team.BLUE
	match kind:
		&"foot_fault":
			rally.foot_fault = true
		&"net_touch":
			net_toucher = culprit
		&"centre_line":
			centre_line_crosser = culprit
		&"handling":
			rally.handling_fault = true
			rally.handling_visibility = randf_range(0.25, 0.85)


## Launches a shot that has to cross the net, at the flattest angle that actually gets
## over it.
##
## The same problem badminton has and solves the same way: a straight line from the
## contact to the target clears the tape comfortably, and the ball does not travel in a
## straight line. The only honest way to know is to fly it and look.
func _send_over(from: Vector3, to: Vector3, angles: Array) -> void:
	# How far the ball travels *along its own path* before it reaches the plane of the
	# net, which is not the same as how far the net is along Z. A serve struck from one
	# corner towards the far one crosses at an angle, so it has flown further than the
	# Z distance by the time it gets there — and checking its height at the Z distance
	# reads it too early, while it is still climbing, and passes shots that then bury
	# themselves in the tape.
	var flat := Vector2(to.x - from.x, to.z - from.z)
	var crosses_at := absf(from.z) / maxf(0.001, absf(to.z - from.z))
	var to_the_net := flat.length() * crosses_at
	var flight := ShotSolver.ball_flight()
	for angle in angles:
		var velocity := ShotSolver.solve(
			from, to, angle, BeachCourt.SURFACE_Y, flight)
		if velocity == Vector3.ZERO:
			continue
		var at_net := ShotSolver.height_after(
			from.y - BeachCourt.SURFACE_Y, velocity.length(), angle, to_the_net, flight)
		if at_net > BeachSpec.NET_HEIGHT + NET_CLEARANCE:
			_aim = to
			_ball.launch(from, velocity)
			return
	# Nothing in the list gets over. Loop it, which is what a player out of options does.
	_send(from, to, 55.0)


## Launches the ball, and remembers where it was meant to go so the next contact knows
## where to be.
func _send(from: Vector3, to: Vector3, angle: float) -> void:
	_aim = to
	var velocity := ShotSolver.solve(
		from, to, angle, BeachCourt.SURFACE_Y, ShotSolver.ball_flight())
	if velocity == Vector3.ZERO:
		# Unreachable at this angle. Lob it instead of abandoning the rally.
		velocity = ShotSolver.solve(
			from, to, 45.0, BeachCourt.SURFACE_Y, ShotSolver.ball_flight())
	_ball.launch(from, velocity)


## Where an attack is aimed.
##
## Most of them are aimed within a few centimetres of a line, and that is deliberate and
## not how beach volleyball is really played. Honest shot selection puts the ball safely
## inside the court, where there is nothing to judge and the referee has no decision to
## make — the same problem badminton had, and the same answer. **Close calls have to be
## manufactured or the job is boring**, and a referee who is never tempted is not being
## tested.
##
## Returns the point. Whether it is in or out is then simply where it fell.
func _attack_target(against: Sides.Team) -> Vector3:
	var side := Sides.half_sign(against)

	if randf() < 0.42:
		# Safely inside. Some rallies have to be easy, or the close ones stop feeling
		# close and the referee starts calling by reflex.
		return _somewhere_in(against, 0.6)

	# Onto a line, or a hand either side of one. Long far more often than wide, because
	# a ball going long passes over the block on its way — which is the only place a
	# touch can happen.
	var nudge := randf_range(-0.28, 0.28)
	if randf() < 0.66:
		return Vector3(
			randf_range(-BeachSpec.HALF_WIDTH + 0.5, BeachSpec.HALF_WIDTH - 0.5),
			BeachCourt.SURFACE_Y,
			side * (BeachSpec.HALF_LENGTH + nudge))
	return Vector3(
		(1.0 if randf() < 0.5 else -1.0) * (BeachSpec.HALF_WIDTH + nudge),
		BeachCourt.SURFACE_Y,
		side * randf_range(2.2, BeachSpec.HALF_LENGTH - 0.6))


## A point somewhere in a team's half, `inset` metres clear of every line.
func _somewhere_in(team: Sides.Team, inset: float) -> Vector3:
	var side := Sides.half_sign(team)
	return Vector3(
		randf_range(-BeachSpec.HALF_WIDTH + inset, BeachSpec.HALF_WIDTH - inset),
		BeachCourt.SURFACE_Y,
		side * randf_range(inset + 0.6, BeachSpec.HALF_LENGTH - inset))


func _physics_process(delta: float) -> void:
	if _phase != Phase.IN_PLAY:
		return
	_rally_seconds += delta
	if _rally_seconds > RALLY_LIMIT:
		_ball.force_landing()
		return

	# The next contact happens when the ball arrives where the last one sent it. Only
	# the attack is allowed to run all the way to the sand.
	if _beat == Beat.ATTACK:
		return
	var here := _ball.global_position
	if Vector2(here.x - _aim.x, here.z - _aim.z).length() > REACH:
		return
	if here.y > 2.6:
		return
	_take_the_next_contact()


func _take_the_next_contact() -> void:
	var here := _ball.global_position
	match _beat:
		Beat.SERVE:
			# The serve has arrived; the receiving side digs it.
			_possession = Sides.opponent(_possession)
			rally.contacts = 1
			_beat = Beat.DIG
			_send(Vector3(here.x, DIG_HEIGHT, here.z), _set_point(_possession), DIG_ANGLE)
		Beat.DIG:
			rally.contacts = 2
			_beat = Beat.SET
			_send(Vector3(here.x, SET_HEIGHT, here.z), _attack_point(_possession), SET_ANGLE)
		Beat.SET:
			rally.contacts = 3
			_beat = Beat.ATTACK
			_attack(Vector3(here.x, ATTACK_HEIGHT, here.z))


## Where the second touch goes: up near the net, on the same side.
func _set_point(team: Sides.Team) -> Vector3:
	var side := Sides.half_sign(team)
	return Vector3(randf_range(-1.8, 1.8), BeachCourt.SURFACE_Y, side * 2.6)


## Where the third touch is played from: at the net, ready to hit over it.
func _attack_point(team: Sides.Team) -> Vector3:
	var side := Sides.half_sign(team)
	return Vector3(randf_range(-2.4, 2.4), BeachCourt.SURFACE_Y, side * 1.5)


## The attack, and the moment the whole sport turns on.
##
## Most attacks are aimed inside the court and there is nothing to judge. About a third
## are aimed out — and of those, a little under half clip the block on the way, which
## sends them out anyway but makes it the blocker's point lost rather than the
## attacker's. Nobody but the referee has any real claim to know which just happened.
func _attack(from: Vector3) -> void:
	rally.struck_by = _possession
	var against := Sides.opponent(_possession)
	rally.receiving = against

	var target := _attack_target(against)
	# A block can only touch a ball that was going out behind it, which in practice
	# means one aimed at or past the end line.
	var going_long: bool = absf(target.z) >= BeachSpec.HALF_LENGTH - 0.05

	if going_long and randf() < BLOCK_TOUCHES:
		rally.was_touched = true
		# How plainly. A ball that barely brushes a fingertip carries on almost
		# unchanged; one that catches a whole hand visibly checks and drops. The
		# deflection is applied to the target so the flight really does differ.
		rally.touch_visibility = randf_range(0.08, 0.95)
		# A touch pushes the ball out. How far is the whole of how obvious it was: a
		# fingernail barely changes anything, a whole hand visibly checks it.
		var deflection := 0.18 + rally.touch_visibility * 1.5
		target.z = Sides.half_sign(against) * (BeachSpec.HALF_LENGTH + deflection)
		target.x += randf_range(-0.8, 0.8) * rally.touch_visibility

	# An attack is struck from above the tape, so it goes over at almost any angle —
	# but a ball spiked from a metre behind the net still has to clear it, and the
	# steeper alternatives are the roll shot and the lob a real player would use.
	_send_over(from, target, [ATTACK_ANGLE, 6.0, 16.0, 28.0])


func _on_ball_landed(point: Vector3) -> void:
	if _phase != Phase.IN_PLAY:
		return
	# Whoever's half it came down in was defending it.
	rally.record_landing(point, Sides.half_containing(point.z))
	if rally.struck_by == Sides.Team.NONE:
		# It never got as far as an attack — a serve that came straight down.
		rally.struck_by = serving
		rally.receiving = Sides.opponent(serving)
	_phase = Phase.AWAITING_CALL
	_awaiting_since = Time.get_ticks_msec()
	ui.set_prompt("LEFT CLICK  in    RIGHT CLICK  out    T  touch    F  fault")


# --- the call -------------------------------------------------------------------

func make_call(id: StringName, against := Sides.Team.NONE) -> void:
	if _phase != Phase.AWAITING_CALL:
		return
	var call := BeachCallBook.get_call(id)
	if call == null:
		return

	rally.seconds_to_call = float(Time.get_ticks_msec() - _awaiting_since) / 1000.0
	rally.record_call(call, against)
	# Net touch and crossing under the net are things a person did, so they are recorded
	# on the match rather than on the ball's rally. The rally has to know about them
	# before it can say who should have won the point.
	rally.net_toucher = net_toucher
	rally.centre_line_crosser = centre_line_crosser

	suspicion.register_judgement(
		rally.verdict() as int,
		rally.visibility(),
		_which_way_it_leaned(),
		call.severity,
		rally.seconds_to_call,
		false, false,
		rally.changed_the_result())

	var winner := rally.point_goes_to()
	if winner != Sides.Team.NONE:
		board.award(winner)
		serving = winner
		ui.announce("%s   ·   POINT %s" % [call.label, Sides.label(winner)],
			Sides.colour(winner))

	ui.react(Crowd.react_to_call(rally.visibility(), suspicion.mood))

	if print_truth_while_testing:
		print("[truth, testing only] %s  |  suspicion %.3f lean %+.2f" % [
			rally.describe(), suspicion.level, suspicion.lean])

	_enter_ready()


## +1 if the call helped BLUE, -1 if it helped RED, 0 if it helped nobody.
##
## The number that matters most in this whole game, and the reason it is worth
## computing carefully: being wrong is survivable, and being wrong the same way every
## time is what gets an official removed. A referee whose touch calls all go one way
## has told the venue something about themselves that no single call could.
func _which_way_it_leaned() -> float:
	var gained := rally.point_goes_to()
	var deserved := rally.rightful_winner()
	if gained == deserved or gained == Sides.Team.NONE:
		return 0.0
	return 1.0 if gained == Sides.Team.BLUE else -1.0


func _enter_ready() -> void:
	if suspicion.is_removed or board.is_over:
		return
	_phase = Phase.READY
	ui.set_score(board, serving)
	ui.set_prompt("SPACE  whistle the serve          F  fault")


func _unhandled_input(event: InputEvent) -> void:
	if _phase == Phase.REMOVED:
		return
	match _phase:
		Phase.READY:
			if event is InputEventKey and event.pressed and event.keycode == KEY_SPACE:
				start_rally()
		Phase.AWAITING_CALL:
			if event is InputEventMouseButton and event.pressed:
				if event.button_index == MOUSE_BUTTON_LEFT:
					make_call(&"in")
				elif event.button_index == MOUSE_BUTTON_RIGHT:
					make_call(&"out")
			elif event is InputEventKey and event.pressed and event.keycode == KEY_T:
				make_call(&"touch")
