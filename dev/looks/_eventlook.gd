extends Node

## Every sport's venue at the bottom, middle and top of its ladder: from the umpire's seat,
## and from high in a corner, to see the whole event round the court.
##
##     godot --path . res://dev/looks/_eventlook.tscn --resolution 1600x900 --fixed-fps 60
##
##   ONLY=tennis     one sport
##   TIERS=4         only these rungs
##   TAG=before      a word in the file name, to keep a before and an after

const SCENES := [
	["badminton", "res://scenes/match.tscn", Career.BADMINTON],
	["tennis", "res://scenes/tennis.tscn", Career.TENNIS],
	["table_tennis", "res://scenes/table_tennis.tscn", Career.TABLE_TENNIS],
	["indoor", "res://scenes/volleyball.tscn", Career.INDOOR],
	["beach", "res://scenes/beach.tscn", Career.BEACH],
	["takraw", "res://scenes/sepak_takraw.tscn", Career.TAKRAW],
]

## Where the wide camera stands for each sport, and what it looks at.
const WIDE := {
	"badminton": [Vector3(-9.0, 7.5, 12.0), Vector3(1.0, 0.5, 0.0)],
	"tennis": [Vector3(-14.0, 11.0, 22.0), Vector3(0.0, 0.0, 0.0)],
	"table_tennis": [Vector3(-6.5, 5.0, 8.0), Vector3(0.0, 0.5, 0.0)],
	"indoor": [Vector3(-11.0, 8.0, 15.0), Vector3(0.0, 0.5, 0.0)],
	"beach": [Vector3(-14.0, 9.0, 18.0), Vector3(0.0, 0.5, 0.0)],
	"takraw": [Vector3(-9.0, 6.5, 10.0), Vector3(0.0, 0.5, 0.0)],
}

## And from the other side of the court, low, looking back at the umpire's side.
const FAR := {
	"badminton": [Vector3(-5.0, 3.5, -8.0), Vector3(6.0, 1.0, 3.0)],
	"tennis": [Vector3(-8.0, 4.0, -17.0), Vector3(8.0, 1.0, 4.0)],
	"table_tennis": [Vector3(-3.3, 2.2, -5.0), Vector3(4.0, 1.0, 2.0)],
	"indoor": [Vector3(-8.0, 4.0, -13.5), Vector3(8.0, 1.0, 3.0)],
	"beach": [Vector3(-9.0, 4.0, -14.0), Vector3(9.0, 1.0, 3.0)],
	"takraw": [Vector3(-5.5, 3.2, -9.0), Vector3(5.0, 1.0, 2.0)],
}

var SAVE := Career.save_path()


func _ready() -> void:
	var saved := FileAccess.get_file_as_string(SAVE) if FileAccess.file_exists(SAVE) else ""
	var only := OS.get_environment("ONLY")
	var tag := OS.get_environment("TAG")
	var tiers: Array = [0, 2, 4]
	if OS.has_environment("TIERS"):
		tiers = Array(OS.get_environment("TIERS").split(",", false)).map(func(t: String) -> int: return int(t))
	for entry in SCENES:
		if only != "" and entry[0] != only:
			continue
		for tier in tiers:
			var arena: OfficiatedMatch = await _open(entry[1], entry[2], tier)
			for f in 40:
				await get_tree().process_frame
			var stem := "res://dev/shots/events/%s_%d%s" % [entry[0], tier, "" if tag == "" else "_" + tag]
			await _save(stem + "_chair.png")
			var wide := Camera3D.new()
			wide.fov = 62.0
			arena.add_child(wide)
			wide.global_position = WIDE[entry[0]][0]
			wide.look_at(WIDE[entry[0]][1])
			wide.make_current()
			await _save(stem + "_wide.png")
			var back := Camera3D.new()
			back.fov = 62.0
			arena.add_child(back)
			back.global_position = FAR[entry[0]][0]
			back.look_at(FAR[entry[0]][1])
			back.make_current()
			await _save(stem + "_far.png")
			print("saved ", stem)
			arena.queue_free()
			await get_tree().process_frame
	if saved.is_empty():
		if FileAccess.file_exists(SAVE):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	else:
		FileAccess.open(SAVE, FileAccess.WRITE).store_string(saved)
	get_tree().quit()


func _save(path: String) -> void:
	for f in 3:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)


func _open(scene: String, sport: StringName, tier: int) -> OfficiatedMatch:
	var arena: OfficiatedMatch = load(scene).instantiate()
	arena.print_truth_while_testing = false
	add_child(arena)
	await get_tree().physics_frame
	arena.career = Career.new()
	arena.career.sport = sport
	arena.career.tier = tier
	arena.settings.taught = true
	arena.settings.taught_beach = true
	arena.settings.taught_indoor = true
	arena.settings.taught_tennis = true
	arena.settings.taught_table_tennis = true
	arena.settings.taught_takraw = true
	if sport == Career.BADMINTON:
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
	arena.has_challenge = false
	return arena
