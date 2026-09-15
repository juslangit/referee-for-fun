extends Node

## The new screen: one a side or two, for the three sports that have both. Sepak takraw's
## is three a side or two, and its first button says REGU.

func _ready() -> void:
	var hall: Node = load("res://scenes/match.tscn").instantiate()
	hall.print_truth_while_testing = false
	add_child(hall)
	await get_tree().physics_frame
	hall.ui._main_menu.visible = false

	for sport in [Career.BADMINTON, Career.TENNIS, Career.TAKRAW]:
		hall.ui.show_format_menu(sport)
		await _shot("res://dev/shots/format_%s.png" % sport)
		hall.ui.hide_format_menu()

	print("sports that ask: %s" % ", ".join(Career.BOTH_FORMATS.map(
		func(s): return Career.name_of(s))))
	for which in Career.IN_ORDER:
		print("   %-20s asks: %s" % [
			Career.name_of(which), Career.has_both_formats(which)])
	print("saved 3")
	get_tree().quit()


func _shot(path: String) -> void:
	for f in 6:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
