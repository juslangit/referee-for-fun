class_name VolleyCutscene
extends Cutscene

## Indoor volleyball's four scenes, done the way an FIVB first referee does them.
##
## The camera, captions, coin and officials are badminton's (see Cutscene); the ceremony is
## the FIVB's own, from the *Refereeing Guidelines and Instructions* (2024 edition), its
## International Playing Protocol and "Referees' procedures – before, during and after the
## match", and the *Official Volleyball Rules 2025–2028*:
##
## - **The toss** is carried out by the 1st referee in front of the scorer's table, in the
##   presence of both team captains, before the warm-up (Rule 7.1).
## - **The teams enter and line up on the end lines.** At the 1st referee's whistle the
##   players move forward and shake hands with their opposite number at the net.
## - **The referees are presented** in the middle of the court close to the net, facing the
##   scorer's table, and then the 1st referee goes to the referee's stand.
## - **After the match** the referees stand in front of the referee's chair; the teams come
##   along the sidelines, shake the referees' hands, then walk along the net shaking hands
##   with their opponents.
## - **Removing a referee** is not something a team can ask for; it is the Game Technical
##   Delegate who would come to the stand.
##
## **There is no 2nd referee**, for the reason table tennis has no assistant umpire: this
## game referees indoor volleyball with the 1st referee alone, and a figure who appeared for
## the ceremony and vanished for the match would be worse than none. Asked of Luqman.
##
## The first referee *stands* on a platform, rather than sitting as every other official in
## this game does, so the stand scenes put the figure on its feet at the platform's height.

## The top of the stand's platform, from VolleyCourt._build_referee_stand: a frame
## EYE_HEIGHT less 1.55 tall with an 8 cm platform on it.
const PLATFORM_TOP := VolleyCourt.EYE_HEIGHT - 1.55 + 0.04

## The scorer's table is across the court from the referee's stand.
const SCORERS_SIDE := -(VolleySpec.HALF_WIDTH + 1.9)

## How far from the net line, along the scorer's table, the toss is made.
const TOSS_ALONG := 2.2

## Where the delegate comes on from, and a removed referee goes: the corner behind the
## stand at RED's end, inside the hall's walls.
const VB_ENTRANCE := Vector3(VolleySpec.HALF_WIDTH + 3.2, 0.0, -(VolleySpec.HALF_LENGTH - 1.0))
const VB_EXIT := Vector3(VolleySpec.HALF_WIDTH + 3.4, 0.0, -(VolleySpec.HALF_LENGTH + 3.0))


func _stand_x() -> float:
	return VolleySpec.POST_X + VolleyCourt.STAND_OFFSET


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


## Across a line of six, 1.5 m apart, the way the teams stand on their end lines.
func _along(i: int, count: int) -> float:
	return (float(i) - float(count - 1) * 0.5) * 1.5


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

	arena.ui.caption("LIVE", [[venue_name.to_upper()]], "Volleyball   ·   six a side")
	await _move(Vector3(-8.0, 7.0, 13.0), Vector3(-6.6, 5.6, 10.4),
		Vector3(0.0, 0.0, 0.0), Vector3(1.0, 0.5, -1.0), 4.0)

	# The toss, in front of the scorer's table, with the two captains (Rule 7.1).
	# A couple of metres along from the net, or the post stands between the camera and them.
	var toss_at := Vector3(SCORERS_SIDE - 0.2, 0.0, TOSS_ALONG)
	var referee := _official(toss_at)
	referee.face(toss_at + Vector3.RIGHT)
	var captains := {}
	for team in [Sides.Team.RED, Sides.Team.BLUE]:
		var captain: Player = _team(team)[0]
		captains[team] = captain
		captain.place(toss_at + Vector3(0.75, 0.0, Sides.half_sign(team) * 0.7))
		captain.visible = true
		captain.face(referee.position)
	arena.ui.caption("BEFORE THE WARM-UP", _teams(" v "), "The toss, with both captains")
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

	# Both teams on their end lines, and the whistle.
	arena.ui.hide_caption()
	referee.place(Vector3(0.0, 0.0, -1.3))
	referee.visible = false
	for team in [Sides.Team.RED, Sides.Team.BLUE]:
		var side := _team(team)
		for i in side.size():
			side[i].visible = true
			side[i].place(Vector3(_along(i, side.size()), 0.0, Sides.half_sign(team) * VolleySpec.HALF_LENGTH))
			side[i].face(Vector3(side[i].position.x, 0.0, 0.0))
	arena.ui.caption("THE TEAMS", [["ON THE END LINES"]], "then forward to the net at the whistle")
	_aim(Vector3(-7.4, 6.2, -14.0), Vector3(0.0, 0.0, 0.0), 52.0)
	await _hold(1.4)
	_whistle()
	for player in arena.players:
		player.walk_to(Vector3(player.position.x, 0.0, Sides.half_sign(player.team) * 0.6))
	await _hold(1.6)

	# Cut to the net as they arrive, each to their opposite number.
	arena.ui.hide_caption()
	for player in arena.players:
		var x := player.position.x
		player.place(Vector3(x, 0.0, Sides.half_sign(player.team) * 2.0))
		player.walk_to(Vector3(x, 0.0, Sides.half_sign(player.team) * 0.6))
	# Below the bottom of the net (1.43 m), which otherwise hides everybody from the chest up.
	_aim(Vector3(-7.0, 1.05, 4.2), Vector3(0.0, 1.1, 0.0), 46.0)
	await _until(func() -> bool:
		return arena.players.all(func(p: Player) -> bool: return p.has_arrived()), 2.5)
	for player in arena.players:
		player.face(Vector3(player.position.x, 0.0, -player.position.z))
		player.gesture("handshake")
	await _move(Vector3(-7.0, 1.05, 4.2), Vector3(-6.0, 1.05, 4.6),
		Vector3(0.0, 1.1, 0.0), Vector3(0.6, 1.1, 0.0), 1.8)
	if skipped:
		_close()
		return winner

	# The referees are presented in the middle of the court, facing the scorer's table, while
	# the teams wait at their benches.
	for player in arena.players:
		player.visible = false
		player.place(player.home)
	referee.visible = true
	referee.face(Vector3(SCORERS_SIDE, 0.0, -1.3))
	arena.ui.caption("PRESENTED", [["FIRST REFEREE"]], "you")
	_aim(Vector3(-4.6, 1.7, -2.6), Vector3(0.0, 1.35, -1.3), 38.0)
	await _hold(2.4)

	# Up to the stand, the starting six on court, and the whistle for the first service.
	for player in arena.players:
		player.visible = true
	referee.place(_on_the_stand())
	referee.rotation.y = -PI * 0.5
	arena.ui.caption("FIRST SERVICE", [["%s TO SERVE" % Sides.label(winner), Sides.colour(winner)]],
		"the 1st referee's whistle")
	_whistle()
	await _move(Vector3(1.4, 3.2, -5.0), Vector3(1.9, 3.1, -4.4),
		Vector3(_stand_x(), 2.7, 0.0), Vector3(_stand_x(), 2.7, 0.0), 3.0)

	for player in arena.players:
		player.visible = true
	_close()
	return winner


# --- the end of the match ----------------------------------------------------------

## The result, the referees in front of the stand shaking hands with the teams as they come
## along the sidelines, and the teams along the net.
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
	await _move(Vector3(-7.6, 4.6, -8.5), Vector3(-6.6, 4.0, -7.4),
		Vector3(0.0, 0.8, 0.0), Vector3(0.0, 0.9, 0.0), 3.0)
	if skipped:
		_close()
		return

	# Down in front of the stand; each team's first player along the sideline to shake hands.
	arena.ui.hide_caption()
	referee.place(_foot_of_the_stand())
	referee.face(_foot_of_the_stand() + Vector3.LEFT)
	var first := {}
	for team in [Sides.Team.RED, Sides.Team.BLUE]:
		var player: Player = _team(team)[0]
		first[team] = player
		var spot := Vector3(_foot_of_the_stand().x - 0.4, 0.0, Sides.half_sign(team) * 0.7)
		player.place(spot + Vector3(-0.2, 0.0, Sides.half_sign(team) * 1.8))
		player.walk_to(spot)
	_aim(Vector3(1.6, 1.8, 3.0), _foot_of_the_stand() + Vector3(0.0, 1.2, 0.0), 42.0)
	await _until(func() -> bool:
		return first.values().all(func(p: Player) -> bool: return p.has_arrived()), 2.5)
	for team in [Sides.Team.RED, Sides.Team.BLUE]:
		if skipped:
			break
		var player: Player = first[team]
		referee.face(player.position)
		player.face(referee.position)
		referee.gesture("handshake")
		player.gesture("handshake")
		await _hold(1.05)
	if skipped:
		_close()
		return

	# And along the net, every one of them.
	for team in [Sides.Team.RED, Sides.Team.BLUE]:
		var side := _team(team)
		for i in side.size():
			side[i].place(Vector3(_along(i, side.size()), 0.0, Sides.half_sign(team) * 0.6))
			side[i].face(Vector3(side[i].position.x, 0.0, 0.0))
			side[i].gesture("handshake")
	arena.cheer()
	await _move(Vector3(-7.0, 1.05, 4.2), Vector3(-5.2, 1.05, 4.8),
		Vector3(-0.5, 1.1, 0.0), Vector3(1.0, 1.1, 0.0), 2.6)
	_close()


# --- taken off ---------------------------------------------------------------------

## The Game Technical Delegate comes to the stand, and the referee is shown the way out.
func taken_off(venue_name: String) -> void:
	_open()
	arena.jeer(0.9)
	var referee := _official(_on_the_stand())
	referee.rotation.y = -PI * 0.5
	for player in arena.players:
		player.go_home()

	var delegate := _official(VB_ENTRANCE)
	delegate.speed = 1.8
	var beside_the_stand := Vector3(_stand_x() - 0.6, 0.0, -1.2)
	delegate.walk_to(beside_the_stand)
	arena.ui.caption("THE TECHNICAL DELEGATE", [["REFEREE REMOVED", UiTheme.RED]],
		"Coming to the stand to take over the match")
	await _follow(Vector3(0.6, 2.4, -7.5), Vector3(1.6, 2.3, -4.8), delegate, 4.4, 46.0)
	await _until(delegate.has_arrived, 2.0)
	for player in arena.players:
		player.face(referee.position)
	delegate.face(referee.position)
	await _hold(0.5)
	if skipped:
		_close()
		return

	await arena.ui.blackout(true, 0.25).finished
	# Both on RED's side of the net line, and the camera with them: from the other side the
	# net band hid the pair of them.
	referee.place(_foot_of_the_stand() + Vector3(0.0, 0.0, -0.5))
	referee.face(delegate.position)
	delegate.face(referee.position)
	delegate.right_arm_towards(VB_EXIT - delegate.position)
	delegate.gesture("point")
	# From outside the sideline behind the stand, where no player is standing between.
	_aim(Vector3(_stand_x() + 2.4, 1.7, -3.6), Vector3(_stand_x() - 0.7, 1.35, -0.9), 46.0)
	arena.ui.hide_caption()
	await arena.ui.blackout(false, 0.25).finished
	await _hold(1.4)

	referee.walk_to(VB_EXIT)
	get_tree().create_timer(0.7).timeout.connect(func() -> void:
		if _running and not skipped:
			delegate.walk_to(VB_EXIT + Vector3(-0.6, 0.0, 0.9)))
	arena.ui.caption("TAKEN OFF THE MATCH", [["YOU", UiTheme.RED]],
		"Volleyball   ·   %s" % venue_name)
	await _follow(Vector3(0.2, 3.6, 1.5), Vector3(1.0, 3.8, -0.8), referee, 4.6, 50.0)
	await arena.ui.blackout(true, 0.5).finished
	_close()


# --- moved up ----------------------------------------------------------------------

## The next hall, from the floor beside the net up over the court.
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

	var from := Vector3(-1.5, 0.5, -10.0)
	var to := Vector3(-8.0, 8.5, 13.0)
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
