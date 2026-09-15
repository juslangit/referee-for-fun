extends Node

## Sepak takraw in play, at the moments that matter to the referee: the lineup before the serve
## with the feet in their circles, the throw, the kick, the spike over the net and the landing —
## once from the chair and once from the side — and a lineup with a foot out of its circle.
##
##     godot --path . res://dev/looks/_takrawshot.tscn --resolution 1600x900 --fixed-fps 60
##
## Pictures go to dev/shots/takraw_*.png. DOUBLES=1 for two a side.

var SAVE := Career.save_path()


func _ready() -> void:
	var saved := FileAccess.get_file_as_string(SAVE) if FileAccess.file_exists(SAVE) else ""
	var doubles := OS.get_environment("DOUBLES") == "1"
	var arena: TakrawMatch = load("res://scenes/sepak_takraw.tscn").instantiate()
	arena.print_truth_while_testing = false
	add_child(arena)
	await get_tree().physics_frame
	arena.career = Career.new()
	arena.career.sport = Career.TAKRAW
	arena.career.tier = 4
	arena.career.doubles = doubles
	arena.settings.taught_takraw = true
	arena.rebuild_players()
	arena.ui.match_requested.emit()
	await get_tree().process_frame
	if arena.pressure.exists():
		arena.ui.briefing_acknowledged.emit()
		await get_tree().process_frame
	arena.begin_match()
	arena.has_challenge = false
	for f in 30:
		await get_tree().process_frame
	var tag := "_doubles" if doubles else ""

	var side := Camera3D.new()
	side.fov = 55.0
	arena.add_child(side)

	# A clean rally: the lineup, then the moments of it, from the chair.
	await _shot("res://dev/shots/takraw%s_lineup.png" % tag)
	arena.start_rally()
	# Each pair is how long after the last picture, and what it is of.
	for moment in [[0.5, "throw"], [0.5, "kick"], [1.6, "receive"]]:
		await _wait(moment[0])
		await _shot("res://dev/shots/takraw%s_%s.png" % [tag, moment[1]])
	# The spike, from the side of the court.
	while arena._phase == arena.Phase.IN_PLAY and arena._beat != TakrawMatch.Beat.ATTACK:
		await get_tree().process_frame
	side.global_position = Vector3(-5.4, 1.4, 3.8)
	side.look_at(Vector3(0.0, 1.4, 0.0))
	side.make_current()
	await _wait(0.35)
	await _shot("res://dev/shots/takraw%s_spike.png" % tag)
	arena.camera.make_current()
	while arena._phase != arena.Phase.AWAITING_CALL:
		await get_tree().process_frame
	await _wait(0.4)
	await _shot("res://dev/shots/takraw%s_landing.png" % tag)

	# Until a rally lines up with a foot out of its circle.
	arena.make_call(&"in" if arena.rally.was_in else &"out")
	while arena._phase != arena.Phase.READY:
		await get_tree().process_frame
	for attempt in 80:
		arena.enter_ready()
		arena.rally = TakrawRally.new()
		arena.rally.served_by = arena.serving
		arena._fault = &"service_fault"
		arena._apply_the_serving_fault()
		if arena.rally.service_fault_visibility > 0.5:
			# Looking down at the circle from behind the server, the way a line referee would.
			var circle := TakrawSpec.service_circle(Sides.half_sign(arena.serving))
			side.global_position = circle + Vector3(1.6, 2.6, Sides.half_sign(arena.serving) * 2.2)
			side.look_at(circle + Vector3(0.0, 0.3, 0.0))
			side.make_current()
			await _wait(0.3)
			await _shot("res://dev/shots/takraw%s_foot_fault.png" % tag)
			break
	if saved.is_empty():
		if FileAccess.file_exists(SAVE):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	else:
		FileAccess.open(SAVE, FileAccess.WRITE).store_string(saved)
	get_tree().quit()


func _wait(seconds: float) -> void:
	await get_tree().create_timer(maxf(0.0, seconds)).timeout


func _shot(path: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
	print("saved ", path)
