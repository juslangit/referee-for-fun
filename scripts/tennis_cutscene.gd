class_name TennisCutscene
extends Cutscene

## Tennis's four scenes, done the way a chair umpire does them.
##
## The camera, the captions, the coin and the officials are badminton's (see Cutscene);
## everything that happens on court is tennis's own, from the ITF's *Duties and Procedures
## for Officials* (2026):
##
## - **The chair umpire is on court before the players arrive** (D.4), so nobody leads
##   anybody on. The umpire waits at the chair and the players walk out to them.
## - **The toss is made in the presence of both players, before the warm-up** (D.5b), and
##   it decides the choice of serve. In this game whoever wins it serves.
## - **The introduction is made from the chair** (G.2a): "To the left of the chair …, and
##   to the right of the chair … … won the toss and elected to serve." Then "Time", and
##   "… to serve, play" (G.1a).
## - **At the end the winner is announced at once** (G.4h, "Game, set and match …" and every
##   set's score), and only then do the players shake hands at the net and with the umpire.
## - **Taking an umpire off is the Supervisor's decision** (section T), so it is the
##   Supervisor who comes onto court.
##
## Every position is read from TennisSpec and TennisCourt. Luqman chose "each sport's real
## procedure", one sport at a time, tennis first, on 2026-09-15.

## Where the players and the Supervisor come on: the chair's side of the court, behind the
## baseline at RED's end, near enough that the walk to the net is a walk and not a trek.
const TENNIS_ENTRANCE := Vector3(7.4, 0.0, -9.6)

## Where a removed umpire is walked off to: back the way everybody came in.
const TENNIS_EXIT := Vector3(7.6, 0.0, -12.5)

## The top of the chair's seat, from TennisCourt._build_chair: the frame is EYE_HEIGHT
## less 1.35 tall and the seat board on top of it is 8 cm thick.
const TENNIS_SEAT_TOP := TennisCourt.EYE_HEIGHT - 1.35 + 0.04


func _chair_x() -> float:
	return TennisSpec.POST_X + TennisCourt.CHAIR_OFFSET


## Where the umpire stands at the foot of the chair, facing the court.
func _foot_of_the_chair() -> Vector3:
	return Vector3(_chair_x() - 0.75, 0.0, 0.0)


func _seat() -> Vector3:
	return Vector3(_chair_x() + 0.2, TENNIS_SEAT_TOP - SEATED_HIPS, 0.0)


## Where each player stands to meet the umpire: beyond the net post, where there is no net
## between them, each on the side of their own end.
func _meeting_spots(file: Array[Player]) -> Dictionary:
	var tennis := arena as TennisMatch
	var spots := {}
	var counts := {Sides.Team.RED: 0, Sides.Team.BLUE: 0}
	for player in file:
		var i: int = counts[player.team]
		counts[player.team] = i + 1
		var end := tennis.end_of(player.team)
		# Wide enough apart that a camera on the court sees the umpire between them.
		spots[player] = Vector3(_chair_x() - 1.5 - 0.25 * i, 0.0, end * (0.9 + 0.7 * i))
	return spots


## From the court, high enough to see over the net, square on to the umpire with a player
## either side. The first version stood off to one side and put a player in front of them.
func _meeting_camera() -> Vector3:
	return Vector3(_chair_x() - 4.2, 2.2, 0.0)


func _file() -> Array[Player]:
	var file: Array[Player] = []
	for team in [Sides.Team.RED, Sides.Team.BLUE]:
		for player in arena.players:
			if player.team == team:
				file.append(player)
	return file


# --- the walk-on ------------------------------------------------------------------

func walk_on(venue_name: String, doubles: bool) -> Sides.Team:
	var winner := Sides.Team.RED if randf() < 0.5 else Sides.Team.BLUE
	toss_winner = winner
	_open()
	var tennis := arena as TennisMatch

	# D.4: the umpire is already there.
	var umpire := _official(_foot_of_the_chair())
	umpire.face(_foot_of_the_chair() + Vector3.FORWARD)

	var file := _file()
	var spots := _meeting_spots(file)
	for player in file:
		player.visible = false
		player.place(TENNIS_ENTRANCE)

	arena.ui.caption("LIVE", [[venue_name.to_upper()]],
		"Tennis   ·   %s" % ("doubles" if doubles else "singles"))
	await _move(Vector3(-13.0, 9.5, 19.0), Vector3(-10.5, 7.0, 13.0),
		Vector3(0.0, 0.0, 0.0), Vector3(3.0, 0.5, -2.0), 4.2)

	# Out they come, one after another, to the umpire waiting at the chair.
	for i in file.size():
		var player := file[i]
		var spot: Vector3 = spots[player]
		get_tree().create_timer(0.6 * float(i)).timeout.connect(func() -> void:
			if not _running or skipped:
				return
			player.visible = true
			player.walk_to(spot))
	arena.ui.caption("TODAY", _teams(" v "), "Chair umpire   ·   you")
	await _follow(Vector3(3.2, 1.9, -12.5), Vector3(4.4, 1.8, -7.5), file[0], 5.0, 42.0)
	await _until(func() -> bool:
		return file.all(func(p: Player) -> bool: return p.has_arrived()), 4.0)
	arena.ui.hide_caption()
	for player in file:
		player.visible = true
		player.face(umpire.position)
	umpire.face(_foot_of_the_chair() + Vector3.LEFT)

	# The toss, with both of them there (D.5b). Wider for four, or the outside pair are cut off.
	_aim(_meeting_camera(), _foot_of_the_chair() + Vector3(0.0, 1.25, 0.0), 48.0 if doubles else 38.0)
	await _hold(0.6)
	await _toss(umpire)
	arena.ui.caption("THE TOSS", [["%s WIN THE TOSS" % Sides.label(winner), Sides.colour(winner)]],
		"and elect to serve")
	await _hold(1.8)

	# To their ends, and the umpire up into the chair for the introduction (G.2a). The chair
	# faces the court, so the end on the chair's left is the end at +z.
	for player in arena.players:
		player.go_home()
	umpire.place(_seat())
	umpire.rotation.y = -PI * 0.5
	umpire.sit()
	var left := Sides.Team.RED if tennis.end_of(Sides.Team.RED) > 0.0 else Sides.Team.BLUE
	var right := Sides.opponent(left)
	arena.ui.caption("LADIES AND GENTLEMEN", [
		["TO THE LEFT OF THE CHAIR"], [Sides.label(left), Sides.colour(left)],
		["TO THE RIGHT"], [Sides.label(right), Sides.colour(right)],
	], "%s won the toss and elected to serve" % Sides.label(winner))
	await _move(Vector3(1.4, 2.5, -3.2), Vector3(2.0, 2.4, -2.5),
		Vector3(_chair_x(), 2.2, 0.0), Vector3(_chair_x(), 2.3, 0.0), 3.8)

	# "Time", and the first serve called (G.1a), from high behind the server's baseline, where
	# television puts its main camera. Looking along the net showed only the net, edge on.
	var end := tennis.end_of(winner)
	arena.ui.caption("TIME", [["%s TO SERVE" % Sides.label(winner), Sides.colour(winner)]], "play")
	await _move(Vector3(0.0, 6.0, end * 22.0), Vector3(0.0, 5.4, end * 20.5),
		Vector3(0.0, 0.0, -end * 2.0), Vector3(0.0, 0.3, -end * 3.0), 2.6)

	for player in file:
		player.visible = true
	_close()
	return winner


# --- the end of the match ----------------------------------------------------------

## The result first (G.4h), then the handshakes at the net, then with the umpire, who has
## come down from the chair for them.
##
## A tennis court is twenty-four metres long, and walked at an official's pace the players
## took nine seconds to reach the net: the first version shook hands eight metres apart. So
## the picture cuts, the way television does, while they are on their way — once to the net
## and once to the chair.
func match_won(winner: Sides.Team, score: String, doubles: bool) -> void:
	_open()
	var tennis := arena as TennisMatch
	var champion: Player = null
	for player in arena.players:
		if player.team == winner:
			player.celebrate()
			if champion == null:
				champion = player
		else:
			player.slump()
	arena.cheer()

	# The winner, close, from the net side of them.
	var end := tennis.end_of(winner)
	var at := champion.position
	arena.ui.caption("GAME, SET AND MATCH", [[Sides.label(winner), Sides.colour(winner)]], score)
	await _move(at + Vector3(-2.2, 1.5, -end * 4.2), at + Vector3(-1.6, 1.4, -end * 3.4),
		at + Vector3(0.0, 1.1, 0.0), at + Vector3(0.0, 1.0, 0.0), 3.0)
	if skipped:
		_close()
		return

	# Cut, and they are nearly at the net.
	var across := [0.0] if not doubles else [-0.8, 0.8]
	var counts := {Sides.Team.RED: 0, Sides.Team.BLUE: 0}
	for player in arena.players:
		var i: int = counts[player.team]
		counts[player.team] = i + 1
		var x: float = across[mini(i, across.size() - 1)]
		var side := tennis.end_of(player.team)
		player.place(Vector3(x - 0.6, 0.0, side * 2.6))
		player.walk_to(Vector3(x, 0.0, side * 0.45))
	arena.ui.hide_caption()
	# From the side and a little above, never along the net, which hides everybody behind it.
	_aim(Vector3(-4.6, 1.9, 4.2), Vector3(0.0, 1.05, 0.0), 40.0)
	await _until(func() -> bool:
		return arena.players.all(func(p: Player) -> bool: return p.has_arrived()), 3.5)
	for player in arena.players:
		player.face(Vector3(player.position.x, 0.0, -player.position.z))
		player.gesture("handshake")
	await _move(Vector3(-4.6, 1.9, 4.2), Vector3(-3.9, 1.8, 3.6),
		Vector3(0.0, 1.05, 0.0), Vector3(0.0, 1.05, 0.0), 1.8)
	if skipped:
		_close()
		return

	# Cut again: the umpire is down, and they are coming over to the chair.
	var umpire := _official(_foot_of_the_chair())
	umpire.face(_foot_of_the_chair() + Vector3.LEFT)
	var file := _file()
	var spots := _meeting_spots(file)
	for player in file:
		var spot: Vector3 = spots[player]
		player.place(spot + Vector3(-2.2, 0.0, 0.0))
		player.walk_to(spot)
	_aim(_meeting_camera() + Vector3(-0.8, 0.1, 0.0),
		_foot_of_the_chair() + Vector3(0.0, 1.2, 0.0), 44.0)
	await _until(func() -> bool:
		return file.all(func(p: Player) -> bool: return p.has_arrived()), 3.0)
	for player in file:
		if skipped:
			break
		umpire.face(player.position)
		player.face(umpire.position)
		umpire.gesture("handshake")
		player.gesture("handshake")
		await _hold(1.05)
	arena.cheer()
	await _hold(1.2)
	_close()


# --- taken off ---------------------------------------------------------------------

## The Supervisor walks out to the chair, the umpire comes down and is shown the way off.
func taken_off(venue_name: String) -> void:
	_open()
	arena.jeer(0.9)
	var umpire := _official(_seat())
	umpire.rotation.y = -PI * 0.5
	umpire.sit()
	for player in arena.players:
		player.go_home()

	var supervisor := _official(TENNIS_ENTRANCE)
	supervisor.speed = 1.8
	var beside_the_chair := Vector3(_chair_x() - 0.9, 0.0, -1.1)
	supervisor.walk_to(beside_the_chair)

	arena.ui.caption("THE SUPERVISOR", [["UMPIRE REMOVED", UiTheme.RED]],
		"Coming onto court to take over the match")
	await _follow(Vector3(2.8, 1.9, -8.5), Vector3(3.6, 1.8, -4.8), supervisor, 5.0, 44.0)
	await _until(supervisor.has_arrived, 2.5)
	for player in arena.players:
		player.face(umpire.position)
	supervisor.face(umpire.position)
	await _hold(0.5)
	if skipped:
		_close()
		return

	await arena.ui.blackout(true, 0.25).finished
	umpire.place(_foot_of_the_chair() + Vector3(0.0, 0.0, 0.2))
	umpire.face(supervisor.position)
	supervisor.face(umpire.position)
	supervisor.right_arm_towards(TENNIS_EXIT - supervisor.position)
	supervisor.gesture("point")
	_aim(Vector3(4.2, 1.7, -2.2), Vector3(_chair_x() - 1.0, 1.35, -0.4), 44.0)
	arena.ui.hide_caption()
	await arena.ui.blackout(false, 0.25).finished
	await _hold(1.4)

	umpire.walk_to(TENNIS_EXIT)
	get_tree().create_timer(0.7).timeout.connect(func() -> void:
		if _running and not skipped:
			supervisor.walk_to(TENNIS_EXIT + Vector3(-0.7, 0.0, 0.9)))
	arena.ui.caption("TAKEN OFF THE MATCH", [["YOU", UiTheme.RED]],
		"Tennis   ·   %s" % venue_name)
	await _follow(Vector3(1.0, 3.2, 2.5), Vector3(2.0, 3.4, 0.5), umpire, 4.6, 50.0)
	await arena.ui.blackout(true, 0.5).finished
	_close()


# --- moved up ----------------------------------------------------------------------

## The next court, from beside the net up over the stands, with its name along the bottom.
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

	var from := Vector3(-1.5, 0.4, -10.5)
	var to := Vector3(-15.0, 10.0, 16.0)
	var look_from := Vector3(0.0, 0.7, 0.0)
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
