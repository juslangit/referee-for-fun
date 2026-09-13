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

## The short form, for the two league rungs that offer one: a single set to fifteen,
## which is what a deciding set is and what everybody plays when time is short.
##
## It used to be sets to 25, best of three — measured at about 123 rallies, which made
## the first match a new player was ever given roughly six times longer than badminton's
## or beach's introduction, and gave it to them before they understood the sport. A
## match nobody finishes teaches nothing.
const QUICK_TARGET := 15

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
	&"rotation", &"wrong_server", &"back_row", &"libero", &"antenna",
]
const FAULT_WEIGHTS := [0.10, 0.14, 0.07, 0.14, 0.13, 0.10, 0.10, 0.09, 0.13]


var court: VolleyCourt

var rally: VolleyRally


## The lineup of each side, and how far it has turned.
var rota := {Sides.Team.RED: Rotation.new(), Sides.Team.BLUE: Rotation.new()}



var net_toucher := Sides.Team.NONE
var centre_line_crosser := Sides.Team.NONE

## Whether this rally's attacker has been run out past the sideline. A ball played from
## out there crosses the net near where it was struck, which is the only way it ever
## passes outside an antenna.
var _chasing_it_wide := false

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
	_ball.bounced.connect(_on_ball_bounced)
	_ball.freeze = true

	ball_cam = ShuttleCam.new()
	ball_cam.name = "BallCam"
	ball_cam.view_metres = 1.75
	add_child(ball_cam)

	build_the_players()
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
	# Volleyball has no cap: a set runs until somebody is two clear, however long that
	# takes. `cap` is badminton's sudden-death ceiling and does not apply.
	made.cap = NO_CAP
	if venue["quick"]:
		made.target = QUICK_TARGET
		made.games_needed = 1
		made.decider_target = 0
	else:
		made.target = SET_TARGET
		made.games_needed = SETS_NEEDED
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
func build_the_players() -> void:
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
			# A first position each, rather than all six on one spot. They are put in
			# their real rotational places by stand_in_position the moment the match
			# begins; this only stops them being built inside one another.
			var spot: Vector2 = Rotation.SPOTS[i + 1]
			player.setup(team, Vector3(
				spot.x * VolleySpec.HALF_WIDTH,
				0.0,
				Sides.half_sign(team) * spot.y * VolleySpec.HALF_LENGTH))
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


## `nearest_of` was here, copied from the spine word for word, and is gone. It did not
## differ by a character; `dev/checks/_inherit` found it by comparing the two bodies.


func stand_in_position() -> void:
	for team in [Sides.Team.RED, Sides.Team.BLUE]:
		var who: Rotation = rota[team]
		_stand(team, who.spots(team == serving))


func _line_up() -> void:
	rally.rotation_fault_by = Sides.Team.NONE
	rally.wrong_server_by = Sides.Team.NONE
	rally.libero_fault_by = Sides.Team.NONE
	rally.libero_did = &""
	rally.back_row_attack_by = Sides.Team.NONE
	net_toucher = Sides.Team.NONE
	centre_line_crosser = Sides.Team.NONE
	_chasing_it_wide = false

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
	# who ends up hitting the ball. So is the antenna: it happens by running the
	# attacker out past the sideline, not by writing it down.
	_back_row_attack_wanted = offender == &"back_row"
	_chasing_it_wide = offender == &"antenna"


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
	# Whoever is nearest the spot the serve comes from is the one who plays it, and they
	# play it with the serve clip — which has been on the character since the beach
	# animations were authored and which no sport has ever asked for. Both volleyballs
	# have served several thousand times with nobody moving.
	var server := nearest_of(serving, Vector3(from.x, 0.0, from.z))
	if server != null:
		server.position = Vector3(from.x, 0.0, from.z)
		server.serve_the_ball(target)

	var receiver := nearest_of(Sides.opponent(serving), target)
	receiver.chase(target)
	_phase = Phase.IN_PLAY
	sound.whistle()
	ui.set_prompt("watch it")
	# The whistle, then the wind-up, then the ball — not all three on one frame.
	toss_then_serve(from, target, SERVE_ANGLES, Player.VB_SERVE_CONTACT)


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
	if _chasing_it_wide and not back_row:
		# Out past the sideline, level with the net. From there the ball crosses the net
		# roughly where it was struck, which is the only way it ever passes outside an
		# antenna — and it is where the call comes from in the real sport too.
		var wide := VolleySpec.ANTENNA_X + randf_range(0.12, 0.55)
		return Vector3((1.0 if randf() < 0.5 else -1.0) * wide,
			VolleyCourt.SURFACE_Y, side * randf_range(0.9, 1.6))
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
			sound.strike(here, false)
			var to_the_setter := _set_point(_possession)
			_setter.chase(to_the_setter)
			send(Vector3(here.x, DIG_HEIGHT, here.z), to_the_setter, DIG_ANGLE)
		Beat.DIG:
			rally.contacts = 2
			_beat = Beat.SET
			if _setter != null:
				_setter.set_the_ball()
			sound.strike(here, false)
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
	if _chasing_it_wide:
		target = _around_the_antenna(against, from)
	var going_long: bool = absf(target.z) >= VolleySpec.HALF_LENGTH - 0.05

	# Where it passes the net, which is what the antenna is about. Measured from the
	# flight rather than asserted by whoever rolled the fault: a ball struck from out
	# past the sideline crosses near where it was hit, and one struck from inside the
	# court does not, whatever anybody intended.
	var at_the_net := crossing_x(from, target)
	rally.inside_the_antennae = VolleySpec.inside_the_antennae(Vector3(at_the_net, 0.0, 0.0))
	rally.antenna_margin = VolleySpec.ANTENNA_X - absf(at_the_net)
	if going_long and randf() < BLOCK_TOUCHES:
		rally.was_touched = true
		rally.touch_visibility = randf_range(0.08, 0.95)
		var deflection := 0.18 + rally.touch_visibility * 1.5
		target.z = Sides.half_sign(against) * (VolleySpec.HALF_LENGTH + deflection)
		target.x += randf_range(-0.8, 0.8) * rally.touch_visibility

	if _digger != null:
		_digger.spike()
	# The one contact in the rally that the back of the stand can hear.
	sound.strike(from, true)
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
			# Both arms over the tape, which is what a block is. See BeachMatch.
			player.block()
			blockers += 1
		else:
			player.chase(Vector3(
				clampf(target.x + randf_range(-1.4, 1.4), -3.8, 3.8),
				0.0, side * clampf(absf(target.z), 3.6, 8.2)))


func _is_front_row_player(team: Sides.Team, player: Player) -> bool:
	return not _is_back_row(team, player)


## The bounces after the landing. The landing itself is heard in _on_ball_landed, with
## the rest of what happens when the ball comes down.
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
	sound.landing(point)
	if has_close_cam:
		ball_cam.aim_at(point)
		ui.show_close_cam(ball_cam.texture())
	ui.set_prompt(
		"LEFT CLICK  in    RIGHT CLICK  out    T  touch    F  fault or rotation")


# --- the call -------------------------------------------------------------------

func make_call(id: StringName, against := Sides.Team.NONE) -> void:
	if _phase != Phase.AWAITING_CALL:
		return
	var call := VolleyCallBook.get_call(id)
	if call != null:
		await judge(call, against)


func cheer() -> void:
	court.cheer()


func jeer(share: float) -> void:
	court.jeer(share)


## A side that wins the serve back rotates. A side that holds it does not — the rule
## most people who have played casually get wrong, and the one that decides who is
## allowed to serve next.
func award_the_point(winner: Sides.Team) -> void:
	if winner != serving:
		rota[winner].rotate()
	super(winner)

func enter_ready() -> void:
	stand_in_position()
	ui.set_prompt("SPACE  whistle the serve")


func _unhandled_input(event: InputEvent) -> void:
	if _reviewing:
		# The only key a review listens to, and only once the answer is on screen. The
		# wait before that is the point of a review and is not skippable.
		if (_can_skip_review and event is InputEventKey and event.pressed
				and event.keycode == KEY_SPACE):
			_review_skipped = true
		return
	if _phase == Phase.REMOVED or _phase == Phase.MENU:
		return

	if ui.is_fault_panel_open():
		if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
			close_the_fault_panel()
		return

	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		pause_the_match()
		return

	if event is InputEventKey and event.pressed and event.keycode == KEY_F:
		open_the_fault_panel()
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


## Where a player run out past the sideline hooks the ball back.
##
## The aim is **solved** rather than nudged, which took two attempts. A wide contact on
## its own does not send a ball outside the antenna: the net is a metre and a half in
## front of the attacker and the ball has covered barely a sixth of its flight by the
## time it reaches it, so a shot struck from 4.3 m out and aimed anywhere near the middle
## still crosses at about 3.6 m — comfortably inside the rod. Nudging the target outward
## by a metre only worked when the ball happened to arrive where it was sent; measured,
## that was under half the time, because the digger's set lands anywhere within reach.
##
## So this asks for a crossing and works backwards to the target that produces it. The
## ball then lands a long way wide, which is what an around-the-antenna shot does.
func _around_the_antenna(against: Sides.Team, from: Vector3) -> Vector3:
	var side := Sides.half_sign(against)
	var out := signf(from.x) if not is_zero_approx(from.x) else 1.0
	var depth := side * randf_range(2.5, VolleySpec.HALF_LENGTH - 0.4)
	var wanted := out * (VolleySpec.ANTENNA_X + randf_range(0.05, 0.45))
	# How far along its own flight the ball is when it reaches the net.
	var at := absf(from.z) / maxf(0.001, absf(depth - from.z))
	var x := from.x + (wanted - from.x) / maxf(0.05, at)
	return Vector3(x, VolleyCourt.SURFACE_Y, depth)


## Where this sport seats its hall, so somebody in it can be given a line to say.
func the_stands() -> Stands:
	return court.stands
