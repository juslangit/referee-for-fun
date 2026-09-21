extends Node

## One shot of the trailer, recorded straight out of the running game.
##
##   godot --path . res://dev/trailer/_shot.tscn --write-movie build/trailer/<name>.avi \
##         --fixed-fps 60 --quit-after <frames>
##
## Driven by the environment, the same way `_hallshot` is, so the whole trailer is a shell
## loop over this one scene rather than fourteen near-identical scripts:
##
##   SHOT     what the shot does: rally, honest, lie, brief, career, ending
##   SCENE    which sport
##   TIER     which rung of the ladder
##   SECONDS  how long to keep playing before quitting
##
## Nothing here is staged footage. The trailer plays the actual game and records what it
## does — `--write-movie` forces a fixed frame rate, so the recording is deterministic and
## a shot that looked right once looks right again.

## The rate `--fixed-fps` is run at. Everything here is counted in frames at this rate.
const FPS := 60

var arena: Node


func _ready() -> void:
	var scene := OS.get_environment("SCENE")
	if scene.is_empty():
		scene = "res://scenes/match.tscn"
	var shot := OS.get_environment("SHOT")
	var tier := int(OS.get_environment("TIER")) if OS.has_environment("TIER") else 4
	var seconds := float(OS.get_environment("SECONDS")) if OS.has_environment("SECONDS") else 8.0

	arena = load(scene).instantiate()
	arena.print_truth_while_testing = false
	add_child(arena)
	await get_tree().physics_frame

	arena.career = Career.new()
	arena.career.tier = tier
	arena.career.reputation = 0.72 if shot == "lie" else 1.0
	arena.settings.taught_beach = true
	arena.settings.taught_indoor = true
	arena.settings.taught_tennis = true
	arena.settings.taught_table_tennis = true
	arena.settings.taught_takraw = true
	arena.ui.match_requested.emit()
	await get_tree().process_frame

	# The briefing is a shot in its own right: somebody telling the umpire who they would
	# like to see win, which is the whole premise in one screen.
	if arena.pressure.exists():
		if shot == "brief":
			await _hold(seconds)
			get_tree().quit()
			return
		arena.ui.briefing_acknowledged.emit()
		await get_tree().process_frame

	arena.begin_match()

	match shot:
		"career":
			arena.ui.career_screen_requested.emit()
			await _hold(seconds)
		"ending":
			# Thrown off for real, rather than told to be. Calling `finish()` by hand
			# produced a card that argued with itself — "THROWN OFF" over a summary
			# reading "0 wrong calls, they went both ways, you were not bent" — because
			# the summary is computed from the match and the match had not done anything
			# wrong yet. So this bends every close call and waits to be removed, however
			# long that takes, and holds on whatever the game decides to say.
			await _play(30.0, false)
			await _hold(seconds)
		"lie":
			await _play(seconds, false)
		_:
			await _play(seconds, true)
	get_tree().quit()


## Rallies, one after another, until the clock runs out.
##
## `honestly` is the difference between the first half of the trailer and the second. An
## honest umpire calls what happened; a bent one calls every close one the other way, and
## the hall is what answers.
func _play(seconds: float, honestly: bool) -> void:
	var left := int(seconds * float(FPS))
	while left > 0:
		left -= 1
		if arena._phase == arena.Phase.READY:
			arena.start_rally()
		elif arena._phase == arena.Phase.AWAITING_CALL:
			# A beat before the call, because an umpire who answers instantly is not
			# deciding anything.
			await _hold(0.7)
			var truth: bool = arena.rally.was_in if arena.rally != null else true
			var says := truth if honestly else not truth
			arena.make_call(&"in" if says else &"out")
			await _hold(1.1)
			left -= int(1.8 * float(FPS))
		elif arena._phase == arena.Phase.REMOVED:
			break
		await get_tree().process_frame
	await get_tree().process_frame


## Waits in **recorded** seconds, not real ones.
##
## `--write-movie` forces a fixed frame rate and then runs as fast or as slow as it likes:
## this machine records at about 30% of real time, so a shot that waits eight seconds on
## the wall clock records under three. Every wait here is therefore a frame count, which
## is the only clock the recording agrees with. `Time.get_ticks_msec()` is the wrong one,
## and the first take of the opening shot came out four seconds long instead of eight.
func _hold(seconds: float) -> void:
	for frame in int(seconds * float(FPS)):
		await get_tree().process_frame
