class_name BeachMatch
extends OfficiatedMatch

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

## Beach sets are to 21 and the third one is to 15, with no cap either way — you win by
## two or you keep playing.
const SET_TARGET := 21
const DECIDER_TARGET := 15
const NO_CAP := 9999

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
const FAULT_KINDS := [&"foot_fault", &"net_touch", &"centre_line", &"handling", &"antenna"]
const FAULT_WEIGHTS := [0.19, 0.24, 0.13, 0.26, 0.18]

var court: BeachCourt

var rally: BeachRally

## The review system, and whether this venue carries one. From the world tour up, which
## is what the two top rungs' blurbs have been promising since they were written.

## Whether this venue has a camera on the line.
##
## Badminton has had one from the school hall up: when the shuttle lands the umpire gets
## an overhead view of it against the paint, every rally. Both volleyball ladders have
## been promising the same thing in their venue data since they were written, and
## neither sport read the flag — so the two sports asking for the most precise line
## calls in the game were the two giving the player the least to judge them with.

## True while a review is on screen, which is the only time the referee is a spectator.

## How long the venue waits before it finds out, and how long it looks at the answer.


## Why the referee might want a particular result this week, if anybody has given them
## one. Nobody is asked to pick a side any more — a reason only ever arrives from
## outside, and only sometimes.

var _beat := Beat.SERVE
var _possession := Sides.Team.NONE

## Who is doing what with this possession.
##
## Beach volleyball's three touches are shared between two people in a fixed pattern:
## whoever digs the ball up does *not* set it, and then attacks the set their partner
## puts up for them. So the pair swap roles constantly, and which of them is at the net
## at the end of a rally depends on who happened to be nearest at the start of it.
var _digger: Player
var _setter: Player
var _rally_seconds := 0.0

## Faults recorded on the match rather than on the rally, because they are things a
## person did rather than things the ball did.
var net_toucher := Sides.Team.NONE
var centre_line_crosser := Sides.Team.NONE

## Whether this rally's attacker has been run out past the sideline. A ball played from
## out there crosses the net near where it was struck, which is the only way it ever
## passes outside an antenna.
var _chasing_it_wide := false



func sport() -> StringName:
	return Career.BEACH


func net_height() -> float:
	return BeachSpec.NET_HEIGHT


func floor_height() -> float:
	return BeachCourt.SURFACE_Y


func current_rally():
	return rally


## The sand, the ball, the four of them and the sky.
func build_the_venue() -> void:
	court = BeachCourt.new()
	court.name = "Court"
	add_child(court)

	_ball = Ball.new()
	_ball.name = "Ball"
	_ball.floor_height = BeachCourt.SURFACE_Y
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
	_build_sky()


func fault_book() -> Array:
	return BeachCallBook.faults()


## Two of them, at diagonally opposite corners, behind the end lines and outside the
## sidelines. From opposite corners the pair see all four boundary lines between them.
func line_judge_spots() -> Array:
	return [
		{"at": Vector3(BeachSpec.HALF_WIDTH + 1.6,
			0.0, BeachSpec.HALF_LENGTH + 1.6)},
		{"at": Vector3(-(BeachSpec.HALF_WIDTH + 1.6),
			0.0, -(BeachSpec.HALF_LENGTH + 1.6))},
	]


## Beach volleyball's director. See BeachCutscene.
func make_cutscene() -> Cutscene:
	return BeachCutscene.new()


## "2 sets to 0   ·   21–15  21–18", the winner's points first in every set.
func result_words(winner: Sides.Team) -> String:
	if board == null:
		return ""
	var loser := Sides.opponent(winner)
	var sets: Array[String] = []
	for points in board.finished_sets:
		sets.append("%d\u2013%d" % [points[winner], points[loser]])
	var won := "%d set%s to %d" % [board.games[winner], "" if board.games[winner] == 1 else "s",
		board.games[loser]]
	return won + ("   ·   " + "  ".join(sets) if not sets.is_empty() else "")


func dress_the_venue(venue: Dictionary) -> void:
	court.dress(venue["dressing"], venue["crowd"])


func make_the_board(venue: Dictionary) -> Scoreboard:
	var made := Scoreboard.new(venue["quick"])
	if not venue["quick"]:
		made.target = SET_TARGET
		made.cap = NO_CAP
		made.decider_target = DECIDER_TARGET
	return made


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


## Where a pair stands when the ball is not their problem: one up at the net, one deep.
## Beach is played as a diagonal, so they are on opposite sides of the court as well as
## at different depths.
const NET_BASE := Vector3(1.7, 0.0, 2.9)
const DEEP_BASE := Vector3(-1.7, 0.0, 5.8)

## How fast they cover sand. Slower than a badminton court on purpose — running in dry
## sand is the hardest thing about this sport, and a player who glides across it at
## badminton speed looks wrong even to somebody who has never played.
const SAND_SPEED := 3.4


func build_the_players() -> void:
	for team in [Sides.Team.RED, Sides.Team.BLUE]:
		var side := Sides.half_sign(team)
		for i in 2:
			var player := Player.new()
			player.name = "%s%d" % [Sides.label(team), i]
			player.volleyball = true
			player.speed = SAND_SPEED
			# A volleyball player reaches a lot further than a badminton player does:
			# two arms, a jump, and no racket to be precise with.
			player.reach = 1.35
			add_child(player)
			var base: Vector3 = NET_BASE if i == 0 else DEEP_BASE
			player.setup(team, Vector3(base.x, 0.0, side * base.z))
			players.append(player)


## The two players on one side.
func _partner(team: Sides.Team, of: Player) -> Player:
	for player in team_of(team):
		if player != of:
			return player
	return of


## Sends the defending pair to meet an attack: one up to block it, one back to dig it.
##
## The block is the reason the touch call exists, so the blocker has to actually be
## under the ball as it crosses. They go to the net at the attacker's shoulder rather
## than to where the ball is aimed, because that is what a blocker does — they take away
## the line and let their partner cover the rest.
func _meet_the_attack(defending: Sides.Team, from: Vector3, target: Vector3) -> void:
	var side := Sides.half_sign(defending)
	var blocker := nearest_of(defending, Vector3(from.x, 0.0, side * 1.1))
	blocker.chase(Vector3(clampf(from.x, -2.8, 2.8), 0.0, side * 1.1))
	# Arms up over the tape. The clip was authored with the beach set and no sport ever
	# played it, so the block this whole sport's signature call is about — did the ball
	# graze a blocker's fingers — was made by somebody standing at the net with their
	# hands by their sides.
	blocker.block()
	_partner(defending, blocker).chase(Vector3(
		clampf(target.x, -3.2, 3.2), 0.0, side * clampf(absf(target.z), 3.4, 7.2)))


# --- the front of the match -----------------------------------------------------
#
# The badminton scene owns the title screen, the sport menu, the settings and the
# lesson, because that is where the game starts. Once beach volleyball has been chosen
# the sport is a different scene, so the screens that belong to a *match* — the career
# ladder, the briefing, the ending, the pause — are wired up again here against the
# same RefereeUI. Nothing is duplicated but the wiring: every screen itself is shared.

func start_rally() -> void:
	if _phase != Phase.READY or _reviewing:
		return
	hush_the_line_judges()
	clear_the_mark()
	rally = BeachRally.new()
	net_toucher = Sides.Team.NONE
	centre_line_crosser = Sides.Team.NONE
	_rally_seconds = 0.0

	_chasing_it_wide = false
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
	# Whoever is nearest the spot the serve comes from is the one who plays it, and they
	# play it with the serve clip — which has been on the character since the beach
	# animations were authored and which no sport has ever asked for. Both volleyballs
	# have served several thousand times with nobody moving.
	var server := nearest_of(serving, Vector3(from.x, 0.0, from.z))
	if server != null:
		server.position = Vector3(from.x, 0.0, from.z)
		server.serve_the_ball(target)

	# The receiving pair read the serve and one of them goes to meet it.
	var receiver := nearest_of(Sides.opponent(serving), target)
	receiver.chase(target)
	_partner(Sides.opponent(serving), receiver).chase(
		_set_point(Sides.opponent(serving)))
	_phase = Phase.IN_PLAY
	sound.whistle()
	ui.set_prompt("watch it")
	# The whistle, then the wind-up, then the ball — not all three on one frame.
	toss_then_serve(from, target, SERVE_ANGLES, Player.VB_SERVE_CONTACT)


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
		&"antenna":
			# Not recorded here. It has to actually happen, and it happens by the
			# attacker being run out wide and playing the ball back round the rod —
			# which is where the call comes from in the real sport too.
			_chasing_it_wide = true


## Launches a shot that has to cross the net, at the flattest angle that actually gets
## over it.
##
## The same problem badminton has and solves the same way: a straight line from the
## contact to the target clears the tape comfortably, and the ball does not travel in a
## straight line. The only honest way to know is to fly it and look.
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
	if not ball_has_arrived(REACH, 2.6):
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
			# Whoever got to it digs, and their partner comes in to set.
			_digger = nearest_of(_possession, here)
			_setter = _partner(_possession, _digger)
			_digger.dig()
			sound.strike(here, false)
			var to_the_setter := _set_point(_possession)
			_setter.chase(to_the_setter)
			send(Vector3(here.x, DIG_HEIGHT, here.z), to_the_setter, DIG_ANGLE)
		Beat.DIG:
			rally.contacts = 2
			_beat = Beat.SET
			# The setter puts it up and the digger comes forward to hit it.
			if _setter != null:
				_setter.set_the_ball()
			sound.strike(here, false)
			var to_the_hitter := _attack_point(_possession)
			if _digger != null:
				_digger.chase(to_the_hitter)
			send(Vector3(here.x, SET_HEIGHT, here.z), to_the_hitter, SET_ANGLE)
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
	if _chasing_it_wide:
		# Out past the sideline, level with the net. From here the ball crosses the net
		# roughly where it was struck, and the antenna is what it has to get past.
		var wide := BeachSpec.ANTENNA_X + randf_range(0.12, 0.55)
		return Vector3((1.0 if randf() < 0.5 else -1.0) * wide,
			BeachCourt.SURFACE_Y, side * randf_range(0.9, 1.6))
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
	if _chasing_it_wide:
		target = _around_the_antenna(against, from)
	# Where it passes the net, which is what the antenna is about. Measured from the
	# flight rather than asserted by whoever rolled the fault: a ball struck from out
	# past the sideline crosses near where it was hit, and one struck from inside the
	# court does not, whatever anybody intended.
	var at_the_net := crossing_x(from, target)
	rally.inside_the_antennae = BeachSpec.inside_the_antennae(Vector3(at_the_net, 0.0, 0.0))
	rally.antenna_margin = BeachSpec.ANTENNA_X - absf(at_the_net)

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
	if _digger != null:
		_digger.spike()
	# The one contact in the rally that the back of the stand can hear.
	sound.strike(from, true)
	_meet_the_attack(against, from, target)
	send_over(from, target, [ATTACK_ANGLE, 6.0, 16.0, 28.0])


## The bounces after the landing. The landing itself is heard in _on_ball_landed, with
## the rest of what happens when the ball comes down.
func _on_ball_bounced(point: Vector3, speed: float, first: bool) -> void:
	if not first and sound != null:
		sound.bounce(point, speed)


func _on_ball_landed(point: Vector3) -> void:
	if _phase != Phase.IN_PLAY:
		return
	# Whoever's half it came down in was defending it.
	rally.record_landing(point, Sides.half_containing(point.z))
	if rally.struck_by == Sides.Team.NONE:
		# It never got as far as an attack — a serve that came straight down.
		rally.struck_by = serving
		rally.receiving = Sides.opponent(serving)
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
	ui.set_prompt("LEFT CLICK  in    RIGHT CLICK  out    T  touch    F  fault")


# --- the call -------------------------------------------------------------------

func make_call(id: StringName, against := Sides.Team.NONE) -> void:
	if _phase != Phase.AWAITING_CALL:
		return
	var call := BeachCallBook.get_call(id)
	if call != null:
		await judge(call, against)


## Net touch and crossing under the net are things a person did, so they are recorded
## on the match rather than on the ball's rally. The rally has to know about them before
## it can say who should have won the point.
func before_pricing() -> void:
	rally.net_toucher = net_toucher
	rally.centre_line_crosser = centre_line_crosser


func cheer() -> void:
	court.cheer()


func jeer(share: float) -> void:
	court.jeer(share)

func enter_ready() -> void:
	ui.set_prompt("SPACE  whistle the serve")


func _unhandled_input(event: InputEvent) -> void:
	# Nothing gets through while a review is on screen. Making a call is a coroutine now
	# that it can pause for a replay, and the phase does not change until it finishes —
	# so without this the referee could stand there calling the same rally three more
	# times while the first call was still being examined.
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
	var depth := side * randf_range(2.5, BeachSpec.HALF_LENGTH - 0.4)
	var wanted := out * (BeachSpec.ANTENNA_X + randf_range(0.05, 0.45))
	# How far along its own flight the ball is when it reaches the net.
	var at := absf(from.z) / maxf(0.001, absf(depth - from.z))
	var x := from.x + (wanted - from.x) / maxf(0.05, at)
	return Vector3(x, BeachCourt.SURFACE_Y, depth)


## Where this sport seats its hall, so somebody in it can be given a line to say.
func the_stands() -> Stands:
	return court.stands
