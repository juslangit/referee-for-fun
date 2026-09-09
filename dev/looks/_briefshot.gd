extends Node

## What the three briefings actually look like on screen, and the question after them.

func _ready() -> void:
	var arena: Node = load("res://scenes/match.tscn").instantiate()
	arena.print_truth_while_testing = false
	add_child(arena)
	await get_tree().physics_frame
	arena.ui.hide_menus()
	arena._umpire_view()

	var career := Career.new()
	career.tier = 3
	career.matches_at_tier = 2

	var shots := {
		"tournament": Pressure._tournament(),
		"promotion": Pressure._promotion(career),
	}
	career.grudge_name = "Wibowo"
	career.grudge_reason = "You took three rallies off them in one match and they counted every one."
	shots["grudge"] = Pressure._grudge(career)

	for label in shots:
		var pressure: Pressure = shots[label]
		arena.ui.show_briefing(pressure)
		await _shot("res://dev/shots/brief_%s.png" % label)
		arena.ui.hide_briefing()

	print("saved %d briefing shots" % shots.size())
	get_tree().quit()


func _shot(path: String) -> void:
	for f in 6:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
