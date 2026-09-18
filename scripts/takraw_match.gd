class_name TakrawMatch
extends OfficiatedMatch

## A sepak takraw match, refereed from the tall chair beside the net.
##
## The referee spine underneath is the one every other sport shares; what is new is the sport.
## Three a side in regu, two in doubles. The ball is played with the feet, knees, chest and
## head, never the arms. Rallies are three touches — receive, set, spike — and the spike is a
## bicycle kick over a net lower than badminton's.
##
## **The rally is scripted rather than played**, as in both volleyballs. Each contact is a real
## flight solved to land on a chosen point, so the landing the referee judges is genuine
## physics and not a number picked in advance.
##
## What this sport gives the referee that no other in the game does is **the serve**. Before
## the ball is kicked, the serving side's feet are held in painted circles — the tekong's
## standing foot in the service circle, the two inside players in their quarter circles at the
## net — and a foot that is out of one is a fault. Those feet are drawn where they really are:
## a fault is a player standing over their line, and the referee has to look.
##
## Scoring, service and faults are ISTAF's 2024 Law of the Game. There is no whistle: the
## referee calls the score, and the serving side throws when it has been called.

enum Beat { THROW, SERVE, RECEIVE, SET, ATTACK }

## How high each kind of contact is made, off the mat. A receive is a foot at knee height, a
## set a foot at the hip near the net, a spike a bicycle kick well over the tape.
const SERVE_HEIGHT := 1.15
const RECEIVE_HEIGHT := 0.55
const SET_HEIGHT := 0.85
const SPIKE_HEIGHT := 2.05

## The angle each contact goes up at, in degrees.
## How long the inside player's underarm throw is in the air before the tekong kicks it.
const THROW_SECONDS := 0.95
const RECEIVE_ANGLE := 70.0
const SET_ANGLE := 76.0
const SERVE_ANGLES := [8.0, 14.0, 20.0, 28.0, 36.0]
const SPIKE_ANGLES := [-14.0, -6.0, 4.0, 14.0]

## How close the ball has to get before the next player takes it.
const REACH := 0.8

## How far the killer will run onto a set, in metres. The set is aimed inside this, because
## a set nobody reaches is a spike played at a ball a foot could never have met.
const FURTHEST_A_KILLER_RUNS := 2.0

## How often a spike going long clips the block on its way. The block in this sport is a back
## turned to the net and a pair of legs, so it touches less than a volleyball block does.
const BLOCK_TOUCHES := 0.32

## How long the ball may be up before the rally is abandoned.
const RALLY_LIMIT := 18.0

## How often something goes wrong that is not about where the ball came down, and which.
## One per rally at most, for the reason BeachMatch gives: two faults have an order, and
## nothing would record it.
const FAULT_CHANCE := 0.16
const FAULT_KINDS := [&"service_fault", &"inside_fault", &"arm", &"net_touch", &"crossing",
	&"four_touches"]
const FAULT_WEIGHTS := [0.22, 0.14, 0.24, 0.16, 0.10, 0.14]

## How far outside a circle a foot at fault is drawn: from a toe over the line to a clear step.
const FOOT_OUT_LEAST := 0.04
const FOOT_OUT_MOST := 0.30

## How fast they move. A sepak takraw player is quick over a small court.
const SPEED := 4.0

var court: TakrawCourt
var rally: TakrawRally

var _beat := Beat.THROW
var _possession := Sides.Team.NONE
var _rally_seconds := 0.0

## Who does what with this possession: who received the ball, who set it, who spikes it.
var _receiver: Player
var _setter: Player
var _spiker: Player

## Faults a person commits, kept on the match and copied to the rally when the call is made.
var net_toucher := Sides.Team.NONE
var centre_line_crosser := Sides.Team.NONE

## The rolled fault waiting to happen this rally, if any.
var _fault := &""

## The side that served first in this set. The other side serves first in the next (Law 10.6).
var _set_first_server := Sides.Team.NONE

## In doubles the two partners take turns as server each time their side serves.
var _doubles_turn := {Sides.Team.RED: 0, Sides.Team.BLUE: 0}

## Where this rally's serve is going, chosen when the ball is thrown.
var _serve_aim := Vector3.ZERO

## The thrower and the server of the rally in progress.
var _thrower: Player
var _server: Player


func sport() -> StringName:
	return Career.TAKRAW


func net_height() -> float:
	return TakrawSpec.NET_HEIGHT


func floor_height() -> float:
	return TakrawCourt.SURFACE_Y


func flight() -> ShotSolver.Flight:
	return TakrawBall.flight()


func current_rally():
	return rally


func fault_book() -> Array:
	return TakrawCallBook.faults()


func build_the_venue() -> void:
	court = TakrawCourt.new()
	court.name = "Court"
	add_child(court)

	_ball = TakrawBall.new()
	_ball.name = "Ball"
	_ball.floor_height = TakrawCourt.SURFACE_Y
	add_child(_ball)
	_ball.landed.connect(_on_ball_landed)
	_ball.bounced.connect(_on_ball_bounced)
	_ball.freeze = true

	ball_cam = ShuttleCam.new()
	ball_cam.name = "BallCam"
	ball_cam.view_metres = 1.2
	add_child(ball_cam)

	build_the_players()
	_build_camera()


## The two line referees, along the sidelines at diagonally opposite corners (Law 10.1).
func line_judge_spots() -> Array:
	return [
		{"at": Vector3(TakrawSpec.HALF_WIDTH + 1.2, 0.0, TakrawSpec.HALF_LENGTH + 1.0)},
		{"at": Vector3(-(TakrawSpec.HALF_WIDTH + 1.2), 0.0, -(TakrawSpec.HALF_LENGTH + 1.0))},
	]


func make_cutscene() -> Cutscene:
	return TakrawCutscene.new()


## "2 sets to 1   ·   15–9  13–15  15–11", the winner's points first in every set.
func result_words(winner: Sides.Team) -> String:
	if board == null:
		return ""
	var loser := Sides.opponent(winner)
	var sets: Array[String] = []
	for points in board.finished_sets:
		sets.append("%d–%d" % [points[winner], points[loser]])
	var won := "%d set%s to %d" % [board.games[winner], "" if board.games[winner] == 1 else "s",
		board.games[loser]]
	return won + ("   ·   " + "  ".join(sets) if not sets.is_empty() else "")


func event_dressing() -> EventDressing:
	return court.event if court != null else null


func dress_the_venue(venue: Dictionary) -> void:
	court.dress(venue["dressing"], venue["crowd"])


func make_the_board(venue: Dictionary) -> Scoreboard:
	return TakrawScore.new(venue["quick"])


func _build_camera() -> void:
	camera = UmpireCamera.new()
	camera.name = "RefereeCamera"
	# On the chair beside the post, looking down the length of the net. Both halves of the
	# court are to left and right, and the circles are below.
	camera.position = Vector3(
		TakrawSpec.POST_X + TakrawCourt.STAND_OFFSET, TakrawCourt.EYE_HEIGHT, 0.0)
	camera.facing_deg = 90.0
	camera.start_pitch_deg = -18.0
	camera.fov = 80.0
	camera.cull_mask = camera.cull_mask & ~TakrawCourt.STAND_LAYER
	camera.current = true
	add_child(camera)


# --- the people -----------------------------------------------------------------

## Three a side in regu — the tekong at the back and the left and right inside players at
## the net — and two in doubles. Each carries its role, so the serve can find them.
func build_the_players() -> void:
	var per_side := 2 if playing_doubles() else 3
	for team in [Sides.Team.RED, Sides.Team.BLUE]:
		var side := Sides.half_sign(team)
		for i in per_side:
			var player := Player.new()
			# From the settings, before the body is built: the kit is a choice of
			# character file, not a recolour applied to one afterwards.
			player.clear_kit = settings.clear_kits
			player.name = "%s%d" % [Sides.label(team), i]
			player.volleyball = true
			# Played with the feet, which is what decides where the ball leaves from: the
			# boot at the top of a roll spike, not the hand of somebody who may not
			# legally touch it at all.
			player.plays_with_the_feet = true
			player.speed = SPEED
			player.reach = 1.1
			add_child(player)
			player.setup(team, _home(team, i, per_side))
			player.set_meta("role", i)
			players.append(player)


## Where a player waits between touches. Regu: the tekong deep in the middle, the inside
## players up at the net either side. Doubles: one back, one up.
func _home(team: Sides.Team, role: int, per_side: int) -> Vector3:
	var side := Sides.half_sign(team)
	if per_side == 2:
		return Vector3(-0.9 if role == 0 else 0.9, 0.0, side * (3.9 if role == 0 else 1.6))
	match role:
		0:
			return Vector3(0.0, 0.0, side * 4.4)
		1:
			return Vector3(-1.8, 0.0, side * 1.5)
		_:
			return Vector3(1.8, 0.0, side * 1.5)


func _role(player: Player) -> int:
	return int(player.get_meta("role", 0))


func _by_role(team: Sides.Team, role: int) -> Player:
	for player in team_of(team):
		if _role(player) == role:
			return player
	return null


## Everybody to where the serve is taken from, which is where the referee checks the feet.
func enter_ready() -> void:
	_line_up_for_the_serve()
	ui.set_prompt("SPACE  call the score")


func _line_up_for_the_serve() -> void:
	var receiving := Sides.opponent(serving)
	for player in players:
		player.go_home()
	if playing_doubles():
		# The server behind the back line, the partner still in the court.
		var turn: int = _doubles_turn[serving]
		_server = _by_role(serving, turn)
		_thrower = _server
		var s_side := Sides.half_sign(serving)
		_server.place(Vector3(randf_range(-1.2, 1.2), 0.0, s_side * (TakrawSpec.HALF_LENGTH + 0.45)))
		var partner := _by_role(serving, 1 - turn)
		partner.place(Vector3(-signf(_server.position.x + 0.01) * 1.2, 0.0, s_side * 2.0))
	else:
		# The tekong's standing foot in the service circle, the inside players in their
		# quarter circles. Drawn where the feet really are.
		var s_side := Sides.half_sign(serving)
		_server = _by_role(serving, 0)
		_server.place(TakrawSpec.service_circle(s_side)
			+ _inside_circle(TakrawSpec.SERVICE_CIRCLE_RADIUS - 0.14))
		var left := _by_role(serving, 1)
		var right := _by_role(serving, 2)
		left.place(_in_quarter(s_side, -1.0))
		right.place(_in_quarter(s_side, 1.0))
		_thrower = left if randf() < 0.5 else right
	for player in team_of(receiving):
		player.place(_home(receiving, _role(player), team_of(receiving).size()))
	_server.face(Vector3(0.0, 0.0, 0.0))


## A point well inside a circle of `radius` around the origin.
func _inside_circle(radius: float) -> Vector3:
	var angle := randf() * TAU
	var r := sqrt(randf()) * maxf(0.0, radius)
	return Vector3(cos(angle) * r, 0.0, sin(angle) * r)


## Where an inside player stands in their quarter circle: well inside it, off the lines.
func _in_quarter(side: float, across: float) -> Vector3:
	var corner := TakrawSpec.quarter_circle(side, across)
	return corner + Vector3(-across * randf_range(0.30, 0.55), 0.0, side * randf_range(0.28, 0.5))


# --- the serve ------------------------------------------------------------------

func start_rally() -> void:
	if _phase != Phase.READY or _reviewing:
		return
	hush_the_line_judges()
	clear_the_mark()
	rally = TakrawRally.new()
	net_toucher = Sides.Team.NONE
	centre_line_crosser = Sides.Team.NONE
	_rally_seconds = 0.0
	if board.points[Sides.Team.RED] == 0 and board.points[Sides.Team.BLUE] == 0:
		_set_first_server = serving

	_fault = _roll_for_one_fault()
	_possession = serving
	rally.served_by = serving
	rally.contacts = 0
	_apply_the_serving_fault()

	_phase = Phase.IN_PLAY
	ui.set_prompt("watch it")
	var target := _serve_target()
	_serve_aim = target
	var receiver := nearest_of(Sides.opponent(serving), target)
	receiver.chase(target)

	if playing_doubles():
		# A doubles server throws the ball to themselves (Double Law 9).
		_beat = Beat.SERVE
		_server.face(target)
		var from := _server.kicking_point(SERVE_HEIGHT)
		_server.takraw_serve(target)
		toss_then_serve(from, target, SERVE_ANGLES, Player.ST_SERVE_CONTACT)
		return

	# Regu: an inside player throws the ball underarm to the tekong, who kicks it.
	_beat = Beat.THROW
	_thrower.face(_server.position)
	_thrower.takraw_throw()
	# Thrown to arrive at the tekong's kicking height after a fixed time, rather than solved
	# to land on the floor like every other shot: the throw is caught by a foot in the air.
	# Over a two-metre lob drag barely matters, so the arc is worked out as if it did not.
	_server.face(target)
	var catch_at := _server.kicking_point(SERVE_HEIGHT)
	var from := _thrower.position + Vector3(0.0, 0.95, 0.0)
	var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)
	_aim = catch_at
	_ball.launch(from, (catch_at - from) / THROW_SECONDS + Vector3(0.0, 0.5 * gravity * THROW_SECONDS, 0.0))
	var this_rally := rally
	# The kick starts so that the foot meets the ball when the throw arrives.
	await get_tree().create_timer(THROW_SECONDS - Player.ST_SERVE_CONTACT, false).timeout
	if rally != this_rally or _phase != Phase.IN_PLAY:
		return
	_server.takraw_serve(target)
	await get_tree().create_timer(Player.ST_SERVE_CONTACT, false).timeout
	if rally != this_rally or _phase != Phase.IN_PLAY:
		return
	_kick_the_serve()


## A serve may land anywhere in the other half. Most go deep; some go at a line.
func _serve_target() -> Vector3:
	var against := Sides.opponent(serving)
	var side := Sides.half_sign(against)
	if randf() < 0.3:
		return _at_a_line(against, 2.0)
	return Vector3(randf_range(-2.4, 2.4), TakrawCourt.SURFACE_Y,
		side * randf_range(2.6, TakrawSpec.HALF_LENGTH - 0.5))


## At most one thing goes wrong per rally, and this decides whether and which.
func _roll_for_one_fault() -> StringName:
	if randf() >= FAULT_CHANCE:
		return &""
	var roll := randf()
	var running := 0.0
	for i in FAULT_KINDS.size():
		running += FAULT_WEIGHTS[i]
		if roll < running:
			return FAULT_KINDS[i]
	return FAULT_KINDS[FAULT_KINDS.size() - 1]


## The two faults of the serve are drawn before the ball moves: a foot over its line.
##
## How plainly is how far over. A toe on the line is a thing only somebody looking straight
## down at it could call; a whole step out of the circle is a thing the stand can see.
func _apply_the_serving_fault() -> void:
	var side := Sides.half_sign(serving)
	match _fault:
		&"service_fault":
			rally.foot_fault = true
			var out := randf_range(FOOT_OUT_LEAST, FOOT_OUT_MOST)
			rally.service_fault_visibility = clampf(0.15 + out * 2.6, 0.0, 0.95)
			if playing_doubles():
				# Standing on the back line rather than behind it.
				_server.place(Vector3(_server.position.x, 0.0, side * (TakrawSpec.HALF_LENGTH - out * 0.6)))
			else:
				var angle := randf() * TAU
				_server.place(TakrawSpec.service_circle(side) + Vector3(
					cos(angle), 0.0, sin(angle)) * (TakrawSpec.SERVICE_CIRCLE_RADIUS + out))
			_server.face(Vector3.ZERO)
		&"inside_fault":
			rally.inside_fault = true
			var out := randf_range(FOOT_OUT_LEAST, FOOT_OUT_MOST)
			rally.inside_fault_visibility = clampf(0.12 + out * 2.2, 0.0, 0.9)
			if playing_doubles():
				# The partner raises both arms before the kick.
				var partner := _by_role(serving, 1 - int(_doubles_turn[serving]))
				partner.block()
			else:
				var mover := _by_role(serving, 1 if randf() < 0.5 else 2)
				var across := -1.0 if _role(mover) == 1 else 1.0
				var corner := TakrawSpec.quarter_circle(side, across)
				var toward := Vector3(-across, 0.0, side).normalized()
				mover.place(corner + toward * (TakrawSpec.QUARTER_CIRCLE_RADIUS + out))


# --- the rally ------------------------------------------------------------------

func _physics_process(delta: float) -> void:
	if _phase != Phase.IN_PLAY:
		return
	_rally_seconds += delta
	if _rally_seconds > RALLY_LIMIT:
		_ball.force_landing()
		return
	if _beat == Beat.ATTACK:
		return
	if _beat == Beat.THROW:
		return
	if not ball_has_arrived(REACH, 2.2):
		# Not yet — but the foot that is going to play it starts moving now, so that it is
		# on the ball when it gets here rather than half a clip behind it.
		start_the_touch_when_due(REACH, 2.2)
		return
	_take_the_next_contact()


func _kick_the_serve() -> void:
	if _beat != Beat.THROW:
		return
	_beat = Beat.SERVE
	var from := _ball.global_position
	var target := _serve_aim
	sound.strike(from, true)
	send_over(from, target, SERVE_ANGLES)
	# Whoever is nearest where it is going is the one who plays it. A serve that is still
	# above head height when it arrives is headed instead, and the early sila is abandoned
	# when that turns out to be what happens — see Player._took_it_early.
	var receiver := nearest_of(Sides.opponent(_possession), target)
	# And they go to meet it. Nobody was ever sent to a takraw serve: the receiving side
	# stood at home and played it from wherever they happened to be, which is a metre from
	# where the foot could reach.
	receiver.chase(target, "st_receive")
	expect_touch(receiver, "st_receive")


func _take_the_next_contact() -> void:
	var here := _ball.global_position
	match _beat:
		Beat.SERVE:
			_possession = Sides.opponent(_possession)
			rally.contacts = 1
			_receive(here)
		Beat.RECEIVE:
			if _fault == &"four_touches" and rally.contacts == 1 and _possession != serving:
				# The receiver's first touch pops up badly, and a teammate plays it again
				# rather than setting it. That second receive makes the set the fourth touch.
				rally.contacts = 2
				_fault = &""
				rally.four_toucher = _possession
				var helper := _someone_else(_possession, _receiver)
				helper.takraw_receive()
				_receiver = helper
				sound.strike(here, false)
				var again := Vector3(randf_range(-1.2, 1.2), TakrawCourt.SURFACE_Y,
					Sides.half_sign(_possession) * 3.2)
				_setter.chase(again, "st_set")
				expect_touch(_setter, "st_set")
				send(helper.struck_from(Vector3(here.x, RECEIVE_HEIGHT, here.z)),
					again, RECEIVE_ANGLE)
				return
			rally.contacts += 1
			_beat = Beat.SET
			if rally.four_toucher != Sides.Team.NONE:
				rally.contacts = 3
			_put_it_up(here)
		Beat.SET:
			rally.contacts += 1
			_beat = Beat.ATTACK
			_attack(Vector3(here.x, SPIKE_HEIGHT, here.z))


## The first touch of a possession: a sepak sila, a thigh, a chest or a header.
func _receive(here: Vector3) -> void:
	_beat = Beat.RECEIVE
	_receiver = nearest_of(_possession, here)
	_setter = _someone_else(_possession, _receiver)
	if here.y > 1.2:
		_receiver.takraw_header()
	else:
		_receiver.takraw_receive()
	# An arm touch happens here if it is going to happen at all: the ball comes in fast and
	# low, the arms are out for balance, and it clips one.
	if _fault == &"arm" and randf() < 0.6:
		rally.arm_toucher = _possession
		rally.handling_visibility = randf_range(0.2, 0.9)
		if rally.handling_visibility > 0.55:
			# Plain enough to see: the arms come up to it.
			_receiver.set_the_ball()
		_fault = &""
	sound.strike(here, false)
	var to_the_setter := Vector3(randf_range(-1.4, 1.4), TakrawCourt.SURFACE_Y,
		Sides.half_sign(_possession) * 1.7)
	_setter.chase(to_the_setter, "st_set")
	expect_touch(_setter, "st_set")
	# Off the foot that played it rather than out of the air above it.
	send(_receiver.struck_from(Vector3(here.x, RECEIVE_HEIGHT, here.z)),
		to_the_setter, RECEIVE_ANGLE)


## The second touch: the feeder puts it up near the net for the killer.
func _put_it_up(here: Vector3) -> void:
	if _setter != null:
		_setter.takraw_set()
	sound.strike(here, false)
	_spiker = _someone_else(_possession, _setter)
	var to_the_spiker := Vector3(clampf(here.x + randf_range(-1.2, 1.2), -2.2, 2.2),
		TakrawCourt.SURFACE_Y, Sides.half_sign(_possession) * 0.9)
	# Set where the killer can actually get to. A set put on the net with the spiker three
	# metres behind it is a set nobody reaches, and the spike then happens with the ball
	# somewhere the foot was never going to be — measured at nearly two metres away.
	var run := Vector2(to_the_spiker.x - _spiker.position.x,
		to_the_spiker.z - _spiker.position.z)
	if run.length() > FURTHEST_A_KILLER_RUNS:
		run = run.normalized() * FURTHEST_A_KILLER_RUNS
		to_the_spiker = Vector3(_spiker.position.x + run.x, TakrawCourt.SURFACE_Y,
			_spiker.position.z + run.y)
	_spiker.chase(to_the_spiker, "st_spike")
	expect_touch(_spiker, "st_spike")
	send(_setter.struck_from(Vector3(here.x, SET_HEIGHT, here.z)) if _setter != null
		else Vector3(here.x, SET_HEIGHT, here.z), to_the_spiker, SET_ANGLE)


## The spike, the block, and the call the whole rally was building to.
func _attack(from: Vector3) -> void:
	rally.struck_by = _possession
	var against := Sides.opponent(_possession)
	rally.receiving = against
	var target := _attack_target(against)
	if _fault == &"arm":
		# The roll never fired on the receive. It can still happen to a blocker.
		rally.arm_toucher = against
		rally.handling_visibility = randf_range(0.2, 0.8)
		_fault = &""

	var going_long: bool = absf(target.z) >= TakrawSpec.HALF_LENGTH - 0.05
	if going_long and randf() < BLOCK_TOUCHES:
		rally.was_touched = true
		rally.touch_visibility = randf_range(0.08, 0.95)
		var deflection := 0.15 + rally.touch_visibility * 1.2
		target.z = Sides.half_sign(against) * (TakrawSpec.HALF_LENGTH + deflection)
		target.x += randf_range(-0.6, 0.6) * rally.touch_visibility

	if _spiker != null:
		_spiker.takraw_spike()
	sound.strike(from, true)
	_meet_the_attack(against, from)
	# Off the boot. A roll spike is struck by the foot at the top of the turn, and that is
	# where the ball leaves from.
	send_over(_spiker.struck_from(from) if _spiker != null else from, target, SPIKE_ANGLES)


## The defending inside players turn their backs to the net and jump at the spike. A blocker
## who touches the net, or lands in the other court, has committed the fault waiting for them.
func _meet_the_attack(defending: Sides.Team, from: Vector3) -> void:
	var side := Sides.half_sign(defending)
	var blocker := nearest_of(defending, Vector3(from.x, 0.0, side * 0.6))
	blocker.chase(Vector3(clampf(from.x, -2.4, 2.4), 0.0, side * 0.45))
	blocker.takraw_block()
	match _fault:
		&"net_touch":
			net_toucher = defending
			court.shake(0.8)
			_fault = &""
		&"crossing":
			centre_line_crosser = defending
			# Landing from the block, the blocker's feet come down over the centre line.
			var over := randf_range(0.08, 0.35)
			await get_tree().create_timer(0.45, false).timeout
			if is_instance_valid(blocker):
				blocker.position.z = -side * over
			_fault = &""


## Where the spike is aimed: safely inside some of the time, at a line the rest.
func _attack_target(against: Sides.Team) -> Vector3:
	if randf() < 0.4:
		var side := Sides.half_sign(against)
		return Vector3(randf_range(-2.4, 2.4), TakrawCourt.SURFACE_Y,
			side * randf_range(1.6, TakrawSpec.HALF_LENGTH - 0.6))
	return _at_a_line(against, 1.2)


## A hand either side of a line: the back line more often, because a ball going long passes
## over the block.
func _at_a_line(team: Sides.Team, nearest_z: float) -> Vector3:
	var side := Sides.half_sign(team)
	var nudge := randf_range(-0.25, 0.25)
	if randf() < 0.62:
		return Vector3(randf_range(-TakrawSpec.HALF_WIDTH + 0.4, TakrawSpec.HALF_WIDTH - 0.4),
			TakrawCourt.SURFACE_Y, side * (TakrawSpec.HALF_LENGTH + nudge))
	return Vector3((1.0 if randf() < 0.5 else -1.0) * (TakrawSpec.HALF_WIDTH + nudge),
		TakrawCourt.SURFACE_Y, side * randf_range(nearest_z, TakrawSpec.HALF_LENGTH - 0.5))


func _someone_else(team: Sides.Team, than: Player) -> Player:
	var best: Player = null
	var closest := 1e9
	for player in team_of(team):
		if player == than:
			continue
		# In regu the tekong rarely sets; prefer an inside player.
		var gap := player.distance_to(Vector3(0.0, 0.0, Sides.half_sign(team) * 1.5))
		if gap < closest:
			closest = gap
			best = player
	return best if best != null else than


func _on_ball_bounced(point: Vector3, speed: float, first: bool) -> void:
	if not first and sound != null:
		sound.bounce(point, speed)


func _on_ball_landed(point: Vector3) -> void:
	if _phase != Phase.IN_PLAY:
		return
	rally.record_landing(point, Sides.half_containing(point.z))
	if rally.struck_by == Sides.Team.NONE:
		rally.struck_by = serving
		rally.receiving = Sides.opponent(serving)
	for player in players:
		player.go_home()
	_receiver = null
	_setter = null
	_spiker = null
	_phase = Phase.AWAITING_CALL
	_awaiting_since = Time.get_ticks_msec()
	line_judges_watch(point, rally.margin, rally.was_in)
	mark_the_landing(point)
	sound.landing(point)
	if has_close_cam:
		ball_cam.aim_at(point)
		ui.show_close_cam(ball_cam.texture())
	ui.set_prompt("LEFT CLICK  in    RIGHT CLICK  out    T  touch    F  fault")


# --- the call -------------------------------------------------------------------

func make_call(id: StringName, against := Sides.Team.NONE) -> void:
	if _phase != Phase.AWAITING_CALL:
		return
	var call := TakrawCallBook.get_call(id)
	if call != null:
		await judge(call, against)


func before_pricing() -> void:
	rally.net_toucher = net_toucher
	rally.centre_line_crosser = centre_line_crosser


## The service changes after every point, whoever wins it (Law 10.5). A new set is served
## first by the side that received first in the last one (Law 10.6).
func award_the_point(winner: Sides.Team) -> void:
	var sets_before := board.finished_sets.size()
	var was_set_up: bool = (board as TakrawScore).set_up
	var server := serving
	board.award(winner)
	if board.finished_sets.size() != sets_before:
		serving = Sides.opponent(_set_first_server)
	else:
		serving = Sides.opponent(server)
	if playing_doubles() and board.finished_sets.size() == sets_before:
		_doubles_turn[server] = 1 - int(_doubles_turn[server])
	if not was_set_up and (board as TakrawScore).set_up:
		ui.react("\"Setting up to seventeen points\"", 3.0)


func cheer() -> void:
	court.cheer()


func jeer(share: float) -> void:
	court.jeer(share)


func _unhandled_input(event: InputEvent) -> void:
	if _reviewing:
		if (_can_skip_review and event is InputEventKey and event.pressed
				and event.keycode == KEY_SPACE):
			_review_skipped = true
		return
	if _phase == Phase.REMOVED or _phase == Phase.MENU:
		return
	if ui.is_fault_panel_open():
		if event.is_action_pressed(&"ref_pause"):
			close_the_fault_panel()
		return
	if event.is_action_pressed(&"ref_pause"):
		pause_the_match()
		return
	if event.is_action_pressed(&"ref_faults"):
		open_the_fault_panel()
		return
	match _phase:
		Phase.READY:
			if event.is_action_pressed(&"ref_serve"):
				start_rally()
		Phase.AWAITING_CALL:
			if event.is_action_pressed(&"ref_call_in"):
				make_call(&"in")
			elif event.is_action_pressed(&"ref_call_out"):
				make_call(&"out")
			elif event.is_action_pressed(&"ref_touch"):
				make_call(&"touch")


func the_stands() -> Stands:
	return court.stands
