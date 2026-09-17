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

## How far the rig's own serve contact may be from SERVE_HEIGHT and still be believed. A
## measurement that comes back near the floor means the clip was read at the wrong frame,
## and the nominal height is the safer answer.
const MOST_A_CONTACT_DIFFERS := 0.7
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
var _sun: DirectionalLight3D
var _sky_environment: Environment
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


## Tennis's director. See TennisCutscene.
func make_cutscene() -> Cutscene:
	return TennisCutscene.new()


## Every set's games, the winner's first (ITF G.4h): "6–4   3–6   7–5".
func result_words(winner: Sides.Team) -> String:
	var tennis := board as TennisScore
	if tennis == null:
		return ""
	var loser := Sides.opponent(winner)
	var sets: Array[String] = []
	for games in tennis.finished_sets:
		sets.append("%d\u2013%d" % [games[winner], games[loser]])
	return "   ".join(sets)


func score_line() -> String:
	var tennis := board as TennisScore
	if tennis == null:
		return super.score_line()
	return "Final score  sets  RED %d — %d BLUE" % [
		tennis.sets[Sides.Team.RED], tennis.sets[Sides.Team.BLUE]]


# --- changing ends --------------------------------------------------------------
#
# Tennis is the only sport in this project where which half a side occupies is not
# fixed. Players change ends after the first, third, fifth game of a set and after every
# six points of a tiebreak, and the reason is not decoration: one end has the sun or the
# wind behind it, and a match decided by which end somebody served the last game from
# would not be a fair match.
#
# It is done here rather than in `Sides`, which is deliberate. `Sides.half_sign` is a
# static fact for the other three sports — RED plays -Z, always — and making it mutable
# to satisfy tennis would put a moving part underneath badminton and both volleyballs
# for no reason. So tennis asks these two instead of asking Sides, and everything
# physical (the chair, the line judges' corners, the landing mark, the ball camera)
# still speaks in plain -Z and +Z, which is what those things are actually about.

## Which way round the two sides currently are.
var _ends_swapped := false

## How long the players take to walk to the other end.
const CHANGEOVER_SECONDS := 2.4


## Which end this side is at, as a sign along Z.
func end_of(team: Sides.Team) -> float:
	var side := Sides.half_sign(team)
	return -side if _ends_swapped else side


## Whose half a point on the floor is in, given who is standing where at the moment.
func side_defending(z: float) -> Sides.Team:
	var team := Sides.half_containing(z)
	return Sides.opponent(team) if _ends_swapped else team


## Walks them to the other end and turns them round.
func change_ends() -> void:
	_ends_swapped = not _ends_swapped
	for player in players:
		player.home = _home_of(player.team)
		player.go_home()
		# Facing across the net, which is now the other way.
		player.rotation.y = PI if end_of(player.team) > 0.0 else 0.0
	ui.announce("CHANGE OF ENDS", UiTheme.ACCENT, CHANGEOVER_SECONDS)
	ui.react("they swap ends and towel off at the net", CHANGEOVER_SECONDS)
	sound.whistle()
	_sit_down_when_they_get_there()


## They walk to the other end and sit. The `sit` clip has been on the character since it
## was forged and nothing had ever asked a player to use it — which was fine while no
## sport had a changeover, and stopped being fine the moment tennis got one.
func _sit_down_when_they_get_there() -> void:
	await get_tree().create_timer(CHANGEOVER_SECONDS * 0.8).timeout
	if _phase == Phase.REMOVED:
		return
	for player in players:
		player.sit_down()


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
	_ball.bounced.connect(_on_ball_bounced)
	_ball.freeze = true

	ball_cam = ShuttleCam.new()
	ball_cam.name = "BallCam"
	# Tighter than the volleyball view. A tennis ball is a third of the size and the
	# lines are half the width, so the same framing would show a speck on a stripe.
	ball_cam.view_metres = 1.15
	add_child(ball_cam)

	build_the_players()
	_build_camera()
	_build_sky()


func event_dressing() -> EventDressing:
	return court.event if court != null else null


func dress_the_venue(venue: Dictionary) -> void:
	court.dress(venue["dressing"], venue["crowd"])
	_light_for_the_venue()


## The club courts are outdoors under the sun; the top of the ladder is an indoor stadium.
## Same two lights either way — the sun becomes the roof lamps, steeper and whiter, and the
## sky goes dark behind the walls — so going indoors costs nothing to draw.
func _light_for_the_venue() -> void:
	if _sky_environment == null or court.event == null:
		return
	var indoors := court.event.indoors()
	if indoors:
		_sky_environment.background_mode = Environment.BG_COLOR
		_sky_environment.background_color = Color(0.03, 0.035, 0.05)
		_sky_environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		_sky_environment.ambient_light_color = Color(0.62, 0.66, 0.74)
		_sky_environment.ambient_light_energy = 0.8
		_sun.rotation = Vector3(deg_to_rad(-78.0), deg_to_rad(-20.0), 0.0)
		_sun.light_color = Color(0.98, 0.98, 1.0)
		_sun.light_energy = 1.3
	else:
		_sky_environment.background_mode = Environment.BG_SKY
		_sky_environment.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
		_sky_environment.ambient_light_energy = 0.7
		_sun.rotation = Vector3(deg_to_rad(-58.0), deg_to_rad(-26.0), 0.0)
		_sun.light_color = Color(1, 1, 1)
		_sun.light_energy = 1.15


func make_the_board(venue: Dictionary) -> Scoreboard:
	return TennisScore.new(venue["quick"])


func cheer() -> void:
	court.cheer()


func jeer(share: float) -> void:
	court.jeer(share)


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
	_sun = sun
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
	_sky_environment = env


## Where a singles player stands when the ball is not in their half: on the middle of
## the baseline, which is the one place from which both corners are the same distance.
func _home_of(team: Sides.Team, which := 0) -> Vector3:
	var side := end_of(team)
	if not playing_doubles():
		return Vector3(0.0, 0.0, side * (TennisSpec.HALF_LENGTH + 0.7))
	# One back behind the baseline and one up at the service line, on opposite sides of
	# the centre — which is where a doubles pair actually stands and why the net player
	# is the one every ball is hit away from.
	if which == 0:
		return Vector3(-1.9, 0.0, side * (TennisSpec.HALF_LENGTH + 0.7))
	return Vector3(2.1, 0.0, side * (TennisSpec.SERVICE_LINE - 1.4))


## One a side or two, as the format menu was answered.
##
## In doubles the two of them stand one back and one at the net, which is the whole
## shape of the game: the net player is there to intercept, and the reason a doubles
## point is shorter and sharper than a singles one.
func build_the_players() -> void:
	var each := 2 if playing_doubles() else 1
	for team in [Sides.Team.RED, Sides.Team.BLUE]:
		for i in each:
			_build_one(team, i)


func _build_one(team: Sides.Team, which: int) -> void:
		var player := Player.new()
		player.name = "%s%d" % [Sides.label(team), which]
		# A racket sport, so they carry one — the flag that hides it is the volleyball
		# one, and a tennis player without a racket is a stranger who has walked on.
		player.volleyball = false
		player.racket_kind = &"tennis"
		player.speed = COURT_SPEED
		player.reach = RACKET_REACH
		add_child(player)
		player.setup(team, _home_of(team, which))
		players.append(player)


## The one player of a side, or in doubles whichever of the pair is nearest the ball —
## which is who would actually play it. Returning the first of a side was fine while
## there was only ever one, and in doubles meant the same partner played every shot and
## the other stood watching for the whole match.
func _player(team: Sides.Team, near := Vector3.ZERO) -> Player:
	var nearest := nearest_of(team, near)
	if nearest != null:
		return nearest
	for player in players:
		if player.team == team:
			return player
	return null


## Which of a doubles pair is serving.
##
## The serving order alternates by game, so a partner serves every other one of their
## side's service games — and keeping track of whose turn it is is a real part of what a
## doubles umpire does, in both this sport and badminton.
func _server_for(team: Sides.Team) -> Player:
	var mine := team_of(team)
	if mine.size() < 2:
		return mine[0] if not mine.is_empty() else null
	var games: int = board.games[Sides.Team.RED] + board.games[Sides.Team.BLUE]
	return mine[int(games / 2.0) % 2]


# --- starting a point -----------------------------------------------------------

func enter_ready() -> void:
	if _serve_number == 2:
		ui.set_prompt("SPACE  second serve")
	else:
		ui.set_prompt("SPACE  call the score and serve")


## Which side of the centre mark the server stands, and which box they serve into.
##
## Deuce court on an even point, advantage court on an odd one, and always diagonally
## across. From the server's own point of view the deuce court is on their right, which
## is a different sign of x at each end of the court — so it is worked out from the half
## they are standing in rather than written down as a number.
func _service_court_for(server: Sides.Team) -> float:
	var played: int = board.points[Sides.Team.RED] + board.points[Sides.Team.BLUE]
	var deuce := (played % 2) == 0
	return end_of(server) * (1.0 if deuce else -1.0)


func start_rally() -> void:
	if _phase != Phase.READY or _reviewing:
		return
	hush_the_line_judges()
	clear_the_mark()

	rally = TennisRally.new()
	# The tramlines are live in doubles — for every ball except the serve, which is
	# judged by the singles sideline whatever the format. TennisSpec.is_a_good_serve
	# has always known that; this is the other half of it.
	rally.doubles = playing_doubles()
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

	var server := _server_for(serving)
	var receiver := _player(Sides.opponent(serving),
		Vector3(0.0, 0.0, -Sides.half_sign(serving) * TennisSpec.HALF_LENGTH))
	_striker = server
	_defender = receiver

	var side := end_of(serving)
	var stand_x := _service_court_for(serving)
	_service_court = -stand_x

	# Behind the baseline, unless their foot is over it.
	var behind := -FOOT_FAULT_OVER if rally.foot_fault else SERVE_BEHIND
	var from := Vector3(
		stand_x * randf_range(0.35, 3.1),
		SERVE_HEIGHT,
		side * (TennisSpec.HALF_LENGTH + behind))
	server.place_to_serve(Vector3(from.x, 0.0, from.z))
	# Tossed to where the racket will be at full stretch, rather than to a point straight
	# above the server's head. The feet stay where they were put, which is what the foot
	# fault is judged on; the contact leans out in front of them, which is what a serve does.
	var racket := server.contact_point("tn_serve", server.rotation.y)
	if absf(racket.y - SERVE_HEIGHT) < MOST_A_CONTACT_DIFFERS:
		from = racket
	receiver.chase(Vector3(
		_service_court * randf_range(1.2, 3.6),
		0.0,
		-side * (TennisSpec.HALF_LENGTH + 0.5)))

	var target := _serve_target()
	_cord_to_hear = -1.0
	if rally.clipped_the_cord:
		target = _drag_it_over_the_cord(target)
		_cord_to_hear = rally.cord_visibility
		_server_end = signf(from.z)

	server.serve_for_tennis()
	sound.whistle()
	_aimed_to_end = false
	_phase = Phase.IN_PLAY
	ui.set_prompt("watch it")
	_toss_it_up(from, target)


## The ball leaves the other hand before it is hit.
##
## It used to appear at 2.55 m already travelling, which is the one part of a tennis
## serve nobody would fail to notice missing: the toss is the slowest, highest and most
## deliberate thing that happens in the sport, and it is thrown by the hand that is not
## holding the racket. It is also what a foot fault is judged against — the server may
## move their feet right up until the ball is struck, not until it is thrown.
##
## The gap is the clip's own: `tn_serve` tosses on frame 8 and makes contact on frame 22,
## which at 24 fps is fourteen frames. The ball and the animation therefore agree by
## construction rather than by being tuned against each other.
##
## Both frames matter, and for a while only one of them was used. The ball was thrown on the
## frame the clip *started* and struck fourteen frames later — so it was met on frame 14 with
## the racket still coming up, a third of a second before the racket got there. The toss now
## waits for frame 8 as well, which is when the hand that is not holding the racket actually
## lets go.
const TOSS_AT := 8.0 / 24.0

## True from the whistle until the ball actually leaves the server's hand.
##
## The rally is in play from the whistle, as it is in the rules, but for those eight frames
## the only ball on court is the **last** rally's, lying where it came down — and the rally
## logic looked at it, decided it was a ball on somebody's side falling below the strike
## ceiling, and played a stroke with it. The server was sent running backwards away from the
## serve they were about to play, and `_contact` found them three metres from it.
var _waiting_for_the_toss := false
const TOSS_SECONDS := 14.0 / 24.0

## Thrown from about shoulder height, hard enough to arrive at the contact point just as
## the racket does. Higher would be a better serve and a worse animation: the ball would
## still be climbing when the arm came through.
const TOSS_FROM_BELOW := 0.9
const TOSS_SPEED := 4.4


func _toss_it_up(from: Vector3, target: Vector3) -> void:
	_waiting_for_the_toss = true
	await get_tree().create_timer(TOSS_AT).timeout
	_waiting_for_the_toss = false
	if _phase != Phase.IN_PLAY:
		return
	_ball.launch(from - Vector3(0.0, TOSS_FROM_BELOW, 0.0),
		Vector3(0.0, TOSS_SPEED, 0.0))
	await get_tree().create_timer(TOSS_SECONDS).timeout
	# The rally can have been abandoned, paused or walked out of while the ball was up.
	if _phase != Phase.IN_PLAY:
		return
	sound.strike(from, true)
	# Off the strings. The toss was aimed at them and the clip is on its contact frame now,
	# so this closes whatever the two have drifted apart by.
	send_over(_striker.struck_from(from) if _striker != null else from,
		target, SERVE_ANGLES)


## Where the serve is aimed.
##
## Most serves are comfortably in and are simply played. The interesting ones are loose:
## a little long, a little wide, or a hand inside the line — and those are the ones the
## point stops for.
func _serve_target() -> Vector3:
	var into := end_of(Sides.opponent(serving))
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

## A serve that clipped the cord is heard doing it, as it goes over. How plainly, from
## nought to one, or below nought when there is nothing to hear; and which end it was
## served from, so the moment it crosses is the moment it changes ends.
var _cord_to_hear := -1.0
var _server_end := 0.0


func _physics_process(delta: float) -> void:
	if _phase != Phase.IN_PLAY:
		return
	if _waiting_for_the_toss:
		return
	_rally_seconds += delta
	if _cord_to_hear >= 0.0 and signf(_ball.global_position.z) != _server_end:
		sound.net_cord(Vector3(_ball.global_position.x, net_height(), 0.0), _cord_to_hear)
		_cord_to_hear = -1.0
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
		_see_the_stroke_coming()
		return
	_take_the_stroke(here)


## Starts the stroke before the ball gets to it.
##
## A tennis stroke is keyed with contact six frames into sixteen — a quarter of a second —
## and it used to be started on the frame the ball was struck, so the ball left while the
## racket was still going back. The ball's drop is flown forward with the same drag it is
## flying with, and the swing begins a quarter of a second before it will be playable.
func _see_the_stroke_coming() -> void:
	var player := _player(side_defending(_ball.global_position.z), _ball.global_position)
	if player == null:
		return
	var due := seconds_until_it_drops_under(STRIKE_CEILING, CHASE_LEAD)
	if float(due[0]) < 0.0:
		return
	var meeting: Vector3 = due[1]
	# Run them at where the ball will actually be played rather than where it landed. A
	# tennis ball goes on travelling after the bounce — several metres of it — and the
	# player was sent to the bounce, so every stroke in this sport was played by somebody
	# standing where the ball had been a second ago.
	player.chase(meeting)
	if float(due[0]) > Player.CONTACT_AT["forehand"]:
		return
	player.begin_stroke(maxf(float(due[0]), 0.01), meeting, meeting.y > OVERHEAD_HEIGHT)


## How far ahead the ball's drop is flown, in seconds. Long enough to give the player time
## to get to it, which is the whole point of looking.
const CHASE_LEAD := 1.4


## The height above which a stroke is played as a smash rather than off the ground. Only
## reachable on a ball that has barely bounced, which is exactly when a player would.
const OVERHEAD_HEIGHT := 1.6


## The next groundstroke. Whoever the ball is on the side of plays it.
func _take_the_stroke(here: Vector3) -> void:
	_beat = Beat.RALLY
	var hitter := side_defending(here.z)
	_striker = _player(hitter, here)
	rally.struck_by = hitter
	rally.receiving = Sides.opponent(hitter)

	_exchanges_left -= 1
	var going_for_it := _exchanges_left <= 0
	var target := _line_ball(Sides.opponent(hitter)) if going_for_it \
		else _safe_ball(Sides.opponent(hitter))

	# Whichever of the defending pair is nearest where it is going, which is who would
	# actually go for it — and in singles is the only one there.
	_defender = _player(Sides.opponent(hitter), target)

	# Somebody who is about to touch the net, or play the ball before it has crossed,
	# does it here — on their way to a shot, at the net, where both happen.
	_stage_any_incident()

	_striker.swing(here.y > OVERHEAD_HEIGHT)
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

	# Off the strings rather than out of the air beside them: the head of the racket is
	# where the swing has put it, and the ball is brought the last few centimetres onto it.
	send_over(_striker.struck_from(Vector3(here.x, STRIKE_HEIGHT, here.z)), target, RALLY_ANGLES)

	# And now that it is in the air, send whoever has to play it to the spot they will
	# actually play it from — past the bounce, which in tennis is metres past the landing.
	# `chase(target)` above puts them where it comes down; this moves them on to where it
	# will be when it is next low enough to hit.
	if not _letting_it_go and _defender != null:
		var next := seconds_until_it_drops_under(STRIKE_CEILING, WHOLE_FLIGHT, true)
		if float(next[0]) > 0.0:
			var spot: Vector3 = next[1]
			if _defender.distance_to(spot) > _defender.speed * float(next[0]) * WORTH_CHASING:
				# They cannot get there, so they do not: the ball was too good and the
				# point ends on the second bounce. This used to play the stroke anyway,
				# from wherever the player happened to be standing — a third of tennis's
				# contacts were made by somebody metres from the ball, which is what a
				# ball being hit by nothing looks like from the chair.
				_aimed_to_end = true
				_letting_it_go = true
				_defender.stand_off()
			else:
				_defender.chase(spot)


## How far ahead a whole shot is flown, in seconds: long enough to cover a lob, its bounce
## and the drop after it.
const WHOLE_FLIGHT := 4.0

## How much of the distance to the ball a player has to be able to cover in the time before
## it is playable for the ball to be worth chasing. Short of all of it, because arriving at
## a full sprint on the exact frame is not a shot anybody plays either.
const WORTH_CHASING := 0.92


## A ball hit safely inside, which the other player will reach and return.
func _safe_ball(against: Sides.Team) -> Vector3:
	var into := end_of(against)
	var wide: float = TennisSpec.HALF_WIDTH_DOUBLES if playing_doubles() \
		else TennisSpec.HALF_WIDTH_SINGLES
	return Vector3(
		randf_range(-wide + 0.7, wide - 0.7),
		TennisCourt.SURFACE_Y,
		into * randf_range(4.6, TennisSpec.HALF_LENGTH - 0.9))


## Which sideline is the boundary today: the tramline in doubles, the singles line in
## singles. The gap between them is 1.37 m, which is the widest "in or out" in this game.
func _sideline() -> float:
	return TennisSpec.HALF_WIDTH_DOUBLES if playing_doubles() \
		else TennisSpec.HALF_WIDTH_SINGLES


## A ball hit at a line, which is where the point is decided and where the umpire earns
## whatever they are being paid.
func _line_ball(against: Sides.Team) -> Vector3:
	var into := end_of(against)
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
			randf_range(-_sideline() + 0.4, _sideline() - 0.4),
			TennisCourt.SURFACE_Y,
			into * (TennisSpec.HALF_LENGTH + nudge))
	# Wide, at whichever sideline is live.
	return Vector3(
		(1.0 if randf() < 0.5 else -1.0) * (_sideline() + nudge),
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
		end_of(culprit) * beyond), 0.8)
	court.shake(0.6)


## Every bounce is heard, not only the one the point is decided on. See Sound.bounce.
func _on_ball_bounced(point: Vector3, speed: float, _first: bool) -> void:
	if sound != null:
		sound.bounce(point, speed)


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
	var into := end_of(Sides.opponent(serving))
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
		rally.record_landing(point, side_defending(point.z))
	for player in players:
		player.go_home()
	_phase = Phase.AWAITING_CALL
	_awaiting_since = Time.get_ticks_msec()
	line_judges_watch(rally.landing_point, rally.margin, rally.was_in)
	mark_the_landing(rally.landing_point)
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
	# Counted before the award, because a set that ends puts the games back to nothing
	# and the changeover rule is about how many were played in the set that just ended.
	var games_before: int = board.games[Sides.Team.RED] + board.games[Sides.Team.BLUE]
	board.award(winner)

	# A game has just ended if the point score has gone back to nothing, which after an
	# awarded point can only mean the game was won by it.
	if board.points[Sides.Team.RED] == 0 and board.points[Sides.Team.BLUE] == 0:
		serving = Sides.opponent(serving)
		# Ends change after the first, third, fifth game — every odd one.
		if (games_before + 1) % 2 == 1:
			change_ends()
		return

	# A tiebreak is the exception to the exception. Inside one the serve changes after
	# the first point and then every two, so that neither player serves twice running
	# from the same end — which is the whole reason the sequence is odd rather than even
	# — and the ends themselves change every six points.
	if was_a_tiebreak:
		var played: int = board.points[Sides.Team.RED] + board.points[Sides.Team.BLUE]
		if played % 2 == 1:
			serving = Sides.opponent(serving)
		if played % 6 == 0:
			change_ends()


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
			elif event is InputEventKey and event.pressed and event.keycode == KEY_L:
				make_call(&"let", serving)


## Where this sport seats its hall, so somebody in it can be given a line to say.
func the_stands() -> Stands:
	return court.stands
