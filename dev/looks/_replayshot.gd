extends Node

## Pictures of the replay of the worst calls and of the next morning's paper, at full size.
##
## Headless renders at 64x64, which is smaller than the close-up picture, so the replay
## and the paper can only be judged by eye from a windowed run. Lies three times, is taken
## off the match, and photographs four moments: the ball in flight, the close view with the
## truth under it, the result, and the paper.
##
##   SPORT   badminton (default), beach, indoor, tennis, table_tennis
##   TIER    which rung of the ladder (default 2 — below the rungs with reviews)
##   PAGE    front for a career that ends here, anything else for the inside page

var SAVE := Career.save_path()

const SCENES := {
	"badminton": ["res://scenes/match.tscn", Career.BADMINTON],
	"beach": ["res://scenes/beach.tscn", Career.BEACH],
	"indoor": ["res://scenes/volleyball.tscn", Career.INDOOR],
	"tennis": ["res://scenes/tennis.tscn", Career.TENNIS],
	"table_tennis": ["res://scenes/table_tennis.tscn", Career.TABLE_TENNIS],
}


func _ready() -> void:
	var saved := FileAccess.get_file_as_string(SAVE) if FileAccess.file_exists(SAVE) else ""
	var sport := OS.get_environment("SPORT") if OS.has_environment("SPORT") else "badminton"
	var tier := int(OS.get_environment("TIER")) if OS.has_environment("TIER") else 2
	var front := OS.get_environment("PAGE") == "front"
	var scene: String = SCENES[sport][0]
	var id: StringName = SCENES[sport][1]

	var arena: OfficiatedMatch = load(scene).instantiate()
	arena.print_truth_while_testing = false
	add_child(arena)
	await get_tree().physics_frame
	arena.career = Career.new()
	arena.career.sport = id
	arena.career.tier = tier
	arena.career.reputation = 0.05 if front else 0.80
	arena.career.matches_refereed = 13
	arena.career.times_removed = 1
	arena.settings.taught = true
	arena.settings.taught_beach = true
	arena.settings.taught_indoor = true
	arena.settings.taught_tennis = true
	arena.settings.taught_table_tennis = true
	if id == Career.BADMINTON:
		arena._on_match_requested()
		if arena.pressure.exists():
			arena.ui.hide_briefing()
	else:
		arena.ui.match_requested.emit()
		await get_tree().process_frame
		if arena.pressure.exists():
			arena.ui.briefing_acknowledged.emit()
			await get_tree().process_frame
	arena.begin_match()
	for f in 4:
		await get_tree().process_frame

	for r in 3:
		if arena._phase == arena.Phase.REMOVED:
			break
		arena.start_rally()
		await _until(func() -> bool: return arena._phase == arena.Phase.AWAITING_CALL, 30.0)
		var rally = arena.current_rally()
		arena.make_call(&"in" if not rally.was_in else &"out")
		print("lie %d: %s" % [r, rally.describe()])
		await _until(func() -> bool: return arena._phase != arena.Phase.AWAITING_CALL, 10.0)

	if arena._phase != arena.Phase.REMOVED:
		arena.suspicion.is_removed = true
		if id == Career.BADMINTON:
			arena._on_removed_from_match()
		else:
			arena.finish("TAKEN OFF THE MATCH", Color(0.96, 0.42, 0.36), true)

	for moment in arena.worst_calls.moments:
		var path: PackedVector3Array = moment["path"]
		print("kept: seen %.2f  %d points  from %v  to %v  | %s" % [
			moment["seen"], path.size(), path[0], moment["landing"], moment["truth_line"]])

	await _until(func() -> bool: return arena.ui._replay.visible, 5.0)
	await _wait(1.1)
	if arena.replay_booth != null:
		print("replay camera at %v, current %s" % [
			arena.replay_booth._camera.global_position, arena.replay_booth._camera.current])
	await _shoot("%s_replay_flight" % sport)
	await _until(func() -> bool: return arena.ui._replay_close.visible, 8.0)
	await _wait(0.4)
	await _shoot("%s_replay_close" % sport)
	arena.ui.replay_skip_all.emit()
	await _until(func() -> bool: return arena.ui._ending.visible, 5.0)
	await _wait(0.3)
	await _shoot("%s_ending" % sport)
	if arena.ui.has_newspaper_waiting():
		arena.ui._after_the_result()
		await _wait(0.5)
		await _shoot("%s_paper_%s" % [sport, "front" if front else "inside"])

	if saved.is_empty():
		if FileAccess.file_exists(SAVE):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	else:
		var file := FileAccess.open(SAVE, FileAccess.WRITE)
		file.store_string(saved)
	get_tree().quit()


func _shoot(name: String) -> void:
	await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://dev/shots"))
	var out := "res://dev/shots/%s.png" % name
	get_viewport().get_texture().get_image().save_png(out)
	print("written to %s" % out)


func _wait(seconds: float) -> void:
	var deadline := Time.get_ticks_msec() + int(seconds * 1000.0)
	while Time.get_ticks_msec() < deadline:
		await get_tree().process_frame


func _until(done: Callable, seconds: float) -> bool:
	var deadline := Time.get_ticks_msec() + int(seconds * 1000.0)
	while not done.call():
		if Time.get_ticks_msec() > deadline:
			return false
		await get_tree().process_frame
	return true
