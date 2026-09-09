extends Node

## Does F actually let you call a fault, in both volleyballs?
##
## This was the stall Luqman hit. Both prompts offered F, neither had wired it, so an
## official who wanted to call a fault had nothing that worked — and SPACE did nothing
## either, because the game was still waiting for the call that could not be made.

func _ready() -> void:
	for scene in ["res://scenes/beach.tscn", "res://scenes/volleyball.tscn"]:
		await _try(scene)
	get_tree().quit()


func _try(scene: String) -> void:
	var arena: Node = load(scene).instantiate()
	arena.print_truth_while_testing = false
	add_child(arena)
	await get_tree().physics_frame

	var beach: bool = scene.ends_with("beach.tscn")
	arena.career = Career.new()
	arena.career.sport = Career.BEACH if beach else Career.INDOOR
	if beach:
		arena.settings.taught_beach = true
	else:
		arena.settings.taught_indoor = true
	arena.ui.match_requested.emit()
	await get_tree().process_frame
	if arena.pressure.exists():
		arena.ui.briefing_acknowledged.emit()
		await get_tree().process_frame
	arena.begin_match()
	for f in 4:
		await get_tree().process_frame

	print("=== %s" % ("beach" if beach else "indoor"))
	arena.start_rally()
	var waited := 0
	while arena._phase != arena.Phase.AWAITING_CALL and waited < 4000:
		await get_tree().physics_frame
		waited += 1

	arena.open_the_fault_panel()
	await get_tree().process_frame
	print("  F opens the panel: %s" % ("yes" if arena.ui.is_fault_panel_open() else "NO"))
	print("  it offers: %s" % ", ".join(_offered(arena)))
	print("  cards offered: %s  (neither sport prices them)" % (
		"YES" if arena.ui.offers_cards else "no"))

	# Point at somebody, the way the panel does.
	var accusing: StringName = &"net_touch"
	arena.ui.punishment_chosen.emit(accusing, Sides.Team.RED)
	var settle := 0
	while arena._phase == arena.Phase.AWAITING_CALL and settle < 600:
		await get_tree().process_frame
		settle += 1
	print("  choosing NET TOUCH made the call: %s" % (
		"yes" if arena.rally.call != null and arena.rally.call.id == accusing else "NO"))
	print("  and the match moved on: %s (phase %d)" % [
		"yes" if arena._phase == arena.Phase.READY else "NO", arena._phase])
	print("  the panel closed: %s" % ("yes" if not arena.ui.is_fault_panel_open() else "NO"))

	arena.queue_free()
	await get_tree().process_frame


func _offered(arena: Node) -> Array[String]:
	var names: Array[String] = []
	for call in arena.ui.fault_book:
		names.append(String(call.label))
	return names
