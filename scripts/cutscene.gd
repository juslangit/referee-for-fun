class_name Cutscene
extends Node3D

## The four moments the umpire's chair cannot show: walking on, the handshakes at the end,
## being taken off, and being moved up to a bigger hall.
##
## For the whole of a match the player *is* the camera, and nothing outside what an umpire
## can see from the chair is ever on screen. These are the exceptions, and they are shot
## the way television shoots them — letterboxed, from wherever the picture is, with a
## caption along the bottom — because that is the one other view of a match that everybody
## already knows how to read. The broadcast dressing is RefereeUI's; this is the camera
## and the people.
##
## **Badminton only, for now.** Luqman chose badminton first on 2026-09-15. Every position
## here is a badminton court's, read from CourtSpec rather than typed in.
##
## **What happens is what a real match does.** The umpire leads the players on, stands on
## the singles sideline with their back to the chair, shakes hands with each of them and
## tosses a coin. At the end the players shake hands over the net, then with the umpire in
## the chair, and only then is the result announced. BWF's Instructions to Technical
## Officials (sections 5.2, 5.3 and 5.6.5) and its umpire and service judge instructions.
##
## **Every scene can be skipped, and a skipped scene leaves the match exactly where a
## watched one would.** Each function here returns early the moment `skipped` is set; the
## match puts everybody where they belong afterwards, the same either way. Nothing a scene
## decides — who won the toss — depends on how much of it was watched.

signal done

var arena: OfficiatedMatch
var skipped := false

## Who won the walk-on's toss, and so serves first. Kept for the checks, which have to be
## able to see that the caption and the serve agree.
var toss_winner := Sides.Team.NONE

var _camera: Camera3D
var _cast: Array[Node3D] = []
var _coin: MeshInstance3D
var _running := false

## Where the officials and players come on from: the corner of the hall behind RED's
## baseline on the chair's side, between the line judge's seat and the chair.
const ENTRANCE := Vector3(4.9, 0.0, -7.0)

## Where a removed umpire is walked off to. The same corner: officials leave by the way
## they came in.
const EXIT := Vector3(5.2, 0.0, -6.6)

## How high the umpire's high chair seats them, and how far the seated clip lowers the
## hips. The figure stands on the floor at its feet, so seated it is lifted by the
## difference to put the hips on the seat.
const SEAT_HEIGHT := 1.62
const SEATED_HIPS := 0.47

## When the coin leaves the hand and comes back to it in `coin_toss`, in seconds. Frames
## 12 and 28 at 24 fps; see tools/meshy/badminton_clips.py.
const COIN_FLICK := 12.0 / 24.0
const COIN_CATCH := 28.0 / 24.0
const COIN_RISE := 0.55


func _ready() -> void:
	_camera = Camera3D.new()
	_camera.name = "BroadcastCamera"
	_camera.fov = 46.0
	add_child(_camera)
	arena.ui.cutscene_skip.connect(skip)


func skip() -> void:
	if _running:
		skipped = true


func _unhandled_input(event: InputEvent) -> void:
	if not _running:
		return
	if event is InputEventKey and event.pressed and not event.echo \
			and event.keycode in [KEY_SPACE, KEY_ENTER, KEY_KP_ENTER, KEY_ESCAPE]:
		skipped = true
		get_viewport().set_input_as_handled()


# --- the walk-on ------------------------------------------------------------------

## Before the first serve. Returns the side that won the toss, which serves first.
func walk_on(venue_name: String, doubles: bool) -> Sides.Team:
	var winner := Sides.Team.RED if randf() < 0.5 else Sides.Team.BLUE
	toss_winner = winner
	_open()

	# BWF: the umpire stands on the singles sideline, back to the chair, feet either side
	# of the short service line, and the players line up in front of them.
	var stand := Vector3(CourtSpec.HALF_WIDTH_SINGLES, 0.0, -CourtSpec.SHORT_SERVICE_LINE)
	var umpire := _official(ENTRANCE)
	umpire.visible = false

	var file: Array[Player] = []
	for team in [Sides.Team.RED, Sides.Team.BLUE]:
		for player in arena.players:
			if player.team == team:
				file.append(player)
	var spacing := 0.75 if doubles else 0.9
	var spots := {}
	for i in file.size():
		var along := (float(i) - float(file.size() - 1) * 0.5) * spacing
		spots[file[i]] = Vector3(stand.x - 1.45, 0.0, stand.z + along)
		file[i].visible = false
		file[i].place(ENTRANCE)

	# The hall, before anybody is in it.
	arena.ui.caption("LIVE", [[venue_name.to_upper()]],
		"Badminton   ·   %s" % ("doubles" if doubles else "singles"))
	await _move(Vector3(-12.4, 7.6, 6.0), Vector3(-11.4, 6.3, -2.5),
		Vector3(0.5, 0.0, 0.0), Vector3(2.5, 0.4, -4.0), 4.5)

	# On they come: the umpire first, then the players (ITTO 5.1 — the umpire leads).
	umpire.visible = true
	umpire.walk_to(stand)
	for i in file.size():
		var player := file[i]
		var spot: Vector3 = spots[player]
		get_tree().create_timer(0.75 * float(i + 1)).timeout.connect(func() -> void:
			if not _running or skipped:
				return
			player.visible = true
			player.walk_to(spot))
	arena.ui.caption("TONIGHT", _teams(" v "), "Your umpire   ·   you")
	await _follow(Vector3(-2.4, 1.7, -6.4), Vector3(-1.4, 1.6, -5.0), umpire, 4.6, 40.0)
	await _until(func() -> bool:
		return umpire.has_arrived() and file.all(func(p: Player) -> bool: return p.has_arrived()),
		5.0)
	arena.ui.hide_caption()
	umpire.face(stand + Vector3.LEFT)
	for player in file:
		player.face(Vector3(stand.x, 0.0, player.position.z))

	# A handshake with each of them, stepping along the line.
	_aim(Vector3(-1.3, 1.65, -0.45), Vector3(1.8, 1.1, -2.1), 42.0)
	for player in file:
		if skipped:
			break
		var opposite := Vector3(player.position.x + 0.72, 0.0, player.position.z)
		umpire.walk_to(opposite)
		await _until(umpire.has_arrived, 1.0)
		umpire.face(player.position)
		player.face(umpire.position)
		umpire.gesture("handshake")
		player.gesture("handshake")
		await _hold(1.05)

	# The toss: one step into the court, the coin, and who won it.
	var toss_spot := stand + Vector3(-0.45, 0.0, 0.0)
	umpire.walk_to(toss_spot)
	await _until(umpire.has_arrived, 1.0)
	umpire.face(toss_spot + Vector3.LEFT)
	_aim(Vector3(1.3, 1.45, -5.4), Vector3(1.8, 1.35, -1.98), 38.0)
	await _toss(umpire)
	arena.ui.caption("THE TOSS", [["%s WIN THE TOSS" % Sides.label(winner), Sides.colour(winner)]],
		"%s to serve" % Sides.label(winner))
	await _hold(1.8)

	# Off to their ends to warm up, and the umpire in the chair to announce the match
	# (ITTO 5.3.1). From the chair's point of view RED is on the right.
	for player in arena.players:
		player.go_home()
	umpire.place(_seat())
	umpire.rotation.y = -PI * 0.5
	umpire.sit()
	var loser := Sides.opponent(winner)
	var serves := "%s to serve" % Sides.label(winner)
	if doubles:
		serves = "%s to serve to %s" % [Sides.label(winner), Sides.label(loser)]
	arena.ui.caption("LADIES AND GENTLEMEN", [
		["ON MY RIGHT"], ["RED", Sides.colour(Sides.Team.RED)],
		["ON MY LEFT"], ["BLUE", Sides.colour(Sides.Team.BLUE)],
	], "%s   ·   love all   ·   play" % serves)
	await _move(Vector3(-0.6, 2.6, -2.7), Vector3(-0.1, 2.5, -2.1),
		Vector3(4.0, 1.8, 0.2), Vector3(4.0, 1.9, 0.0), 3.6)

	for player in file:
		player.visible = true
	_close()
	return winner


func _toss(umpire: Official) -> void:
	umpire.gesture("coin_toss")
	_coin.visible = false
	var t := 0.0
	while t < COIN_CATCH + 0.25 and not skipped:
		await get_tree().process_frame
		t += get_process_delta_time()
		var hand := umpire.bone_position("RightHand")
		if t < COIN_FLICK:
			continue
		_coin.visible = t < COIN_CATCH + 0.2
		var f := clampf((t - COIN_FLICK) / (COIN_CATCH - COIN_FLICK), 0.0, 1.0)
		_coin.global_position = hand + Vector3.UP * (sin(f * PI) * COIN_RISE + 0.03)
		_coin.rotation.x = t * 38.0
	_coin.visible = false
	await _hold(0.6)


# --- the end of the match ----------------------------------------------------------

## Winners celebrate, the players shake hands over the net and then with the umpire in the
## chair, and the umpire announces the result (ITTO 5.6.5, in that order).
func match_won(winner: Sides.Team, score: String, doubles: bool) -> void:
	_open()
	for player in arena.players:
		if player.team == winner:
			player.celebrate()
		else:
			player.slump()
	arena.court.stands.cheer()

	arena.ui.caption("GAME, MATCH", [["%s WIN" % Sides.label(winner), Sides.colour(winner)]], score)
	await _move(Vector3(-5.2, 2.4, -9.0), Vector3(-4.6, 2.0, -7.2),
		Vector3(0.0, 0.8, 0.0), Vector3(0.0, 0.9, 0.0), 3.0)
	if skipped:
		_close()
		return

	# To the net. Opposite each other, a pace either side of it.
	var across := [0.0] if not doubles else [-0.75, 0.75]
	var counts := {Sides.Team.RED: 0, Sides.Team.BLUE: 0}
	for player in arena.players:
		var i: int = counts[player.team]
		counts[player.team] = i + 1
		player.walk_to(Vector3(across[mini(i, across.size() - 1)], 0.0,
			Sides.half_sign(player.team) * 0.42))
	arena.ui.hide_caption()
	_aim(Vector3(-4.6, 1.5, 0.0), Vector3(0.0, 1.0, 0.0), 40.0)
	await _until(func() -> bool:
		return arena.players.all(func(p: Player) -> bool: return p.has_arrived()), 4.0)
	for player in arena.players:
		player.face(Vector3(player.position.x, 0.0, -player.position.z))
		player.gesture("handshake")
	await _move(Vector3(-4.6, 1.5, 0.0), Vector3(-3.8, 1.45, 0.0),
		Vector3(0.0, 1.0, 0.0), Vector3(0.0, 1.0, 0.0), 1.5)
	if skipped:
		_close()
		return

	# Then to the chair, where the umpire shakes each of their hands without getting down.
	var umpire := _official(_seat())
	umpire.rotation.y = -PI * 0.5
	umpire.sit()
	# Each on their own side of the net, beyond the post, which is where the net stops.
	var line: Array[Player] = arena.players.duplicate()
	line.sort_custom(func(a: Player, b: Player) -> bool: return a.position.z < b.position.z)
	var in_line := {Sides.Team.RED: 0, Sides.Team.BLUE: 0}
	for player in line:
		var k: int = in_line[player.team]
		in_line[player.team] = k + 1
		player.walk_to(Vector3(CourtSpec.HALF_WIDTH_DOUBLES + 0.3, 0.0,
			Sides.half_sign(player.team) * (0.45 + 0.65 * k)))
	_aim(Vector3(0.9, 2.2, -2.9), Vector3(3.9, 1.55, 0.0), 42.0)
	await _until(func() -> bool:
		return line.all(func(p: Player) -> bool: return p.has_arrived()), 4.0)
	for player in line:
		if skipped:
			break
		player.face(umpire.position)
		umpire.face(player.position)
		umpire.gesture("sit_handshake")
		player.gesture("handshake")
		await _hold(1.05)

	arena.ui.caption("THE UMPIRE", [["MATCH WON BY"], [Sides.label(winner), Sides.colour(winner)]],
		score)
	arena.court.stands.cheer()
	await _hold(2.4)
	_close()


# --- taken off ---------------------------------------------------------------------

## The tournament referee comes onto court, the umpire is shown the way off, and walks it.
func taken_off(venue_name: String) -> void:
	_open()
	arena.court.stands.jeer(0.9)
	var umpire := _official(_seat())
	umpire.rotation.y = -PI * 0.5
	umpire.sit()
	for player in arena.players:
		player.go_home()

	var referee := _official(Vector3(CourtSpec.HALF_WIDTH_DOUBLES + 1.5, 0.0,
		-(CourtSpec.HALF_LENGTH + 0.6)))
	referee.speed = 1.8
	var beside_the_chair := Vector3(CourtSpec.HALF_WIDTH_DOUBLES + 0.35, 0.0, -1.15)
	referee.walk_to(beside_the_chair)

	arena.ui.caption("THE TOURNAMENT REFEREE", [["UMPIRE REMOVED", UiTheme.RED]],
		"Coming onto court to take over the match")
	await _follow(Vector3(-0.8, 1.8, -4.2), Vector3(-0.3, 1.7, -3.4), referee, 4.2, 44.0)
	await _until(referee.has_arrived, 1.5)
	for player in arena.players:
		player.face(umpire.position)
	referee.face(umpire.position)
	await _hold(0.5)
	if skipped:
		_close()
		return

	# Down from the chair, and shown the way out.
	await arena.ui.blackout(true, 0.25).finished
	umpire.place(Vector3(CourtSpec.HALF_WIDTH_DOUBLES + 0.5, 0.0, -0.3))
	umpire.face(referee.position)
	referee.face(umpire.position)
	referee.right_arm_towards(EXIT - referee.position)
	referee.gesture("point")
	_aim(Vector3(0.6, 1.7, -0.9), Vector3(3.45, 1.35, -0.3), 44.0)
	arena.ui.hide_caption()
	await arena.ui.blackout(false, 0.25).finished
	await _hold(1.4)

	umpire.walk_to(EXIT)
	get_tree().create_timer(0.7).timeout.connect(func() -> void:
		if _running and not skipped:
			referee.walk_to(EXIT + Vector3(-0.6, 0.0, 0.9)))
	arena.ui.caption("TAKEN OFF THE MATCH", [["YOU", UiTheme.RED]],
		"Badminton   ·   %s" % venue_name)
	await _follow(Vector3(-2.6, 3.0, 2.6), Vector3(-2.0, 3.2, 1.2), umpire, 4.4, 48.0)
	await arena.ui.blackout(true, 0.5).finished
	_close()


# --- moved up ----------------------------------------------------------------------

## The next hall, from the floor up to the rafters, with its name across the bottom.
func moved_up(venue: Dictionary) -> void:
	_open()
	arena.ui.blackout(true, 0.0)
	await get_tree().process_frame
	for player in arena.players:
		player.visible = false
	arena.set_line_judges_present(venue["line_judges"])
	arena.court.dress(venue["dressing"])
	arena.court.stands.set_density(venue["crowd"])
	await get_tree().process_frame
	arena.ui.blackout(false, 0.7)

	var from := Vector3(0.0, 0.35, -8.6)
	var to := Vector3(-11.6, 7.2, 5.5)
	var look_from := Vector3(0.0, 0.6, 0.0)
	var look_to := Vector3(1.0, 0.0, 0.0)
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
			arena.court.stands.cheer()
			arena.sound.set_won()
		# The photographers, where the hall has any.
		if named and arena.court.venue != null and randf() < 0.25:
			arena.court.venue.flash()
	await arena.ui.blackout(true, 0.5).finished
	_close()


# --- the camera ----------------------------------------------------------------------

func _aim(at: Vector3, look: Vector3, fov := -1.0) -> void:
	if fov > 0.0:
		_camera.fov = fov
	_camera.global_position = at
	if not at.is_equal_approx(look):
		_camera.look_at(look, Vector3.UP)


## A dolly from one place to another, looking from one point to another, eased at both ends.
func _move(from: Vector3, to: Vector3, look_from: Vector3, look_to: Vector3, seconds: float) -> void:
	var t := 0.0
	_aim(from, look_from)
	while t < seconds and not skipped:
		await get_tree().process_frame
		t += get_process_delta_time()
		var f := smoothstep(0.0, 1.0, clampf(t / seconds, 0.0, 1.0))
		_aim(from.lerp(to, f), look_from.lerp(look_to, f))


## A dolly that keeps somebody in the middle of the frame.
func _follow(from: Vector3, to: Vector3, who: Node3D, seconds: float, fov := -1.0) -> void:
	if fov > 0.0:
		_camera.fov = fov
	var t := 0.0
	while t < seconds and not skipped:
		var f := smoothstep(0.0, 1.0, clampf(t / seconds, 0.0, 1.0))
		_aim(from.lerp(to, f), who.global_position + Vector3.UP * 1.2)
		await get_tree().process_frame
		t += get_process_delta_time()


func _hold(seconds: float) -> void:
	var t := 0.0
	while t < seconds and not skipped:
		await get_tree().process_frame
		t += get_process_delta_time()


## Waits for something to be true, but never longer than `most` — a player who cannot get
## where they were sent must not hold the match up.
func _until(condition: Callable, most: float) -> void:
	var t := 0.0
	while t < most and not skipped and not condition.call():
		await get_tree().process_frame
		t += get_process_delta_time()


# --- the people ------------------------------------------------------------------------

## An official made for this scene, on the chair's layer so the umpire's camera can never
## see one if anything outlives the cut back to the chair.
func _official(at: Vector3) -> Official:
	var official := Official.new()
	official.position = at
	add_child(official)
	official.set_layer(Court.CHAIR_LAYER)
	_cast.append(official)
	return official


## Where the umpire's feet go so that a seated umpire is sitting on the high chair.
func _seat() -> Vector3:
	return Vector3(CourtSpec.HALF_WIDTH_DOUBLES + Court.CHAIR_OFFSET + 0.24,
		SEAT_HEIGHT - SEATED_HIPS, 0.0)


func _teams(between: String) -> Array:
	return [["RED", Sides.colour(Sides.Team.RED)], [between], ["BLUE", Sides.colour(Sides.Team.BLUE)]]


func _open() -> void:
	_running = true
	skipped = false
	arena._back_to_full_speed()
	arena.camera.set_active(false)
	_camera.current = true
	# The commentators' caption sits where the lower third goes, and whatever they were
	# still saying about the last point has been overtaken by the picture.
	if arena.commentary != null:
		arena.commentary.stop()
	arena.ui.show_broadcast()
	if _coin == null:
		_coin = MeshInstance3D.new()
		var disc := CylinderMesh.new()
		disc.top_radius = 0.02
		disc.bottom_radius = 0.02
		disc.height = 0.003
		_coin.mesh = disc
		var gold := StandardMaterial3D.new()
		gold.albedo_color = Color(0.95, 0.76, 0.28)
		# Unlit, so it catches the eye in a dark hall the way a real coin catches the lights.
		gold.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_coin.material_override = gold
		_coin.layers = Court.CHAIR_LAYER
		_coin.visible = false
		add_child(_coin)


func _close() -> void:
	_running = false
	for member in _cast:
		if is_instance_valid(member):
			member.queue_free()
	_cast.clear()
	if _coin != null:
		_coin.visible = false
	arena.ui.blackout(false, 0.0)
	arena.ui.hide_broadcast()
	arena.camera.current = true
	done.emit()
