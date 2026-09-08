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

## Where a serve is struck from, and how high.
const SERVE_DISTANCE := 3.0
const SERVE_HEIGHT := 2.45

## Where the four players stand when the shuttle is not their problem. Front and
## back, which is how a doubles pair defends.
const HOME_POSITIONS := [
	Vector3(-1.20, 0.0, -2.20),
	Vector3(1.20, 0.0, -4.60),
	Vector3(1.20, 0.0, 2.20),
	Vector3(-1.20, 0.0, 4.60),
]

## How many shots a rally can run to before somebody simply runs out of legs.
const RALLY_SHOT_CAP := 16

## A hard stop on a rally, in seconds. A backstop, not a design.
const MAX_RALLY_SECONDS := 40.0

## Where the line judges sit: diagonally opposite corners, behind the back line and
## outside the sideline.
##
## Diagonally is the point. A full tournament has up to ten line judges; a match with
## two seats them across the diagonal from each other, because from opposite corners
## the pair of them can see all four boundary lines between them. Putting both on the
## same side — which is what this originally did — leaves them looking straight down
## the court at one another and covers the same two lines twice.
##
## Each watches one half and says nothing about the other, so the two of them can
## never end up publicly contradicting each other. In a real match every judge has
## their own lines.
const LINE_JUDGE_SEATS := {
	Sides.Team.BLUE: Vector3(-3.85, 0.0, 7.60),
	Sides.Team.RED: Vector3(3.85, 0.0, -7.60),
}

## How long the hall is left waiting for the answer, and how long the answer stays up.
const REVIEW_SUSPENSE := 1.9
const REVIEW_VERDICT := 2.3

## How long the hall waits before the line judge's call goes up. Long enough for the
## shuttle to have visibly landed, short enough that it still feels like a reaction.
const LINE_JUDGE_DELAY := 0.45

## How often a stroke goes wrong in some way other than missing the court. Rolled per
## stroke, so with rallies running to six or seven shots this is roughly a third of
## rallies having something in them.
## The chance of an offence, rolled on every stroke — not once per rally.
##
## That distinction is the whole of it. At seven percent a stroke and six and a half
## strokes to a rally, two rallies in five contained a fault, and roughly half of those
## mark an honest umpire wrong for not spotting it. An umpire who called every line
## correctly was being booed inside ten rallies, which is what Luqman found and what
## sent me looking here.
##
## A carry or a double hit is a notable event in a real match, not something that
## happens twice a game. At this figure about one rally in twelve has an offence in it.
const INCIDENT_CHANCE := 0.012

## How long the shuttle sits on the racket when a player carries it, and how long
## after a first stroke the same side gets a second one in.
const CARRY_HOLD := 0.18
const DOUBLE_HIT_GAP := 0.14

## How badly a player can misread where a shot is going, in metres.
const READING_ERROR := 0.32

## How high the shuttle has to be for a player to hit down on it, and how often they
## take the chance.
##
## Without this the rally never ends on its own: a lifted shot hangs in the air for
## two seconds, which is long enough for anyone to walk to it, so every rally would
## finish only when a player chose not to play one. A smash arrives in well under a
## second and simply cannot be reached. It is what makes a shot a winner.
const SMASH_MIN_HEIGHT := 2.20
const SMASH_CHANCE := 0.32

## How often a player goes for the line, and how far either side of it they land.
##
## The range is deliberately lopsided. A player aiming at the line is trying to keep
## it in, so most of these land just inside and only some slip out — which is both
## how badminton actually looks and what stops the umpire's job becoming a coin toss.
const CLOSE_CALL_CHANCE := 0.34
const CLOSE_CALL_INSIDE := 0.13
const CLOSE_CALL_OUTSIDE := 0.06

## How often a shot is simply a bad one that sails clearly out, and how far past the
## line it goes. These are the rallies where the whole hall can see the answer.
const BAD_SHOT_CHANCE := 0.06
const BAD_SHOT_MIN := 0.30
const BAD_SHOT_MAX := 1.30

## How often a player simply mishits one into the net.
##
## Without this the game quietly became perfect at clearing the tape, because every
## shot that would have clipped it was retried higher until it did not. Net cords are
## a real and common way to lose a rally, and they are the most obvious call an
## umpire ever gets, so a few of them belong in every match.
const NET_MISHIT_CHANCE := 0.045

## How often a shot is dropped just over the net, and how far past it it lands.
##
## Badminton is played at the net as much as at the back, and without these there was
## no net play at all — which also meant nobody was ever close enough to the net to
## touch it or reach over it, so two of the four offences could never happen.
const NET_SHOT_CHANCE := 0.18
const NET_SHOT_NEAR := 0.70
const NET_SHOT_FAR := 1.90

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

## How often somebody lines up in the wrong service court.
##
## Low, because unlike a line call this one is not a matter of opinion — it is standing
## in plain sight for the whole of the ready phase, and an umpire who is looking will
## always see it. What makes it hard is remembering that the court is decided by the
## *score*: even means the right-hand box, odd means the left. A player who has not
## worked that out will miss every one of them, which is why the lesson now says so.
const SERVICE_COURT_ERROR_CHANCE := 0.06

## Of those, how many are the server standing wrong rather than the receiving pair.
## Weighted towards the server because that is the plainer of the two to see.
const SERVER_AT_FAULT := 0.6

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

## Why they might want that. Handed to them in a corridor before the match — or, in the
## case of a debt, built by them halfway through it without meaning to.
var pressure := Pressure.new()
var debt: Pressure = null

## Which way the umpire's mistakes were leaning when the debt was taken on. A debt is
## settled by a later wrong call going the *other* way, so this is what to compare
## against.
var _debt_direction := Sides.Team.NONE

## Whether a second wrong call has since gone the other way and settled it.
var _debt_evened := false

## How much the hall doubts you. Never displayed — you find out by reading the room.
var suspicion: Suspicion

## The scoreline, and the badminton rules that govern it.
var board: Scoreboard

var players: Array[Player] = []
## The career this match belongs to, and the venue it decides.
var career: Career

## Whether this venue has a camera on the line. School halls do not.
var has_shuttle_cam := true

var line_judges: Array[LineJudge] = []
var shuttle_cam: ShuttleCam
var sound: Sound
var settings: Settings

## The review system, and whether this venue has one.
var challenge := Challenge.new()
var has_hawk_eye := false

## True while a review is on screen, which is the only time the umpire is a spectator.
var _reviewing := false
var menu_camera: MenuCamera

## Whether the lesson was opened on the way into a match, or from the title screen. It
## decides where GOT IT leads.
var _teaching_leads_to_play := false

var _all_line_judges: Array[LineJudge] = []
var serving := Sides.Team.RED

var _shots_this_rally := 0

## Which service court this serve is coming from, decided when the players line up
## rather than when the whistle goes — the umpire has to be able to look at the court
## and disagree with it before anything is served.
var _serve_court := 1.0

## Which side, if either, is standing in the wrong service court right now. This is the
## truth behind the WRONG COURT call, and unlike every other truth in this game it is
## visible on screen the whole time: the player is not guessing, they are looking.
var service_error := Sides.Team.NONE

## Whether the umpire has already dealt with it, either by stopping the serve or by
## correcting it afterwards. Stops one error being called twice.
var _service_error_handled := false

## Whether the shuttle that just landed was left to drop rather than chased. Set as
## each shot is directed, so by the time it lands it describes the final shot.
var rally_left_alone := false

var _rally_seconds := 0.0

## Where the shuttle was on the previous physics tick, used to catch the exact moment
## it passes the plane of the net.
var _previous_shuttle_spot := Vector3.ZERO

## When the shuttle landed, so the game knows how long the umpire stood there.
var _awaiting_since := 0

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
	# Everything but the chair the umpire is sitting in.
	camera.cull_mask = camera.cull_mask & ~Court.CHAIR_LAYER
	camera.current = true
	add_child(camera)

	menu_camera = MenuCamera.new()
	menu_camera.name = "MenuCamera"
	add_child(menu_camera)

	ui = RefereeUI.new()
	ui.name = "RefereeUI"
	ui.length_chosen.connect(_on_length_chosen)
	ui.favour_chosen.connect(_on_favour_chosen)
	ui.briefing_acknowledged.connect(_on_briefing_acknowledged)
	ui.punishment_chosen.connect(_on_punishment_chosen)
	ui.match_requested.connect(_on_match_requested)
	ui.continue_requested.connect(_on_continue_requested)
	ui.career_restart_requested.connect(_on_career_restart_requested)
	ui.new_career_requested.connect(_on_new_career_requested)
	ui.career_screen_requested.connect(_on_career_screen_requested)
	ui.resume_requested.connect(_on_resume_requested)
	ui.walk_out_requested.connect(_on_walk_out_requested)
	ui.quit_requested.connect(_on_quit_requested)
	ui.play_requested.connect(_on_play_requested)
	ui.sport_chosen.connect(_on_sport_chosen)
	ui.settings_requested.connect(_on_settings_requested)
	ui.main_menu_requested.connect(_on_main_menu_requested)
	ui.look_speed_changed.connect(_on_look_speed_changed)
	ui.teaching_requested.connect(_on_teaching_requested)
	ui.teaching_finished.connect(_on_teaching_finished)
	add_child(ui)

	_build_players()

	for team in LINE_JUDGE_SEATS:
		var judge := LineJudge.new()
		judge.name = "LineJudge%s" % Sides.label(team)
		judge.watches = team
		judge.position = LINE_JUDGE_SEATS[team]
		add_child(judge)
		_all_line_judges.append(judge)
	line_judges = _all_line_judges.duplicate()

	shuttle_cam = ShuttleCam.new()
	shuttle_cam.name = "ShuttleCam"
	add_child(shuttle_cam)

	sound = Sound.new()
	sound.name = "Sound"
	add_child(sound)

	settings = Settings.load_or_default()
	settings.apply()
	camera.sensitivity = settings.sensitivity

	career = Career.load_or_start()
	court.stands.set_density(career.venue()["crowd"])
	_menu_view()
	ui.show_main_menu(career)

	suspicion = Suspicion.new()
	suspicion.warning_issued.connect(_on_warning_issued)
	suspicion.removed_from_match.connect(_on_removed_from_match)
	# The room's mood follows the umpire's standing without either of them being shown
	# a number. This is the only wire between suspicion and what the player can hear.
	suspicion.level_changed.connect(sound.set_mood)


# --- the loop ------------------------------------------------------------------

## Sets the match up for wherever on the ladder this umpire has got to. The venue is
## the difficulty: it decides how long the match is, whether anybody is helping,
## whether there is a camera, and how closely the hall is watching.
func _on_match_requested() -> void:
	var venue := career.venue()
	suspicion.scrutiny = venue["scrutiny"]
	has_shuttle_cam = venue["shuttle_cam"]
	has_hawk_eye = venue["hawk_eye"]
	challenge.reset()
	_set_line_judges_present(venue["line_judges"])
	# Dressed before the crowd is counted, because dressing the hall rebuilds the
	# seating and everybody in it, and a density set before that is thrown away.
	court.dress(venue["dressing"])
	court.stands.set_density(venue["crowd"])
	_on_length_chosen(venue["quick"])


func _set_line_judges_present(present: bool) -> void:
	# Cleared rather than replaced with []: a bare empty array is untyped and will not
	# assign to an Array[LineJudge], which failed silently enough that the school hall
	# quietly kept its line judges.
	line_judges.clear()
	if present:
		line_judges.assign(_all_line_judges)
	for judge in _all_line_judges:
		judge.visible = present
		judge.silence()


## PLAY on the title screen. Which sport, then which career — in that order, because
## the sport decides everything after it.
func _on_play_requested() -> void:
	ui.hide_menus()
	_menu_view()
	ui.show_sport_menu()


## Only badminton opens, so this always leads to the same place. It is still routed
## through the id rather than assumed, because the second sport is the whole reason the
## screen exists and it should not need this function rewritten.
func _on_sport_chosen(id: StringName) -> void:
	ui.hide_sport_menu()
	if id != &"badminton":
		return
	# Somebody who has never been told what a carry looks like cannot referee one, so
	# the first time through they are told before they are asked to. Once only: it is
	# remembered against the player, not against the career.
	if not settings.taught:
		_teaching_leads_to_play = true
		_on_teaching_requested()
		return
	_on_career_screen_requested()


func _on_teaching_requested() -> void:
	ui.hide_menus()
	_menu_view()
	ui.show_teaching()


func _on_teaching_finished() -> void:
	ui.hide_teaching()
	settings.taught = true
	settings.save()
	if _teaching_leads_to_play:
		_teaching_leads_to_play = false
		_on_career_screen_requested()
	else:
		_on_main_menu_requested()


func _on_settings_requested() -> void:
	ui.hide_menus()
	_menu_view()
	ui.show_settings(settings)


## Back out of anything to the title screen.
func _on_main_menu_requested() -> void:
	ui.hide_sport_menu()
	ui.hide_settings()
	_menu_view()
	ui.show_main_menu(career)


func _on_look_speed_changed(radians_per_pixel: float) -> void:
	camera.sensitivity = radians_per_pixel


## The drifting view of the hall that sits behind every menu, and the hall dressed at
## its best while it is showing. A title screen is a shop window: it should be the good
## version of the game, not whichever rung of the ladder this career happens to be on.
func _menu_view() -> void:
	if menu_camera == null:
		return
	camera.set_active(false)
	menu_camera.current = true
	if court != null and court.venue != null and court.venue.tier != Venue.Tier.ARENA:
		court.dress(Venue.Tier.ARENA)
		court.stands.set_density(1.0)


## Back into the chair. Called wherever a match actually begins, which is the same place
## the menus are cleared — every route in has to go through both or the player ends up
## refereeing from somewhere over the stands.
func _umpire_view() -> void:
	if menu_camera != null:
		menu_camera.current = false
	camera.current = true


func _on_continue_requested() -> void:
	get_tree().reload_current_scene()


func _on_career_screen_requested() -> void:
	_menu_view()
	ui.show_career(career)


func _on_new_career_requested() -> void:
	career = Career.start_again()
	career.save()
	court.stands.set_density(career.venue()["crowd"])
	_menu_view()
	ui.show_career(career)


func _on_quit_requested() -> void:
	get_tree().quit()


## Stops the match dead. The mouse goes back to the player, because a menu you cannot
## click is not a menu.
func _pause() -> void:
	camera.set_active(false)
	ui.show_pause_menu()
	get_tree().paused = true


func _on_resume_requested() -> void:
	get_tree().paused = false
	ui.hide_pause_menu()
	camera.set_active(true)


## Walking out is recorded exactly as being thrown off is. Leaving early would
## otherwise be a way to escape a match that had gone badly, which would make the
## suspicion you had built up worth nothing at all.
func _on_walk_out_requested() -> void:
	get_tree().paused = false
	ui.hide_pause_menu()
	_finish_match("YOU WALKED OUT", Color(0.96, 0.42, 0.36), true)


func _on_career_restart_requested() -> void:
	Career.start_again().save()
	get_tree().reload_current_scene()


func _on_length_chosen(quick: bool) -> void:
	# A match is starting, however it was started. Putting this here rather than in
	# the career screen's button means it holds for every route in — including the
	# development scenes, which were leaving the menu sitting over the court.
	ui.hide_menus()
	_umpire_view()
	board = Scoreboard.new(quick)
	board.game_won.connect(_on_game_won)
	board.match_won.connect(_on_match_won)

	# Whoever has a reason to lean on you this week gets to say their piece before the
	# question is asked, so that the question has an answer worth thinking about.
	pressure = Pressure.for_match(career)
	debt = null
	_debt_direction = Sides.Team.NONE
	_debt_evened = false
	challenge.watching = pressure.watched
	if pressure.exists():
		ui.show_briefing(pressure)
	else:
		ui.show_favour_choice()


func _on_briefing_acknowledged() -> void:
	ui.hide_briefing()
	ui.show_favour_choice(pressure.ask)


func _on_favour_chosen(team: Sides.Team) -> void:
	favoured = team
	if board == null:
		board = Scoreboard.new(false)
		board.game_won.connect(_on_game_won)
		board.match_won.connect(_on_match_won)
	ui.hide_pre_match()
	camera.set_active(true)
	_enter_ready()


func _build_players() -> void:
	for i in HOME_POSITIONS.size():
		var home: Vector3 = HOME_POSITIONS[i]
		var player := Player.new()
		player.name = "Player%d" % i
		# One of the four builds each, so the court holds four people rather than one
		# person standing in four places.
		add_child(player)
		player.setup(Sides.half_containing(home.z), home)
		players.append(player)


func _unhandled_input(event: InputEvent) -> void:
	# Nothing gets through while a review is on screen. Making a call is a coroutine now
	# that it can pause for the hall to watch a replay, and the phase does not change
	# until it finishes — so without this the umpire could stand there calling the same
	# rally three more times while the first call was still being examined.
	if _reviewing:
		return

	if ui.is_fault_panel_open():
		if _is_key(event, KEY_ESCAPE):
			_close_fault_panel()
		return

	if _phase == Phase.REMOVED:
		return

	if _is_key(event, KEY_ESCAPE):
		_pause()
		return

	if _is_key(event, KEY_F):
		_open_fault_panel()
		return

	# The service court call is the only thing in the game that can be said at two
	# different moments, and the moment is the whole of the difference. Before the
	# whistle you have stopped it in time and the serve is taken again; afterwards you
	# have discovered it late, and Law 12.2 is blunt about that — the error is
	# corrected and the existing score stands.
	if _is_key(event, KEY_W) and (_phase == Phase.READY or _phase == Phase.AWAITING_CALL):
		_call_service_court(_phase == Phase.READY)
		return

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


## "Service court error." The one call in this game that decides nothing.
##
## Whatever the umpire says, nobody wins or loses a point: under Law 12.2 the error is
## corrected and the existing score stands. What changes is only whether the serve is
## taken again — stopped before the whistle it is, discovered afterwards it is not,
## because by then the rally has been played and the score it produced is the score.
##
## So this call cannot be used to help anybody, and a bent umpire gets nothing out of
## it. It is purely a test of whether the person in the chair is paying attention, and
## it is the only call in the game whose truth was on screen all along: the four of
## them stand there in their boxes for as long as you care to look.
func _call_service_court(in_time: bool) -> void:
	if _service_error_handled:
		return
	_service_error_handled = true

	var real := service_error != Sides.Team.NONE
	suspicion.register_service_court(real, true)

	# The announcement is the same either way. The umpire says what the umpire says;
	# the game does not lean over and tell the player whether they were right, here or
	# anywhere else. The hall's reaction is the only answer they get.
	if in_time:
		ui.announce("SERVICE COURT ERROR   ·   TAKE THE SERVE AGAIN", Color(0.95, 0.90, 0.60))
		# A whistle stops play. There is no play to stop once the rally is over, so the
		# late version is said rather than blown.
		sound.whistle()
	else:
		ui.announce("SERVICE COURT ERROR   ·   CORRECTED, SCORE STANDS", Color(0.95, 0.90, 0.60))

	if real:
		ui.react("a coach nods; somebody had noticed that too", 3.4)
	else:
		ui.react("the players look at each other, and then at you", 4.0)

	if not in_time:
		# Nothing to move: the rally is over and the next one lines up from scratch.
		return

	# Stopped in time, so put them where they should have been and let the umpire
	# whistle again. Doing this even when there was no error is deliberate — an umpire
	# who stops the match for nothing still has to stand there and restart it.
	service_error = Sides.Team.NONE
	_stand_for_serve(_serve_court)


## Between rallies there is no rally to fault anybody over, so only misconduct is on
## offer. Cards can be handed out whenever the umpire feels like it.
func _open_fault_panel() -> void:
	if _phase != Phase.READY and _phase != Phase.AWAITING_CALL:
		return
	camera.set_active(false)
	ui.show_fault_panel(_phase == Phase.READY)


func _close_fault_panel() -> void:
	ui.hide_fault_panel()
	camera.set_active(true)


func _on_punishment_chosen(id: StringName, team: Sides.Team) -> void:
	_close_fault_panel()
	if id == &"yellow" or id == &"red":
		show_card(team, id == &"red")
		return
	if _phase == Phase.AWAITING_CALL:
		_make_call(id, team)


## Produces a card. Nothing happened — nothing ever happened — so this is not a
## judgement at all, it is the umpire simply taking a point off somebody in front of
## a hall that watched them do nothing. It is the only cheat available on a rally you
## did not even have to wait for, and it is priced accordingly.
func show_card(against: Sides.Team, red: bool) -> void:
	if _phase == Phase.REMOVED or board == null or board.is_over:
		return

	suspicion.register_card(against, red)
	ui.announce(
		"%s   ·   %s" % ["RED CARD" if red else "YELLOW CARD", Sides.label(against)],
		Color(0.94, 0.36, 0.32) if red else Color(0.95, 0.85, 0.30),
		2.4
	)
	ui.react(Crowd.react_to_card(red), 3.4)

	if print_truth_while_testing:
		print("[truth, testing only] %s card on %s for nothing  |  suspicion %.3f lean %+.2f" % [
			"RED" if red else "YELLOW", Sides.label(against), suspicion.level, suspicion.lean
		])

	if not red:
		# A yellow is a warning. The rally, if there is one, still needs deciding.
		return

	var beneficiary := Sides.opponent(against)
	board.award(beneficiary)
	serving = beneficiary
	if _phase == Phase.AWAITING_CALL:
		ui.hide_shuttle_cam()
		for judge in line_judges:
			judge.silence()
		_enter_ready()
	else:
		_update_score()


func _enter_ready() -> void:
	if suspicion.is_removed or board.is_over:
		return
	_phase = Phase.READY
	_update_score()

	# Everybody takes up position now, before the whistle, so there is something to
	# look at in the gap between rallies. It used to happen inside _start_rally, which
	# meant the four of them snapped into place and the serve went in the same frame.
	_set_up_the_serve()
	ui.set_prompt("SPACE  whistle          W  service court          F  cards")

	# The hall gets on with having an opinion whether or not anything just happened.
	if randf() < AMBIENT_CHANCE:
		ui.react(Crowd.ambient(suspicion.mood), 3.2)


## Lines the four of them up for the next serve, and decides whether one of them gets
## it wrong. Called at the top of the ready phase, so the mistake is on the court and
## visible for as long as the umpire cares to look at it.
func _set_up_the_serve() -> void:
	_serve_court = service_court(serving)
	service_error = Sides.Team.NONE
	_service_error_handled = false

	if randf() < SERVICE_COURT_ERROR_CHANCE:
		# Either the server serves from the wrong box, or the wrong one of the
		# receiving pair stands ready to take it. Both are service court errors and
		# both are Law 12.1; the second is the harder of the two to spot.
		service_error = serving if randf() < SERVER_AT_FAULT else Sides.opponent(serving)

	_stand_for_serve(_serve_court, service_error)


func _start_rally() -> void:
	_shots_this_rally = 0
	_rally_seconds = 0.0
	for judge in line_judges:
		judge.silence()
	rally = Rally.new(serving, true)
	rally.service_court_error = service_error

	# The serve leaves from wherever the server is actually standing, and goes to the
	# box diagonally opposite *that* — so a server in the wrong court serves the whole
	# rally across the wrong diagonal, which is what makes the error worth spotting.
	var court := _serve_court
	var served_from := -court if service_error == serving else court

	var from := Vector3(
		served_from * randf_range(0.65, 1.55),
		SERVE_HEIGHT,
		Sides.half_sign(serving) * SERVE_DISTANCE
	)
	var target := _pick_serve_target(
		Sides.half_sign(Sides.opponent(serving)), -served_from)

	if not _hit_or_something_safer(from, target, serving):
		push_warning("Could not serve at all from %v" % from)
		return

	sound.whistle()
	_phase = Phase.IN_FLIGHT
	ui.set_prompt("watch it")


## Watches for a player getting a racket on the shuttle before it can land.
func _physics_process(_delta: float) -> void:
	if _phase != Phase.IN_FLIGHT:
		return
	if not is_instance_valid(_shuttle) or _shuttle.has_landed:
		return
	# Only on the way down. A shuttle still climbing is on its way over the net.
	if _shuttle.linear_velocity.y >= 0.0:
		_watch_for_net_crossing()
		return

	_watch_for_net_crossing()

	var receiving := Sides.opponent(rally.struck_by)

	# A player may only play the shuttle once it is on their own side of the net.
	# This is a real rule, and it is also the only thing stopping a pair of players
	# standing either side of the net batting the same shuttle back and forth in one
	# spot forever — a smash starts descending the instant it is struck, so without
	# this the receiver can return it from the point it was hit, and the rally never
	# ends.
	if _shuttle.global_position.z * Sides.half_sign(receiving) <= 0.0:
		return

	for player in players:
		if player.team != receiving:
			continue
		if player.can_strike(_shuttle.global_position):
			_return_shot(player)
			return

	# A rally that has somehow gone on far too long is brought to an end rather than
	# left to hang. Nothing should reach this, but a match that cannot finish is a
	# far worse failure than a rally that ends oddly.
	_rally_seconds += _delta
	if _rally_seconds > MAX_RALLY_SECONDS:
		# Most likely the shuttle is resting in the net and will never reach the
		# floor on its own, so it is brought down where it is.
		for player in players:
			player.stand_off()
		_shuttle.force_landing()


## Notices the moment the shuttle passes the plane of the net, and whether it went
## over the thing or merely past it.
##
## Solving for the exact crossing rather than checking the position each tick matters
## for the same reason it did for the landing: a fast shuttle covers most of a metre
## between ticks, and the net is two centimetres thick.
func _watch_for_net_crossing() -> void:
	var here := _shuttle.global_position
	var there := _previous_shuttle_spot
	_previous_shuttle_spot = here

	if signf(here.z) == signf(there.z) or is_zero_approx(there.z):
		return

	var span := absf(there.z) + absf(here.z)
	if is_zero_approx(span):
		return
	var crossing := absf(there.z) / span
	var height := lerpf(there.y, here.y, crossing)
	var across := lerpf(there.x, here.x, crossing)

	# A badminton net stops 764 mm above the floor and ends at the posts, so getting
	# to the other side underneath it or around the outside of it is perfectly
	# possible — and a fault.
	var net_bottom := CourtSpec.NET_HEIGHT_CENTRE - CourtSpec.NET_DEPTH
	if height < net_bottom or absf(across) > CourtSpec.POST_X:
		rally.went_over_the_net = false


func _return_shot(player: Player) -> void:
	# Rallies cannot run forever. Past the cap the legs go and the shuttle drops.
	if _shots_this_rally >= RALLY_SHOT_CAP:
		player.stand_off()
		return

	# They have played their shot, whatever happens next. Standing them off first
	# also stops this being re-entered while a carry is being held.
	player.stand_off()
	# Overhead if the shuttle is up around head height, which is what decides whether
	# the animation plays a smash or a groundstroke.
	var overhead := _shuttle.global_position.y > 1.95
	player.swing(overhead)
	sound.strike(_shuttle.global_position, overhead)

	var offence := _roll_for_offence(player)

	if offence == Incident.Kind.CARRY:
		# The shuttle stops dead on the racket and is slung on a moment later. From
		# the chair it is a hesitation in the middle of a stroke, and that hesitation
		# is the only thing there is to see.
		_shuttle.freeze = true
		await get_tree().create_timer(CARRY_HOLD).timeout
		if _phase != Phase.IN_FLIGHT or not is_instance_valid(_shuttle):
			return
		_shuttle.freeze = false

	var from := _shuttle.global_position
	var target := _pick_target(Sides.half_sign(Sides.opponent(player.team)))
	if not _hit_or_something_safer(from, target, player.team):
		return

	if offence == Incident.Kind.DOUBLE_HIT:
		await get_tree().create_timer(DOUBLE_HIT_GAP).timeout
		if _phase != Phase.IN_FLIGHT or not is_instance_valid(_shuttle) or _shuttle.has_landed:
			return
		# The same side gets a second stroke in, which is the whole of the offence.
		var again := _pick_target(Sides.half_sign(Sides.opponent(player.team)))
		var here := _shuttle.global_position
		_hit(here, again, _choose_angle(here), player.team)


## Plays the shot that was wanted, or an easier one if that shot cannot be played.
##
## Some shots genuinely cannot be hit — a drop landing a few centimetres past the net
## struck from the back of the court is asking for the shuttle to clear the tape and
## then stop, and there is no speed at any angle that does both. A player who cannot
## find the shot they wanted does not stand there holding the shuttle: they push
## something safer into the middle. Without this the rally simply stopped, which left
## the match waiting for a landing that was never going to come.
func _hit_or_something_safer(from: Vector3, target: Vector3, striker: Sides.Team) -> bool:
	if _hit(from, target, _choose_angle(from), striker):
		return true

	var into := Sides.half_sign(Sides.opponent(striker))
	for attempt in 3:
		var safe := Vector3(randf_range(-2.0, 2.0), 0.0, into * randf_range(3.0, 5.2))
		if _hit(from, safe, _choose_angle(from), striker):
			return true
	return false


## Decides whether this stroke goes wrong, and in what way.
##
## Only one offence per rally. Two would be unfair on the umpire, who would then have
## to pick which of them to announce, and the rules say the first one ends the rally
## anyway.
func _roll_for_offence(player: Player) -> Incident.Kind:
	if rally.incident.happened() or randf() > INCIDENT_CHANCE:
		return Incident.Kind.NONE

	# Touching the net and reaching over it depend on where the *player* is, not
	# where the shuttle is. Testing the shuttle meant these two offences could
	# essentially never happen: a player standing at the net still meets the shuttle
	# a metre or two back from it.
	var choices: Array = [Incident.Kind.CARRY, Incident.Kind.DOUBLE_HIT]
	if absf(player.position.z) < 1.75:
		choices.append(Incident.Kind.NET_TOUCH)
		choices.append(Incident.Kind.OBSTRUCTION)

	var kind: Incident.Kind = choices[randi() % choices.size()]
	var seen := _how_visible(kind)
	rally.incident = Incident.new(kind, player.team, seen, _shuttle.global_position)
	_perform_offence(kind, player, seen)
	return kind


## How plainly each kind of offence reads from the umpire's chair. A carry is a
## flicker in a stroke; somebody reaching over the net is not something you miss.
func _how_visible(kind: Incident.Kind) -> float:
	match kind:
		Incident.Kind.NET_TOUCH:
			return randf_range(0.25, 0.85)
		Incident.Kind.CARRY:
			return randf_range(0.15, 0.55)
		Incident.Kind.DOUBLE_HIT:
			return randf_range(0.30, 0.80)
		Incident.Kind.OBSTRUCTION:
			return randf_range(0.40, 0.95)
	return 0.0


## Makes the offence actually happen on court, so there is something to have seen.
func _perform_offence(kind: Incident.Kind, player: Player, seen: float) -> void:
	match kind:
		Incident.Kind.NET_TOUCH:
			court.shake_net(seen)
		Incident.Kind.OBSTRUCTION:
			# Over the net and back, into the opponent's half.
			var over := Vector3(player.position.x, 0.0, -Sides.half_sign(player.team) * 0.55)
			player.lunge(over, 0.8)
			court.shake_net(seen * 0.5)


## Sends the shuttle from `from` to `target`, and points the receiving side at it.
func _hit(from: Vector3, target: Vector3, angle: float, striker: Sides.Team) -> bool:
	# Try the shot, and if the arc would clip the net, hit it higher and try again.
	# Players miss the tape occasionally and that is fine — but they should not do it
	# on every drop shot because the game only checked a straight line.
	var velocity := Vector3.ZERO
	var attempt_angle := angle
	var mishit := randf() < NET_MISHIT_CHANCE

	for attempt in 4:
		var candidate := ShotSolver.solve(from, target, attempt_angle, Court.SURFACE_Y)
		if candidate == Vector3.ZERO:
			attempt_angle += 9.0
			continue
		# On a mishit the player does not get to try again, and the tape is where the
		# rally ends.
		if mishit or _clears_the_net(from, target, candidate):
			velocity = candidate
			break
		attempt_angle += 9.0

	if velocity == Vector3.ZERO:
		return false

	if not is_instance_valid(_shuttle):
		_shuttle = Shuttle.new()
		_shuttle.name = "Shuttle"
		add_child(_shuttle)
		_shuttle.landed.connect(_on_shuttle_landed)

	_shuttle.launch(from, velocity)
	rally.struck_by = striker
	# Every shot has to get over the net on its own account, so the question is
	# reopened each time the shuttle is struck.
	rally.went_over_the_net = true
	_previous_shuttle_spot = from
	_shots_this_rally += 1
	_direct_players(Sides.opponent(striker), target)
	return true


## Decides which of the receiving pair goes for the shuttle, and whether they bother.
func _direct_players(receiving: Sides.Team, target: Vector3) -> void:
	var taker: Player = null
	var shortest := INF

	for player in players:
		if player.team != receiving:
			player.go_home()
			continue
		var distance := player.distance_to(target)
		if distance < shortest:
			shortest = distance
			taker = player

	for player in players:
		if player.team == receiving and player != taker:
			player.go_home()

	rally_left_alone = false

	if taker == null:
		rally_left_alone = true
		return

	if _leaves_it(target):
		rally_left_alone = true
		# They have decided it is going out and are going to stand and watch. The
		# rally is now entirely in the umpire's hands, and they have no idea whose
		# side the umpire is on.
		taker.stand_off()
		return

	taker.chase(target + Vector3(
		randf_range(-READING_ERROR, READING_ERROR),
		0.0,
		randf_range(-READING_ERROR, READING_ERROR)
	))


## Whether the receiving player lets the shuttle drop rather than playing it.
##
## Real players do this constantly, and it is the single most useful thing they can
## do for this game: a shuttle nobody touches has to be ruled on, and the player who
## left it has staked the rally on the umpire being honest.
func _leaves_it(target: Vector3) -> bool:
	var margin := CourtSpec.margin(target, true)
	if margin > 0.06:
		# Comfortably in. Occasionally somebody misreads one anyway.
		return randf() < 0.03
	if margin < -0.25:
		# Clearly going out. Only a nervous player plays this.
		return randf() < 0.80
	# Too close to be sure. This is where the umpire earns their money.
	return randf() < 0.40


## Whether this shot actually gets over the tape, flown rather than eyeballed.
func _clears_the_net(from: Vector3, target: Vector3, velocity: Vector3) -> bool:
	# A shot that stays on one side never meets the net.
	if signf(from.z) == signf(target.z) or is_zero_approx(from.z):
		return true

	var flat := Vector2(target.x - from.x, target.z - from.z).length()
	var span := absf(target.z - from.z)
	if flat < 0.01 or span < 0.01:
		return true

	# How far the shuttle travels horizontally before it reaches the plane of the net.
	var along := absf(from.z) * (flat / span)
	var speed := velocity.length()
	var climb := rad_to_deg(asin(clampf(velocity.y / maxf(0.001, speed), -1.0, 1.0)))
	var height := ShotSolver.height_after(from.y, speed, climb, along)
	return height > CourtSpec.NET_HEIGHT_CENTRE + 0.05


## Picks a launch angle for a shot struck from `from`.
##
## Two jobs. The first is to keep the shuttle above the net: a player scrambling near
## the floor must lift it, or it would fly straight through the net, which looks
## exactly as wrong as it sounds. The second is to hit down on it when they can,
## because a rally with no winning shot in it never ends.
func _choose_angle(from: Vector3) -> float:
	var to_net := maxf(0.15, absf(from.z))
	var clearance := CourtSpec.NET_HEIGHT_CENTRE + 0.12

	# The steepest downward angle that still gets over the net from here. Below the
	# net tape there is no such angle and the shuttle has to be lifted.
	if from.y > clearance and from.y >= SMASH_MIN_HEIGHT:
		var steepest := rad_to_deg(atan((from.y - clearance) / to_net))
		if steepest > 6.0 and randf() < SMASH_CHANCE:
			return -randf_range(3.0, minf(steepest - 2.0, 20.0))

	var lowest := 10.0
	var rise := clearance - from.y
	if rise > 0.0:
		lowest = rad_to_deg(atan(rise / to_net)) + 7.0
	return clampf(randf_range(26.0, 46.0), lowest, 64.0)


func _on_shuttle_landed(point: Vector3) -> void:
	rally.record_landing(point)
	sound.landing(point)
	_phase = Phase.AWAITING_CALL
	ui.set_prompt("LEFT CLICK  in    RIGHT CLICK  out    L  let    W  service court    F  fault or card")

	_awaiting_since = Time.get_ticks_msec()
	if has_shuttle_cam:
		shuttle_cam.aim_at(point)
		ui.show_shuttle_cam(shuttle_cam.texture())

	# The line judge makes their mind up the moment it lands, but does not say so
	# until a beat later. Deciding it now means an umpire who calls before the bubble
	# goes up has still overruled them, rather than dodging the whole question by
	# being quick.
	var judge := _judge_watching(point)
	if judge != null:
		rally.line_judge_said_in = judge.judge(rally)
		rally.line_judge_called = true
		_announce_line_judge(judge)


## Whichever line judge is responsible for the end the shuttle came down at, if this is
## a rally for a line judge to have an opinion about at all.
##
## A line judge watches lines and nothing else, so they say nothing about a shuttle that
## never got over the net. That one is not a line call at all: a shuttle that fails to
## cross is recorded as `was_in = false` with a blatant margin, because for scoring
## purposes it is as good as out — so the line judge was announcing OUT, at the top of
## their voice, about a shuttle that had plainly landed well inside the lines.
##
## They do still call the line when an offence has happened, which is what a real line
## judge does: they signal what they saw on their line and the umpire's fault call
## overrides it. Silencing them there was a mistake with a consequence I did not see —
## agreeing with a line judge halves what a wrong call costs, so muting them on exactly
## the rallies where an honest umpire is most likely to be marked wrong quietly stripped
## away the cover the whole system was balanced around.
func _judge_watching(point: Vector3) -> LineJudge:
	if rally == null or not rally.crossed_the_net:
		return null
	var half := Sides.half_containing(point.z)
	for judge in line_judges:
		if judge.watches == half:
			return judge
	return null


func _announce_line_judge(judge: LineJudge) -> void:
	await get_tree().create_timer(LINE_JUDGE_DELAY).timeout
	if _phase != Phase.AWAITING_CALL or not is_instance_valid(judge):
		return
	judge.announce(rally.line_judge_said_in)


func _make_call(id: StringName, against := Sides.Team.NONE) -> void:
	var call := CallBook.get_call(id)
	if call == null:
		return

	rally.seconds_to_call = float(Time.get_ticks_msec() - _awaiting_since) / 1000.0
	rally.record_call(call, against)
	ui.hide_shuttle_cam()
	var winner := rally.point_goes_to()

	# The hall makes up its mind about what it just saw. The player is told nothing
	# except how the room reacted — which is the whole of the feedback they get.
	#
	# This happens before any review, not after. A review only ever adds to what the call
	# already cost, and the rule that nobody is removed without one warning is checked
	# against the level at the time — so pricing them the wrong way round let a review
	# push an umpire past the warning that the call itself should have given them first.
	suspicion.register(rally)
	_weigh_the_debt()

	# And whether somebody spent the whole rally in the wrong box without the umpire
	# ever saying so. Charged after the call itself, and lightly: this is inattention
	# rather than dishonesty, and it takes nothing off anybody.
	if rally.service_court_error != Sides.Team.NONE and not _service_error_handled:
		_service_error_handled = true
		suspicion.register_service_court(true, false)
		ui.react("somebody in the stands is pointing at the service courts", 4.0)

	# Now, before the point is given, whoever it was taken from gets to ask. This is the
	# only moment in the game where the truth is put on a screen, and the umpire has to
	# sit through it like everybody else.
	if has_hawk_eye:
		var asked := challenge.challenger(rally)
		if asked != Sides.Team.NONE:
			var overturned := await _review(asked)
			if overturned:
				winner = rally.rightful_winner()

	# A review can be the thing that ends the match: being caught on screen at an
	# international final is enough to be removed on the spot. If that happened while the
	# replay was playing, the ending screen is already up and its summary already written
	# — so nothing below should award another point behind it.
	if _phase == Phase.REMOVED:
		return

	if winner != Sides.Team.NONE:
		board.award(winner)
		# In badminton the side that wins the rally serves the next one.
		serving = winner
		var accused := "" if against == Sides.Team.NONE else " on %s" % Sides.label(against)
		ui.announce(
			"%s%s   ·   POINT %s" % [call.label, accused, Sides.label(winner)],
			Sides.colour(winner)
		)
	else:
		ui.announce("%s   ·   PLAY IT AGAIN" % call.label, Color(0.85, 0.85, 0.80))

	# What the hall makes of it: the call itself, or the length of the silence before
	# it. A slow clap for taking four seconds over a shuttle a metre out.
	var reaction := Crowd.react_to_call(rally.visibility(), suspicion.mood)
	if reaction.is_empty():
		reaction = Crowd.react_to_delay(rally.seconds_to_call)
	ui.react(reaction)

	_react_to_call(winner)

	if print_truth_while_testing:
		print("[truth, testing only] %s  |  took %.1fs  |  suspicion %.3f lean %+.2f" % [
			rally.describe(), rally.seconds_to_call, suspicion.level, suspicion.lean
		])

	_enter_ready()


## Plays the review out: the challenge, a pause, and then the answer. Returns whether the
## call was overturned.
##
## The pause is not decoration. A review that resolved instantly would be a line of text;
## the second and a half between the hall asking and the hall finding out is the only
## time in this game an umpire has to wait to learn whether they got away with it.
func _review(asked: Sides.Team) -> bool:
	_reviewing = true
	var overturned := rally.verdict() == Rally.Verdict.WRONG

	shuttle_cam.aim_at(rally.landing_point)
	ui.show_review(asked, challenge.remaining(asked), shuttle_cam.texture())
	sound.react(false)
	await get_tree().create_timer(REVIEW_SUSPENSE).timeout

	var truth := "IN" if rally.was_in else "OUT"
	if overturned:
		ui.set_review_verdict("%s  ·  CALL OVERTURNED" % truth, Color(0.96, 0.42, 0.36))
	else:
		ui.set_review_verdict("%s  ·  CALL STANDS" % truth, Color(0.55, 0.85, 0.60))

	challenge.settle(asked, overturned)
	suspicion.register_review(rally, overturned)
	sound.react(not overturned)
	ui.react(Crowd.react_to_review(overturned))

	await get_tree().create_timer(REVIEW_VERDICT).timeout
	ui.hide_review()
	_reviewing = false
	return overturned


func _on_warning_issued() -> void:
	ui.show_banner("THE TOURNAMENT REFEREE HAS BEEN CALLED")
	ui.react("the tournament referee walks to the side of the court and sits down", 5.0)


func _on_removed_from_match() -> void:
	_finish_match("YOU HAVE BEEN REMOVED FROM THE MATCH", Color(0.96, 0.42, 0.36), true)


## Closes the match out and folds it into the career. This is the only screen in the
## game allowed to state the truth, because there is nothing left to judge.
func _finish_match(headline: String, tint: Color, removed: bool) -> void:
	_phase = Phase.REMOVED
	camera.set_active(false)
	ui.hide_shuttle_cam()
	ui.set_prompt("")

	# Whoever was leaning on you finds out how it went. Resolved before the career is
	# told about it, because two of them change what the career does next.
	var pressures: Array = []
	if pressure.exists():
		pressure.resolve(board, suspicion)
		pressures.append(pressure)
	if debt != null:
		debt.resolve(board, suspicion, _debt_evened)
		pressures.append(debt)

	var detail := _reckoning()
	if career != null:
		var note := career.finish_match(suspicion.level, removed, pressures)
		# And whether tonight made somebody an enemy for a later match. Done after
		# finish_match, which is where an old grudge gets marked as spent — so an umpire
		# who settles one score badly walks straight out with a fresh one, which is the
		# whole loop this system is for.
		career.remember_grudge(
			String(Pressure.NAMES.pick_random()),
			suspicion.wrong_calls, suspicion.stolen_rallies, suspicion.lean)
		career.save()
		detail += "\n\n%s\n\nReputation  %d / 100" % [note, roundi(career.reputation * 100.0)]

	ui.show_ending(headline, detail, tint)


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
	lines.append("Final score  RED %d — %d BLUE      games  %d — %d" % [
		board.points[Sides.Team.RED],
		board.points[Sides.Team.BLUE],
		board.games[Sides.Team.RED],
		board.games[Sides.Team.BLUE],
	])
	return "\n".join(lines)


## The one pressure the player builds for themselves.
##
## The first time a call goes wrong plainly enough that the hall saw it, a side is a
## point down because of the umpire, and there is an obvious way to put that right which
## involves getting a second one wrong on purpose. The game already makes that second
## lie cheap — suspicion charges for being wrong in a *pattern*, so a mistake the other
## way genuinely does cost less than another one the same way. All this does is say so.
##
## Nothing here reveals anything. It fires only above Pressure.DEBT_NOTICED, which is
## the level at which the crowd is already telling you.
func _weigh_the_debt() -> void:
	if rally == null or rally.verdict() != Rally.Verdict.WRONG:
		return
	if rally.visibility() < Pressure.DEBT_NOTICED:
		return

	var helped := rally.point_goes_to()
	if helped == Sides.Team.NONE:
		return
	var robbed := Sides.opponent(helped)

	if debt == null:
		if not rally.changed_the_result():
			return
		debt = Pressure.debt_from(rally, robbed)
		_debt_direction = robbed
		# Whoever you just cost a rally stops giving you the benefit of the doubt. If
		# somebody was already watching you, they keep the attention — you cannot be
		# under less scrutiny for having made a second enemy.
		if challenge.watching == Sides.Team.NONE:
			challenge.watching = robbed
		ui.show_banner("THAT ONE WAS WRONG AND EVERYONE SAW IT", 4.0)
		ui.react("%s are a point down because of you" % Sides.label(robbed), 5.0)
		return

	# A later mistake going the other way is the books being balanced, which is two
	# wrong calls dressed up as fairness.
	if not _debt_evened and helped == _debt_direction:
		_debt_evened = true
		ui.react("nobody in this hall thinks that evened anything up", 5.0)


## The players' answer to the call. Whoever won it celebrates; whoever was robbed of
## it, plainly enough that they could tell, turns round and argues with the chair.
##
## This is the first thing in the game that reacts to the umpire as a person rather
## than as a rule, and it costs almost nothing now that the characters can act.
func _react_to_call(winner: Sides.Team) -> void:
	var robbed := Sides.Team.NONE
	if rally != null and rally.verdict() == Rally.Verdict.WRONG and rally.visibility() > 0.25:
		robbed = Sides.opponent(rally.point_goes_to())

	for player in players:
		if player.team == robbed:
			player.argue()
		elif winner != Sides.Team.NONE and player.team == winner:
			player.celebrate()

	# The hall reacts too: the stands come up out of their seats and, at the venues
	# that have photographers in them, a scatter of flashes goes off. Both are things
	# the umpire catches out of the corner of their eye while wondering whether they
	# have got away with it.
	if winner != Sides.Team.NONE:
		court.stands.cheer()
		if court.venue != null:
			court.venue.flash()

	# A groan every time the hall catches something, and applause only sometimes —
	# a room that claps every single point stops meaning anything by the third game.
	if robbed != Sides.Team.NONE:
		sound.react(false)
	elif winner != Sides.Team.NONE and randf() < 0.45:
		sound.react(true)


func _update_score() -> void:
	ui.set_score(board, serving)
	ui.set_reviews(
		challenge.remaining(Sides.Team.RED),
		challenge.remaining(Sides.Team.BLUE),
		has_hawk_eye
	)
	# The hanging board says the same thing as the HUD, so the hall and the umpire
	# never disagree about the score.
	if court.venue != null:
		court.venue.set_score(board.points[Sides.Team.RED], board.points[Sides.Team.BLUE])


func _on_game_won(team: Sides.Team) -> void:
	challenge.reset()
	if board.is_over:
		return
	ui.announce("GAME  ·  %s" % Sides.label(team), Sides.colour(team), 2.6)


func _on_match_won(team: Sides.Team) -> void:
	_finish_match("%s WIN THE MATCH" % Sides.label(team), Sides.colour(team), false)


# --- hitting the shuttle -------------------------------------------------------

## Hits one shuttle with no rally around it: nobody chases it and it simply lands.
## Used by the development scenes to set up an exact situation on demand.
func serve(from: Vector3, target: Vector3, angle := 36.0, striker := Sides.Team.NONE) -> Shuttle:
	for player in players:
		player.go_home()
	rally = Rally.new(striker, true)
	_shots_this_rally = RALLY_SHOT_CAP
	if not _hit(from, target, angle, striker):
		push_warning("No shot at %.0f degrees reaches %v from %v" % [angle, target, from])
		return null
	_phase = Phase.IN_FLIGHT
	return _shuttle


## Which service court the serving side is serving from, as a sign along X.
##
## The rule is the whole of doubles service rotation and it is one line: serve from the
## right when your score is even, from the left when it is odd. Everything else — who
## serves, who receives, which players have swapped sides — follows from it, which is
## why a real umpire tracks the score and the court together and why an umpire who has
## lost the score cannot referee the serve at all.
##
## Right and left are from the server's own view, facing the net. RED defends the -Z half
## and so faces +Z, which puts their right hand towards -X; BLUE faces the other way and
## theirs is +X. Getting this backwards is invisible in a screenshot and obvious the
## moment somebody who plays the sport watches a serve cross the wrong diagonal.
func service_court(team: Sides.Team) -> float:
	var right := -1.0 if team == Sides.Team.RED else 1.0
	if board == null:
		return right
	var even: bool = int(board.points.get(team, 0)) % 2 == 0
	return right if even else -right


## Puts the four of them where the rules say they stand: the server in the service court
## their score dictates, the receiver diagonally opposite, and both partners behind and
## across. Before this everybody simply stood at the same four spots every rally, which
## meant the serve came from wherever the server happened to be.
func _stand_for_serve(court: float, mistaken := Sides.Team.NONE) -> void:
	for team in [Sides.Team.RED, Sides.Team.BLUE]:
		var side := Sides.half_sign(team)
		# The pair whose court this is: the server serves from `court`, the receiver
		# stands in the box the serve is coming to, which is the opposite sign.
		var front := court if team == serving else -court
		# Unless this is the side getting it wrong, in which case the pair of them are
		# simply the other way round. That is exactly what a service court error looks
		# like from the chair: nobody is doing anything strange, they are just stood in
		# each other's boxes.
		if team == mistaken:
			front = -front
		var placed := 0
		for player in players:
			if player.team != team:
				continue
			if placed == 0:
				player.home = Vector3(front * 1.15, 0.0, side * 2.35)
			else:
				player.home = Vector3(-front * 1.30, 0.0, side * 4.70)
			placed += 1
	for player in players:
		player.go_home()


## Where a serve is aimed: safely inside the service court, and nowhere near a line.
##
## A serve is not judged by the same boundary as a rally shot. In doubles it has to land
## short of the long service line at 5.94 m, not the back line at 6.70 — so a serve
## dropping in the 76 cm between them is a fault, and this game scored it as good,
## because the serve was aimed with the same picker as every other shot and then judged
## with `CourtSpec.is_in`. An umpire who knows badminton called it out and was told they
## were lying.
##
## Service faults are deliberately outside this game's scope: judging one properly needs
## the racket head, the server's waist and their feet all modelled, and none of that
## exists. So rather than judge serves by a rule the player is never told about, the
## server simply does not play the shot — every serve lands comfortably inside its box,
## and the calls worth making come later in the rally, where the boundary really is the
## back line.
func _pick_serve_target(half: float, court: float) -> Vector3:
	return Vector3(
		court * randf_range(0.40, 2.45),
		0.0,
		half * randf_range(CourtSpec.SHORT_SERVICE_LINE + 0.55,
			CourtSpec.LONG_SERVICE_LINE_DOUBLES - 0.45)
	)


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

	# A drop just over the net. Nothing to judge about where it lands, but it drags
	# both players up to the net, which is the only place two of the four offences
	# can happen at all.
	if roll < BAD_SHOT_CHANCE + NET_SHOT_CHANCE:
		return Vector3(
			randf_range(-2.5, 2.5),
			0.0,
			half * randf_range(NET_SHOT_NEAR, NET_SHOT_FAR)
		)

	# A shot played safely into the middle of the court, where there is nothing to
	# judge and the umpire simply confirms what everyone saw.
	if roll > BAD_SHOT_CHANCE + NET_SHOT_CHANCE + CLOSE_CALL_CHANCE:
		return Vector3(randf_range(-2.3, 2.3), 0.0, half * randf_range(2.6, 5.6))

	var drift := randf_range(-CLOSE_CALL_INSIDE, CLOSE_CALL_OUTSIDE)

	if randf() < 0.5:
		# Along a sideline, a whisker in or a whisker out.
		var side := CourtSpec.HALF_WIDTH_DOUBLES * (1.0 if randf() < 0.5 else -1.0)
		return Vector3(side + drift * signf(side), 0.0, half * randf_range(2.2, 6.2))

	# Along the back line, just short or just long.
	return Vector3(randf_range(-2.8, 2.8), 0.0, half * (CourtSpec.HALF_LENGTH + drift))


func _is_key(event: InputEvent, keycode: Key) -> bool:
	return event is InputEventKey and event.pressed and not event.echo and event.keycode == keycode


# --- the hall ------------------------------------------------------------------

## The hall used to be lit from here: a key light, a grid of six lamps and a world
## environment, all fixed. That moved into Venue when the career ladder started
## changing what the hall looks like — a school hall lit flatly from above and an arena
## lit as a dark bowl with the court burning in the middle are the same code with
## different numbers, and having two owners of the lighting meant two of everything,
## with the brighter one winning. There is nothing left to do here.
func _build_environment() -> void:
	pass
