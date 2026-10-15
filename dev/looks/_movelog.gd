extends Node

## Plays real matches in every sport and writes down every movement an athlete makes, so the
## animation list can be built from what actually happens on court rather than from memory.
##
## Luqman, 2026-10-15: "act like human, play the game and record all the possible movement
## that the athlete will do". For every contact it records where the ball was against the
## athlete's own body — racket side or the other side, in front or behind, how high — how
## far they had to reach, how they were moving into it, what the shot became once it left
## them, which clip the game played, and how far that clip's implement was from the ball.
## Between contacts it counts which footwork clip played against the way they were actually
## moving.
##
##     godot --headless --path . res://dev/looks/_movelog.tscn --fixed-fps 120
##     SPORT=badminton   RALLIES=40
##
## Writes build/movelog/<sport>.csv, one row per contact, and prints a summary.

const SCENES := {
	"badminton": ["res://scenes/match.tscn", Career.BADMINTON],
	"beach": ["res://scenes/beach.tscn", Career.BEACH],
	"indoor": ["res://scenes/volleyball.tscn", Career.INDOOR],
	"tennis": ["res://scenes/tennis.tscn", Career.TENNIS],
	"table_tennis": ["res://scenes/table_tennis.tscn", Career.TABLE_TENNIS],
	"takraw": ["res://scenes/sepak_takraw.tscn", Career.TAKRAW],
}
const STRIKES := &"strike"
const NEAR_A_PLAYER := 3.5
## Frames after a contact at which the ball's new flight is read.
const READ_FLIGHT_AFTER := 4
## Frames of position history used to say how somebody was moving into a contact.
const HISTORY := 12


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://build/movelog"))
	var only := OS.get_environment("SPORT")
	var sports: Array = [only] if SCENES.has(only) else SCENES.keys()
	for sport in sports:
		await _play(sport)
	get_tree().quit()


func _play(sport: String) -> void:
	var rallies := int(OS.get_environment("RALLIES")) if OS.has_environment("RALLIES") else 40
	var arena: Node = load(str(SCENES[sport][0])).instantiate()
	arena.print_truth_while_testing = false
	add_child(arena)
	await get_tree().physics_frame
	arena.career = Career.new()
	arena.career.sport = SCENES[sport][1]
	for flag in ["taught", "taught_beach", "taught_indoor", "taught_tennis",
			"taught_table_tennis", "taught_takraw"]:
		arena.settings.set(flag, true)
	if arena.has_method("rebuild_players"):
		arena.rebuild_players()
	arena.ui.match_requested.emit()
	await get_tree().process_frame
	if arena.pressure.exists():
		arena.ui.briefing_acknowledged.emit()
		await get_tree().process_frame
	arena.begin_match()
	for f in 4:
		await get_tree().process_frame

	var rows: Array[String] = ["sport,rally,shot_no,team,player,clip,side,front,height_m,height,reach_m,moving,speed,flight,angle,ball_speed,gap_m,turn_deg"]
	var history := {}
	var footwork := {}
	var strikes_before := int(arena.sound.heard.get(STRIKES, 0))
	var pending: Array = []
	var rally_no := 0
	var shot_no := 0
	var judged := 0

	for frame in 400000:
		await get_tree().physics_frame
		for player in arena.players:
			var trail: Array = history.get(player, [])
			trail.append(player.position)
			if trail.size() > HISTORY:
				trail.pop_front()
			history[player] = trail

		var ball: Node3D = arena.ball_in_play()
		var live: bool = arena._phase == arena.Phase.IN_PLAY and ball != null and is_instance_valid(ball)
		if live:
			for player in arena.players:
				var how := _moving(player, history.get(player, []))
				var key := "%s|%s" % [player.playing_clip(), how[0]]
				footwork[key] = int(footwork.get(key, 0)) + 1
			var struck := int(arena.sound.heard.get(STRIKES, 0))
			if struck > strikes_before:
				var who := _striker(arena, ball.global_position)
				if who != null:
					shot_no += 1
					pending.append({"frames": READ_FLIGHT_AFTER, "who": who,
						"ball": ball.global_position, "how": _moving(who, history.get(who, [])),
						"clip": who.playing_clip(), "gap": who.hitting_point().distance_to(ball.global_position),
						"shot": shot_no, "rally": rally_no,
						"turn": rad_to_deg(wrapf(who.rotation.y - who.across_the_net(), -PI, PI))})
			strikes_before = struck
		else:
			strikes_before = int(arena.sound.heard.get(STRIKES, 0))

		for p in pending.duplicate():
			p["frames"] -= 1
			if p["frames"] > 0:
				continue
			pending.erase(p)
			var velocity := Vector3.ZERO
			if ball != null and is_instance_valid(ball) and ball is RigidBody3D:
				velocity = (ball as RigidBody3D).linear_velocity
			rows.append(_row(sport, p, velocity))

		if arena._phase == arena.Phase.READY:
			arena.start_rally()
			rally_no += 1
			shot_no = 0
		elif arena._phase == arena.Phase.AWAITING_CALL:
			arena._awaiting_since = Time.get_ticks_msec()
			arena.make_call(&"in" if arena.current_rally().was_in else &"out")
			for f in 3:
				await get_tree().process_frame
			judged += 1
			if judged >= rallies:
				break
			if arena.board.is_over:
				arena.begin_match()

	var path := "res://build/movelog/%s.csv" % sport
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string("\n".join(rows) + "\n")
	file.close()
	print("%s: %d rallies, %d contacts -> %s" % [sport, judged, rows.size() - 1, path])
	var keys := footwork.keys()
	keys.sort_custom(func(a, b): return footwork[a] > footwork[b])
	var top: Array[String] = []
	for k in keys.slice(0, 16):
		top.append("%s=%d" % [k, footwork[k]])
	print("  footwork (clip|movement=frames): " + ", ".join(top))
	arena.queue_free()
	await get_tree().process_frame


func _striker(arena: Node, ball: Vector3) -> Player:
	var best: Player = null
	var nearest := NEAR_A_PLAYER
	for player in arena.players:
		var d: float = player.hitting_point().distance_to(ball)
		if d < nearest:
			nearest = d
			best = player
	return best


## How somebody was moving, in their own terms: towards the net, away from it, or across it
## to their own left or right, and how fast.
func _moving(player: Player, trail: Array) -> Array:
	if trail.size() < 2:
		return ["still", 0.0]
	var step: Vector3 = (trail[-1] - trail[0]) / float(trail.size() - 1) * 120.0
	var flat := Vector2(step.x, step.z)
	var speed := flat.length()
	if speed < 0.35:
		return ["still", speed]
	var facing := player.across_the_net()
	var forward := Vector2(sin(facing), cos(facing))
	var right := Vector2(-forward.y, forward.x)
	var ahead := flat.normalized().dot(forward)
	var across := flat.normalized().dot(right)
	if absf(ahead) >= absf(across):
		return ["to_net" if ahead > 0.0 else "away_from_net", speed]
	return ["to_own_right" if across > 0.0 else "to_own_left", speed]


func _row(sport: String, p: Dictionary, velocity: Vector3) -> String:
	var who: Player = p["who"]
	var ball: Vector3 = p["ball"]
	var local: Vector3 = who.global_transform.basis.inverse() * (ball - who.global_position)
	# The characters look down their own +Z, so their right hand is on -X.
	var side := "right" if local.x < 0.0 else "left"
	var front := "front" if local.z >= 0.0 else "behind"
	var height := ball.y
	var band := "floor" if height < 0.4 else ("low" if height < 0.9 else (
		"waist" if height < 1.35 else ("shoulder" if height < 1.9 else (
		"overhead" if height < 2.6 else "jump"))))
	var reach := Vector2(local.x, local.z).length()
	var horizontal := Vector2(velocity.x, velocity.z).length()
	var angle := rad_to_deg(atan2(velocity.y, maxf(horizontal, 0.001)))
	var speed := velocity.length()
	var flight := "steep_down" if angle < -8.0 else ("flat" if angle < 12.0 else (
		"rising" if angle < 35.0 else "high"))
	if speed < 8.0 and flight != "high":
		flight = "soft_" + flight
	var how: Array = p["how"]
	return "%s,%d,%d,%d,%s,%s,%s,%s,%.2f,%s,%.2f,%s,%.2f,%s,%.0f,%.1f,%.2f,%.0f" % [
		sport, p["rally"], p["shot"], who.team, who.name, p["clip"], side, front, height, band,
		reach, how[0], how[1], flight, angle, speed, p["gap"], p["turn"]]
