class_name TakrawCutscene
extends Cutscene

## Sepak takraw's four scenes, run the way a sepak takraw match is run.
##
## The camera, captions, coin and officials are badminton's (see Cutscene). The ceremony is
## from three sources, because ISTAF's own Law of the Game covers only the toss (see
## dev/ref/takraw/research.md, section F):
##
## - **ISTAF Law of the Game 2024, Law 8**: the coin toss is made by the **Court Referee** in
##   front of both captains; the winner chooses to serve first.
## - **Sepak Takraw Canada's match protocol**: the teams line up behind their back lines, are
##   announced, and **walk round the court anticlockwise**, shaking hands over the middle of
##   the net; the referee then takes the chair. At the end the referee announces the result,
##   and the players shake the referees' hands at the posts and each other's over the net.
## - **The Thai referees' manual (2012)**: the referee announces "players of both teams shake
##   hands"; the officials stand to the right of the referee's chair while they are introduced.
##
## **There is no whistle.** Nothing in the 2024 regu or doubles rulebooks uses one, and the
## Canadian federation says so outright: the referee's voice runs the match.
##
## Taking a referee off is the **Official Referee**'s job — the only official allowed to stop a
## match (Law 14.3).

const TAKRAW_ENTRANCE := Vector3(TakrawSpec.HALF_WIDTH + 3.0, 0.0, -(TakrawSpec.HALF_LENGTH + 2.2))
const TAKRAW_EXIT := Vector3(TakrawSpec.HALF_WIDTH + 3.2, 0.0, -(TakrawSpec.HALF_LENGTH + 4.2))

## Where the chair's seat is, so a seated official's hips sit on it.
const CHAIR_SEAT := TakrawCourt.EYE_HEIGHT - 0.85


func _chair_x() -> float:
	return TakrawSpec.POST_X + TakrawCourt.STAND_OFFSET


func _on_the_chair() -> Vector3:
	return Vector3(_chair_x(), CHAIR_SEAT - SEATED_HIPS, 0.0)


func _foot_of_the_chair() -> Vector3:
	return Vector3(_chair_x() - 0.8, 0.0, 0.0)


func _team(team: Sides.Team) -> Array[Player]:
	var side: Array[Player] = []
	for player in arena.players:
		if player.team == team:
			side.append(player)
	return side


func _all_arrived() -> bool:
	return arena.players.all(func(p: Player) -> bool: return p.has_arrived())


# --- the walk-on ------------------------------------------------------------------

func walk_on(venue_name: String, doubles: bool) -> Sides.Team:
	var winner := Sides.Team.RED if randf() < 0.5 else Sides.Team.BLUE
	toss_winner = winner
	_open()
	for player in arena.players:
		player.visible = false

	arena.ui.caption("LIVE", [[venue_name.to_upper()]],
		"Sepak takraw   ·   %s" % ("doubles" if doubles else "regu, three a side"))
	await _move(Vector3(-8.5, 6.4, 10.5), Vector3(-7.0, 5.2, 8.6),
		Vector3(0.0, 0.0, 0.0), Vector3(1.0, 0.4, -1.0), 4.0)

	# The teams behind their back lines, announced.
	var back := TakrawSpec.HALF_LENGTH + 1.0
	for team in [Sides.Team.RED, Sides.Team.BLUE]:
		var side := _team(team)
		for i in side.size():
			var x := (float(i) - float(side.size() - 1) * 0.5) * 1.2
			side[i].place(Vector3(x, 0.0, Sides.half_sign(team) * back))
			side[i].visible = true
	arena.ui.caption("THE TEAMS", _teams(" v "), "announced from behind their back lines")
	arena.cheer()
	# High on the far side, over the assistant referee's head rather than behind it.
	_aim(Vector3(-8.0, 4.6, 1.5), Vector3(0.0, 0.6, 0.0), 66.0)
	await _hold(1.8)
	if skipped:
		_close()
		return winner

	# Round the court anticlockwise as seen from above, and hands shaken over the middle of
	# the net. Anticlockwise from above is towards -x from the +z end.
	arena.ui.hide_caption()
	for team in [Sides.Team.RED, Sides.Team.BLUE]:
		var side := _team(team)
		for i in side.size():
			var z := Sides.half_sign(team) * 0.45
			var x := (float(i) - float(side.size() - 1) * 0.5) * 0.8
			side[i].walk_to(Vector3(x, 0.0, z))
	# From the referee's side of the court, where nobody stands between the camera and the net.
	_aim(Vector3(5.4, 1.2, 3.4), Vector3(0.0, 1.0, 0.0), 48.0)
	await _until(_all_arrived, 3.0)
	for player in arena.players:
		player.face(Vector3(player.position.x, 0.0, -player.position.z))
		player.gesture("handshake")
	arena.ui.caption("HANDS", [["OVER THE NET"]], "\"Players of both teams, shake hands\"")
	await _move(Vector3(5.4, 1.2, 3.4), Vector3(4.8, 1.2, 3.9),
		Vector3(0.0, 1.0, 0.0), Vector3(-0.3, 1.0, 0.0), 1.8)
	if skipped:
		_close()
		return winner

	# The Court Referee's coin toss, with the two captains, just outside the sideline and clear
	# of the net, so nothing stands between the camera and the coin.
	arena.ui.hide_caption()
	var toss_at := Vector3(-TakrawSpec.HALF_WIDTH - 1.2, 0.0, 1.8)
	var court_referee := _official(toss_at)
	court_referee.face(toss_at + Vector3.RIGHT)
	for player in arena.players:
		player.visible = false
	for team in [Sides.Team.RED, Sides.Team.BLUE]:
		var captain: Player = _team(team)[0]
		# Either side of the court referee rather than in front, so the camera sees the coin.
		captain.place(toss_at + Vector3(0.35, 0.0, Sides.half_sign(team) * 0.8))
		captain.visible = true
		captain.face(court_referee.position)
	arena.ui.caption("THE TOSS", _teams(" v "), "The court referee tosses with both captains")
	_aim(Vector3(toss_at.x + 4.2, 1.7, toss_at.z + 0.6), toss_at + Vector3(0.3, 1.1, 0.0), 40.0)
	await _hold(1.1)
	arena.ui.hide_caption()
	await _toss(court_referee)
	arena.ui.caption("THE TOSS", [["%s WIN THE TOSS" % Sides.label(winner), Sides.colour(winner)]],
		"and choose to serve")
	await _hold(1.6)
	if skipped:
		_close()
		return winner

	# The referee to the chair, the teams to their places, and the score called.
	arena.ui.hide_caption()
	court_referee.place(Vector3(_chair_x() + 0.3, 0.0, -1.6))
	court_referee.face(Vector3.ZERO)
	var referee := _official(_on_the_chair())
	referee.rotation.y = -PI * 0.5
	referee.sit()
	for player in arena.players:
		player.place(player.home)
		player.visible = true
	arena.ui.caption("FIRST SERVICE", [["%s TO SERVE" % Sides.label(winner), Sides.colour(winner)]],
		"\"Love all\" — the referee calls it, there is no whistle")
	await _move(Vector3(1.0, 2.8, -4.2), Vector3(1.4, 2.7, -3.7),
		Vector3(_chair_x(), CHAIR_SEAT + 0.6, 0.0), Vector3(_chair_x(), CHAIR_SEAT + 0.6, 0.0), 3.0)

	_close()
	return winner


# --- the end of the match ----------------------------------------------------------

## The referee announces the result, then hands: the referees' at the posts, each other's over
## the net, and a wave to the crowd.
func match_won(winner: Sides.Team, score: String, _doubles: bool) -> void:
	_open()
	for player in arena.players:
		if player.team == winner:
			player.celebrate()
		else:
			player.slump()
	arena.cheer()
	var referee := _official(_on_the_chair())
	referee.rotation.y = -PI * 0.5
	referee.sit()

	arena.ui.caption("MATCH", [[Sides.label(winner) + " WIN", Sides.colour(winner)]], score)
	await _move(Vector3(-7.4, 4.2, -7.0), Vector3(-6.2, 3.6, -6.0),
		Vector3(0.0, 0.8, 0.0), Vector3(0.0, 0.9, 0.0), 3.0)
	if skipped:
		_close()
		return

	arena.ui.hide_caption()
	referee.place(_foot_of_the_chair() + Vector3(0.2, 0.0, -1.0))
	referee.face(Vector3.ZERO)
	for team in [Sides.Team.RED, Sides.Team.BLUE]:
		var side := _team(team)
		for i in side.size():
			var spot := Vector3(1.6 - 0.8 * i, 0.0, Sides.half_sign(team) * 0.45)
			side[i].walk_to(spot)
	_aim(Vector3(-0.2, 1.2, -4.4), Vector3(0.8, 1.0, 0.0), 48.0)
	await _until(_all_arrived, 2.5)
	for player in arena.players:
		player.face(Vector3(player.position.x, 0.0, -player.position.z))
		player.gesture("handshake")
	await _hold(1.1)
	for team in [Sides.Team.RED, Sides.Team.BLUE]:
		if skipped:
			break
		var nearest: Player = _team(team)[0]
		referee.face(nearest.position)
		nearest.face(referee.position)
		referee.gesture("handshake")
		nearest.gesture("handshake")
		await _hold(1.0)
	if skipped:
		_close()
		return

	for player in _team(winner):
		player.face(Vector3(-12.0, 0.0, player.position.z))
		player.celebrate()
	arena.cheer()
	await _move(Vector3(-2.0, 3.2, -6.8), Vector3(-2.6, 3.0, -6.2),
		Vector3(0.0, 0.8, 0.0), Vector3(-2.0, 0.8, 0.0), 2.4)
	_close()


# --- taken off ---------------------------------------------------------------------

func taken_off(venue_name: String) -> void:
	_open()
	arena.jeer(0.9)
	var referee := _official(_on_the_chair())
	referee.rotation.y = -PI * 0.5
	referee.sit()
	for player in arena.players:
		player.go_home()

	var official := _official(TAKRAW_ENTRANCE)
	official.speed = 1.8
	var beside_the_chair := Vector3(_chair_x() - 0.7, 0.0, -1.4)
	official.walk_to(beside_the_chair)
	arena.ui.caption("THE OFFICIAL REFEREE", [["REFEREE REMOVED", UiTheme.RED]],
		"The one official who may stop a match")
	await _follow(Vector3(0.2, 2.6, -7.2), Vector3(1.2, 2.4, -4.8), official, 4.6, 50.0)
	await _until(official.has_arrived, 2.0)
	for player in arena.players:
		player.face(referee.position)
	official.face(referee.position)
	await _hold(0.5)
	if skipped:
		_close()
		return

	await arena.ui.blackout(true, 0.25).finished
	referee.place(_foot_of_the_chair() + Vector3(0.0, 0.0, -0.5))
	referee.face(official.position)
	official.face(referee.position)
	official.right_arm_towards(TAKRAW_EXIT - official.position)
	official.gesture("point")
	_aim(Vector3(_chair_x() + 2.2, 1.7, -3.4), Vector3(_chair_x() - 0.8, 1.35, -1.0), 46.0)
	arena.ui.hide_caption()
	await arena.ui.blackout(false, 0.25).finished
	await _hold(1.4)

	referee.walk_to(TAKRAW_EXIT)
	get_tree().create_timer(0.7).timeout.connect(func() -> void:
		if _running and not skipped:
			official.walk_to(TAKRAW_EXIT + Vector3(-0.6, 0.0, 0.9)))
	arena.ui.caption("TAKEN OFF THE MATCH", [["YOU", UiTheme.RED]],
		"Sepak takraw   ·   %s" % venue_name)
	await _follow(Vector3(-0.5, 3.6, -1.0), Vector3(0.4, 3.8, -3.0), referee, 4.6, 50.0)
	await arena.ui.blackout(true, 0.5).finished
	_close()


# --- moved up ----------------------------------------------------------------------

func moved_up(venue: Dictionary) -> void:
	_open()
	arena.ui.blackout(true, 0.0)
	await get_tree().process_frame
	for player in arena.players:
		player.visible = false
	arena.set_line_judges_present(venue["line_judges"])
	arena.dress_the_venue(venue)
	await get_tree().process_frame
	arena.ui.blackout(false, 0.7)

	var from := Vector3(-1.5, 0.5, -7.5)
	var to := Vector3(-9.0, 8.0, 11.0)
	var look_from := Vector3(0.0, 1.0, 0.0)
	var look_to := Vector3(1.0, 0.0, -1.0)
	const RISE := 6.5
	const NAMED_AT := 1.4
	var named := false
	var t := 0.0
	_aim(from, look_from, 50.0)
	while t < RISE + 1.2 and not skipped:
		await get_tree().process_frame
		t += get_process_delta_time()
		var f := smoothstep(0.0, 1.0, clampf(t / RISE, 0.0, 1.0))
		_aim(from.lerp(to, f), look_from.lerp(look_to, f))
		if t >= NAMED_AT and not named:
			named = true
			arena.ui.caption("PROMOTED", [[String(venue["name"]).to_upper()]],
				String(venue["blurb"]))
			arena.cheer()
			arena.sound.set_won()
	await arena.ui.blackout(true, 0.5).finished
	_close()
