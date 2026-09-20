extends Node

## One sport's hall from the official's seat, at a given rung of the ladder.
##
## Written on 2026-09-20 to compare tennis and table tennis before and after they were
## moved onto the shared lighting rig. Takes the scene, a tag for the file name, and the
## tier, so the same camera answers for every sport.

func _ready() -> void:
	var scene := OS.get_environment("SCENE")
	var tag := OS.get_environment("TAG")
	var tier := int(OS.get_environment("TIER")) if OS.has_environment("TIER") else 4
	var arena: Node = load(scene).instantiate()
	arena.print_truth_while_testing = false
	add_child(arena)
	await get_tree().physics_frame
	arena.career = Career.new()
	arena.career.tier = tier
	# Past the lesson and the briefing, which are not what is being looked at.
	arena.settings.taught_beach = true
	arena.settings.taught_indoor = true
	arena.settings.taught_tennis = true
	arena.settings.taught_table_tennis = true
	arena.settings.taught_takraw = true
	arena.ui.match_requested.emit()
	await get_tree().process_frame
	if arena.pressure.exists():
		arena.ui.briefing_acknowledged.emit()
		await get_tree().process_frame
	arena.begin_match()
	arena.ui.visible = false
	for f in 30:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(
		"res://dev/shots/hall_%s_%d.png" % [tag, tier])
	print("saved %s tier %d" % [tag, tier])
	get_tree().quit()
