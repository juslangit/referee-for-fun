extends Node

## Any sport's venue, at the career tier in TIER, from three places: the umpire's chair,
## level from the chair (so what stands in front of the umpire is seen whole), and a wide
## shot from above one corner. For judging the modelled buildings of 2026-10-20.
##
## SCENE is the sport's scene, TAG names the files, WIDE (optional, "x,y,z") moves the wide
## camera and LOOK (optional, "x,y,z") what it looks at. Writes
## dev/shots/_venue_<TAG>_t<TIER>_{chair,level,wide}.png.

func _ready() -> void:
	var tier := int(OS.get_environment("TIER")) if OS.get_environment("TIER") != "" else 0
	var tag := OS.get_environment("TAG")
	var arena: Node = load(OS.get_environment("SCENE")).instantiate()
	arena.print_truth_while_testing = false
	add_child(arena)
	await get_tree().physics_frame
	arena.career = Career.new()
	arena.career.tier = tier
	for taught in ["taught_beach", "taught_indoor", "taught_tennis", "taught_table_tennis", "taught_takraw"]:
		arena.settings.set(taught, true)
	arena.ui.match_requested.emit()
	await get_tree().process_frame
	if arena.pressure.exists():
		arena.ui.briefing_acknowledged.emit()
		await get_tree().process_frame
	arena.begin_match()
	for f in 40:
		await get_tree().process_frame
	arena.ui.visible = false
	var stem := "res://dev/shots/_venue_%s_t%d" % [tag, tier]
	var cam := arena.camera as Camera3D
	cam.current = true
	await _shot(stem + "_chair.png")
	cam.rotation_degrees.x = 3.0
	await _shot(stem + "_level.png")
	var wide := Camera3D.new()
	add_child(wide)
	wide.fov = 70.0
	wide.position = _vec("WIDE", Vector3(-30.0, 26.0, -40.0))
	wide.look_at(_vec("LOOK", Vector3(0, 1, 0)))
	wide.current = true
	await _shot(stem + "_wide.png")
	get_tree().quit()


func _vec(name: String, fallback: Vector3) -> Vector3:
	var raw := OS.get_environment(name)
	if raw.is_empty():
		return fallback
	var p := raw.split(",")
	return Vector3(float(p[0]), float(p[1]), float(p[2]))


func _shot(path: String) -> void:
	for f in 6:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
