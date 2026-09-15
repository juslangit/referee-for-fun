extends Node

## The broadcast caption in a real window, with everything else the bottom of the HUD can
## show at the same time — the prompt, the hall's line, the line judge and the reputation
## meter — so an overlap is seen rather than argued about.
##
##     godot --path . res://dev/looks/_commentaryshot.tscn --resolution 1920x1080
##
## SPORT=tennis (or beach, indoor, table_tennis) for another hall.

func _ready() -> void:
	var scenes := {
		"badminton": ["res://scenes/match.tscn", Career.BADMINTON],
		"beach": ["res://scenes/beach.tscn", Career.BEACH],
		"indoor": ["res://scenes/volleyball.tscn", Career.INDOOR],
		"tennis": ["res://scenes/tennis.tscn", Career.TENNIS],
		"table_tennis": ["res://scenes/table_tennis.tscn", Career.TABLE_TENNIS],
	}
	var which := OS.get_environment("SPORT") if OS.has_environment("SPORT") else "badminton"
	var arena: Node = load(scenes[which][0]).instantiate()
	arena.print_truth_while_testing = false
	add_child(arena)
	await get_tree().physics_frame
	arena.career = Career.new()
	arena.career.sport = scenes[which][1]
	for flag in ["taught", "taught_beach", "taught_indoor", "taught_tennis", "taught_table_tennis"]:
		arena.settings.set(flag, true)
	arena.ui.match_requested.emit()
	await get_tree().process_frame
	if arena.pressure.exists():
		arena.ui.briefing_acknowledged.emit()
		arena.ui.hide_briefing()
		await get_tree().process_frame
	arena.begin_match()
	for f in 30:
		await get_tree().process_frame

	arena.ui.show_commentary(Commentary.CHANNEL, Commentary.AISHA,
		"I've sat in that chair. When a whole hall reacts like that, you've lost them.")
	arena.ui.react("\"Are you WATCHING this?\"", 30.0)
	arena.ui.show_line_judge(false, 30.0)
	arena.ui.show_reputation(0.62, -0.04, true)
	for f in 40:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var path := "res://dev/shots/commentary_%s.png" % which
	get_viewport().get_texture().get_image().save_png(path)
	print("saved %s" % path)
	get_tree().quit()
