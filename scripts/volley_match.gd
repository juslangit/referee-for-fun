class_name VolleyMatch
extends OfficiatedMatch

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

enum Beat { SERVE, DIG, SET, ATTACK }

const SERVE_BEHIND := 1.2
const SERVE_HEIGHT := 2.25

const DIG_ANGLE := 68.0
const SET_ANGLE := 72.0
const ATTACK_ANGLE := -5.0
const SERVE_ANGLES := [14.0, 20.0, 26.0, 34.0, 42.0, 50.0]

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

## The fifth set is to fifteen, not twenty-five. Every other set in the sport is the
## same length and the last one is not, which is the detail anybody who watches
## volleyball would notice missing.
const DECIDER_TARGET := 15

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


var court: VolleyCourt

var rally: VolleyRally


## The lineup of each side, and how far it has turned.
var rota := {Sides.Team.RED: Rotation.new(), Sides.Team.BLUE: Rotation.new()}



var net_toucher := Sides.Team.NONE
var centre_line_crosser := Sides.Team.NONE

var _beat := Beat.SERVE
var _possession := Sides.Team.NONE
var _digger: Player
var _setter: Player
var _attacker_is_back_row := false
var _rally_seconds := 0.0



func sport() -> StringName:
	return Career.INDOOR


func net_height() -> float:
	return VolleySpec.NET_HEIGHT


func floor_height() -> float:
	return VolleyCourt.SURFACE_Y


func current_rally():
	return rally


func fault_book() -> Array:
	return VolleyCallBook.faults()


## The hall, the ball, the twelve of them and the lights.
func build_the_venue() -> void:
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


## Two of them, at diagonally opposite corners, behind the end lines and outside the
## sidelines. From opposite corners the pair see all four boundary lines between them.
func line_judge_spots() -> Array:
	return [
		{"at": Vector3(VolleySpec.HALF_WIDTH + 1.4,
			0.0, VolleySpec.HALF_LENGTH + 1.4)},
		{"at": Vector3(-(VolleySpec.HALF_WIDTH + 1.4),
			0.0, -(VolleySpec.HALF_LENGTH + 1.4))},
	]


func dress_the_venue(venue: Dictionary) -> void:
	court.dress(venue["dressing"], venue["crowd"])


func make_the_board(venue: Dictionary) -> Scoreboard:
	var made := Scoreboard.new(venue["quick"])
	made.target = SET_TARGET
	# Volleyball has no cap: a set runs until somebody is two clear, however long that
	# takes. `cap` is badminton's sudden-death ceiling.
	made.cap = NO_CAP
	made.games_needed = 2 if venue["quick"] else SETS_NEEDED
	made.decider_target = DECIDER_TARGET
	return made


## A new set is a new lineup as well as two fresh challenges.
func _on_set_won(team: Sides.Team) -> void:
	for side in [Sides.Team.RED, Sides.Team.BLUE]:
		rota[side].reset(4)
		_dress_the_libero(side)
	super(team)


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


func nearest_of(team: Sides.Team, to: Vector3) -> Player:
	var best: Player = null
	var closest := 1e9
	for player in team_of(team):
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
	hush_the_line_judges()
	clear_the_mark()
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
	send_over(from, target, SERVE_ANGLES)

	var receiver := nearest_of(Sides.opponent(serving), target)
	receiver.chase(target)
	_phase = Phase.IN_PLAY
	sound.whistle()
	ui.set_prompt("watch it")


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
	if not ball_has_arrived(REACH, 2.8):
		return
	_take_the_next_contact()


func _take_the_next_contact() -> void:
	var here := _ball.global_position
	match _beat:
		Beat.SERVE:
			_possession = Sides.opponent(_possession)
			rally.contacts = 1
			_beat = Beat.DIG
			_digger = nearest_of(_possession, here)
			_setter = _closest_to_the_net(_possession, _digger)
			_digger.dig()
			var to_the_setter := _set_point(_possession)
			_setter.chase(to_the_setter)
			send(Vector3(here.x, DIG_HEIGHT, here.z), to_the_setter, DIG_ANGLE)
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
			send(Vector3(here.x, SET_HEIGHT, here.z), to_the_hitter, SET_ANGLE)
		Beat.SET:
			rally.contacts = 3
			_beat = Beat.ATTACK
			_attack(Vector3(here.x, ATTACK_HEIGHT, here.z))


func _closest_to_the_net(team: Sides.Team, other: Player) -> Player:
	var best: Player = null
	var nearest := 1e9
	for player in team_of(team):
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
	return nearest_of(team, Vector3(0.0, 0.0, Sides.half_sign(team) * 2.0))


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
	send_over(from, target, [ATTACK_ANGLE, 6.0, 16.0, 28.0])


## Two blockers to the net, the rest back to dig.
func _meet_the_attack(defending: Sides.Team, from: Vector3, target: Vector3) -> void:
	var side := Sides.half_sign(defending)
	var blockers := 0
	for player in team_of(defending):
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
	# The line judge on that line makes their mind up now and raises the flag a beat
	# later, so an official who calls first has contradicted them rather than dodged it.
	line_judges_watch(point, rally.margin, rally.was_in)
	mark_the_landing(point)
	if has_close_cam:
		ball_cam.aim_at(point)
		ui.show_close_cam(ball_cam.texture())
	ui.set_prompt(
		"LEFT CLICK  in    RIGHT CLICK  out    T  touch    R  rotation    F  fault")


# --- the call -------------------------------------------------------------------

func make_call(id: StringName, against := Sides.Team.NONE) -> void:
	if _phase != Phase.AWAITING_CALL:
		return
	var call := VolleyCallBook.get_call(id)
	if call != null:
		await judge(call, against)


func cheer() -> void:
	court.cheer()


## A side that wins the serve back rotates. A side that holds it does not — the rule
## most people who have played casually get wrong, and the one that decides who is
## allowed to serve next.
func award_the_point(winner: Sides.Team) -> void:
	if winner != serving:
		rota[winner].rotate()
	super(winner)

func enter_ready() -> void:
	ui.set_prompt("SPACE  whistle the serve      F  fault, including the rotation")


func _unhandled_input(event: InputEvent) -> void:
	if _reviewing or _phase == Phase.REMOVED or _phase == Phase.MENU:
		return

	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		pause_the_match()
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

