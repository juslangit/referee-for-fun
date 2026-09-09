class_name TennisMatch
extends OfficiatedMatch

## A singles tennis match, umpired from the chair beside the net.
##
## Everything the two volleyballs share is underneath this, unchanged. What tennis
## brings that no other sport in this game has is **a point that is not one event.**
##
## A badminton rally, a beach rally and an indoor rally all end exactly once, in one
## landing, and the umpire is asked exactly one question about it. A tennis point has a
## first serve and possibly a second, and then a rally in which the ball lands over and
## over and only the last of those landings decides anything. So the umpire here is
## making calls *before the point has started* — and the same call costs completely
## different amounts depending on which serve it was. A fault called on the first serve
## takes a serve away. The same call on the second takes the point.
##
## That asymmetry is the whole reason this sport is in the game. A careful cheat calls
## first serves; a greedy one calls seconds; and the difference between them is visible
## in the scoresheet afterwards even though every individual call looked defensible.

enum Beat { SERVE, RALLY }

## Where the server stands behind their baseline, and how high the ball is struck.
const SERVE_BEHIND := 0.35
const SERVE_HEIGHT := 2.55

## A foot fault puts them over the line instead of behind it. Small — it is a foot
## fault, not a walk to the net — but it has to be visible from the chair or the call is
## a coin toss.
const FOOT_FAULT_OVER := 0.14

## Angles a serve may be struck at, flattest first. The first one that clears the tape
## is used. A real serve is struck *downwards*, which is why this list starts negative —
## and why it still needs the flatter alternatives behind it, because a serve aimed
## short into the box cannot go down and still get there.
const SERVE_ANGLES := [-4.0, -1.0, 2.0, 6.0, 12.0, 20.0]

## A groundstroke is played off the bounce, about waist height.
const STRIKE_HEIGHT := 0.85
const STRIKE_CEILING := 1.25
const RALLY_ANGLES := [7.0, 12.0, 18.0, 26.0, 38.0]

## How fast a player covers a hard court, and how far a racket reaches.
const COURT_SPEED := 5.4
const RACKET_REACH := 1.7

## How near a line a ball has to land before the point stops for a call.
##
## The other three sports in this game ask the official about every rally, because every
## rally ends in a landing somebody has to rule on. Tennis does not work that way: a
## serve down the middle of the box is played, and nobody says anything. So the point
## stops when there is a question — when the ball was out, or close enough that the
## receiver looks at the chair instead of playing it, which is what really happens.
const CLOSE_TO_A_LINE := 0.30

## How many strokes a rally runs for before somebody goes for a line.
const SHORTEST_RALLY := 1
const LONGEST_RALLY := 5

## How long a point may run before it is abandoned.
const RALLY_LIMIT := 26.0

## How often a serve clips the net cord.
##
## The one call in this sport decided by a sound. A serve that touches the tape and
## still lands in the box is a let and is played again; one that touches and misses is
## simply a fault. Nobody in the stand can be sure they heard it and the umpire is a
## metre from the net, which makes it tennis's version of the beach block touch — and,
## like the block touch, the easiest thing here to invent and the easiest to deny.
const CORD_CHANCE := 0.09

## How often anything else goes wrong, and which of the four it is when it does.
##
## **One fault per point, never two**, for the same reason the beach match has that
## rule: two faults have an order, and nothing here records one, so a point containing
## both a foot fault and a touched net would leave the game and the umpire disagreeing
## about which decided it.
const FAULT_CHANCE := 0.13
const FAULT_KINDS := [&"foot_fault", &"not_up", &"touched_net", &"through_the_net"]
const FAULT_WEIGHTS := [0.34, 0.34, 0.22, 0.10]

## How many of the serves that are meant to be interesting are actually faults, and how
## many are good but close enough to stop the point.
const SERVE_IS_LOOSE := 0.42
const LOOSE_IS_OUT := 0.55

var court: TennisCourt
var rally: TennisRally

var _beat := Beat.SERVE
var _serve_number := 1
var _rally_seconds := 0.0

## Whose shot is in the air, and how many more exchanges before somebody goes for a line.
var _striker: Player
var _defender: Player
var _exchanges_left := 0

## Whether the shot now in the air is meant to end the point, and whether the defender
## is deliberately letting it bounce twice.
var _aimed_to_end := false
var _letting_it_go := false
var _not_up_visibility := 0.0

## Which service box this delivery is aimed at: the sign of its x.
var _service_court := 1.0

## Faults recorded on the match rather than on the rally, because they are things a
## person did rather than things the ball did.
var net_toucher := Sides.Team.NONE
var reached_over_by := Sides.Team.NONE
var _incident_visibility := 0.0

## Whether the point's one incident has already been put on screen.
var _incident_shown := false


func sport() -> StringName:
	return Career.TENNIS


## The height the aiming code has to clear.
##
## The real net sags from 1.07 m at the posts to 0.914 m in the middle, and the court
## draws it that way — but the shot solver wants one number, and taking the *post*
## height means every shot it approves clears the net at every point across it. Being
## conservative here costs nothing; being optimistic puts balls in the tape.
func net_height() -> float:
	return TennisSpec.NET_HEIGHT_POST


func floor_height() -> float:
	return TennisCourt.SURFACE_Y


## A tennis ball, not a volleyball. Five times lighter and a third of the size, and a
## shot aimed with the wrong drag model lands metres from where it was sent.
func flight() -> ShotSolver.Flight:
	return ShotSolver.tennis_flight()


func current_rally():
	return rally


func fault_book() -> Array:
	return TennisCallBook.faults()


func score_line() -> String:
	var tennis := board as TennisScore
	if tennis == null:
		return super.score_line()
	return "Final score  sets  RED %d — %d BLUE" % [
		tennis.sets[Sides.Team.RED], tennis.sets[Sides.Team.BLUE]]


# --- the venue ------------------------------------------------------------------

func build_the_venue() -> void:
	court = TennisCourt.new()
	court.name = "Court"
	add_child(court)

	_ball = TennisBall.new()
	_ball.name = "Ball"
	_ball.floor_height = TennisCourt.SURFACE_Y
	add_child(_ball)
	_ball.landed.connect(_on_ball_landed)
	_ball.freeze = true

	ball_cam = ShuttleCam.new()
	ball_cam.name = "BallCam"
	# Tighter than the volleyball view. A tennis ball is a third of the size and the
	# lines are half the width, so the same framing would show a speck on a stripe.
	ball_cam.view_metres = 1.15
	add_child(ball_cam)

	_build_players()
	_build_camera()
	_build_sky()


func dress_the_venue(venue: Dictionary) -> void:
	court.dress(venue["dressing"], venue["crowd"])


func make_the_board(venue: Dictionary) -> Scoreboard:
	return TennisScore.new(venue["quick"])


func cheer() -> void:
	court.cheer()


## Two of them, at diagonally opposite corners, behind the baselines and outside the
## tramlines. A real match has up to nine; two is what every sport in this game gets,
## and from opposite corners the pair see all four boundary lines between them.
func line_judge_spots() -> Array:
	return [
		{"at": Vector3(TennisSpec.HALF_WIDTH_DOUBLES + 1.9, 0.0,
			TennisSpec.HALF_LENGTH + 2.1)},
		{"at": Vector3(-(TennisSpec.HALF_WIDTH_DOUBLES + 1.9), 0.0,
			-(TennisSpec.HALF_LENGTH + 2.1))},
	]


func _build_camera() -> void:
	camera = UmpireCamera.new()
	camera.name = "RefereeCamera"
	# In the chair, at the net, to one side. Both service boxes are then in front of
	# the umpire and both baselines are down the diagonals — which is exactly why this
	# is where the chair goes in the real sport.
	camera.position = Vector3(
		TennisSpec.POST_X + TennisCourt.CHAIR_OFFSET, TennisCourt.EYE_HEIGHT, 0.0)
	camera.facing_deg = 90.0
	camera.start_pitch_deg = -14.0
	camera.fov = 80.0
	# Not looking at the chair the camera is sitting in.
	camera.cull_mask = camera.cull_mask & ~TennisCourt.CHAIR_LAYER
	camera.current = true
	add_child(camera)


func _build_sky() -> void:
	var sun := DirectionalLight3D.new()
	sun.name = "Sun"
	sun.rotation = Vector3(deg_to_rad(-58.0), deg_to_rad(-26.0), 0.0)
	sun.light_energy = 1.15
	sun.shadow_enabled = true
	add_child(sun)

	var world := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	var material := ProceduralSkyMaterial.new()
	material.sky_top_color = Color(0.24, 0.46, 0.78)
	material.sky_horizon_color = Color(0.74, 0.82, 0.90)
	material.ground_bottom_color = Color(0.24, 0.36, 0.24)
	material.ground_horizon_color = Color(0.46, 0.56, 0.42)
	sky.sky_material = material
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.7
	world.environment = env
	add_child(world)


## Where a singles player stands when the ball is not in their half: on the middle of
## the baseline, which is the one place from which both corners are the same distance.
func _home_of(team: Sides.Team) -> Vector3:
	return Vector3(0.0, 0.0, Sides.half_sign(team) * (TennisSpec.HALF_LENGTH + 0.7))


func _build_players() -> void:
	for team in [Sides.Team.RED, Sides.Team.BLUE]:
		var player := Player.new()
		player.name = Sides.label(team)
		# A racket sport, so they carry one — the flag that hides it is the volleyball
		# one, and a tennis player without a racket is a stranger who has walked on.
		player.volleyball = false
		player.speed = COURT_SPEED
		player.reach = RACKET_REACH
		add_child(player)
		player.setup(team, _home_of(team))
		players.append(player)


func _player(team: Sides.Team) -> Player:
	for player in players:
		if player.team == team:
			return player
	return null


# --- starting a point -----------------------------------------------------------

func enter_ready() -> void:
	if _serve_number == 2:
		ui.set_prompt("SPACE  second serve")
	else:
		ui.set_prompt("SPACE  whistle the serve")


## Which side of the centre mark the server stands, and which box they serve into.
##
## Deuce court on an even point, advantage court on an odd one, and always diagonally
## across. From the server's own point of view the deuce court is on their right, which
## is a different sign of x at each end of the court — so it is worked out from the half
## they are standing in rather than written down as a number.
func _service_court_for(server: Sides.Team) -> float:
	var played: int = board.points[Sides.Team.RED] + board.points[Sides.Team.BLUE]
	var deuce := (played % 2) == 0
	return Sides.half_sign(server) * (1.0 if deuce else -1.0)


func start_rally() -> void:
	if _phase != Phase.READY or _reviewing:
		return
	hush_the_line_judges()
	clear_the_mark()

	rally = TennisRally.new()
	rally.serve_number = _serve_number
	rally.struck_by = serving
	rally.receiving = Sides.opponent(serving)
	net_toucher = Sides.Team.NONE
	reached_over_by = Sides.Team.NONE
	_incident_visibility = 0.0
	_incident_shown = false
	_rally_seconds = 0.0
	_letting_it_go = false
	_not_up_visibility = 0.0
	_beat = Beat.SERVE
	_exchanges_left = randi_range(SHORTEST_RALLY, LONGEST_RALLY)

	_roll_for_one_fault()

	var server := _player(serving)
	var receiver := _player(Sides.opponent(serving))
	_striker = server
	_defender = receiver

	var side := Sides.half_sign(serving)
	var stand_x := _service_court_for(serving)
	_service_court = -stand_x

	# Behind the baseline, unless their foot is over it.
	var behind := -FOOT_FAULT_OVER if rally.foot_fault else SERVE_BEHIND
	var from := Vector3(
		stand_x * randf_range(0.35, 3.1),
		SERVE_HEIGHT,
		side * (TennisSpec.HALF_LENGTH + behind))
	server.position = Vector3(from.x, 0.0, from.z)
	receiver.chase(Vector3(
		_service_court * randf_range(1.2, 3.6),
		0.0,
		-side * (TennisSpec.HALF_LENGTH + 0.5)))

	var target := _serve_target()
	if rally.clipped_the_cord:
		target = _drag_it_over_the_cord(target)

	server.swing(true)
	sound.whistle()
	sound.strike(from, true)
	_aimed_to_end = false
	send_over(from, target, SERVE_ANGLES)
	_phase = Phase.IN_PLAY
	ui.set_prompt("watch it")


## Where the serve is aimed.
##
## Most serves are comfortably in and are simply played. The interesting ones are loose:
## a little long, a little wide, or a hand inside the line — and those are the ones the
## point stops for.
func _serve_target() -> Vector3:
	var into := Sides.half_sign(Sides.opponent(serving))
	var floor := TennisCourt.SURFACE_Y

	if randf() >= SERVE_IS_LOOSE:
		return Vector3(
			_service_court * randf_range(0.55, TennisSpec.HALF_WIDTH_SINGLES - 0.55),
			floor,
			into * randf_range(2.6, TennisSpec.SERVICE_LINE - 0.6))

	var over := randf_range(0.02, 0.42) if randf() < LOOSE_IS_OUT else -randf_range(0.02, 0.26)
	if randf() < 0.62:
		# Long, past the service line. The commonest fault there is.
		return Vector3(
			_service_court * randf_range(0.4, TennisSpec.HALF_WIDTH_SINGLES - 0.5),
			floor,
			into * (TennisSpec.SERVICE_LINE + over))
	# Wide, past the singles sideline.
	return Vector3(
		_service_court * (TennisSpec.HALF_WIDTH_SINGLES + over),
		floor,
		into * randf_range(3.0, TennisSpec.SERVICE_LINE - 0.35))


## What clipping the cord does to a serve.
##
## A graze barely changes anything and the ball lands where it was going; a heavier
## touch checks it and drops it short. So the same event produces both outcomes in the
## rules — a let if it still lands good, a plain fault if it does not — and how far the
## ball was moved is exactly how obvious the touch was.
func _drag_it_over_the_cord(target: Vector3) -> Vector3:
	court.shake(0.4 + rally.cord_visibility)
	var into := signf(target.z)
	var pulled := target
	pulled.z = into * maxf(0.9, absf(target.z) - rally.cord_visibility * 2.4)
	pulled.x += randf_range(-0.5, 0.5) * rally.cord_visibility
	return pulled


## At most one thing goes wrong per point, plus the cord, which is rolled on its own
## because a net cord is not a fault by anybody — it is a thing that happened.
func _roll_for_one_fault() -> void:
	if _beat == Beat.SERVE and randf() < CORD_CHANCE:
		rally.clipped_the_cord = true
		rally.cord_visibility = randf_range(0.05, 0.92)

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

	match kind:
		&"foot_fault":
			rally.foot_fault = true
			# Seen from the chair down the length of the baseline, which is the worst
			# angle in the sport for it. Some are plain and some are guesswork.
			rally.foot_fault_visibility = randf_range(0.12, 0.9)
		&"not_up":
			# Not recorded yet: it has to actually happen, which it does when a shot
			# lands in and the player it was hit past fails to reach it.
			_not_up_visibility = randf_range(0.1, 0.85)
		&"touched_net":
			net_toucher = Sides.Team.RED if randf() < 0.5 else Sides.Team.BLUE
			_incident_visibility = randf_range(0.2, 0.95)
		&"through_the_net":
			reached_over_by = Sides.Team.RED if randf() < 0.5 else Sides.Team.BLUE
			_incident_visibility = randf_range(0.3, 0.95)


# --- the point being played -----------------------------------------------------

func _physics_process(delta: float) -> void:
	if _phase != Phase.IN_PLAY:
		return
	_rally_seconds += delta
	if _rally_seconds > RALLY_LIMIT:
		_end_the_point(_ball.landing_point if _ball.has_landed else _ball.global_position)
		return

	# Still in the air on the current stroke. Every stroke is its own flight, which is
	# how a sport whose ball lands five times in one point can be built on a ball that
	# reports one landing.
	if not _ball.has_landed:
		return
	if _aimed_to_end:
		return

	if _ball.bounces >= 2:
		_the_second_bounce()
		return
	if _letting_it_go:
		return

	# Struck off the bounce, on the way down, at about waist height.
	var here := _ball.global_position
	if _ball.linear_velocity.y > 0.0 or here.y > STRIKE_CEILING:
		return
	_take_the_stroke(here)


## The next groundstroke. Whoever the ball is on the side of plays it.
func _take_the_stroke(here: Vector3) -> void:
	_beat = Beat.RALLY
	var hitter := Sides.half_containing(here.z)
	_striker = _player(hitter)
	_defender = _player(Sides.opponent(hitter))
	rally.struck_by = hitter
	rally.receiving = Sides.opponent(hitter)

	_exchanges_left -= 1
	var going_for_it := _exchanges_left <= 0
	var target := _line_ball(Sides.opponent(hitter)) if going_for_it \
		else _safe_ball(Sides.opponent(hitter))

	# Somebody who is about to touch the net, or play the ball before it has crossed,
	# does it here — on their way to a shot, at the net, where both happen.
	_stage_any_incident()

	_striker.swing(here.y > 1.6)
	sound.strike(here, going_for_it)

	# A ball hit at a line is a winner: the point ends where it lands, and the player it
	# was hit past does not get there. A rally ball is chased.
	_aimed_to_end = going_for_it
	_letting_it_go = going_for_it or _not_up_visibility > 0.0
	if _letting_it_go and not going_for_it:
		# The scripted not-up. They let it bounce, and the second bounce ends it.
		_defender.stand_off()
	elif going_for_it:
		_defender.stand_off()
	else:
		_defender.chase(target)

	send_over(Vector3(here.x, STRIKE_HEIGHT, here.z), target, RALLY_ANGLES)


## A ball hit safely inside, which the other player will reach and return.
func _safe_ball(against: Sides.Team) -> Vector3:
	var into := Sides.half_sign(against)
	return Vector3(
		randf_range(-TennisSpec.HALF_WIDTH_SINGLES + 0.7,
			TennisSpec.HALF_WIDTH_SINGLES - 0.7),
		TennisCourt.SURFACE_Y,
		into * randf_range(4.6, TennisSpec.HALF_LENGTH - 0.9))


## A ball hit at a line, which is where the point is decided and where the umpire earns
## whatever they are being paid.
func _line_ball(against: Sides.Team) -> Vector3:
	var into := Sides.half_sign(against)
	# Not every winner is a line ball. About a third are struck cleanly into the middle
	# of the court and simply not reached, which matters for the same reason a beach
	# attack is sometimes aimed safely inside: if every decisive shot lands on paint,
	# the close ones stop feeling close and the umpire starts calling by reflex.
	if randf() < 0.34:
		return _safe_ball(against)

	var nudge := randf_range(-0.26, 0.26)
	if randf() < 0.55:
		# Deep, at the baseline. The commonest close call in the sport, and the one the
		# umpire in the chair is worst placed to see.
		return Vector3(
			randf_range(-TennisSpec.HALF_WIDTH_SINGLES + 0.4,
				TennisSpec.HALF_WIDTH_SINGLES - 0.4),
			TennisCourt.SURFACE_Y,
			into * (TennisSpec.HALF_LENGTH + nudge))
	# Wide, at the singles sideline.
	return Vector3(
		(1.0 if randf() < 0.5 else -1.0) * (TennisSpec.HALF_WIDTH_SINGLES + nudge),
		TennisCourt.SURFACE_Y,
		into * randf_range(3.2, TennisSpec.HALF_LENGTH - 0.7))


## A net touch or a reach over the net, put on screen at the moment it happens.
##
## The truth is written onto the rally **here**, as the thing occurs, rather than at
## pricing time. That is not tidiness. A point that ends at the serve never gets as far
## as a groundstroke, so nothing was ever staged — and recording it afterwards anyway
## told the game that somebody had reached over the net during a delivery nobody had
## returned. An umpire who correctly called the serve a fault was then charged for
## missing an offence that had not happened.
func _stage_any_incident() -> void:
	# Once a point, whoever it is. It used to happen only when the culprit was the
	# player about to hit, which quietly meant that about half of every net touch and
	# every reach over the net was rolled and then never occurred — the defender is at
	# the net as often as the striker is. Without the guard it would now happen on every
	# stroke instead, which is the same mistake the other way round.
	if _incident_shown:
		return
	var culprit := Sides.Team.NONE
	if net_toucher != Sides.Team.NONE:
		culprit = net_toucher
	elif reached_over_by != Sides.Team.NONE:
		culprit = reached_over_by
	if culprit == Sides.Team.NONE:
		return
	var offender := _player(culprit)
	if offender == null:
		return
	_incident_shown = true
	if net_toucher == culprit:
		rally.net_toucher = culprit
	else:
		rally.reached_over_by = culprit
	rally.incident_visibility = maxf(rally.incident_visibility, _incident_visibility)
	# Over the tape if they reached over it, right up against it if they touched it.
	var beyond := -0.35 if reached_over_by == culprit else 0.45
	offender.lunge(Vector3(offender.position.x, 0.0,
		Sides.half_sign(culprit) * beyond), 0.8)
	court.shake(0.6)


func _on_ball_landed(point: Vector3) -> void:
	if _phase != Phase.IN_PLAY:
		return

	if _beat == Beat.SERVE:
		_the_serve_landed(point)
		return

	# A ball hit at a line ends the point wherever it came down. A rally ball that lands
	# out ends it too, even though nobody was aiming there — a shot the solver could not
	# get inside the court is still a shot that went out.
	if _aimed_to_end or not TennisSpec.is_in(point, rally.doubles):
		_aimed_to_end = true
		_end_the_point(point)


## Whether the umpire is asked about this serve, or whether it is simply played.
##
## The other three sports here stop for a call on every rally. Tennis does not, and it
## would be wrong to make it: a serve down the middle of the box is played and nobody
## says a word. The point stops when there is a question — a fault, a foot fault, a cord
## that may or may not have been clipped, or a ball close enough to the line that the
## receiver looks at the chair instead of playing it.
func _the_serve_landed(point: Vector3) -> void:
	var into := Sides.half_sign(Sides.opponent(serving))
	rally.record_serve_landing(point, Sides.opponent(serving), into, _service_court)

	var worth_asking := (
		not rally.serve_was_good
		or rally.clipped_the_cord
		or rally.foot_fault
		or absf(rally.margin) <= CLOSE_TO_A_LINE
	)
	if worth_asking:
		_end_the_point(point)
		return

	# Played. The point is no longer a serve — which has to be said out loud, because
	# every truth on the rally was recorded against the service box and none of it
	# applies to a groundstroke. Leaving it set froze the point at the serve: the ball
	# went on landing and the rally went on carrying the serve's landing, its margin and
	# its verdict, and an honest umpire was charged for a call about a ball that had
	# been struck four times since.
	rally.is_a_serve = false
	rally.is_settled = false
	_aimed_to_end = false
	_letting_it_go = false
	_beat = Beat.RALLY
	_defender.chase(Vector3(point.x, 0.0, point.z + into * 1.4))


## The ball bounced twice. Either the scripted not-up, or a winner nobody reached.
func _the_second_bounce() -> void:
	if _aimed_to_end:
		return
	if _not_up_visibility > 0.0:
		rally.not_up_by = rally.receiving
		rally.incident_visibility = _not_up_visibility
		_not_up_visibility = 0.0
	_aimed_to_end = true
	_end_the_point(_ball.landing_point)


## The point is over. Everything from here is the same in every sport on this spine.
func _end_the_point(point: Vector3) -> void:
	if _phase != Phase.IN_PLAY:
		return
	if not rally.is_settled:
		rally.record_landing(point, Sides.half_containing(point.z))
	for player in players:
		player.go_home()
	_phase = Phase.AWAITING_CALL
	_awaiting_since = Time.get_ticks_msec()
	line_judges_watch(rally.landing_point, rally.margin, rally.was_in)
	mark_the_landing(rally.landing_point)
	sound.landing(rally.landing_point)
	if has_close_cam:
		ball_cam.aim_at(rally.landing_point)
		ui.show_close_cam(ball_cam.texture())
	if rally.is_a_serve:
		ui.set_prompt(
			"LEFT CLICK  in    RIGHT CLICK  fault    L  let    F  foot fault / other")
	else:
		ui.set_prompt("LEFT CLICK  in    RIGHT CLICK  out    F  a fault")


# --- the call -------------------------------------------------------------------

func make_call(id: StringName, against := Sides.Team.NONE) -> void:
	if _phase != Phase.AWAITING_CALL:
		return
	var call := TennisCallBook.get_call(id)
	if call != null:
		await judge(call, against)


## The server changes at the end of every game, never in the middle of one — which is
## the opposite of every other sport in this project, where whoever wins the point
## serves next.
func award_the_point(winner: Sides.Team) -> void:
	var tennis := board as TennisScore
	var was_a_tiebreak := tennis != null and tennis.in_tiebreak
	board.award(winner)

	# A game has just ended if the point score has gone back to nothing, which after an
	# awarded point can only mean the game was won by it.
	if board.points[Sides.Team.RED] == 0 and board.points[Sides.Team.BLUE] == 0:
		serving = Sides.opponent(serving)
		return

	# A tiebreak is the exception to the exception. Inside one the serve changes after
	# the first point and then every two, so that neither player serves twice running
	# from the same end — which is the whole reason the sequence is odd rather than even.
	if was_a_tiebreak:
		var played: int = board.points[Sides.Team.RED] + board.points[Sides.Team.BLUE]
		if played % 2 == 1:
			serving = Sides.opponent(serving)


## What the call means for the next delivery.
##
## Read off the **call**, not off the truth. A serve the umpire called out is a fault
## whether or not it was one, and the server plays a second — which is the whole of what
## this game is about, and the reason it is worth building tennis at all.
func go_ready() -> void:
	if rally != null and rally.call != null:
		if rally.call_means_replay():
			pass
		elif rally.call_means_a_second_serve():
			_serve_number = 2
		else:
			_serve_number = 1
	super.go_ready()


func _unhandled_input(event: InputEvent) -> void:
	if _reviewing:
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
			elif event is InputEventKey and event.pressed and event.keycode == KEY_L:
				make_call(&"let", serving)
