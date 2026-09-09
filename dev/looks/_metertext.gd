extends Node

## The last page of each lesson, which is where the reputation meter is now explained.
##
## It replaced a promise the game had made four times over — that nothing would ever
## count your mistakes for you — so it is worth looking at rather than assuming it fits.

func _ready() -> void:
	var arena: Node = load("res://scenes/beach.tscn").instantiate()
	arena.print_truth_while_testing = false
	add_child(arena)
	await get_tree().physics_frame

	for entry in [
		[Career.BADMINTON, RefereeUI.BADMINTON_LESSONS, "badminton"],
		[Career.BEACH, RefereeUI.BEACH_LESSONS, "beach"],
		[Career.INDOOR, RefereeUI.INDOOR_LESSONS, "indoor"],
		[Career.TENNIS, RefereeUI.TENNIS_LESSONS, "tennis"],
	]:
		var pages: Array = entry[1]
		arena.ui.show_teaching(entry[0])
		arena.ui._lesson = pages.size() - 1
		arena.ui._draw_lesson()
		arena.ui._teaching.visible = true
		await _shot("res://dev/shots/lesson_meter_%s.png" % entry[2])
		arena.ui.hide_teaching()
		print("%-10s last page is '%s', %d characters" % [
			entry[2], pages[pages.size() - 1]["title"],
			String(pages[pages.size() - 1]["body"]).length()])

	print("saved 4")
	get_tree().quit()


func _shot(path: String) -> void:
	for f in 4:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
