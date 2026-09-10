extends Node

## Every match so far — what the one reputation number is actually made of.

func _ready() -> void:
	var hall: Node = load("res://scenes/match.tscn").instantiate()
	hall.print_truth_while_testing = false
	add_child(hall)
	await get_tree().physics_frame
	hall.ui._main_menu.visible = false

	# A career several sports and several disasters deep.
	var career := Career.new()
	for entry in [
		[Career.BADMINTON, true, 0.08], [Career.BADMINTON, true, 0.31],
		[Career.BEACH, true, 0.12], [Career.BADMINTON, false, 0.04],
		[Career.INDOOR, true, 0.55], [Career.TENNIS, false, 0.09],
		[Career.TENNIS, true, 0.22], [Career.BEACH, true, 0.86],
	]:
		career.sport = entry[0]
		career.doubles = entry[1]
		career.finish_match(entry[2], entry[2] > 0.8, [])
	hall.career = career

	print("rows kept: %d of %d matches (cap %d)" % [
		career.history.size(), career.matches_refereed, Career.HISTORY_KEPT])
	print("newest first: %s at %s" % [
		Career.name_of(StringName(career.history[0]["sport"])),
		career.history[0]["venue"]])

	# And that it survives a save and a reload, which is the whole point of a record.
	career.save()
	var read := Career.load_or_start()
	print("after saving and reopening: %d rows, newest %s" % [
		read.history.size(), read.history[0]["venue"] if not read.history.is_empty() else "—"])
	Career.start_again().save()

	hall.ui.show_history(career)
	await _shot("res://dev/shots/history.png")
	print("saved")
	get_tree().quit()


func _shot(path: String) -> void:
	for f in 6:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
