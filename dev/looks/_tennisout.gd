extends Node

## The outdoor tennis courts, from the chair and from a corner, at the career tier in
## TIER (default 0). For judging the sky and what stands round the court.

func _ready() -> void:
	var tier := int(OS.get_environment("TIER")) if OS.get_environment("TIER") != "" else 0
	var court: Node = load("res://scenes/tennis.tscn").instantiate()
	court.print_truth_while_testing = false
	if OS.get_environment("SKY") != "":
		court.sky_id = StringName(OS.get_environment("SKY"))
	add_child(court)
	await get_tree().physics_frame
	court.career = Career.new()
	court.career.sport = Career.TENNIS
	court.career.tier = tier
	court.settings.taught_tennis = true
	court.ui.match_requested.emit()
	await get_tree().process_frame
	if court.pressure.exists():
		court.ui.briefing_acknowledged.emit()
		await get_tree().process_frame
	court.begin_match()
	for f in 30:
		await get_tree().process_frame
	court.ui.visible = false
	var tag := "t%d_%s" % [tier, court.sky_id]
	await _shot("res://dev/shots/_tennisout_%s_chair.png" % tag)
	var cam := court.camera as Camera3D
	cam.rotation_degrees.x = 2.0
	await _shot("res://dev/shots/_tennisout_%s_level.png" % tag)
	var wide := Camera3D.new()
	add_child(wide)
	wide.fov = 70.0
	wide.position = Vector3(-38.0, 40.0, -62.0)
	wide.look_at(Vector3(0, 1, 0))
	wide.current = true
	await _shot("res://dev/shots/_tennisout_%s_wide.png" % tag)
	get_tree().quit()


func _shot(path: String) -> void:
	for f in 6:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
