class_name TableTennisMatch
extends OfficiatedMatch

## A table tennis match, umpired from a chair beside the net at the height of the table.
##
## Four things here exist in no other sport in this game.
##
## The umpire is **alone**. There are no line judges at all — at this size nobody else is
## close enough to be worth asking — so every truth in the match passes through one
## person, and there is nothing to hide behind and nothing to overrule.
##
## The serve **lands twice**. It must bounce once on the server's own half and once on
## the receiver's, which means the umpire is watching two landings before the point has
## properly begun, and only the second of them is a call.
##
## There is **no second serve**. A serve that misses is the point. Every service call
## here is worth as much as any other call in the sport, where in tennis the same words
## cost a serve or cost a point depending on when they were said.
##
## And the sport's own call is the **edge**. A ball that clips the top of the table is
## in; one that clips the vertical side a centimetre lower is out. They are two
## centimetres apart, they sound almost the same, and the only person in the building
## with a view of the difference is sitting level with the surface with a pen in their
## hand.

enum Beat { SERVE_DOWN, SERVE_OVER, RALLY }

## Where the server stands and how high the ball is struck on the serve.
##
## The ball must be thrown up at least 16 cm from an open flat palm and struck on the way
## down, behind the end line, in full view of the receiver. It is the strictest service
## law in any of these five sports, and every clause of it is something only the umpire
## can check.
const SERVE_BEHIND := 0.40
const SERVE_HEIGHT := TableTennisSpec.HEIGHT + 0.22
const LEGAL_TOSS := 0.16

## A serve is struck almost flat and slightly down; the flatter alternatives are there
## for a short serve, which cannot go down and still reach the far half.
const SERVE_ANGLES := [8.0, 14.0, 22.0, 32.0]

## A rally stroke: taken off the bounce, a hand above the table.
const STRIKE_HEIGHT := TableTennisSpec.HEIGHT + 0.15
const STRIKE_CEILING := TableTennisSpec.HEIGHT + 0.55
const RALLY_ANGLES := [10.0, 16.0, 24.0, 34.0, 46.0]

## How much daylight a shot needs over a net 15 cm high.
##
## The spine's 14 cm is most of a table tennis net, and asking every ball to pass at
## twice the height of the tape put all of them off the far end. Three centimetres is
## what a loop actually clears by.
const TABLE_CLEARANCE := 0.032

## How fast a player moves at the table, and how far a bat reaches.
##
## Both small, and deliberately. A table tennis player covers very little ground — the
## table is 1.5 m wide — and the game is decided by what they get to in a tenth of a
## second rather than by how far they run.
## How long they take to walk round the table, and how far out they go to do it.
const CHANGEOVER_SECONDS := 3.0
const ROOM_BESIDE_THE_TABLE := 0.45

const TABLE_SPEED := 3.4
const BAT_REACH := 1.05

## How near an edge a ball has to land before the point stops for a call.
##
## A twentieth of what tennis uses, because everything here is a twentieth of the size.
## A ball 6 cm inside the line on a table 1.5 m wide is about the same question as a ball
## 30 cm inside the line on a court 11 m wide.
##
## It started at 9 cm and, measured, stopped **60% of all points at the serve** — the
## sport came out a serving contest with a rally attached. Table tennis is a rally sport
## and the point of it is the exchange; a serve everybody plays is the normal case and
## has to look like it.
const CLOSE_TO_AN_EDGE := 0.06

## How many strokes a rally runs for before somebody goes for a corner.
const SHORTEST_RALLY := 2
const LONGEST_RALLY := 8

## How long a point may run before it is abandoned.
const RALLY_LIMIT := 22.0

## How often a serve clips the net and is played again.
##
## Higher than tennis's cord, because the net is 15 cm high and every serve is meant to
## pass just over it. A let costs nobody anything, which makes it the cheapest lie in the
## sport and the reason it is priced by how plainly the net moved.
const NET_CHANCE := 0.11

## How often anything else goes wrong, and which of the three it is when it does.
##
## One fault per point, never two, for the reason every sport on this spine has that
## rule: two faults have an order, nothing records one, and the game and the umpire then
## disagree about which decided the point.
const FAULT_CHANCE := 0.14
const FAULT_KINDS := [&"illegal_service", &"double_bounce", &"touched_the_table",
	&"volley"]
const FAULT_WEIGHTS := [0.38, 0.26, 0.20, 0.16]

## Which parts of the service law get broken, and how plainly.
const SERVICE_FAULTS := [&"low toss", &"hidden serve", &"off the palm"]

## How many serves are loose enough to be worth stopping for, and how many of those miss.
##
## A third rather than the two fifths it started at, for the same reason the question
## band narrowed: most serves in this sport are simply played.
const SERVE_IS_LOOSE := 0.32
const LOOSE_IS_OUT := 0.52

## How often a decisive shot is aimed at the edge rather than merely past somebody.
##
## Every sport in this game over-represents the close call on purpose — an official with
## nothing to decide is not playing anything — but this one has a limit the others do
## not. An edge ball is a piece of luck that the whole hall reacts to and that the player
## who hit it apologises for. Measured at two fifths it made **43% of all points** an
## edge ball, which is not a rare event happening often, it is the normal way to win a
## point. A fifth leaves it frequent enough to be the job and rare enough to still be
## worth looking up for.
const GOES_FOR_THE_EDGE := 0.20

## Which way round the two sides currently are.
##
## The same pair tennis has, and it is here for the same reason: players change ends
## between games, and a match where one of them had the hall lights behind them for the
## whole of it would not be a fair match. `Sides.half_sign` stays a static fact for the
## other sports — RED plays -Z, always — so table tennis asks these two instead of
## asking Sides, and everything physical (the chair, the landing mark, the ball camera)
## still speaks in plain -Z and +Z, which is what those things are actually about.
var _ends_swapped := false

var table: TableTennisTable
var rally: TableTennisRally

var _beat := Beat.SERVE_DOWN
var _rally_seconds := 0.0

var _striker: Player
var _defender: Player
var _exchanges_left := 0

## Where the serve is going after it has bounced on the server's own half.
var _serve_lands_at := Vector3.ZERO

var _aimed_to_end := false
var _letting_it_go := false
var _double_bounce_visibility := 0.0

## Faults recorded on the match rather than on the rally, because they are things a
## person did rather than things the ball did.
var table_toucher := Sides.Team.NONE
var volleyed_by := Sides.Team.NONE
var _incident_visibility := 0.0
var _incident_shown := false


func sport() -> StringName:
	return Career.TABLE_TENNIS


## Which end this side is at, as a sign along Z.
func end_of(team: Sides.Team) -> float:
	var side := Sides.half_sign(team)
	return -side if _ends_swapped else side


## Whose half a point on the table is in, given who is standing where at the moment.
func side_defending(z: float) -> Sides.Team:
	var team := Sides.half_containing(z)
	return Sides.opponent(team) if _ends_swapped else team


## How much room a person needs behind their end line.
##
## Enough that a body half a metre across is clear of the edge rather than touching it.
const ROOM_BEHIND_THE_END := 0.34


## Keeps somebody behind their own end line, whatever they were sent to chase.
##
## **Table tennis is the first sport in this game with furniture in the playing area.**
## Players are Node3Ds walked towards a destination — there is no collision on a player
## anywhere in this project, and there has never needed to be, because the other four
## sports are played on the floor the players are standing on. Here a chase point 55 cm
## behind a ball that dropped short landed inside the table's footprint, and the player
## walked through a table 76 cm high to get to it.
##
## Every point a player is sent to goes through this. Clamping the destination rather
## than adding a physics body to Player is the smaller change and the truer one: the
## table is not something a player is meant to bump into and recover from, it is
## somewhere they never go.
func _off_the_table(point: Vector3, whose_end: Sides.Team) -> Vector3:
	var side := end_of(whose_end)
	var line := TableTennisSpec.HALF_LENGTH + ROOM_BEHIND_THE_END
	var clear := point
	clear.z = maxf(point.z, line) if side > 0.0 else minf(point.z, -line)
	return clear


## Above the table, which is what the shot solver measures against — not above the
## floor. 15 cm, and the smallest net in the game by a factor of six.
func net_height() -> float:
	return TableTennisSpec.NET_HEIGHT


func net_clearance() -> float:
	return TABLE_CLEARANCE


func floor_height() -> float:
	return TableTennisSpec.HEIGHT


## The lightest projectile in this game by a factor of two, and the only one whose drag
## genuinely decides where it lands.
func flight() -> ShotSolver.Flight:
	return ShotSolver.table_tennis_flight()


func current_rally():
	return rally


## Inside the barriers. The drape half a metre behind them is black on purpose, so a ball
## can be followed against it, and a replay camera standing behind it sees nothing else.
func replay_room() -> Vector2:
	return Vector2(TableTennisTable.BARRIER_X - 0.2, TableTennisTable.BARRIER_Z - 0.2)


func fault_book() -> Array:
	return TableTennisCallBook.faults()


func score_line() -> String:
	var tt := board as TableTennisScore
	if tt == null:
		return super.score_line()
	return "Final score  games  RED %d — %d BLUE" % [
		tt.games[Sides.Team.RED], tt.games[Sides.Team.BLUE]]


# --- the venue ------------------------------------------------------------------

func build_the_venue() -> void:
	table = TableTennisTable.new()
	table.name = "Table"
	add_child(table)

	_ball = TableTennisBall.new()
	_ball.name = "Ball"
	_ball.floor_height = TableTennisSpec.HEIGHT
	add_child(_ball)
	_ball.landed.connect(_on_ball_landed)
	_ball.bounced.connect(_on_ball_bounced)
	_ball.freeze = true

	ball_cam = ShuttleCam.new()
	ball_cam.name = "BallCam"
	# The tightest view in the game. A 40 mm ball against a 20 mm line needs it — the
	# tennis framing of 1.15 m would show the whole end of the table and settle nothing.
	ball_cam.view_metres = 0.38
	add_child(ball_cam)

	build_the_players()
	_build_camera()
	_build_hall()


## Table tennis's director. See TableTennisCutscene.
func make_cutscene() -> Cutscene:
	return TableTennisCutscene.new()


## "RED wins 3 games to 1", the way the umpire says it (ITTF HMO, post-match announcement).
func result_words(winner: Sides.Team) -> String:
	if board == null:
		return ""
	return "%s wins %d games to %d" % [
		Sides.label(winner), board.games[winner], board.games[Sides.opponent(winner)]]


func event_dressing() -> EventDressing:
	return table.event if table != null else null


func dress_the_venue(venue: Dictionary) -> void:
	table.dress(venue["dressing"], venue["crowd"])


func make_the_board(venue: Dictionary) -> Scoreboard:
	return TableTennisScore.new(venue["quick"])


func cheer() -> void:
	table.cheer()


func jeer(share: float) -> void:
	table.jeer(share)


## None. Table tennis is the only sport in this game with no line judges at all.
##
## It is not an omission. At a table 2.74 m long there is nowhere for a second official
## to stand that the umpire cannot already see, so the sport never invented them — and
## the consequence for this game is the interesting part. In every other sport a lie can
## be dressed up as agreeing with somebody. Here there is nobody to agree with.
func line_judge_spots() -> Array:
	return []


func _build_camera() -> void:
	camera = UmpireCamera.new()
	camera.name = "RefereeCamera"
	camera.position = Vector3(
		TableTennisSpec.HALF_WIDTH + TableTennisTable.CHAIR_OFFSET,
		TableTennisTable.EYE_HEIGHT, 0.0)
	camera.facing_deg = 90.0
	# Barely tilted. Every other official in this game looks down at the play; this one
	# looks along the surface, which is the only angle the edge ball can be seen from.
	camera.start_pitch_deg = -6.0
	camera.fov = 74.0
	camera.cull_mask = camera.cull_mask & ~TableTennisTable.CHAIR_LAYER
	camera.current = true
	add_child(camera)


## Indoors, under hall lights. There is no sky here: table tennis is played in a room,
## and the lighting is written into the rules — 600 lux, evenly, no window behind the
## table — because a ball this small is unplayable in a shadow.
func _build_hall() -> void:
	var key := DirectionalLight3D.new()
	key.name = "HallLight"
	key.rotation = Vector3(deg_to_rad(-72.0), deg_to_rad(-18.0), 0.0)
	key.light_energy = 1.05
	key.shadow_enabled = true
	add_child(key)

	var world := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.05, 0.05, 0.07)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.62, 0.64, 0.70)
	env.ambient_light_energy = 0.85
	world.environment = env
	add_child(world)


## Where a player stands between shots: on the middle of the end line, a little back.
func _home_of(team: Sides.Team) -> Vector3:
	return Vector3(0.0, 0.0,
		end_of(team) * (TableTennisSpec.HALF_LENGTH + 0.85))


## One a side. Table tennis doubles exists and is a genuinely different job to referee —
## the pair must strike strictly alternately — but it is not in this game yet, so the
## format menu is not offered for this sport and neither is a partner.
func build_the_players() -> void:
	for team in [Sides.Team.RED, Sides.Team.BLUE]:
		var player := Player.new()
		player.name = Sides.label(team)
		player.volleyball = false
		player.racket_kind = &"bat"
		player.speed = TABLE_SPEED
		player.reach = BAT_REACH
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
	var tt := board as TableTennisScore
	if tt != null and tt.is_tense():
		ui.set_prompt("SPACE  serve   —   %s" % tt.called_score(serving))
	else:
		ui.set_prompt("SPACE  call the score and serve")


func start_rally() -> void:
	if _phase != Phase.READY or _reviewing:
		return
	hush_the_line_judges()
	clear_the_mark()

	rally = TableTennisRally.new()
	rally.is_a_serve = true
	rally.served_by = serving
	rally.struck_by = serving
	rally.receiving = Sides.opponent(serving)
	table_toucher = Sides.Team.NONE
	volleyed_by = Sides.Team.NONE
	_incident_visibility = 0.0
	_incident_shown = false
	_double_bounce_visibility = 0.0
	_rally_seconds = 0.0
	_letting_it_go = false
	_aimed_to_end = false
	_beat = Beat.SERVE_DOWN
	_exchanges_left = randi_range(SHORTEST_RALLY, LONGEST_RALLY)

	_roll_for_one_fault()

	var server := _player(serving)
	var receiver := _player(Sides.opponent(serving))
	_striker = server
	_defender = receiver

	var side := end_of(serving)
	var from := Vector3(
		randf_range(-TableTennisSpec.HALF_WIDTH + 0.1,
			TableTennisSpec.HALF_WIDTH - 0.1),
		SERVE_HEIGHT,
		side * (TableTennisSpec.HALF_LENGTH + SERVE_BEHIND))
	server.position = _off_the_table(Vector3(from.x, 0.0, from.z), serving)
	receiver.go_home()

	# The first bounce, on the server's own half. Near the middle of it: a serve that
	# bounces too close to the net has nowhere to go and one that bounces too near the
	# end line is a long serve, which is a different shot rather than a fault.
	var first := Vector3(
		from.x * randf_range(0.3, 0.8),
		TableTennisSpec.HEIGHT,
		side * randf_range(0.35, 1.15))
	_serve_lands_at = _serve_target()

	server.serve_for_tennis()
	sound.whistle()
	_phase = Phase.IN_PLAY
	ui.set_prompt("watch it")
	_throw_it_up(from, first)


## The ball goes up off an open palm before it is struck.
##
## The toss is not decoration here, it is a **law**: at least 16 cm, near vertical, from
## a flat open hand, and visible to the receiver the whole way. Three of the four things
## an illegal service can be are things about this throw, so it has to happen on screen
## or the umpire is being asked to rule on something the game never showed them.
const THROW_SECONDS := 0.42
const THROW_SPEED := 2.6


func _throw_it_up(from: Vector3, first: Vector3) -> void:
	# A short toss is one of the ways a service is illegal, and it is meant to look
	# like one: the ball barely leaves the hand.
	var thrown := THROW_SPEED
	if rally.illegal_service and rally.service_fault == &"low toss":
		thrown = THROW_SPEED * 0.42
	_ball.launch(from - Vector3(0.0, 0.30, 0.0), Vector3(0.0, thrown, 0.0))

	await get_tree().create_timer(THROW_SECONDS).timeout
	if _phase != Phase.IN_PLAY:
		return
	sound.strike(from, false)
	# Down onto the server's own half first. It does not cross the net, so it is sent
	# rather than sent over — nothing to clear.
	send(from, first, 16.0)


## Where the serve is meant to finish, on the far half.
##
## Most serves land comfortably and are simply played. The interesting ones are long,
## wide, or on the edge — and it is those the point stops for.
func _serve_target() -> Vector3:
	var into := -end_of(serving)
	var top := TableTennisSpec.HEIGHT

	if randf() >= SERVE_IS_LOOSE:
		# Comfortably inside, and comfortably means comfortably: aimed to within 25 cm
		# of an edge it still landed inside the question band often enough to stop the
		# point, because a ball this light does not go exactly where it was sent.
		return Vector3(
			randf_range(-TableTennisSpec.HALF_WIDTH + 0.26,
				TableTennisSpec.HALF_WIDTH - 0.26),
			top,
			into * randf_range(0.40, TableTennisSpec.HALF_LENGTH - 0.34))

	var over := randf_range(0.004, 0.09) if randf() < LOOSE_IS_OUT \
		else -randf_range(0.004, 0.05)
	if randf() < 0.58:
		# Long, past the end line — the commonest way a serve misses.
		return Vector3(
			randf_range(-TableTennisSpec.HALF_WIDTH + 0.12,
				TableTennisSpec.HALF_WIDTH - 0.12),
			top,
			into * (TableTennisSpec.HALF_LENGTH + over))
	# Wide, past the side.
	return Vector3(
		(1.0 if randf() < 0.5 else -1.0) * (TableTennisSpec.HALF_WIDTH + over),
		top,
		into * randf_range(0.4, TableTennisSpec.HALF_LENGTH - 0.2))


## What clipping the net does to a serve.
##
## A graze lets it through and it lands where it was going, which is a let; a heavier
## touch checks it and drops it short of the far half, which is simply the point. Same
## event, two outcomes, exactly as the tennis cord works — and how far the ball moved is
## how plainly it was touched.
func _drag_it_over_the_net(target: Vector3) -> Vector3:
	table.shake_the_net(0.4 + rally.net_visibility)
	var into := signf(target.z)
	var pulled := target
	pulled.z = into * maxf(0.05, absf(target.z) - rally.net_visibility * 1.5)
	pulled.x += randf_range(-0.12, 0.12) * rally.net_visibility
	return pulled


func _roll_for_one_fault() -> void:
	if randf() < NET_CHANCE:
		rally.clipped_the_net = true
		rally.net_visibility = randf_range(0.05, 0.9)

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
		&"illegal_service":
			rally.illegal_service = true
			rally.service_fault = SERVICE_FAULTS[randi() % SERVICE_FAULTS.size()]
			# A hidden serve is the hardest of the three to be sure of, because the
			# thing hiding the ball is the server's own body and the umpire is looking
			# at it side on.
			rally.service_visibility = randf_range(0.10, 0.60) \
				if rally.service_fault == &"hidden serve" else randf_range(0.25, 0.92)
		&"double_bounce":
			# Not recorded yet: it has to actually happen, which it does when a ball
			# lands good and the player it was hit past fails to reach it.
			_double_bounce_visibility = randf_range(0.15, 0.9)
		&"touched_the_table":
			table_toucher = Sides.Team.RED if randf() < 0.5 else Sides.Team.BLUE
			_incident_visibility = randf_range(0.2, 0.95)
		&"volley":
			volleyed_by = Sides.Team.RED if randf() < 0.5 else Sides.Team.BLUE
			_incident_visibility = randf_range(0.3, 0.95)


# --- the point being played -----------------------------------------------------

## A serve that clipped the net is heard doing it, as it goes over. The same as tennis's
## cord: how plainly, or below nought for nothing to hear, and the end it came from.
var _net_to_hear := -1.0
var _server_end := 0.0

## The physics frame an edge ball was heard on, so the bounce that comes with it in the
## same frame is not heard as well.
var _edge_heard_on := -1


func _physics_process(delta: float) -> void:
	if _phase != Phase.IN_PLAY:
		return
	_rally_seconds += delta
	if _net_to_hear >= 0.0 and signf(_ball.global_position.z) != _server_end:
		sound.net_cord(Vector3(_ball.global_position.x, net_height(), 0.0), _net_to_hear)
		_net_to_hear = -1.0
	if _rally_seconds > RALLY_LIMIT:
		_end_the_point(_ball.landing_point if _ball.has_landed else _ball.global_position)
		return

	if not _ball.has_landed:
		return
	if _aimed_to_end or _beat != Beat.RALLY:
		return

	if _ball.bounces >= 2:
		_the_second_bounce()
		return
	if _letting_it_go:
		return

	var here := _ball.global_position
	if _ball.linear_velocity.y > 0.0 or here.y > STRIKE_CEILING:
		_see_the_stroke_coming()
		return
	_take_the_stroke(here)


## Starts the stroke before the ball gets to it. See TennisMatch for why, which is the same
## reason: the bat reaches the ball a quarter of the way into the clip and not at the start
## of it, so the stroke has to begin before the contact rather than on it.
func _see_the_stroke_coming() -> void:
	var player := _player(side_defending(_ball.global_position.z))
	if player == null:
		return
	var due := seconds_until_it_drops_under(STRIKE_CEILING, Player.CONTACT_AT["forehand"])
	if float(due[0]) < 0.0:
		return
	player.begin_stroke(maxf(float(due[0]), 0.01),
		float(due[1]) > TableTennisSpec.HEIGHT + 0.35)


func _take_the_stroke(here: Vector3) -> void:
	var hitter := side_defending(here.z)
	_striker = _player(hitter)
	rally.struck_by = hitter
	rally.receiving = Sides.opponent(hitter)

	_exchanges_left -= 1
	var going_for_it := _exchanges_left <= 0
	var target := _edge_ball(Sides.opponent(hitter)) if going_for_it \
		else _safe_ball(Sides.opponent(hitter))
	_defender = _player(Sides.opponent(hitter))

	_stage_any_incident()

	_striker.swing(here.y > TableTennisSpec.HEIGHT + 0.35)
	sound.strike(here, going_for_it)

	_aimed_to_end = going_for_it
	_letting_it_go = going_for_it or _double_bounce_visibility > 0.0
	if _letting_it_go:
		_defender.stand_off()
	else:
		_defender.chase(_off_the_table(
			Vector3(target.x, 0.0, target.z + signf(target.z) * 0.55),
			Sides.opponent(hitter)))

	# Off the rubber rather than out of the air beside it.
	send_over(_striker.struck_from(Vector3(here.x, maxf(here.y, STRIKE_HEIGHT), here.z)),
		target, RALLY_ANGLES)


## A ball hit safely onto the far half, which the other player will reach and return.
func _safe_ball(against: Sides.Team) -> Vector3:
	var into := end_of(against)
	return Vector3(
		randf_range(-TableTennisSpec.HALF_WIDTH + 0.18,
			TableTennisSpec.HALF_WIDTH - 0.18),
		TableTennisSpec.HEIGHT,
		into * randf_range(0.35, TableTennisSpec.HALF_LENGTH - 0.22))


## A ball hit at an edge, which is where this sport's umpire earns their fee.
func _edge_ball(against: Sides.Team) -> Vector3:
	var into := end_of(against)
	if randf() >= GOES_FOR_THE_EDGE:
		# Not every winner is on the paint. Plenty are simply hit past somebody, and if
		# every decisive ball landed on an edge the close ones would stop feeling close.
		return _safe_ball(against)

	var nudge := randf_range(-TableTennisSpec.EDGE_BAND, TableTennisSpec.EDGE_BAND)
	if randf() < 0.5:
		# The far edge, straight down the table and away from the umpire.
		return Vector3(
			randf_range(-TableTennisSpec.HALF_WIDTH + 0.1,
				TableTennisSpec.HALF_WIDTH - 0.1),
			TableTennisSpec.HEIGHT,
			into * (TableTennisSpec.HALF_LENGTH + nudge))
	# A side edge. The far one of the two is the worst call in the sport.
	return Vector3(
		(1.0 if randf() < 0.5 else -1.0) * (TableTennisSpec.HALF_WIDTH + nudge),
		TableTennisSpec.HEIGHT,
		into * randf_range(0.3, TableTennisSpec.HALF_LENGTH - 0.2))


## A free hand on the table, or a ball struck before it bounced, shown as it happens.
func _stage_any_incident() -> void:
	if _incident_shown:
		return
	var culprit := Sides.Team.NONE
	if table_toucher != Sides.Team.NONE:
		culprit = table_toucher
	elif volleyed_by != Sides.Team.NONE:
		culprit = volleyed_by
	if culprit == Sides.Team.NONE:
		return
	var offender := _player(culprit)
	if offender == null:
		return
	_incident_shown = true
	if table_toucher == culprit:
		rally.touched_the_table_by = culprit
	else:
		rally.volleyed_by = culprit
	rally.incident_visibility = maxf(rally.incident_visibility, _incident_visibility)
	# Right up against the end, leaning in — not standing in the middle of the table,
	# which is where `HALF_LENGTH - 0.15` used to put them.
	offender.lunge(_off_the_table(
		Vector3(offender.position.x, 0.0, 0.0), culprit), 0.7)


## Every bounce is heard, on the table and off it. See Sound.bounce.
func _on_ball_bounced(point: Vector3, speed: float, first: bool) -> void:
	if sound == null:
		return
	if first and _edge_heard_on == Engine.get_physics_frames():
		return
	sound.bounce(point, speed)


func _on_ball_landed(point: Vector3) -> void:
	if _phase != Phase.IN_PLAY:
		return

	match _beat:
		Beat.SERVE_DOWN:
			_the_serve_bounced_at_home(point)
		Beat.SERVE_OVER:
			_the_serve_landed(point)
		Beat.RALLY:
			if _aimed_to_end or not TableTennisSpec.is_in(point):
				_aimed_to_end = true
				_end_the_point(point)

	# The edge is heard as the edge. Only a landing the point stopped for has been
	# measured against it — a ball played on was never asked — and a ball off the side
	# does not bounce, so without this it would make no sound at all.
	if rally != null and rally.clipped_the_edge and sound != null:
		sound.edge(point, TableTennisSpec.margin(point) >= 0.0)
		_edge_heard_on = Engine.get_physics_frames()


## The serve's first bounce, on the server's own half, and then over.
##
## The hop is flown as its own shot rather than left to the ball's own bounce, for the
## same reason every tennis stroke is: the whole game turns on where the ball lands to
## within a centimetre, and an elastic bounce off a rigid body cannot be aimed. What the
## ball does between the two landings is decoration; where it finishes is the call.
func _the_serve_bounced_at_home(point: Vector3) -> void:
	if not TableTennisSpec.is_in(point):
		# The serve did not even find its own half — the ball was dropped or scuffed.
		# It is still just a service fault, which in this sport is the point.
		rally.serve_was_good = false
		_beat = Beat.SERVE_OVER
		_end_the_point(point)
		return

	_beat = Beat.SERVE_OVER
	var target := _serve_lands_at
	if rally.clipped_the_net:
		target = _drag_it_over_the_net(target)
		_net_to_hear = rally.net_visibility
		_server_end = signf(point.z)
	send_over(Vector3(point.x, TableTennisSpec.HEIGHT + 0.06, point.z),
		target, SERVE_ANGLES)


## The serve's second bounce, which is the one the umpire is asked about.
##
## As in tennis, the point does not stop for every serve. A serve that lands plainly on
## the far half is played, and nobody says a word — and that is the only reason a rally
## in this sport ever gets past the second stroke.
func _the_serve_landed(point: Vector3) -> void:
	rally.record_landing(point, Sides.opponent(serving))
	rally.serve_was_good = rally.was_in \
		and signf(point.z) == -end_of(serving)

	var worth_asking := (
		not rally.serve_was_good
		or rally.clipped_the_net
		or rally.illegal_service
		or rally.clipped_the_edge
		or absf(rally.margin) <= CLOSE_TO_AN_EDGE
	)
	if worth_asking:
		_end_the_point(point)
		return

	# Played on. Everything recorded so far belonged to the serve and none of it applies
	# to what happens next, so it is all put back — the same reset tennis needs, and for
	# the same reason: leaving it set freezes the point at its delivery and charges the
	# umpire for a call about a ball that has been struck four times since.
	rally.is_a_serve = false
	rally.is_settled = false
	rally.clipped_the_edge = false
	rally.edge_visibility = 0.0
	_aimed_to_end = false
	_letting_it_go = false
	_beat = Beat.RALLY
	_defender.chase(_off_the_table(
		Vector3(point.x, 0.0, point.z - end_of(serving) * 0.55),
		Sides.opponent(serving)))


## The ball bounced twice on one half: whoever was meant to play it did not reach it.
func _the_second_bounce() -> void:
	if _aimed_to_end:
		return
	if _double_bounce_visibility > 0.0:
		rally.double_bounce_by = rally.receiving
		rally.incident_visibility = _double_bounce_visibility
		_double_bounce_visibility = 0.0
	_aimed_to_end = true
	_end_the_point(_ball.landing_point)


func _end_the_point(point: Vector3) -> void:
	if _phase != Phase.IN_PLAY:
		return
	if not rally.is_settled:
		rally.record_landing(point, side_defending(point.z))
	for player in players:
		player.go_home()
	_phase = Phase.AWAITING_CALL
	_awaiting_since = Time.get_ticks_msec()
	mark_the_landing(rally.landing_point)
	if has_close_cam:
		ball_cam.aim_at(rally.landing_point)
		ui.show_close_cam(ball_cam.texture())
	if rally.is_a_serve:
		ui.set_prompt(
			"LEFT CLICK  good    RIGHT CLICK  fault    L  let    F  illegal service")
	else:
		ui.set_prompt("LEFT CLICK  in    RIGHT CLICK  out    F  a fault")


# --- the call -------------------------------------------------------------------

func make_call(id: StringName, against := Sides.Team.NONE) -> void:
	if _phase != Phase.AWAITING_CALL:
		return
	var call := TableTennisCallBook.get_call(id)
	if call != null:
		await judge(call, against)


## Whoever wins the point does not necessarily serve next.
##
## The serve changes hands every two points, and every point from ten-all — which is the
## umpire's real job in this sport. Nobody in the hall is tracking it except them, and
## everybody in the hall will notice the moment they get it wrong.
func award_the_point(winner: Sides.Team) -> void:
	board.award(winner)
	var tt := board as TableTennisScore
	if tt == null:
		serving = winner
		return
	if tt.points[Sides.Team.RED] == 0 and tt.points[Sides.Team.BLUE] == 0:
		# A game just ended. The side that received first in it serves first in the next.
		serving = Sides.opponent(serving)
		_change_ends()
		return
	if tt.serve_changes_now():
		serving = Sides.opponent(serving)


## Players change ends between games, which is the same fairness rule tennis has and for
## a much smaller reason: one end of a hall has the lights behind it, and a ball 40 mm
## across is unplayable against a light.
func _change_ends() -> void:
	_ends_swapped = not _ends_swapped
	ui.announce("CHANGE OF ENDS", UiTheme.ACCENT, CHANGEOVER_SECONDS)
	ui.react("they swap ends and wipe the table down", CHANGEOVER_SECONDS)
	sound.whistle()
	_walk_round_the_table()


## They go round the table rather than through it.
##
## Player has one destination and no path between here and it, so sending somebody
## straight from one end to the other walks them through 2.74 m of tabletop — which is
## the same bug as a chase point landing on the table, at the one moment of the match
## when both of them cross it. Every other sport can send a player anywhere on the floor
## and be right.
##
## Three legs, and each one is clear of the table by construction: out to the side while
## still behind their own end, along the side past both ends, then back in to the middle
## of the new one. That is also simply what players do — they pick up their bat and walk
## round, on opposite sides of the table so they are not squeezing past each other.
## Waits until everybody has reached where they were sent, or until the time is up.
##
## Gated on arrival rather than on a share of the changeover, because the three legs are
## nowhere near the same length: the walk along the side of the table is three and a half
## metres and the steps either side of it are half of one. Splitting the time equally
## left the long leg unfinished, and the next leg then set off for the far end from
## halfway down the side — straight across the table, which is the exact thing this walk
## exists to avoid. Measured, that put somebody 30 cm inside the tabletop for a fifth of
## a second every change of ends.
func _everybody_gets_there(cap := CHANGEOVER_SECONDS) -> void:
	var left := cap
	while left > 0.0:
		var still_walking := false
		for player in players:
			if not player.has_arrived():
				still_walking = true
				break
		if not still_walking:
			return
		await get_tree().physics_frame
		if _phase == Phase.REMOVED:
			return
		left -= get_physics_process_delta_time()


## Which side of the table this player walks round, so the two of them are not squeezing
## past each other. It is their team, and it does not change when the ends do — the point
## is only that the two of them pick different sides.
func _rounds_on(player: Player) -> float:
	return 1.0 if player.team == Sides.Team.RED else -1.0


func _walk_round_the_table() -> void:
	var beside := TableTennisSpec.HALF_WIDTH + ROOM_BESIDE_THE_TABLE
	var behind := TableTennisSpec.HALF_LENGTH + ROOM_BEHIND_THE_END

	for player in players:
		# Out to the side, still behind the end they are leaving. `_ends_swapped` has
		# already flipped, so `end_of` is the end they are walking to.
		player.chase(Vector3(_rounds_on(player) * beside, 0.0,
			-end_of(player.team) * behind))

	await _everybody_gets_there()
	if _phase == Phase.REMOVED:
		return
	for player in players:
		# Along the side, past the end of the table. Never over it: |x| is outside the
		# table's own half-width for the whole of this leg.
		player.chase(Vector3(_rounds_on(player) * beside, 0.0,
			end_of(player.team) * behind))

	await _everybody_gets_there()
	if _phase == Phase.REMOVED:
		return
	for player in players:
		player.home = _home_of(player.team)
		player.go_home()
		player.rotation.y = PI if end_of(player.team) > 0.0 else 0.0


func _unhandled_input(event: InputEvent) -> void:
	if _reviewing:
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
	return table.stands
