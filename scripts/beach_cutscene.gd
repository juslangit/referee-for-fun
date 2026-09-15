class_name BeachCutscene
extends Cutscene

## Beach volleyball's four scenes, done the way the FIVB's beach Official Match Protocol runs a
## match.
##
## The camera, captions, coin and officials are badminton's (see Cutscene); the ceremony is
## from the FIVB *Beach Volleyball Refereeing Guidelines and Instructions* (2023), "Official
## Match Protocol":
##
## - **-5 min: the coin toss** in front of the scorer's table, with the captains.
## - **-1 min: the first referee to the referee's chair**, and each player is announced and
##   **enters onto the rear of the court** one at a time.
## - **After the last player's entry the first referee whistles** and the players shake hands
##   under the net. Then the match.
## - **At the end** the players shake hands with their opponents and the referees **near the
##   first referee's chair**, and cross the court to the scorer's table.
## - **Taking a referee off** belongs to the FIVB Technical Delegate.
##
## As indoors, **there is no second referee**: this game has only the first referee in play.
## And as indoors, the first referee stands on a platform rather than sitting.

const PLATFORM_TOP := BeachCourt.EYE_HEIGHT - 1.55 + 0.04
const SCORERS_SIDE := -(BeachSpec.HALF_WIDTH + 2.0)
const TOSS_ALONG := 2.0
const BEACH_ENTRANCE := Vector3(BeachSpec.HALF_WIDTH + 3.0, 0.0, -(BeachSpec.HALF_LENGTH + 2.5))
const BEACH_EXIT := Vector3(BeachSpec.HALF_WIDTH + 3.2, 0.0, -(BeachSpec.HALF_LENGTH + 4.5))


func _stand_x() -> float:
	return BeachSpec.POST_X + BeachCourt.STAND_OFFSET


func _on_the_stand() -> Vector3:
	return Vector3(_stand_x(), PLATFORM_TOP, 0.0)


func _foot_of_the_stand() -> Vector3:
	return Vector3(_stand_x() - 0.8, 0.0, 0.0)


func _team(team: Sides.Team) -> Array[Player]:
	var side: Array[Player] = []
	for player in arena.players:
		if player.team == team:
			side.append(player)
	return side


func _whistle() -> void:
	if arena.sound != null and arena.sound.has_method("whistle"):
		arena.sound.whistle()


# --- the walk-on ------------------------------------------------------------------

func walk_on(venue_name: String, _doubles: bool) -> Sides.Team:
	var winner := Sides.Team.RED if randf() < 0.5 else Sides.Team.BLUE
	toss_winner = winner
	_open()
	for player in arena.players:
		player.visible = false

	arena.ui.caption("LIVE", [[venue_name.to_upper()]], "Beach volleyball   ·   two a side")
	await _move(Vector3(-9.0, 7.0, 12.5), Vector3(-7.4, 5.6, 10.0),
		Vector3(0.0, 0.0, 0.0), Vector3(1.0, 0.5, -1.0), 4.0)

	# The coin toss in front of the scorer's table.
	var toss_at := Vector3(SCORERS_SIDE - 0.2, 0.0, TOSS_ALONG)
	var referee := _official(toss_at)
	referee.face(toss_at + Vector3.RIGHT)
	for team in [Sides.Team.RED, Sides.Team.BLUE]:
		var captain: Player = _team(team)[0]
		captain.place(toss_at + Vector3(0.75, 0.0, Sides.half_sign(team) * 0.7))
		captain.visible = true
		captain.face(referee.position)
	arena.ui.caption("FIVE MINUTES TO PLAY", _teams(" v "), "The coin toss, in front of the scorer's table")
	_aim(Vector3(SCORERS_SIDE + 3.6, 1.7, TOSS_ALONG), toss_at + Vector3(0.4, 1.2, 0.0), 40.0)
	await _hold(1.2)
	arena.ui.hide_caption()
	await _toss(referee)
	arena.ui.caption("THE TOSS", [["%s WIN THE TOSS" % Sides.label(winner), Sides.colour(winner)]],
		"and choose to serve")
	await _hold(1.6)
	if skipped:
		_close()
		return winner

	# The first referee to the chair; each player announced onto the rear of the court.
	arena.ui.hide_caption()
	for player in arena.players:
		player.visible = false
	referee.place(_on_the_stand())
	referee.rotation.y = -PI * 0.5
	_aim(Vector3(-8.2, 4.6, -5.0), Vector3(0.0, 0.3, 1.2), 50.0)
	var order: Array[Player] = []
	for i in 2:
		for team in [Sides.Team.RED, Sides.Team.BLUE]:
			order.append(_team(team)[i])
	for i in order.size():
		if skipped:
			break
		var player := order[i]
		var side := Sides.half_sign(player.team)
		var x := -1.4 if _team(player.team).find(player) == 0 else 1.4
		player.place(Vector3(x, 0.0, side * (BeachSpec.HALF_LENGTH + 2.5)))
		player.visible = true
		player.walk_to(Vector3(x, 0.0, side * (BeachSpec.HALF_LENGTH - 0.5)))
		arena.ui.caption("ON COURT", [[Sides.label(player.team), Sides.colour(player.team)],
			["PLAYER %d" % (_team(player.team).find(player) + 1)]], "announced, onto the rear of the court")
		arena.cheer()
		await _hold(1.1)
	await _until(func() -> bool:
		return arena.players.all(func(p: Player) -> bool: return p.has_arrived()), 2.5)
	arena.ui.hide_caption()

	# The whistle after the last entry, and hands shaken under the net.
	_whistle()
	for player in arena.players:
		var x := player.position.x
		var side := Sides.half_sign(player.team)
		player.place(Vector3(x, 0.0, side * 2.0))
		player.walk_to(Vector3(x, 0.0, side * 0.6))
	_aim(Vector3(-6.6, 1.05, 3.9), Vector3(0.0, 1.1, 0.0), 46.0)
	await _until(func() -> bool:
		return arena.players.all(func(p: Player) -> bool: return p.has_arrived()), 2.5)
	for player in arena.players:
		player.face(Vector3(player.position.x, 0.0, -player.position.z))
		player.gesture("handshake")
	await _move(Vector3(-6.6, 1.05, 3.9), Vector3(-5.6, 1.05, 4.3),
		Vector3(0.0, 1.1, 0.0), Vector3(0.4, 1.1, 0.0), 1.8)

	# To their places, and the first service.
	for player in arena.players:
		player.place(player.home)
	arena.ui.caption("FIRST SERVICE", [["%s TO SERVE" % Sides.label(winner), Sides.colour(winner)]],
		"the first referee's whistle")
	_whistle()
	await _move(Vector3(1.2, 3.2, -4.6), Vector3(1.7, 3.1, -4.0),
		Vector3(_stand_x(), 2.7, 0.0), Vector3(_stand_x(), 2.7, 0.0), 3.0)

	for player in arena.players:
		player.visible = true
	_close()
	return winner


# --- the end of the match ----------------------------------------------------------

## Hands shaken with the opponents and the referee near the first referee's chair, then
## across the court to the scorer's table.
func match_won(winner: Sides.Team, score: String, _doubles: bool) -> void:
	_open()
	for player in arena.players:
		if player.team == winner:
			player.celebrate()
		else:
			player.slump()
	arena.cheer()
	var referee := _official(_on_the_stand())
	referee.rotation.y = -PI * 0.5

	arena.ui.caption("MATCH", [[Sides.label(winner) + " WIN", Sides.colour(winner)]], score)
	await _move(Vector3(-8.0, 4.6, -8.0), Vector3(-6.8, 4.0, -6.8),
		Vector3(0.0, 0.8, 0.0), Vector3(0.0, 0.9, 0.0), 3.0)
	if skipped:
		_close()
		return

	# Near the chair: the referee down, the four of them either side of the net beside it.
	arena.ui.hide_caption()
	# Out in front of the stand's leg, towards the camera, or the leg hides them.
	var beside := _foot_of_the_stand() + Vector3(0.2, 0.0, -1.1)
	referee.place(beside)
	referee.face(beside + Vector3.LEFT)
	var spots := {}
	for team in [Sides.Team.RED, Sides.Team.BLUE]:
		var side := _team(team)
		for i in side.size():
			var spot := Vector3(_foot_of_the_stand().x - 0.9 - 0.8 * i, 0.0, Sides.half_sign(team) * 0.6)
			spots[side[i]] = spot
			side[i].place(spot + Vector3(-1.2, 0.0, Sides.half_sign(team) * 1.6))
			side[i].walk_to(spot)
	# From RED's side and below the bottom of the net, so nobody is behind it.
	_aim(Vector3(0.8, 1.25, -4.8), Vector3(_foot_of_the_stand().x - 0.8, 1.1, -0.4), 48.0)
	await _until(func() -> bool:
		return arena.players.all(func(p: Player) -> bool: return p.has_arrived()), 2.5)
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

	# And across the court to the scorer's table.
	for player in arena.players:
		player.walk_to(Vector3(SCORERS_SIDE + 0.8, 0.0, player.position.z))
	arena.cheer()
	await _move(Vector3(-2.0, 3.6, -7.5), Vector3(-2.6, 3.4, -6.8),
		Vector3(0.0, 0.8, 0.0), Vector3(-2.0, 0.8, 0.0), 2.6)
	_close()


# --- taken off ---------------------------------------------------------------------

func taken_off(venue_name: String) -> void:
	_open()
	arena.jeer(0.9)
	var referee := _official(_on_the_stand())
	referee.rotation.y = -PI * 0.5
	for player in arena.players:
		player.go_home()

	var delegate := _official(BEACH_ENTRANCE)
	delegate.speed = 1.8
	var beside_the_stand := Vector3(_stand_x() - 0.7, 0.0, -1.5)
	delegate.walk_to(beside_the_stand)
	arena.ui.caption("THE TECHNICAL DELEGATE", [["REFEREE REMOVED", UiTheme.RED]],
		"Coming to the stand to take over the match")
	await _follow(Vector3(0.2, 2.8, -8.0), Vector3(1.2, 2.6, -5.4), delegate, 4.6, 50.0)
	await _until(delegate.has_arrived, 2.0)
	for player in arena.players:
		player.face(referee.position)
	delegate.face(referee.position)
	await _hold(0.5)
	if skipped:
		_close()
		return

	await arena.ui.blackout(true, 0.25).finished
	referee.place(_foot_of_the_stand() + Vector3(0.0, 0.0, -0.5))
	referee.face(delegate.position)
	delegate.face(referee.position)
	delegate.right_arm_towards(BEACH_EXIT - delegate.position)
	delegate.gesture("point")
	# From outside the sideline behind the stand, where no player is standing between.
	_aim(Vector3(_stand_x() + 2.4, 1.7, -3.6), Vector3(_stand_x() - 0.8, 1.35, -1.0), 46.0)
	arena.ui.hide_caption()
	await arena.ui.blackout(false, 0.25).finished
	await _hold(1.4)

	referee.walk_to(BEACH_EXIT)
	get_tree().create_timer(0.7).timeout.connect(func() -> void:
		if _running and not skipped:
			delegate.walk_to(BEACH_EXIT + Vector3(-0.6, 0.0, 0.9)))
	arena.ui.caption("TAKEN OFF THE MATCH", [["YOU", UiTheme.RED]],
		"Beach volleyball   ·   %s" % venue_name)
	await _follow(Vector3(-0.5, 3.8, -1.0), Vector3(0.4, 4.0, -3.0), referee, 4.6, 50.0)
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

	var from := Vector3(-1.5, 0.5, -9.0)
	var to := Vector3(-10.0, 9.0, 13.0)
	var look_from := Vector3(0.0, 1.2, 0.0)
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
