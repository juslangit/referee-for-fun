class_name VolleyMatch
extends Node3D

## An indoor volleyball match, refereed from the stand beside the net.
##
## The rally is beach volleyball's — serve, dig, set, attack, with each contact a real
## flight solved onto a chosen point — on a bigger court with six a side. What is new is
## everything that happens *before* the whistle: six players in a rotation, a lineup
## fixed at the start of the set, and a libero in a different shirt who may not do three
## of the things everybody else may.
##
## That changes the job rather than adding to it. Beach asks the referee to judge things
## they can see and cannot be certain about. Indoor asks them to judge things that are
## perfectly certain if they were paying attention twenty seconds ago, and unknowable if
## they were not.

enum Phase { MENU, READY, IN_PLAY, AWAITING_CALL, REMOVED }
enum Beat { SERVE, DIG, SET, ATTACK }

const SERVE_BEHIND := 1.2
const SERVE_HEIGHT := 2.25

const DIG_ANGLE := 68.0
const SET_ANGLE := 72.0
const ATTACK_ANGLE := -5.0
const SERVE_ANGLES := [14.0, 20.0, 26.0, 34.0, 42.0, 50.0]
const NET_CLEARANCE := 0.14

const DIG_HEIGHT := 0.55
const SET_HEIGHT := 1.95
const ATTACK_HEIGHT := 3.05

const REACH := 0.95
const BLOCK_TOUCHES := 0.45
const RALLY_LIMIT := 22.0

## How fast they cross a sprung floor. Quicker than sand, slower than a badminton court
## — six people share the ground, so nobody has far to go.
const COURT_SPEED := 4.2

## Sets to 25, and best of five. The scoreboard already knows how to do this.
const SET_TARGET := 25
const SETS_NEEDED := 3

## Volleyball has no sudden-death ceiling — you win by two or you keep playing. High
## enough never to be reached, rather than a special case in the scoreboard.
const NO_CAP := 9999

## How often anything goes wrong that is not about the ball, and which of the eight it
## is when it does. **One fault per rally, never two** — the lesson beach volleyball
## learned when a rally with both a foot fault and a net touch left the game and the
## referee disagreeing about which decided the point.
const FAULT_CHANCE := 0.15
const FAULT_KINDS := [
	&"foot_fault", &"net_touch", &"centre_line", &"handling",
	&"rotation", &"wrong_server", &"back_row", &"libero",
]
const FAULT_WEIGHTS := [0.12, 0.16, 0.09, 0.17, 0.15, 0.12, 0.11, 0.08]

const REVIEW_SUSPENSE := 1.9
const REVIEW_VERDICT := 2.3

var court: VolleyCourt
var camera: UmpireCamera
var ui: RefereeUI

var rally: VolleyRally
var suspicion: Suspicion
var board: Scoreboard
var career: Career
var settings: Settings
var sound: Sound

var players: Array[Player] = []
var serving := Sides.Team.RED

## The lineup of each side, and how far it has turned.
var rota := {Sides.Team.RED: Rotation.new(), Sides.Team.BLUE: Rotation.new()}

var pressure := Pressure.new()
var challenge := Challenge.new()
var has_challenge := false
var ball_cam: ShuttleCam

var net_toucher := Sides.Team.NONE
var centre_line_crosser := Sides.Team.NONE

var _phase := Phase.MENU
var _reviewing := false
var _ball: Ball
var _beat := Beat.SERVE
var _possession := Sides.Team.NONE
var _aim := Vector3.ZERO
var _digger: Player
var _setter: Player
var _attacker_is_back_row := false
var _rally_seconds := 0.0
var _awaiting_since := 0

@export var print_truth_while_testing := true


func _ready() -> void:
	suspicion = Suspicion.new()
	settings = Settings.load_or_default()
	settings.apply()

	court = VolleyCourt.new()
	court.name = "Court"
	add_child(court)

	_ball = Ball.new()
	_ball.name = "Ball"
	_ball.floor_height = VolleyCourt.SURFACE_Y
	add_child(_ball)
	_ball.landed.connect(_on_ball_landed)
	_ball.freeze = true

	ball_cam = ShuttleCam.new()
	ball_cam.name = "BallCam"
	ball_cam.view_metres = 1.75
	add_child(ball_cam)

	_build_players()
	_build_camera()
	_build_lighting()

	ui = RefereeUI.new()
	ui.name = "UI"
	add_child(ui)
	ui.show_hud(false)
	ui.fault_book = VolleyCallBook.faults()
	_connect_menus()

	sound = Sound.new()
	sound.name = "Sound"
	add_child(sound)

	suspicion.warning_issued.connect(func() -> void:
		ui.show_banner("THE MATCH REFEREE HAS BEEN CALLED")
		ui.react("the match referee comes over and stands by the post", 5.0))
	suspicion.removed_from_match.connect(func() -> void:
		_finish("TAKEN OFF THE MATCH", Color(0.96, 0.42, 0.36), true))

	career = Career.load_or_start()
	career.sport = Career.INDOOR
	board = Scoreboard.new(false)

	if not settings.taught_indoor:
		ui.show_teaching(Career.INDOOR)
	else:
		ui.show_career(career)


func _build_camera() -> void:
	camera = UmpireCamera.new()
	camera.name = "RefereeCamera"
	camera.position = Vector3(
		VolleySpec.POST_X + VolleyCourt.STAND_OFFSET, VolleyCourt.EYE_HEIGHT, 0.0)
	camera.facing_deg = 90.0
	camera.start_pitch_deg = -17.0
	camera.fov = 80.0
	camera.cull_mask = camera.cull_mask & ~VolleyCourt.STAND_LAYER
	camera.current = true
	add_child(camera)


func _build_lighting() -> void:
	var lamp := DirectionalLight3D.new()
	lamp.name = "Lights"
	lamp.rotation = Vector3(deg_to_rad(-70.0), deg_to_rad(24.0), 0.0)
	lamp.light_energy = 1.9
	lamp.shadow_enabled = true
	add_child(lamp)

	var world := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.09, 0.10, 0.13)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.62, 0.65, 0.72)
	env.ambient_light_energy = 1.35
	world.environment = env
	add_child(world)


## Six a side, and one of each six wearing a different shirt.
func _build_players() -> void:
	for team in [Sides.Team.RED, Sides.Team.BLUE]:
		# The libero starts in the back row, which is where they live. When the rotation
		# would carry them to the front they are substituted off in the real sport; here
		# they simply stop being treated as a libero for those rallies, which stands in
		# for the substitution without needing a bench.
		var who: Rotation = rota[team]
		who.reset(4)
		for i in Rotation.POSITIONS:
			var player := Player.new()
			player.name = "%s%d" % [Sides.label(team), i]
			player.volleyball = true
			player.speed = COURT_SPEED
			player.reach = 1.35
			add_child(player)
			player.setup(team, Vector3(0.0, 0.0, Sides.half_sign(team) * 4.0))
			players.append(player)
		_dress_the_libero(team)


## The libero's shirt. Nothing else in either sport identifies a player at a glance, and
## the whole reason the rule exists is that the referee has to be able to.
func _dress_the_libero(team: Sides.Team) -> void:
	var who: Rotation = rota[team]
	if who.libero < 0:
		return
	var wearing := _player(team, who.libero)
	if wearing != null:
		Models.wear_bib(wearing, Color(0.95, 0.82, 0.20))


func _player(team: Sides.Team, index: int) -> Player:
	var found := 0
	for player in players:
		if player.team != team:
			continue
		if found == index:
			return player
		found += 1
	return null


func _pair(team: Sides.Team) -> Array[Player]:
	var found: Array[Player] = []
	for player in players:
		if player.team == team:
			found.append(player)
	return found


func _nearest(team: Sides.Team, to: Vector3) -> Player:
	var best: Player = null
	var closest := 1e9
	for player in _pair(team):
		var gap := player.distance_to(to)
		if gap < closest:
			closest = gap
			best = player
	return best


# --- lining up ------------------------------------------------------------------

## Puts twelve people on court according to two rotations, and decides whether one of
## them is standing somewhere they should not be.
##
## This is where the sport's own kind of truth is made. Everything else in this game is
## decided by the ball; this is decided before the ball is touched, by six people
## walking to six places, and the referee either noticed or did not.
func _line_up() -> void:
	rally.rotation_fault_by = Sides.Team.NONE
	rally.wrong_server_by = Sides.Team.NONE
	rally.libero_fault_by = Sides.Team.NONE
	rally.libero_did = &""
	rally.back_row_attack_by = Sides.Team.NONE
	net_toucher = Sides.Team.NONE
	centre_line_crosser = Sides.Team.NONE

	var offender := _roll_for_one_fault()

	for team in [Sides.Team.RED, Sides.Team.BLUE]:
		var who: Rotation = rota[team]
		var placed := who.spots(team == serving)

		# A positional fault is two of the six swapping places. Which two is chosen so
		# that the swap actually breaks a rule — see below.
		if offender == &"rotation" and team == _fault_team:
			placed = _break_the_rotation(who, placed)
			rally.rotation_fault_by = team

		_stand(team, placed)

	# The other faults that are decided before the whistle.
	match offender:
		&"wrong_server":
			rally.wrong_server_by = _fault_team
		&"libero":
			_a_libero_does_something_they_may_not(_fault_team)
		&"net_touch":
			net_toucher = _fault_team
		&"centre_line":
			centre_line_crosser = _fault_team
		&"handling":
			rally.handling_fault = true
			rally.handling_visibility = randf_range(0.25, 0.85)
		&"foot_fault":
			rally.foot_fault = true

	# Back row attack is decided at the attack rather than here, because it depends on
	# who ends up hitting the ball.
	_back_row_attack_wanted = offender == &"back_row"


## Swaps two of the six so that they really are out of order.
##
## The swap is checked against the rules rather than assumed, and picked again if it did
## not break anything. **A fault the rules cannot see is not a fault, it is a bug** —
## and this is the one place in the game where the truth is a claim about a rule rather
## than about a place, so it has to be a claim the rule agrees with.
func _break_the_rotation(who: Rotation, placed: Dictionary) -> Dictionary:
	var pairs := [[3, 6], [4, 5], [2, 1], [4, 2], [5, 1]]
	pairs.shuffle()
	for pair in pairs:
		var broken := placed.duplicate()
		var one: int = who.player_in(pair[0])
		var two: int = who.player_in(pair[1])
		var keep: Vector2 = broken[one]
		broken[one] = broken[two]
		broken[two] = keep
		if not who.is_legal(broken):
			return broken
	# Every swap somehow legal, which should not happen. Leave them alone rather than
	# claim a fault that is not there.
	rally.rotation_fault_by = Sides.Team.NONE
	return placed


## The three things a libero may not do, and which of them just happened.
func _a_libero_does_something_they_may_not(team: Sides.Team) -> void:
	var who: Rotation = rota[team]
	if who.libero < 0 or who.is_front_row(who.libero):
		# Not on court as a libero this rally, so there is nothing to break.
		return
	rally.libero_fault_by = team
	rally.libero_did = [&"attacked", &"served", &"set from the front zone"].pick_random()
	if rally.libero_did == &"served":
		# Serving is only possible for whoever is in position 1.
		if who.server() != who.libero:
			rally.libero_did = &"attacked"


## Sends the six of one side to their places, in court metres.
func _stand(team: Sides.Team, placed: Dictionary) -> void:
	var side := Sides.half_sign(team)
	for index in placed:
		var player := _player(team, index)
		if player == null:
			continue
		var spot: Vector2 = placed[index]
		player.home = Vector3(
			spot.x * VolleySpec.HALF_WIDTH,
			0.0,
			side * spot.y * VolleySpec.HALF_LENGTH)
		player.go_home()


var _fault_team := Sides.Team.NONE
var _back_row_attack_wanted := false


## At most one thing goes wrong per rally, and this decides whether and which.
func _roll_for_one_fault() -> StringName:
	_fault_team = Sides.Team.NONE
	if randf() >= FAULT_CHANCE:
		return &""

	var roll := randf()
	var running := 0.0
	var kind: StringName = FAULT_KINDS[FAULT_KINDS.size() - 1]
	for i in FAULT_KINDS.size():
		running += FAULT_WEIGHTS[i]
		if roll < running:
			kind = FAULT_KINDS[i]
			break

	# A service fault belongs to whoever is serving; everything else could be either.
	if kind == &"wrong_server" or kind == &"foot_fault":
		_fault_team = serving
	else:
		_fault_team = Sides.Team.RED if randf() < 0.5 else Sides.Team.BLUE
	return kind


# --- the rally ------------------------------------------------------------------

func start_rally() -> void:
	if _phase != Phase.READY or _reviewing:
		return
	rally = VolleyRally.new()
	rally.served_by = serving
	_rally_seconds = 0.0
	_line_up()

	_possession = serving
	_beat = Beat.SERVE
	rally.contacts = 1

	var side := Sides.half_sign(serving)
	var from := Vector3(
		randf_range(-3.0, 3.0), SERVE_HEIGHT,
		side * (VolleySpec.HALF_LENGTH + SERVE_BEHIND))
	var target := _somewhere_in(Sides.opponent(serving), 0.7)
	target.z = Sides.half_sign(Sides.opponent(serving)) * randf_range(
		3.2, VolleySpec.HALF_LENGTH - 0.7)
	_send_over(from, target, SERVE_ANGLES)

	var receiver := _nearest(Sides.opponent(serving), target)
	receiver.chase(target)
	_phase = Phase.IN_PLAY
	sound.whistle()
	ui.set_prompt("watch it")


func _send_over(from: Vector3, to: Vector3, angles: Array) -> void:
	var flat := Vector2(to.x - from.x, to.z - from.z)
	var crosses_at := absf(from.z) / maxf(0.001, absf(to.z - from.z))
	var to_the_net := flat.length() * crosses_at
	var flight := ShotSolver.ball_flight()
	for angle in angles:
		var velocity := ShotSolver.solve(from, to, angle, VolleyCourt.SURFACE_Y, flight)
		if velocity == Vector3.ZERO:
			continue
		var at_net := ShotSolver.height_after(
			from.y - VolleyCourt.SURFACE_Y, velocity.length(), angle, to_the_net, flight)
		if at_net > VolleySpec.NET_HEIGHT + NET_CLEARANCE:
			_aim = to
			_ball.launch(from, velocity)
			return
	_send(from, to, 55.0)


func _send(from: Vector3, to: Vector3, angle: float) -> void:
	_aim = to
	var velocity := ShotSolver.solve(
		from, to, angle, VolleyCourt.SURFACE_Y, ShotSolver.ball_flight())
	if velocity == Vector3.ZERO:
		velocity = ShotSolver.solve(
			from, to, 45.0, VolleyCourt.SURFACE_Y, ShotSolver.ball_flight())
	_ball.launch(from, velocity)


func _somewhere_in(team: Sides.Team, inset: float) -> Vector3:
	var side := Sides.half_sign(team)
	return Vector3(
		randf_range(-VolleySpec.HALF_WIDTH + inset, VolleySpec.HALF_WIDTH - inset),
		VolleyCourt.SURFACE_Y,
		side * randf_range(inset + 0.8, VolleySpec.HALF_LENGTH - inset))


## Where an attack is aimed. Most of them at a line, for the same reason as every other
## sport in this game: close calls have to be manufactured or the job is boring.
func _attack_target(against: Sides.Team) -> Vector3:
	var side := Sides.half_sign(against)
	if randf() < 0.42:
		return _somewhere_in(against, 0.7)
	var nudge := randf_range(-0.28, 0.28)
	if randf() < 0.62:
		return Vector3(
			randf_range(-VolleySpec.HALF_WIDTH + 0.6, VolleySpec.HALF_WIDTH - 0.6),
			VolleyCourt.SURFACE_Y, side * (VolleySpec.HALF_LENGTH + nudge))
	return Vector3(
		(1.0 if randf() < 0.5 else -1.0) * (VolleySpec.HALF_WIDTH + nudge),
		VolleyCourt.SURFACE_Y, side * randf_range(2.4, VolleySpec.HALF_LENGTH - 0.8))


func _set_point(team: Sides.Team) -> Vector3:
	var side := Sides.half_sign(team)
	return Vector3(randf_range(-2.2, 2.2), VolleyCourt.SURFACE_Y, side * 2.4)


## Where the third touch is hit from.
##
## A front-row attacker hits from just behind the net. A back-row attacker is supposed
## to take off from behind the attack line — and when the game has decided to commit a
## back row attack, they take off in front of it instead, which is the fault.
func _attack_point(team: Sides.Team, back_row: bool, illegal: bool) -> Vector3:
	var side := Sides.half_sign(team)
	var depth := 1.4
	if back_row:
		depth = 1.9 if illegal else VolleySpec.ATTACK_LINE + randf_range(0.3, 1.2)
	return Vector3(randf_range(-2.8, 2.8), VolleyCourt.SURFACE_Y, side * depth)


func _physics_process(delta: float) -> void:
	if _phase != Phase.IN_PLAY:
		return
	_rally_seconds += delta
	if _rally_seconds > RALLY_LIMIT:
		_ball.force_landing()
		return
	if _beat == Beat.ATTACK:
		return
	var here := _ball.global_position
	if Vector2(here.x - _aim.x, here.z - _aim.z).length() > REACH:
		return
	if here.y > 2.8:
		return
	_take_the_next_contact()


func _take_the_next_contact() -> void:
	var here := _ball.global_position
	match _beat:
		Beat.SERVE:
			_possession = Sides.opponent(_possession)
			rally.contacts = 1
			_beat = Beat.DIG
			_digger = _nearest(_possession, here)
			_setter = _closest_to_the_net(_possession, _digger)
			_digger.dig()
			var to_the_setter := _set_point(_possession)
			_setter.chase(to_the_setter)
			_send(Vector3(here.x, DIG_HEIGHT, here.z), to_the_setter, DIG_ANGLE)
		Beat.DIG:
			rally.contacts = 2
			_beat = Beat.SET
			if _setter != null:
				_setter.set_the_ball()
			# Whoever attacks is whoever is furthest forward and is not the setter, which
			# with six people is usually a front-row player and sometimes is not.
			var hitter := _pick_an_attacker(_possession)
			_attacker_is_back_row = _is_back_row(_possession, hitter)
			var illegal := _back_row_attack_wanted and _attacker_is_back_row
			var to_the_hitter := _attack_point(_possession, _attacker_is_back_row, illegal)
			_digger = hitter
			hitter.chase(to_the_hitter)
			_send(Vector3(here.x, SET_HEIGHT, here.z), to_the_hitter, SET_ANGLE)
		Beat.SET:
			rally.contacts = 3
			_beat = Beat.ATTACK
			_attack(Vector3(here.x, ATTACK_HEIGHT, here.z))


func _closest_to_the_net(team: Sides.Team, other: Player) -> Player:
	var best: Player = null
	var nearest := 1e9
	for player in _pair(team):
		if player == other:
			continue
		if absf(player.position.z) < nearest:
			nearest = absf(player.position.z)
			best = player
	return best


## Who hits the third ball. Usually somebody in the front row; occasionally a back-row
## player coming in behind them, which is the whole reason the attack line exists.
func _pick_an_attacker(team: Sides.Team) -> Player:
	var who: Rotation = rota[team]
	var wants_back_row := _back_row_attack_wanted or randf() < 0.28
	for index in Rotation.POSITIONS:
		var back := not who.is_front_row(index)
		if back == wants_back_row:
			var found := _player(team, index)
			if found != null and found != _setter:
				return found
	return _nearest(team, Vector3(0.0, 0.0, Sides.half_sign(team) * 2.0))


func _is_back_row(team: Sides.Team, player: Player) -> bool:
	var who: Rotation = rota[team]
	for index in Rotation.POSITIONS:
		if _player(team, index) == player:
			return not who.is_front_row(index)
	return false


func _attack(from: Vector3) -> void:
	rally.struck_by = _possession
	var against := Sides.opponent(_possession)
	rally.receiving = against

	# The fault, if this is the rally that has one: a back-row player who took off in
	# front of the attack line.
	if _attacker_is_back_row and _back_row_attack_wanted \
			and VolleySpec.in_front_zone(from, Sides.half_sign(_possession)):
		rally.back_row_attack_by = _possession

	var target := _attack_target(against)
	var going_long: bool = absf(target.z) >= VolleySpec.HALF_LENGTH - 0.05
	if going_long and randf() < BLOCK_TOUCHES:
		rally.was_touched = true
		rally.touch_visibility = randf_range(0.08, 0.95)
		var deflection := 0.18 + rally.touch_visibility * 1.5
		target.z = Sides.half_sign(against) * (VolleySpec.HALF_LENGTH + deflection)
		target.x += randf_range(-0.8, 0.8) * rally.touch_visibility

	if _digger != null:
		_digger.spike()
	_meet_the_attack(against, from, target)
	_send_over(from, target, [ATTACK_ANGLE, 6.0, 16.0, 28.0])


## Two blockers to the net, the rest back to dig.
func _meet_the_attack(defending: Sides.Team, from: Vector3, target: Vector3) -> void:
	var side := Sides.half_sign(defending)
	var blockers := 0
	for player in _pair(defending):
		if blockers < 2 and _is_front_row_player(defending, player):
			player.chase(Vector3(
				clampf(from.x + (0.5 if blockers == 0 else -0.5), -3.2, 3.2),
				0.0, side * 1.0))
			blockers += 1
		else:
			player.chase(Vector3(
				clampf(target.x + randf_range(-1.4, 1.4), -3.8, 3.8),
				0.0, side * clampf(absf(target.z), 3.6, 8.2)))


func _is_front_row_player(team: Sides.Team, player: Player) -> bool:
	return not _is_back_row(team, player)


func _on_ball_landed(point: Vector3) -> void:
	if _phase != Phase.IN_PLAY:
		return
	rally.record_landing(point, Sides.half_containing(point.z))
	if rally.struck_by == Sides.Team.NONE:
		rally.struck_by = serving
		rally.receiving = Sides.opponent(serving)
	rally.net_toucher = net_toucher
	rally.centre_line_crosser = centre_line_crosser
	for player in players:
		player.go_home()
	_digger = null
	_setter = null
	_phase = Phase.AWAITING_CALL
	_awaiting_since = Time.get_ticks_msec()
	ui.set_prompt(
		"LEFT CLICK  in    RIGHT CLICK  out    T  touch    R  rotation    F  fault")


# --- the call -------------------------------------------------------------------

func make_call(id: StringName, against := Sides.Team.NONE) -> void:
	if _phase != Phase.AWAITING_CALL:
		return
	var call := VolleyCallBook.get_call(id)
	if call == null:
		return

	rally.seconds_to_call = float(Time.get_ticks_msec() - _awaiting_since) / 1000.0
	rally.record_call(call, against)

	suspicion.register_judgement(
		rally.verdict() as int,
		rally.visibility(),
		_which_way_it_leaned(),
		call.severity,
		rally.seconds_to_call,
		false, false,
		rally.changed_the_result())

	var winner := rally.point_goes_to()
	if has_challenge:
		var asked := _who_would_challenge()
		if asked != Sides.Team.NONE:
			var overturned := await _review(asked)
			if overturned:
				winner = rally.rightful_winner()

	if _phase == Phase.REMOVED:
		return

	if winner != Sides.Team.NONE:
		# A side that wins the serve back rotates. A side that holds it does not — the
		# rule most people who have played casually get wrong, and the one that decides
		# who is allowed to serve next.
		if winner != serving:
			rota[winner].rotate()
		board.award(winner)
		serving = winner
		ui.announce("%s   ·   POINT %s" % [call.label, Sides.label(winner)],
			Sides.colour(winner))
		court.cheer()

	ui.react(Crowd.react_to_call(rally.visibility(), suspicion.mood))
	ui.set_reviews(challenge.remaining(Sides.Team.RED),
		challenge.remaining(Sides.Team.BLUE), has_challenge)

	if print_truth_while_testing:
		print("[truth, testing only] %s  |  suspicion %.3f lean %+.2f" % [
			rally.describe(), suspicion.level, suspicion.lean])

	_enter_ready()


func _which_way_it_leaned() -> float:
	var gained := rally.point_goes_to()
	var deserved := rally.rightful_winner()
	if gained == deserved or gained == Sides.Team.NONE:
		return 0.0
	return 1.0 if gained == Sides.Team.BLUE else -1.0


## Line calls and touches only, as on the beach.
##
## The positional faults are deliberately not reviewable, and that is not a shortcut. A
## challenge in this sport looks at video of the *ball*. Where six people were standing
## twenty seconds earlier is settled by the scoresheet and the second referee, not by a
## camera — so a rotation call, uniquely, is the referee's word and stays that way.
func _who_would_challenge() -> Sides.Team:
	if rally == null or rally.call == null or not rally.is_settled:
		return Sides.Team.NONE
	if not (rally.call.judges_the_landing or rally.call.judges_the_touch):
		return Sides.Team.NONE
	var lost := Sides.opponent(rally.point_goes_to())
	var closeness := rally.margin
	if rally.call.judges_the_touch:
		closeness = (1.0 - rally.touch_visibility) * Challenge.DOUBT_RANGE
	return challenge.who_challenges(
		lost, rally.verdict() == BeachRally.Verdict.WRONG, rally.visibility(), closeness)


func _review(asked: Sides.Team) -> bool:
	_reviewing = true

	# Everything this needs is read now, before the first await.
	#
	# A review is two seconds of waiting with the game still running, and `rally` is a
	# reference that the next serve replaces. Reading `rally.call` on the far side of a
	# timer worked until something started a rally during one, and then crashed on a
	# call that no longer existed. Nothing below touches the rally again.
	var overturned := rally.verdict() == BeachRally.Verdict.WRONG
	var about_a_touch: bool = rally.call != null and rally.call.judges_the_touch
	var truth := ""
	if about_a_touch:
		truth = "TOUCHED" if rally.was_touched else "NO TOUCH"
	else:
		truth = "IN" if rally.was_in else "OUT"
	var seen := rally.visibility()
	var leaned := _which_way_it_leaned()

	ball_cam.aim_at(rally.landing_point)
	ui.show_review(asked, challenge.remaining(asked), ball_cam.texture())
	sound.react(false)
	await get_tree().create_timer(REVIEW_SUSPENSE).timeout

	if overturned:
		ui.set_review_verdict("%s  ·  CALL OVERTURNED" % truth, Color(0.96, 0.42, 0.36))
	else:
		ui.set_review_verdict("%s  ·  CALL STANDS" % truth, Color(0.55, 0.85, 0.60))

	challenge.settle(asked, overturned)
	suspicion.register_review_judgement(seen, leaned, overturned)
	sound.react(not overturned)
	ui.react(Crowd.react_to_review(overturned))

	await get_tree().create_timer(REVIEW_VERDICT).timeout
	ui.hide_review()
	_reviewing = false
	return overturned


func _enter_ready() -> void:
	if suspicion.is_removed or board.is_over:
		return
	_phase = Phase.READY
	ui.set_score(board, serving)
	ui.set_prompt("SPACE  whistle the serve      R  rotation      F  fault")


func _unhandled_input(event: InputEvent) -> void:
	if _reviewing or _phase == Phase.REMOVED or _phase == Phase.MENU:
		return

	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		camera.set_active(false)
		ui.show_pause_menu()
		get_tree().paused = true
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


# --- the front of the match -----------------------------------------------------

func _connect_menus() -> void:
	ui.match_requested.connect(_on_match_requested)
	ui.briefing_acknowledged.connect(func() -> void:
		ui.hide_briefing()
		begin_match())
	ui.continue_requested.connect(func() -> void: get_tree().reload_current_scene())
	ui.career_screen_requested.connect(func() -> void: ui.show_career(career))
	ui.teaching_requested.connect(func() -> void: ui.show_teaching(Career.INDOOR))
	ui.teaching_finished.connect(func() -> void:
		settings.taught_indoor = true
		settings.save()
		ui.hide_teaching()
		ui.show_career(career))
	for restart in [ui.new_career_requested, ui.career_restart_requested]:
		restart.connect(func() -> void:
			career = Career.start_again()
			career.sport = Career.INDOOR
			career.save()
			ui.show_career(career))
	ui.resume_requested.connect(func() -> void:
		get_tree().paused = false
		ui.hide_pause_menu()
		camera.set_active(true))
	ui.walk_out_requested.connect(func() -> void:
		get_tree().paused = false
		_finish("YOU WALKED OFF", Color(0.85, 0.62, 0.32), true))
	ui.main_menu_requested.connect(func() -> void:
		get_tree().paused = false
		get_tree().change_scene_to_file("res://scenes/match.tscn"))
	ui.quit_requested.connect(func() -> void: get_tree().quit())


func _on_match_requested() -> void:
	var venue := career.venue()
	suspicion.scrutiny = venue["scrutiny"]
	has_challenge = venue["hawk_eye"]
	challenge.reset()
	court.dress(venue["dressing"], venue["crowd"])

	# Sets to 25 rather than 21, and best of five rather than three.
	board = Scoreboard.new(venue["quick"])
	board.target = SET_TARGET
	# Volleyball has no cap: a set runs until somebody is two clear, however long that
	# takes. `cap` is badminton's sudden-death ceiling and the scoreboard treats
	# reaching it as an instant win — set to zero it ends the set on the first point,
	# which is a very short match indeed.
	board.cap = NO_CAP
	board.games_needed = 2 if venue["quick"] else SETS_NEEDED
	board.game_won.connect(func(_team: Sides.Team) -> void:
		# A new set is a new lineup and two fresh challenges.
		for team in [Sides.Team.RED, Sides.Team.BLUE]:
			rota[team].reset(4)
			_dress_the_libero(team)
		challenge.reset()
		ui.set_score(board, serving))
	board.match_won.connect(func(team: Sides.Team) -> void:
		_finish("%s WIN" % Sides.label(team), Sides.colour(team), false))

	ui.hide_menus()
	ui.hide_career()

	pressure = Pressure.for_match(career)
	if pressure.exists():
		ui.show_briefing(pressure)
	else:
		begin_match()


func begin_match(_unused := Sides.Team.NONE) -> void:
	camera.set_active(true)
	_enter_ready()


func _finish(headline: String, tint: Color, removed: bool) -> void:
	if _phase == Phase.REMOVED:
		return
	_phase = Phase.REMOVED
	camera.set_active(false)
	ui.set_prompt("")

	var detail := _reckoning()
	var pressures: Array = []
	if pressure.exists():
		pressure.resolve(board, suspicion)
		pressures.append(pressure)

	var note := career.finish_match(suspicion.level, removed, pressures)
	career.remember_grudge(
		String(Pressure.NAMES.pick_random()),
		suspicion.wrong_calls, suspicion.stolen_rallies, suspicion.lean)
	career.save()
	detail += "\n\n%s\n\nReputation  %d / 100" % [note, roundi(career.reputation * 100.0)]
	ui.show_ending(headline, detail, tint)


func _reckoning() -> String:
	var lines := []
	lines.append("%d wrong calls, %d of which decided the rally." % [
		suspicion.wrong_calls, suspicion.stolen_rallies])

	if absf(suspicion.lean) < 0.15:
		lines.append("They went both ways. You were not bent. You were just bad at this.")
	else:
		var helped := Sides.Team.BLUE if suspicion.lean > 0.0 else Sides.Team.RED
		lines.append("Almost every one of them helped %s." % Sides.label(helped))
		if pressure.exists() and pressure.wants == helped:
			lines.append("Which is the result somebody mentioned to you before you went out.")
		else:
			lines.append("Nobody asked you to. That is the part people find hard to believe.")

	lines.append("")
	lines.append("Final score  RED %d — %d BLUE      sets  %d — %d" % [
		board.points[Sides.Team.RED], board.points[Sides.Team.BLUE],
		board.games[Sides.Team.RED], board.games[Sides.Team.BLUE]])
	return "\n".join(lines)
