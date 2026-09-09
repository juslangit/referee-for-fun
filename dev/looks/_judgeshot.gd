extends Node

## What the player actually sees now: the meter as they go out, and the line judge's
## call in words where the chair can read it.

func _ready() -> void:
	var court: Node = load("res://scenes/tennis.tscn").instantiate()
	court.print_truth_while_testing = false
	add_child(court)
	await get_tree().physics_frame
	court.career = Career.new()
	court.career.sport = Career.TENNIS
	court.career.tier = 3
	court.career.reputation = 0.74
	court.settings.taught_tennis = true
	court.ui.match_requested.emit()
	await get_tree().process_frame
	if court.pressure.exists():
		court.ui.briefing_acknowledged.emit()
		await get_tree().process_frame
	court.begin_match()

	# The meter, shown once as you go out even though nothing has moved yet.
	var waited := 0
	while court.ui._meter.modulate.a < 0.99 and waited < 400:
		await get_tree().process_frame
		waited += 1
	await _shot("res://dev/shots/meter_going_out.png")
	print("meter as the match begins: alpha %.2f, reads %s" % [
		court.ui._meter.modulate.a, court.ui._meter_value.text])

	# And a rally, held at the moment the line judge speaks.
	for r in 8:
		court.start_rally()
		var w := 0
		while court._phase != court.Phase.AWAITING_CALL and w < 4000:
			await get_tree().physics_frame
			w += 1
		if court._phase != court.Phase.AWAITING_CALL:
			continue
		var held := 0
		while not court.ui._judge_plate.visible and held < 200:
			await get_tree().physics_frame
			held += 1
		if court.ui._judge_plate.visible:
			print("line judge said: %s" % court.ui._judge_label.text)
			await _shot("res://dev/shots/line_judge_call.png")
			print("saved 2")
			get_tree().quit()
			return
		court._awaiting_since = Time.get_ticks_msec()
		court.make_call(&"in" if court.rally.was_in else &"out")
		for f in 30:
			await get_tree().process_frame
	print("the judge never spoke in eight rallies")
	get_tree().quit()


func _shot(path: String) -> void:
	for f in 4:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
