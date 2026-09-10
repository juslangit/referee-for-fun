class_name OfficiatedMatch
extends Node3D

## Everything a match needs that is not the sport.
##
## The two volleyballs were written a fortnight apart and came out 26% identical — the
## same career screen, the same briefing, the same review, the same ending, the same
## fold-in to a career. That is not tidiness to worry about later: it is a place bugs
## live in pairs. The crash where a review read its rally after two awaits existed in
## both files and had to be found and fixed in both; the bug where an invented fault
## scored as correct was caught in both only because inheritance happened to cover it.
##
## So this file owns the parts that have nothing to do with what is being played, and a
## sport is what is left over: its court, its ball, its rulebook, its truths, and the
## handful of hooks below.
##
## Badminton is deliberately not on this base. It owns the whole front of the game —
## title screen, sport menu, settings, teaching — and converting it would be a much
## larger change than the duplication it would remove. Its `_finish_match` and
## `_reckoning` are the remaining overlap, and they are worth revisiting only if a
## fourth sport ever wants them.

enum Phase {
	## In the menus. Nothing is being officiated yet.
	MENU,
	## Waiting for the official to start the rally.
	READY,
	## The ball is up.
	IN_PLAY,
	## It has come down. The venue is waiting.
	AWAITING_CALL,
	## Taken off the match.
	REMOVED,
}

## How long the venue waits before it finds out, and how long it looks at the answer.
const REVIEW_SUSPENSE := 1.9
const REVIEW_VERDICT := 2.3

var ui: RefereeUI
var camera: UmpireCamera
var suspicion: Suspicion
var board: Scoreboard
var career: Career
var settings: Settings
var sound: Sound

var pressure := Pressure.new()
var challenge := Challenge.new()
var has_challenge := false
var has_close_cam := true
var ball_cam: ShuttleCam

var players: Array[Player] = []
var serving := Sides.Team.RED

var _phase := Phase.MENU
var _reviewing := false
var _awaiting_since := 0

## How many calls this official has made in this match. Only used to decide whether
## leaving costs anything: before the first call there is nothing to answer for.
var calls_made := 0

@export var print_truth_while_testing := true


# --- what each sport has to answer ----------------------------------------------
#
# Six hooks. Everything above and below this line is shared; everything a sport does
# differently goes through one of these.

## Which sport this is, for the career and the lesson.
func sport() -> StringName:
	return Career.BADMINTON


## Whether this match is two a side. Only badminton and tennis are ever asked; the two
## volleyballs are what they are, and answer for the sport rather than from the career.
func playing_doubles() -> bool:
	if career == null or not Career.has_both_formats(sport()):
		return true
	return career.doubles


## Build the court, the ball, the players, the camera and the lighting.
func build_the_venue() -> void:
	pass


## Puts the people on court. Each sport's own, and called again at the start of every
## match by `rebuild_players`.
func build_the_players() -> void:
	pass


## Rebuilds the people on court now that the format is known.
##
## They are built when the scene is, and the scene is built **before the career has been
## loaded** — so at that moment nobody knows whether this is singles or doubles, and
## `playing_doubles()` answers "doubles" because it has nothing better to say. A player
## who chose singles got four people anyway.
##
## Doing it again here, once per match, also means the choice can change between matches
## without reloading the scene.
func rebuild_players() -> void:
	for player in players:
		player.queue_free()
	players.clear()
	build_the_players()


## Dress the venue for a rung of the ladder and fill the seats.
func dress_the_venue(_venue: Dictionary) -> void:
	pass


## Make the scoreboard this sport is scored on.
func make_the_board(_venue: Dictionary) -> Scoreboard:
	return Scoreboard.new(false)


## Put everybody in position and get ready for the next rally.
func enter_ready() -> void:
	pass


## The rally that has just been judged, or null between rallies.
func current_rally():
	return null


## Everything the reckoning wants to say about the final score. Sports that call a game
## something other than a set override it.
func score_line() -> String:
	return "Final score  RED %d — %d BLUE      sets  %d — %d" % [
		board.points[Sides.Team.RED], board.points[Sides.Team.BLUE],
		board.games[Sides.Team.RED], board.games[Sides.Team.BLUE]]


## The faults the panel offers. "Four hits" means nothing on a badminton court and
## "carry" means nothing on a volleyball one.
func fault_book() -> Array:
	return CallBook.faults()


# --- setting up -----------------------------------------------------------------

func _ready() -> void:
	suspicion = Suspicion.new()
	settings = Settings.load_or_default()
	settings.apply()

	build_the_venue()
	build_line_judges()
	_build_the_mark()

	ui = RefereeUI.new()
	ui.name = "UI"
	add_child(ui)
	ui.show_hud(false)
	ui.fault_book = fault_book()
	ui.offers_cards = false
	ui.punishment_chosen.connect(_on_fault_chosen)
	_connect_menus()

	sound = Sound.new()
	sound.name = "Sound"
	sound.kit = sport()
	add_child(sound)

	# The bed behind the match darkens as the room turns against you.
	#
	# This is not decoration in a game whose central rule is that there is no suspicion
	# meter and you read the room instead. Badminton has had it since the sound was
	# built; both volleyballs shipped without it, so in two sports out of three half the
	# room was mute and the player was reading a room that could not answer.
	suspicion.level_changed.connect(sound.set_mood)
	suspicion.level_changed.connect(_on_reputation_moved)
	suspicion.warning_issued.connect(_on_warning)
	suspicion.removed_from_match.connect(func() -> void:
		finish("TAKEN OFF THE MATCH", Color(0.96, 0.42, 0.36), true))

	career = Career.load_or_start()
	# The sport is written into the save before the hand-off, but a scene run straight
	# from the editor has never been through the menu.
	career.sport = sport()
	board = Scoreboard.new(false)

	if _has_been_taught():
		ui.show_career(career)
	else:
		ui.show_teaching(sport())


func _on_warning() -> void:
	ui.show_banner("THE MATCH REFEREE HAS BEEN CALLED")
	ui.react("the match referee comes over and stands by the post", 5.0)


func _has_been_taught() -> bool:
	match sport():
		Career.BEACH: return settings.taught_beach
		Career.INDOOR: return settings.taught_indoor
		Career.TENNIS: return settings.taught_tennis
	return settings.taught


func _remember_being_taught() -> void:
	match sport():
		Career.BEACH: settings.taught_beach = true
		Career.INDOOR: settings.taught_indoor = true
		Career.TENNIS: settings.taught_tennis = true
		_: settings.taught = true
	settings.save()


# --- the front of the match -----------------------------------------------------
#
# Badminton owns the title screen, the sport menu, the settings and the lesson, because
# that is where the game starts. Once another sport has been chosen it is a different
# scene, so the screens that belong to a *match* are wired up again here against the
# same RefereeUI. Nothing is duplicated but the wiring; every screen itself is shared.

func _connect_menus() -> void:
	ui.match_requested.connect(_on_match_requested)
	ui.briefing_acknowledged.connect(func() -> void:
		ui.hide_briefing()
		begin_match())
	ui.continue_requested.connect(func() -> void: get_tree().reload_current_scene())
	ui.career_screen_requested.connect(func() -> void:
		ui.hide_history()
		ui.show_career(career))
	ui.history_requested.connect(func() -> void: ui.show_history(career))
	ui.teaching_requested.connect(func() -> void:
		ui.hide_career()
		ui.show_teaching(sport()))
	ui.teaching_finished.connect(func() -> void:
		_remember_being_taught()
		ui.hide_teaching()
		ui.show_career(career))
	for restart in [ui.new_career_requested, ui.career_restart_requested]:
		restart.connect(func() -> void:
			career = Career.start_again()
			career.sport = sport()
			career.save()
			ui.show_career(career))
	ui.resume_requested.connect(func() -> void:
		get_tree().paused = false
		ui.hide_pause_menu()
		camera.set_active(true))
	ui.walk_out_requested.connect(func() -> void:
		get_tree().paused = false
		finish("YOU WALKED OFF", Color(0.85, 0.62, 0.32), true))
	# Back to the front of the game, which lives in the badminton scene.
	ui.main_menu_requested.connect(func() -> void:
		get_tree().paused = false
		get_tree().change_scene_to_file("res://scenes/match.tscn"))
	ui.quit_requested.connect(func() -> void: get_tree().quit())


func _on_match_requested() -> void:
	# One a side or two, which is only knowable now: the scene was built before the
	# career was loaded. See rebuild_players.
	rebuild_players()
	var venue := career.venue()
	suspicion.scrutiny = venue["scrutiny"]
	has_challenge = venue["hawk_eye"]
	has_close_cam = venue["close_cam"]
	challenge.reset()
	dress_the_venue(venue)

	set_line_judges_present(venue["line_judges"])
	board = make_the_board(venue)
	board.game_won.connect(_on_set_won)
	board.match_won.connect(func(team: Sides.Team) -> void:
		finish("%s WIN" % Sides.label(team), Sides.colour(team), false))

	ui.hide_menus()
	ui.hide_career()

	pressure = Pressure.for_match(career)
	if pressure.exists():
		ui.show_briefing(pressure)
	else:
		begin_match()


## A new set hands both sides their challenges back. Sports with more to reset override
## this and call up to it.
func _on_set_won(_team: Sides.Team) -> void:
	challenge.reset()
	show_where_you_stand()
	_show_reviews()
	ui.set_score(board, serving)


## Out to the chair. Every route into a match ends here.
##
## The camera takes the mouse only now, and not a moment earlier. Two screens can come
## between asking for a match and the first serve, and capturing the cursor for the
## camera leaves both of them showing buttons that cannot be clicked.
func begin_match(_unused := Sides.Team.NONE) -> void:
	calls_made = 0
	camera.set_active(true)
	_start_watching_reputation()
	go_ready()


func go_ready() -> void:
	if suspicion.is_removed or board.is_over:
		return
	_phase = Phase.READY
	ui.set_score(board, serving)
	enter_ready()


func _show_reviews() -> void:
	ui.set_reviews(challenge.remaining(Sides.Team.RED),
		challenge.remaining(Sides.Team.BLUE), has_challenge)


# --- the review -----------------------------------------------------------------

## Plays the review out: the challenge, a pause, and then the answer.
##
## The pause is not decoration. A review that resolved instantly would be a line of
## text; the second and a half between the venue asking and the venue finding out is the
## only time in this game an official has to wait to learn whether they got away with it.
##
## Everything it needs is read before the first await. A review is two seconds of
## waiting with the game still running, and the rally is a reference the next serve
## replaces — reading it on the far side of a timer worked until something started a
## rally during one, and then crashed on a call that no longer existed.
func review(asked: Sides.Team) -> bool:
	var rally = current_rally()
	if rally == null:
		return false

	_reviewing = true
	var overturned: bool = rally.verdict() == Rally.Verdict.WRONG
	var about_a_touch: bool = rally.call != null and rally.call.judges_the_touch
	var truth := ""
	if about_a_touch:
		truth = "TOUCHED" if rally.was_touched else "NO TOUCH"
	else:
		truth = "IN" if rally.was_in else "OUT"
	var seen: float = rally.visibility()
	var leaned := which_way_it_leaned()
	var landing: Vector3 = rally.landing_point

	ball_cam.aim_at(landing)
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

	ui.set_review_hint("SPACE   ·   carry on")
	await _wait_or_skip(REVIEW_VERDICT)
	ui.hide_review()
	_reviewing = false
	return overturned


# --- sitting through a review ---------------------------------------------------
#
# The wait before the answer is the point of a review: it is the only moment in this
# game where an official has to sit and find out, in public, whether they got away with
# something. That half of it is not skippable and should not be.
#
# The half **after** the answer is just reading a line you have already read, and on the
# tenth review of a match it is dead time. So that half takes SPACE.

## Whether a review is far enough along that it can be waved away, and whether it has.
var _can_skip_review := false
var _review_skipped := false


## Waits out `seconds`, or until the official waves it on.
func _wait_or_skip(seconds: float) -> void:
	_review_skipped = false
	_can_skip_review = true
	var left := seconds
	while left > 0.0 and not _review_skipped:
		await get_tree().process_frame
		left -= get_process_delta_time()
	_can_skip_review = false
	_review_skipped = false


## Whether anybody challenges this call, and who.
##
## Line calls and touches, and nothing else. A challenge looks at video of the ball, so
## it can settle where the ball landed and whether it brushed a hand on the way — but
## not whether a set came off two fingers unevenly, and not where six people were
## standing. Those stay the official's word against the venue's.
func who_would_challenge() -> Sides.Team:
	var rally = current_rally()
	if rally == null or rally.call == null or not rally.is_settled:
		return Sides.Team.NONE
	if not (rally.call.judges_the_landing or rally.call.judges_the_touch):
		return Sides.Team.NONE

	var lost := Sides.opponent(rally.point_goes_to())
	# A touch has no landing to be near or far from, so how close a call it *felt* is
	# how slight the deflection was.
	var closeness: float = rally.margin
	if rally.call.judges_the_touch:
		closeness = (1.0 - rally.touch_visibility) * Challenge.DOUBT_RANGE
	return challenge.who_challenges(
		lost, rally.verdict() == Rally.Verdict.WRONG, rally.visibility(), closeness)


## +1 if the call helped BLUE, -1 if it helped RED, 0 if it helped nobody.
##
## The number that matters most in this whole game: being wrong is survivable, and being
## wrong the same way every time is what gets an official removed.
func which_way_it_leaned() -> float:
	var rally = current_rally()
	if rally == null:
		return 0.0
	# Typed explicitly: `current_rally()` is deliberately untyped so that three sports
	# with three different rally classes can all answer it, and an untyped value cannot
	# have a type inferred from it.
	var gained: Sides.Team = rally.point_goes_to()
	var deserved: Sides.Team = rally.rightful_winner()
	if gained == deserved or gained == Sides.Team.NONE:
		return 0.0
	return 1.0 if gained == Sides.Team.BLUE else -1.0


# --- the end --------------------------------------------------------------------

## Closes the match out and folds it into the career. The only screen in the game
## allowed to state the truth, because there is nothing left to judge.
func finish(headline: String, tint: Color, removed: bool) -> void:
	if _phase == Phase.REMOVED:
		return
	_phase = Phase.REMOVED
	_reputation_showing = -1
	camera.set_active(false)
	ui.hide_close_cam()
	ui.hide_reputation()
	ui.set_prompt("")

	var detail := _where_this_was() + "\n\n" + _reckoning()
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


## The line at the top of the ending: which sport, and which rung of which ladder.
##
## With four ladders running in parallel and one reputation across all of them, a screen
## that says "3 wrong calls" and nothing about where you were is a result without a
## match attached to it. The venue is also the whole of why the number is what it is —
## the same lie is nearly free at the school hall and career-ending at the final.
func _where_this_was() -> String:
	return "%s   ·   %s" % [sport_name(), career.venue()["name"]]


## What this sport is called on screen. The ids are lower case and are for the save file.
func sport_name() -> String:
	match sport():
		Career.BEACH: return "BEACH VOLLEYBALL"
		Career.INDOOR: return "INDOOR VOLLEYBALL"
		Career.TENNIS: return "TENNIS"
	return "BADMINTON"


func _reckoning() -> String:
	var lines := []
	lines.append("%d wrong calls, %d of which decided the rally." % [
		suspicion.wrong_calls, suspicion.stolen_rallies])

	if absf(suspicion.lean) < 0.15:
		lines.append("They went both ways. You were not bent. You were just bad at this.")
	else:
		var helped := Sides.Team.BLUE if suspicion.lean > 0.0 else Sides.Team.RED
		lines.append("Almost every one of them helped %s." % Sides.label(helped))
		# Nobody was ever asked who they wanted to win, so this cannot be read back to
		# them as a broken promise. What it can say is the thing that actually gets an
		# official caught: not that they were wrong, but that they were wrong in one
		# direction, which is a pattern rather than a bad night.
		if pressure.exists() and pressure.wants == helped:
			lines.append("Which is the result somebody mentioned to you before you went out.")
		else:
			lines.append("Nobody asked you to. That is the part people find hard to believe.")

	lines.append("")
	lines.append(score_line())
	return "\n".join(lines)


# --- pausing --------------------------------------------------------------------

## Escape stops the match dead and gives the mouse back, because a menu you cannot
## click is not a menu.
func pause_the_match() -> void:
	camera.set_active(false)
	# The free exit is offered only while nothing has happened. See show_pause_menu.
	ui.show_pause_menu(calls_made == 0)
	get_tree().paused = true


# --- flying the ball ------------------------------------------------------------
#
# Both volleyballs put the ball in the air the same way and differ only in the size of
# the court and the height of the net.

## How much daylight a shot has to show over the tape to count as clearing it.
const NET_CLEARANCE := 0.14

var _ball: Ball

## Where the last shot was sent, so the next contact knows where to be.
var _aim := Vector3.ZERO


func net_height() -> float:
	return 2.43


func floor_height() -> float:
	return 0.0


## Which projectile the aim is solved for. The solver runs the same drag model the real
## ball uses, so handing it the wrong one is not a rounding error: a tennis ball aimed
## with a volleyball's drag lands metres from where it was sent.
func flight() -> ShotSolver.Flight:
	return ShotSolver.ball_flight()


## Launches a shot that has to cross the net, at the flattest angle that gets over it.
##
## A straight line from the contact to the target clears the tape comfortably, and the
## ball does not travel in a straight line. The only honest way to know is to fly it and
## look — measured, at 14 degrees a serve only clears 2.43 m if it is aimed deep, and
## the first version of this buried thirteen of seventeen rallies in the net.
func send_over(from: Vector3, to: Vector3, angles: Array) -> void:
	# How far the ball travels along its own path before it reaches the plane of the
	# net, which is not the same as how far the net is along Z. A shot struck from one
	# corner towards the far one has flown further than the Z distance by the time it
	# gets there, and checking its height at the Z distance reads it too early — while
	# it is still climbing — and passes shots that then hit the tape.
	var flat := Vector2(to.x - from.x, to.z - from.z)
	var crosses_at := absf(from.z) / maxf(0.001, absf(to.z - from.z))
	var to_the_net := flat.length() * crosses_at
	var shot := flight()

	for angle in angles:
		var velocity := ShotSolver.solve(from, to, angle, floor_height(), shot)
		if velocity == Vector3.ZERO:
			continue
		var at_net := ShotSolver.height_after(
			from.y - floor_height(), velocity.length(), angle, to_the_net, shot)
		if at_net > net_height() + NET_CLEARANCE:
			_aim = to
			_ball.launch(from, velocity)
			return

	# Nothing in the list gets over. Loop it, which is what a player out of options does.
	send(from, to, 55.0)


## Where a shot's path crosses the plane of the net, in x.
##
## Exact rather than approximate. Drag acts along the direction of travel, so a ball's
## path seen from above is a straight line even though its height is a curve — which is
## why this can be solved rather than flown. Both volleyballs need it for the antenna,
## the one boundary in those sports that is judged in the air with nothing left on the
## sand to walk over and argue about.
func crossing_x(from: Vector3, to: Vector3) -> float:
	var span := to.z - from.z
	if is_zero_approx(span):
		return from.x
	return from.x + (to.x - from.x) * (absf(from.z) / absf(span))


## Launches a shot that stays on one side of the net.
func send(from: Vector3, to: Vector3, angle: float) -> void:
	_aim = to
	var shot := flight()
	var velocity := ShotSolver.solve(from, to, angle, floor_height(), shot)
	if velocity == Vector3.ZERO:
		velocity = ShotSolver.solve(from, to, 45.0, floor_height(), shot)
	_ball.launch(from, velocity)


## Whether the ball has reached where the last contact sent it, and is low enough to be
## played. `reach` is how close counts; `ceiling` is how high is still too high.
func ball_has_arrived(reach: float, ceiling: float) -> bool:
	var here := _ball.global_position
	if Vector2(here.x - _aim.x, here.z - _aim.z).length() > reach:
		return false
	return here.y <= ceiling


## The two players of one side, or all six.
func team_of(team: Sides.Team) -> Array[Player]:
	var found: Array[Player] = []
	for player in players:
		if player.team == team:
			found.append(player)
	return found


## Whichever of a side is closest to a spot — which is who would go for it.
func nearest_of(team: Sides.Team, to: Vector3) -> Player:
	var best: Player = null
	var closest := 1e9
	for player in team_of(team):
		var gap := player.distance_to(to)
		if gap < closest:
			closest = gap
			best = player
	return best


# --- making a call --------------------------------------------------------------

## The whole of what happens when an official says something.
##
## Both volleyballs had a copy of this and it is the worst place in the game for them to
## have had one: it is where the call is priced, where the challenge happens, where the
## point is awarded and where the match can end. A difference between two copies of this
## would not look like a bug, it would look like one sport being scored differently from
## another, which is exactly the thing this game cannot afford to get wrong quietly.
##
## The sport supplies the call and whatever it needs to record beforehand; everything
## from the pricing onwards is the same in both.
func judge(call: CallType, against: Sides.Team) -> void:
	var rally = current_rally()
	if rally == null:
		return

	calls_made += 1
	rally.seconds_to_call = float(Time.get_ticks_msec() - _awaiting_since) / 1000.0
	rally.record_call(call, against)
	record_the_line_judge(rally)
	before_pricing()
	ui.hide_close_cam()

	price_the_call(rally, call)

	# Before the point is given, whoever it was taken from gets to ask. This is the only
	# moment in these sports where the truth is put on a screen, and the official has to
	# sit through it like everybody else.
	var winner: Sides.Team = rally.point_goes_to()
	if has_challenge:
		var asked := who_would_challenge()
		if asked != Sides.Team.NONE:
			var overturned := await review(asked)
			if overturned:
				winner = rally.rightful_winner()

	# A review can be the thing that ends the match: being caught on screen at a final is
	# enough to be taken off on the spot. If that happened while the replay was playing,
	# the ending is already up and nothing below may award a point behind it.
	if _phase == Phase.REMOVED:
		return

	if winner != Sides.Team.NONE:
		award_the_point(winner)
		cheer()
		_the_players_react(winner, rally)
	announce_the_call(call, against, winner)

	# And what the room made of the person awarding it. Separate from the cheer on
	# purpose: the cheer is about the rally and fires whoever won it, and this is about
	# the call. A hall that celebrates every point and never objects to anything is not
	# reading anything back to you, which is what it did until now.
	_the_room_reacts(rally)

	# What the hall makes of it: the call itself, or the length of the silence before it.
	# A slow clap for taking four seconds over a ball a metre out.
	var reaction := Crowd.react_to_call(rally.visibility(), suspicion.mood)
	if reaction.is_empty():
		reaction = Crowd.react_to_delay(rally.seconds_to_call)
	ui.react(reaction)
	_show_reviews()

	if print_truth_while_testing:
		print("[truth, testing only] %s  |  suspicion %.3f lean %+.2f" % [
			rally.describe(), suspicion.level, suspicion.lean])

	go_ready()


## Anything the sport has to write onto the rally before it is priced — the faults it
## keeps on the match rather than on the ball.
func before_pricing() -> void:
	pass


## What the line judge on that line said, written onto the rally.
##
## The three ball sports learn it at the landing and keep it on the match; badminton
## writes it straight onto its own rally when the shuttle comes down, and overrides this
## to leave well alone. Getting it wrong is silent — the cover a line judge gives simply
## stops applying — which is why it is a named step rather than two assignments.
func record_the_line_judge(rally) -> void:
	rally.line_judge_called = _judge_called
	rally.line_judge_said_in = _judge_said_in


## What the call costs. Every sport prices the same way; badminton adds two charges of
## its own that no other sport has — the debt it may have just settled, and a service
## court error it sat through — so it wraps this rather than replacing it.
func price_the_call(rally, call: CallType) -> void:
	suspicion.register_judgement(
		rally.verdict() as int,
		rally.visibility(),
		which_way_it_leaned(),
		call.severity,
		rally.seconds_to_call,
		rally.echoes_line_judge(),
		rally.overrules_line_judge(),
		rally.changed_the_result())


## What the umpire is heard to say. A call that awards nothing is not "point to nobody";
## in badminton it is a let, and the hall is told to play it again.
func announce_the_call(call: CallType, against: Sides.Team, winner: Sides.Team) -> void:
	var accused := "" if against == Sides.Team.NONE else " on %s" % Sides.label(against)
	if winner == Sides.Team.NONE:
		ui.announce("%s%s" % [call.label, accused], Color(0.85, 0.85, 0.80))
		return
	ui.announce("%s%s   ·   POINT %s" % [call.label, accused, Sides.label(winner)],
		Sides.colour(winner))


## Gives the point. Indoor overrides this because a side that wins the serve back
## rotates, and a side that holds it does not.
func award_the_point(winner: Sides.Team) -> void:
	board.award(winner)
	serving = winner


## The stand coming out of its seats for a point.
func cheer() -> void:
	pass


## The stand coming out of its seats at **you**. Overridden per sport, like cheer().
func jeer(_share: float) -> void:
	pass


## How plainly wrong a call has to be before anybody gets out of their seat, and how much
## of the hall does when it is beyond argument.
const JEER_THRESHOLD := 0.30
const MOST_OF_THE_HALL := 0.55


## The stands answering the call rather than the rally.
##
## Priced by the same visibility everything else is: a shaved line nobody could see moves
## nobody, and a ball given three feet out empties the seats. A hall already hostile is
## quicker off its seat than one that still trusts you, which is what the mood is for.
func _the_room_reacts(rally) -> void:
	if rally == null or rally.verdict() != Rally.Verdict.WRONG:
		return
	var seen: float = rally.visibility()
	var short_fuse: float = 1.0 if suspicion.mood >= Suspicion.Mood.HOSTILE else 0.0
	if seen < JEER_THRESHOLD - short_fuse * 0.12:
		return
	jeer(MOST_OF_THE_HALL * clampf(seen, 0.0, 1.0))


## The two sides answering a call: one celebrates, the other turns round.
##
## Both clips have been on the character from the start and **only badminton ever played
## them** — so in three sports out of four nobody on court ever reacted to anything. That
## matters more here than it sounds. This game's feedback loop is reading the room, and
## the players are the closest part of the room to the chair.
##
## The losing side only argues when the call was plainly wrong. A player who turns on the
## umpire after every point they lose is not reading anything back to you.
const ARGUES_WHEN_SEEN := 0.35

func _the_players_react(winner: Sides.Team, rally) -> void:
	var seen: float = rally.visibility() if rally != null else 0.0
	var wrong: bool = rally != null and rally.verdict() == Rally.Verdict.WRONG
	for player in players:
		if player.team == winner:
			player.celebrate()
		elif wrong and seen >= ARGUES_WHEN_SEEN:
			player.argue()


# --- the reputation meter -------------------------------------------------------

## What the meter last showed, out of a hundred. Negative until a match has begun.
var _reputation_showing := -1


## Reputation moved, so the meter puts itself up for three seconds and goes again.
##
## Driven off Suspicion rather than off the call, so every route that costs you
## something reaches it in one place: a wrong call, a review that went against you on
## camera, a fault you sat through, and the slow repair a clean rally earns back.
##
## Only a change to the **whole number** is shown. Suspicion moves by thousandths on an
## honest rally, and a meter that appeared for each of those would be on screen
## permanently, which is the one thing it must never be.
func _on_reputation_moved(_level: float) -> void:
	if career == null or ui == null or _reputation_showing < 0:
		return
	var now := career.reputation_as_it_stands(suspicion.level, suspicion.is_removed)
	var out_of_100 := roundi(now * 100.0)
	if out_of_100 == _reputation_showing:
		return
	var moved := float(out_of_100 - _reputation_showing) / 100.0
	_reputation_showing = out_of_100
	ui.show_reputation(now, moved)


## Seeds the meter at whatever the career screen just showed, so that the first call of
## the match is measured against the number the player last read.
func _start_watching_reputation() -> void:
	if career == null:
		return
	_reputation_showing = roundi(
		career.reputation_as_it_stands(suspicion.level, false) * 100.0)
	show_where_you_stand()


## Puts the meter up whether or not the number has moved.
##
## Only-on-change is right for the middle of a match and wrong at its edges. A referee
## who has a clean night never sees the bar at all and reasonably concludes it is
## broken — which is exactly what happened. So it is also shown once as you go out, and
## again at the end of every set: three times a match on a clean one, and never often
## enough to become the permanent readout the game was built not to have.
func show_where_you_stand() -> void:
	if career == null or ui == null:
		return
	var now := career.reputation_as_it_stands(suspicion.level, suspicion.is_removed)
	_reputation_showing = roundi(now * 100.0)
	ui.show_reputation(now, 0.0, true)


# --- the line judges ------------------------------------------------------------
#
# Both volleyball ladders have promised line judges on four of five rungs since they
# were written, and neither sport had any. That is not only an unkept promise: it left
# the two sports missing a mechanic badminton has had from the start, so the same lie
# was priced differently in different sports for no reason anybody had stated.
#
# What a line judge is *for*, in this game, is cover. They are usually right and least
# reliable exactly when it matters most, and that is the point of them:
#
#   Agree with one who has just got it wrong, and the mistake is shared with an
#   official standing in plain sight. Suspicion halves it.
#
#   Contradict one and the venue has watched two officials disagree in public, with
#   only one call deciding the rally. Suspicion charges 1.6 times, and a little even
#   when the official turns out to have been right.

## How long after the ball lands before they raise the flag. They make their mind up
## the instant it lands and say so a beat later, so an official who calls before the
## flag goes up has still contradicted them rather than dodging the question.
const LINE_JUDGE_DELAY := 0.55

var line_judges: Array[LineJudge] = []

## What the judge on that line said about the rally being judged now.
var _judge_called := false
var _judge_said_in := false


## Where this sport stands its line judges, and which half each of them watches.
##
## Diagonally opposite corners, in every sport that has them. From opposite corners the
## pair of them see all four boundary lines between them; two on the same side cover the
## same two lines twice.
func line_judge_spots() -> Array:
	return []


func build_line_judges() -> void:
	for judge in line_judges:
		judge.queue_free()
	line_judges.clear()

	for spot in line_judge_spots():
		var judge := LineJudge.new()
		judge.name = "LineJudge"
		judge.seated = false
		judge.watches = Sides.half_containing(float(spot["at"].z))
		judge.position = spot["at"]
		add_child(judge)
		line_judges.append(judge)


## Whether this venue has them at all, and how many.
func set_line_judges_present(present: bool) -> void:
	for judge in line_judges:
		judge.visible = present
		judge.silence()


## The judge responsible for the line the ball came down near, if any.
func judge_watching(point: Vector3) -> LineJudge:
	if not _line_judges_present():
		return null
	var half := Sides.half_containing(point.z)
	for judge in line_judges:
		if judge.watches == half:
			return judge
	return null


func _line_judges_present() -> bool:
	for judge in line_judges:
		if judge.visible:
			return true
	return false


## Called the moment the ball lands: the judge on that line makes up their mind, and
## says so a beat later.
func line_judges_watch(point: Vector3, margin: float, was_in: bool) -> void:
	_judge_called = false
	_judge_said_in = false
	var judge := judge_watching(point)
	if judge == null:
		return
	_judge_called = true
	_judge_said_in = judge.decide(margin, was_in)
	_announce_after_a_beat(judge)


func _announce_after_a_beat(judge: LineJudge) -> void:
	await get_tree().create_timer(LINE_JUDGE_DELAY).timeout
	if _phase != Phase.AWAITING_CALL or not is_instance_valid(judge):
		return
	judge.announce(_judge_said_in)
	# Said as well as shown. The bubble is over their head, and in tennis their head is
	# fourteen metres away in a corner the chair is not looking at.
	ui.show_line_judge(_judge_said_in)
	if not _judge_said_in:
		# Only OUT is called aloud, which is what a line judge actually does — a ball
		# they thought was good gets a hand signal and nothing else.
		sound.judge_calls_out(judge.global_position)


func hush_the_line_judges() -> void:
	for judge in line_judges:
		judge.silence()
	ui.hide_line_judge()


# --- accusing somebody ----------------------------------------------------------
#
# Every fault has to name a side: IN and OUT are about the ball, but a net touch or a
# rotation is about a person, so the official points. Both volleyball prompts have
# offered F since they were written and neither had wired it — which left an official
# who wanted to call a fault with nothing that worked, and no way forward, because the
# game was still waiting for a call that could not be made.

func open_the_fault_panel() -> void:
	if _phase != Phase.READY and _phase != Phase.AWAITING_CALL:
		return
	camera.set_active(false)
	# Only the faults, never the cards: a fault between rallies belongs to the rally
	# that has not happened yet, so there is nothing to accuse anybody of.
	if _phase != Phase.AWAITING_CALL:
		return
	ui.show_fault_panel(false)


func close_the_fault_panel() -> void:
	ui.hide_fault_panel()
	camera.set_active(true)


func _on_fault_chosen(id: StringName, team: Sides.Team) -> void:
	close_the_fault_panel()
	make_call(id, team)


## Overridden by each sport, because each has its own book.
func make_call(_id: StringName, _against := Sides.Team.NONE) -> void:
	pass


# --- the mark ------------------------------------------------------------------

## The dent the ball leaves where it landed.
##
## A shuttlecock stops dead when it lands, so the badminton camera can point at it and
## the shuttle is still there. A volleyball bounces — which is right, and which meant
## the camera on the line showed the ball for about a fifth of a second and then a bare
## patch of sand for as long as the official took to decide.
##
## So the landing is marked. This is not a convenience invented for the game: arguing
## about the mark is exactly how a beach line call is settled in the real sport, and
## both sides walk over to look at it.
const MARK_RADIUS := 0.085

var _landing_mark: MeshInstance3D


func _build_the_mark() -> void:
	_landing_mark = MeshInstance3D.new()
	_landing_mark.name = "Mark"
	var disc := CylinderMesh.new()
	disc.top_radius = MARK_RADIUS
	disc.bottom_radius = MARK_RADIUS
	disc.height = 0.004
	disc.radial_segments = 20
	_landing_mark.mesh = disc

	var dent := StandardMaterial3D.new()
	# A shadow in the sand rather than a sticker on it: dark, and see-through enough
	# that the line underneath still reads.
	dent.albedo_color = Color(0.24, 0.18, 0.10, 0.55)
	dent.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dent.roughness = 1.0
	_landing_mark.material_override = dent
	_landing_mark.layers = Ball.COURT_LAYER
	_landing_mark.visible = false
	add_child(_landing_mark)


func mark_the_landing(point: Vector3) -> void:
	# The point is over — every sport on this spine marks the landing at exactly that
	# moment — so the ball is given a beat to bounce and is then stopped. See
	# Ball.let_it_settle: without it a tennis ball was 13.6 m from its own mark and
	# still travelling while the official decided.
	if _ball != null:
		_ball.let_it_settle()
	if _landing_mark == null:
		return
	_landing_mark.global_position = point + Vector3(0.0, 0.002, 0.0)
	_landing_mark.visible = true


func clear_the_mark() -> void:
	if _landing_mark != null:
		_landing_mark.visible = false
