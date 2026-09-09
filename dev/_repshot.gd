extends Node

## What the reputation meter looks like: at full opacity, and half way through its fade.

func _ready() -> void:
	var sand: Node = load("res://scenes/beach.tscn").instantiate()
	sand.print_truth_while_testing = false
	add_child(sand)
	await get_tree().physics_frame

	sand.career = Career.new()
	sand.career.sport = Career.BEACH
	sand.career.tier = 3
	sand.career.reputation = 0.71
	sand.settings.taught_beach = true
	sand.ui.match_requested.emit()
	await get_tree().process_frame
	if sand.pressure.exists():
		sand.ui.briefing_acknowledged.emit()
		await get_tree().process_frame
	sand.begin_match()
	for f in 3:
		await get_tree().process_frame

	# One rally, and a lie about it, which is what puts the meter up.
	sand.start_rally()
	var waited := 0
	while sand._phase != sand.Phase.AWAITING_CALL and waited < 4000:
		await get_tree().physics_frame
		waited += 1
	sand._awaiting_since = Time.get_ticks_msec()
	sand.make_call(&"in" if not sand.rally.was_in else &"out")

	# Full opacity, part way through the hold.
	var held := 0
	while held < 900 and sand.ui._meter.modulate.a < 0.99:
		await get_tree().process_frame
		held += 1
	sand.ui.set_prompt("SPACE  whistle the serve")
	await _shot("res://dev/shots/reputation_meter.png")
	print("meter at full: alpha %.2f, bar %d / 100" % [
		sand.ui._meter.modulate.a, roundi(sand.ui._meter_bar.value)])

	# And half way out, to show the fade is a fade and not a cut.
	while sand.ui._meter.modulate.a > 0.55 and sand.ui._meter.visible:
		await get_tree().process_frame
	await _shot("res://dev/shots/reputation_fading.png")
	print("meter fading: alpha %.2f" % sand.ui._meter.modulate.a)
	print("saved 2")
	get_tree().quit()


func _shot(path: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
