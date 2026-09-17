extends Node

## Does a smash have its crouch in front of it, and does the crouch meet the stroke?
##
## Badminton looks ahead for the contact that is coming (`_see_the_contact_coming`) and
## starts `smash_windup`, timed to end where the smash itself begins. Three ways that can
## be wrong, all measured on real rallies by watching which clip each player is in on every
## physics frame: smashes that came with no crouch, crouches that came with no smash, and
## crouches that end well before or after the stroke they lead into.
##
## The stroke in turn begins a quarter of a second before the shuttle is struck, because
## that is how far into the clip the racket reaches the shuttle — so a crouch that meets
## the stroke ends a quarter of a second before the strike, by design.

## At least this share of smashes should be seen coming. Not all can be: a shuttle that
## crosses the net and is struck within a third of a second leaves nothing to look ahead at.
const SEEN_COMING_AT_LEAST := 0.6
## At most this share of wind-ups may lead to no smash by that player.
const FALSE_ALARMS_AT_MOST := 0.25
## How far the crouch's planned end may miss the start of the stroke, in seconds, at the
## median.
const MEDIAN_MISS_AT_MOST := 0.08

var _problems: Array[String] = []


func _ready() -> void:
	var hall: Node = load("res://scenes/match.tscn").instantiate()
	hall.print_truth_while_testing = false
	add_child(hall)
	await get_tree().physics_frame
	hall.career = Career.new()
	hall.career.sport = Career.BADMINTON
	hall.settings.taught = true
	hall._on_match_requested()
	if hall.pressure.exists():
		hall.ui.hide_briefing()
	hall.begin_match()
	for f in 4:
		await get_tree().process_frame

	var smashes := 0
	var seen_coming := 0
	var wind_ups := 0
	var false_alarms := 0
	var misses: Array[float] = []
	# Per player: when the wind-up started and when it was planned to end, in seconds.
	var started := {}
	var clip_was := {}
	var clock := 0.0

	for r in _rallies_wanted(24):
		if hall.board.is_over:
			break
		hall.start_rally()
		var w := 0
		while hall._phase != hall.Phase.AWAITING_CALL and w < 4000:
			await get_tree().physics_frame
			clock += 1.0 / float(Engine.physics_ticks_per_second)
			w += 1
			for player in hall.players:
				var clip: String = player._clip
				var was: String = clip_was.get(player, "")
				if clip != was:
					if clip == "smash_windup":
						wind_ups += 1
						var animator: AnimationPlayer = player._animator
						var planned: float = animator.get_animation("smash_windup").length \
							/ maxf(0.01, animator.get_playing_speed())
						started[player] = [clock, clock + planned]
					elif clip == "smash":
						smashes += 1
						if started.has(player):
							seen_coming += 1
							misses.append(absf(clock - float(started[player][1])))
							started.erase(player)
					clip_was[player] = clip
				# A wind-up nobody followed with a smash within a second is a false alarm.
				if started.has(player) and clock - float(started[player][0]) > 1.0:
					false_alarms += 1
					started.erase(player)
		hall._awaiting_since = Time.get_ticks_msec()
		hall.make_call(&"in" if hall.rally.was_in else &"out")
		var w2 := 0
		while hall._phase == hall.Phase.AWAITING_CALL and w2 < 600:
			await get_tree().process_frame
			w2 += 1
		for f in 30:
			await get_tree().process_frame

	misses.sort()
	var median: float = misses[misses.size() / 2] if not misses.is_empty() else -1.0
	var worst: float = misses[-1] if not misses.is_empty() else -1.0
	print("smashes %d, seen coming %d (%.0f%%)" % [
		smashes, seen_coming, 100.0 * seen_coming / maxf(1.0, smashes)])
	print("wind-ups %d, with no smash after %d (%.0f%%)" % [
		wind_ups, false_alarms, 100.0 * false_alarms / maxf(1.0, wind_ups)])
	print("crouch end vs stroke: median %.3f s, worst %.3f s" % [median, worst])

	if smashes < 5:
		_problems.append("only %d smashes, too few to judge" % smashes)
	if float(seen_coming) / maxf(1.0, smashes) < SEEN_COMING_AT_LEAST:
		_problems.append("under %.0f%% of smashes were seen coming" % (SEEN_COMING_AT_LEAST * 100.0))
	if float(false_alarms) / maxf(1.0, wind_ups) > FALSE_ALARMS_AT_MOST:
		_problems.append("over %.0f%% of wind-ups led to no smash" % (FALSE_ALARMS_AT_MOST * 100.0))
	if median > MEDIAN_MISS_AT_MOST:
		_problems.append("the crouch misses the stroke by %.3f s at the median" % median)
	print("PASS" if _problems.is_empty() else "FAIL:\n   " + "\n   ".join(_problems))
	get_tree().quit()


func _rallies_wanted(usually: int) -> int:
	var asked := OS.get_environment("RALLIES")
	if asked.is_valid_int() and asked.to_int() > 0:
		return asked.to_int()
	return usually
