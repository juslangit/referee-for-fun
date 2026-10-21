extends Node

## Does a review cost frames? Measured before the v0.3.2 release (2026-10-21).
##
## The review replay draws the hall a second time for the big screen's feed and moves up to
## 1,400 clapping spectators, so the frame rate is measured during a rally and during a
## review at the top venue of each sport. Windowed, vsync off; see `_fps`.

const SPORTS := [
	["badminton", "res://scenes/match.tscn", Career.BADMINTON],
	["beach", "res://scenes/beach.tscn", Career.BEACH],
	["indoor", "res://scenes/volleyball.tscn", Career.INDOOR],
	["tennis", "res://scenes/tennis.tscn", Career.TENNIS],
	["table_tennis", "res://scenes/table_tennis.tscn", Career.TABLE_TENNIS],
	["takraw", "res://scenes/sepak_takraw.tscn", Career.TAKRAW],
]


func _ready() -> void:
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	print("%-13s %10s %10s %12s %12s" % ["sport", "rally fps", "worst 1%", "review fps", "worst 1%"])
	for entry in SPORTS:
		await _measure(entry[0], entry[1], entry[2])
	get_tree().quit()


func _measure(name: String, scene: String, sport: StringName) -> void:
	var arena: Node = load(scene).instantiate()
	arena.print_truth_while_testing = false
	arena.cutscenes = false
	add_child(arena)
	await get_tree().physics_frame
	arena.career = Career.new()
	arena.career.sport = sport
	arena.career.tier = 4
	for flag in ["taught", "taught_beach", "taught_indoor", "taught_tennis",
			"taught_table_tennis", "taught_takraw"]:
		arena.settings.set(flag, true)
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
	for f in 30:
		await get_tree().process_frame

	# A rally, timed while it is played.
	arena.start_rally()
	var rally_frames: Array[float] = []
	while arena._phase != arena.Phase.AWAITING_CALL and rally_frames.size() < 2000:
		await get_tree().process_frame
		rally_frames.append(get_process_delta_time())
	var rally = arena.current_rally()
	var book: Variant = {
		Career.BADMINTON: CallBook, Career.BEACH: BeachCallBook, Career.INDOOR: VolleyCallBook,
		Career.TENNIS: TennisCallBook, Career.TABLE_TENNIS: TableTennisCallBook,
		Career.TAKRAW: TakrawCallBook}[sport]
	var call: CallType = book.get_call(&"in" if not rally.was_in else &"out")
	if sport == Career.BADMINTON:
		rally.record_call(call)
	else:
		rally.record_call(call, Sides.Team.NONE)

	# The review, timed the same way.
	var state := {"finished": false}
	var run := func() -> void:
		await arena.review(Sides.Team.RED)
		state.finished = true
	run.call()
	var review_frames: Array[float] = []
	while not state.finished and review_frames.size() < 4000:
		await get_tree().process_frame
		review_frames.append(get_process_delta_time())
	var a := _summary(rally_frames)
	var b := _summary(review_frames)
	print("%-13s %10.0f %10.0f %12.0f %12.0f" % [name, a[0], a[1], b[0], b[1]])
	arena.queue_free()
	await get_tree().process_frame


## Average fps and the fps of the slowest 1% of frames.
func _summary(frames: Array[float]) -> Array:
	if frames.size() < 10:
		return [0.0, 0.0]
	var sorted := frames.duplicate()
	sorted.sort()
	var total := 0.0
	for f in frames:
		total += f
	var slow: float = sorted[int(sorted.size() * 0.99)]
	return [frames.size() / total, 1.0 / slow]
