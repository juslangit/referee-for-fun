extends Node

## The whole path a player takes from the title screen into a rally, pressing only the
## things a player can press.

func _ready() -> void:
	var arena: Node = load("res://scenes/match.tscn").instantiate()
	add_child(arena)
	await get_tree().physics_frame
	print("1. title screen")
	arena.ui.play_requested.emit()
	await get_tree().process_frame
	print("2. sport screen   visible=%s" % arena.ui._sport_menu.visible)
	arena.ui.sport_chosen.emit(&"badminton")
	await get_tree().process_frame
	print("3. career screen  sport menu gone=%s" % (not arena.ui._sport_menu.visible))
	arena.ui.match_requested.emit()
	await get_tree().process_frame
	arena._on_favour_chosen(Sides.Team.NONE)
	for f in 40:
		await get_tree().process_frame
		if arena._phase == arena.Phase.READY:
			arena._start_rally()
			break
	for f in 60:
		await get_tree().process_frame
	print("4. in a rally     phase=%d  venue=%s  shuttle cam=%s" % [
		arena._phase, arena.career.venue()["name"], arena.has_shuttle_cam])
	print("   settings applied: crowd bus=%d effects bus=%d look=%.4f" % [
		AudioServer.get_bus_index(Settings.CROWD_BUS),
		AudioServer.get_bus_index(Settings.EFFECTS_BUS),
		arena.camera.sensitivity])
	get_tree().quit()
