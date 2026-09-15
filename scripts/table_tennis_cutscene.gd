class_name TableTennisCutscene
extends Cutscene

## Table tennis's four scenes, done the way an ITTF umpire does them.
##
## The camera, captions, coin and officials are badminton's (see Cutscene); what happens at
## the table is table tennis's own, from the ITTF *Handbook for Match Officials* (16th
## edition, 2019):
##
## - **The umpire team enters through the corner nearest the umpire's chair**, and at a
##   feature match the players walk in with them, "umpire – players – assistant umpire".
## - **Before practice** the umpire checks the rackets and **tosses a coin in front of both
##   players** for the choice of service and ends, then **sits in the chair for the practice**.
## - **The start** (Appendix D): "Time", the players' names "… versus …", "First game", point
##   to the server, "… to serve", "Love all".
## - **The end**: "Game and match to …", "… wins 3 games to 1". The umpires then walk out
##   together, the umpire leading.
## - **The referee** is who deals with anything the umpire cannot, so the referee comes to
##   the table to take an umpire off.
##
## **There is no assistant umpire.** The handbook has one, sitting opposite the umpire in line
## with the net; this game decided on 2026-09-10 that table tennis has no second official, and
## a figure who walked on and then vanished for the match would be worse than none. Asked of
## Luqman on the review.
##
## Everything happens inside the barriers (TableTennisTable.BARRIER_X/Z) or above the drape,
## because the drape stands 50 cm behind them and a camera outside it sees only curtain.

## The corner nearest the umpire's chair (HMO: "one of the nearest corners on the side of the
## umpire's chair"), just inside the barriers.
const TT_ENTRANCE := Vector3(TableTennisTable.BARRIER_X - 0.45, 0.0, -(TableTennisTable.BARRIER_Z - 0.45))
const TT_EXIT := TT_ENTRANCE

## The seat, from TableTennisTable._build_chair: the frame is EYE_HEIGHT less 0.75 tall and
## the seat board on it is 6 cm thick.
const TT_SEAT_TOP := TableTennisTable.EYE_HEIGHT - 0.75 + 0.03


func _chair_x() -> float:
	return TableTennisSpec.HALF_WIDTH + TableTennisTable.CHAIR_OFFSET


func _seat() -> Vector3:
	return Vector3(_chair_x() + 0.08, TT_SEAT_TOP - SEATED_HIPS, 0.0)


## Beside the table at the net, on the umpire's side: where the toss is made and the hands
## are shaken.
func _beside_the_net() -> Vector3:
	return Vector3(TableTennisSpec.HALF_WIDTH + 0.75, 0.0, 0.0)


func _player_beside_the_net(player: Player) -> Vector3:
	var tt := arena as TableTennisMatch
	return Vector3(TableTennisSpec.HALF_WIDTH + 0.45, 0.0, tt.end_of(player.team) * 0.75)


func _players_in_order() -> Array[Player]:
	var file: Array[Player] = []
	for team in [Sides.Team.RED, Sides.Team.BLUE]:
		for player in arena.players:
			if player.team == team:
				file.append(player)
	return file


# --- the walk-on ------------------------------------------------------------------

func walk_on(venue_name: String, _doubles: bool) -> Sides.Team:
	var winner := Sides.Team.RED if randf() < 0.5 else Sides.Team.BLUE
	toss_winner = winner
	_open()

	var umpire := _official(TT_ENTRANCE)
	umpire.visible = false
	var file := _players_in_order()
	for player in file:
		player.visible = false
		player.place(TT_ENTRANCE)

	arena.ui.caption("LIVE", [[venue_name.to_upper()]], "Table tennis   ·   singles")
	await _move(Vector3(-3.1, 3.0, 5.0), Vector3(-2.5, 2.4, 4.1),
		Vector3(0.3, 0.7, -0.6), Vector3(0.6, 0.7, -0.9), 4.0)

	# In they come through the corner: the umpire first, then the players.
	umpire.visible = true
	umpire.walk_to(_beside_the_net())
	for i in file.size():
		var player := file[i]
		var spot := _player_beside_the_net(player)
		get_tree().create_timer(0.8 * float(i + 1)).timeout.connect(func() -> void:
			if not _running or skipped:
				return
			player.visible = true
			player.walk_to(spot))
	arena.ui.caption("TONIGHT", _teams(" v "), "Your umpire   ·   you")
	await _follow(Vector3(-1.2, 1.6, -4.4), Vector3(-0.8, 1.55, -2.6), umpire, 4.6, 46.0)
	await _until(func() -> bool:
		return umpire.has_arrived() and file.all(func(p: Player) -> bool: return p.has_arrived()),
		4.0)
	arena.ui.hide_caption()
	for player in file:
		player.visible = true
		player.face(umpire.position)
	umpire.face(_beside_the_net() + Vector3.LEFT)

	# Rackets, then the toss in front of both of them, from across the table.
	var across := Vector3(-2.6, 1.55, 0.0)
	var look := _beside_the_net() + Vector3(0.0, 1.15, 0.0)
	_aim(across, look, 40.0)
	arena.ui.caption("BEFORE PRACTICE", [["RACKETS CHECKED"]], "and the toss for service and ends")
	for player in file:
		if skipped:
			break
		umpire.face(player.position)
		await _hold(0.8)
	umpire.face(_beside_the_net() + Vector3.LEFT)
	arena.ui.hide_caption()
	await _toss(umpire)
	arena.ui.caption("THE TOSS", [["%s WIN THE TOSS" % Sides.label(winner), Sides.colour(winner)]],
		"and choose to serve")
	await _hold(1.8)

	# Practice at their ends, the umpire in the chair for it (HMO p.45).
	for player in arena.players:
		player.go_home()
	umpire.place(_seat())
	umpire.rotation.y = -PI * 0.5
	umpire.sit()
	arena.ui.caption("PRACTICE", [["TWO MINUTES"]], "the umpire in the chair")
	# From across the table and above it, both ends in frame. From behind an end the player
	# at that end filled the picture.
	await _move(Vector3(-3.1, 2.5, 0.9), Vector3(-2.9, 2.3, 0.4),
		Vector3(0.6, 0.6, 0.0), Vector3(0.8, 0.6, 0.0), 2.6)

	# "Time", and the start as the handbook words it.
	arena.ui.caption("TIME", [
		["RED", Sides.colour(Sides.Team.RED)], ["VERSUS"], ["BLUE", Sides.colour(Sides.Team.BLUE)],
	], "First game   ·   %s to serve   ·   love all" % Sides.label(winner))
	# On the umpire making the call: the first version stood behind the chair and left them out.
	await _move(Vector3(1.0, 1.35, 2.3), Vector3(1.2, 1.3, 1.9),
		Vector3(_chair_x(), 0.9, 0.0), Vector3(_chair_x(), 0.9, 0.0), 3.2)

	for player in file:
		player.visible = true
	_close()
	return winner


# --- the end of the match ----------------------------------------------------------

## The result called from the chair, the players' handshake at the side of the table, a
## handshake with the umpire, and the umpire walking out.
func match_won(winner: Sides.Team, score: String, _doubles: bool) -> void:
	_open()
	var tt := arena as TableTennisMatch
	var champion: Player = null
	for player in arena.players:
		if player.team == winner:
			player.celebrate()
			champion = player
		else:
			player.slump()
	arena.cheer()

	var umpire := _official(_seat())
	umpire.rotation.y = -PI * 0.5
	umpire.sit()
	var at := champion.position
	var end := tt.end_of(winner)
	arena.ui.caption("GAME AND MATCH", [[Sides.label(winner), Sides.colour(winner)]], score)
	# Far enough back to keep their arms in the picture when they go up.
	_camera.fov = 46.0
	await _move(at + Vector3(-2.4, 1.5, -end * 3.0), at + Vector3(-2.0, 1.45, -end * 2.6),
		at + Vector3(0.0, 1.1, 0.0), at + Vector3(0.0, 1.05, 0.0), 3.0)
	if skipped:
		_close()
		return

	# To the side of the table at the net, and a handshake.
	for player in arena.players:
		player.walk_to(_player_beside_the_net(player) + Vector3(0.0, 0.0, -tt.end_of(player.team) * 0.35))
	arena.ui.hide_caption()
	_aim(Vector3(-3.3, 1.7, 0.3), Vector3(TableTennisSpec.HALF_WIDTH + 0.45, 1.05, 0.0), 44.0)
	await _until(func() -> bool:
		return arena.players.all(func(p: Player) -> bool: return p.has_arrived()), 4.0)
	for player in arena.players:
		player.face(Vector3(player.position.x, 0.0, -player.position.z))
		player.gesture("handshake")
	await _hold(1.3)
	if skipped:
		_close()
		return

	# Up from the chair, and a hand for each of them.
	umpire.place(_beside_the_net() + Vector3(0.5, 0.0, 0.0))
	for player in arena.players:
		if skipped:
			break
		umpire.face(player.position)
		player.face(umpire.position)
		umpire.gesture("handshake")
		player.gesture("handshake")
		await _hold(1.05)

	# And out, the umpire leading (HMO p.47).
	umpire.walk_to(TT_EXIT)
	arena.cheer()
	await _follow(Vector3(-2.2, 1.7, 1.6), Vector3(-1.6, 1.8, 0.6), umpire, 2.4, 46.0)
	_close()


# --- taken off ---------------------------------------------------------------------

## The referee comes to the table, and the umpire is shown the way out through the corner.
func taken_off(venue_name: String) -> void:
	_open()
	arena.jeer(0.9)
	var umpire := _official(_seat())
	umpire.rotation.y = -PI * 0.5
	umpire.sit()
	for player in arena.players:
		player.go_home()

	var referee := _official(TT_ENTRANCE)
	referee.speed = 1.6
	var beside_the_chair := Vector3(_chair_x() - 0.2, 0.0, -0.9)
	referee.walk_to(beside_the_chair)
	arena.ui.caption("THE REFEREE", [["UMPIRE REMOVED", UiTheme.RED]],
		"Coming to the table to take over the match")
	# From across the table and above it. Nearer an end, the player at that end filled the frame.
	await _follow(Vector3(-3.0, 2.4, -1.2), Vector3(-2.7, 2.2, -0.6), referee, 4.0, 46.0)
	await _until(referee.has_arrived, 2.0)
	for player in arena.players:
		player.face(umpire.position)
	referee.face(umpire.position)
	await _hold(0.5)
	if skipped:
		_close()
		return

	await arena.ui.blackout(true, 0.25).finished
	umpire.place(Vector3(_chair_x() - 0.3, 0.0, 0.1))
	umpire.face(referee.position)
	referee.face(umpire.position)
	referee.right_arm_towards(TT_EXIT - referee.position)
	referee.gesture("point")
	_aim(Vector3(-0.6, 1.6, 0.9), Vector3(_chair_x() - 0.25, 1.35, -0.4), 44.0)
	arena.ui.hide_caption()
	await arena.ui.blackout(false, 0.25).finished
	await _hold(1.4)

	umpire.walk_to(TT_EXIT)
	get_tree().create_timer(0.7).timeout.connect(func() -> void:
		if _running and not skipped:
			referee.walk_to(TT_EXIT + Vector3(-0.5, 0.0, 0.7)))
	arena.ui.caption("TAKEN OFF THE MATCH", [["YOU", UiTheme.RED]],
		"Table tennis   ·   %s" % venue_name)
	await _follow(Vector3(-2.8, 2.6, 2.6), Vector3(-2.4, 2.8, 1.4), umpire, 4.2, 50.0)
	await arena.ui.blackout(true, 0.5).finished
	_close()


# --- moved up ----------------------------------------------------------------------

## The next venue, from table height beside the net up over the barriers.
func moved_up(venue: Dictionary) -> void:
	_open()
	arena.ui.blackout(true, 0.0)
	await get_tree().process_frame
	for player in arena.players:
		player.visible = false
	arena.dress_the_venue(venue)
	await get_tree().process_frame
	arena.ui.blackout(false, 0.7)

	var from := Vector3(-2.2, 0.95, 0.9)
	var to := Vector3(-3.2, 5.0, 5.1)
	var look_from := Vector3(0.0, 0.8, 0.0)
	var look_to := Vector3(0.6, 0.0, -1.2)
	const RISE := 6.0
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
