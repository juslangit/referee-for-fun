extends Node

## Does Godot's movie writer record this game at all?
##
## Everything else in the trailer depends on the answer, so it is asked first and on its
## own. Run with --write-movie: the engine then advances at a fixed frame rate and writes
## every frame, which also makes the recording deterministic.

func _ready() -> void:
	var arena: Node = load("res://scenes/match.tscn").instantiate()
	arena.print_truth_while_testing = false
	add_child(arena)
	await get_tree().physics_frame
	arena.career = Career.new()
	arena.career.tier = 4
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
	arena.start_rally()
	for f in 180:
		await get_tree().process_frame
	print("recorded 180 frames")
	get_tree().quit()
