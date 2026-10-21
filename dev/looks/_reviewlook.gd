extends Node

## What a challenged line call looks like in every sport, as a strip of stills.
##
## Luqman asked on 2026-10-21 for every sport's review to play like the BWF one: an empty
## court, the flight again with a trail, and a dive onto the mark. This runs one review at
## the top venue of each sport and saves a picture every third of a second to `OUT`, or to
## the folder passed after `--`.

const SPORTS := [
	["badminton", "res://scenes/match.tscn", Career.BADMINTON],
	["beach", "res://scenes/beach.tscn", Career.BEACH],
	["indoor", "res://scenes/volleyball.tscn", Career.INDOOR],
	["tennis", "res://scenes/tennis.tscn", Career.TENNIS],
	["table_tennis", "res://scenes/table_tennis.tscn", Career.TABLE_TENNIS],
	["takraw", "res://scenes/sepak_takraw.tscn", Career.TAKRAW],
]
const EVERY := 0.33
const OUT := "user://reviewlook"

var _out := OUT


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		_out = args[0]
	DirAccess.make_dir_recursive_absolute(_out)
	var only := args[1] if args.size() > 1 else ""
	for entry in SPORTS:
		if only != "" and entry[0] != only:
			continue
		await _look(entry[0], entry[1], entry[2])
	get_tree().quit()


func _look(name: String, scene: String, sport: StringName) -> void:
	var arena: Node = load(scene).instantiate()
	arena.print_truth_while_testing = false
	# No walk-on: the review is what is being looked at, not the titles.
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
	for f in 4:
		await get_tree().process_frame

	# A rally that came down on the floor after a real flight.
	var path := PackedVector3Array()
	for attempt in 12:
		arena.start_rally()
		var waited := 0
		while arena._phase != arena.Phase.AWAITING_CALL and waited < 4000:
			await get_tree().physics_frame
			waited += 1
		var rally = arena.current_rally()
		if rally != null and arena.recorder != null:
			path = arena.recorder.path_to(rally.landing_point)
		if path.size() > 40:
			break
		arena._phase = arena.Phase.READY
	var rally = arena.current_rally()
	var book: Variant = {
		Career.BADMINTON: CallBook, Career.BEACH: BeachCallBook, Career.INDOOR: VolleyCallBook,
		Career.TENNIS: TennisCallBook, Career.TABLE_TENNIS: TableTennisCallBook,
		Career.TAKRAW: TakrawCallBook}[sport]
	# The wrong call, so the review has something to overturn.
	var call: CallType = book.get_call(&"in" if not rally.was_in else &"out")
	if sport == Career.BADMINTON:
		rally.record_call(call)
	else:
		rally.record_call(call, Sides.Team.NONE)
	print("%s: reviewing %d points of flight, margin %.2f, truth %s" % [
		name, path.size(), rally.margin, "IN" if rally.was_in else "OUT"])

	# `-- <dir> <sport> booth` plays this call as the final whistle's replay instead.
	var booth := OS.get_cmdline_user_args().size() > 2 and OS.get_cmdline_user_args()[2] == "booth"
	var state := {"finished": false}
	var run := func() -> void:
		if booth:
			arena.worst_calls.consider(rally, path)
			var replays := ReplayBooth.new()
			replays.arena = arena
			arena.add_child(replays)
			# As the real ending does: the paper's photograph first, then the replays.
			await replays.photograph(arena.worst_calls.worst())
			await replays.play(arena.worst_calls.countdown())
		else:
			await arena.review(Sides.Team.RED)
		state.finished = true
	run.call()
	var shot := 0
	var clock := 0.0
	var started := Time.get_ticks_msec()
	while not state.finished and Time.get_ticks_msec() - started < 15000:
		await get_tree().process_frame
		clock += get_process_delta_time()
		if clock >= EVERY:
			clock -= EVERY
			var image := get_viewport().get_texture().get_image()
			image.save_png("%s/%s_%02d.png" % [_out, name, shot])
			shot += 1
	var back: bool = arena.players.all(func(p): return p.visible)
	print("%s: %d stills, finished %s, players back %s, umpire camera back %s" % [
		name, shot, state.finished, back,
		get_viewport().get_camera_3d() == arena.camera])
	arena.queue_free()
	await get_tree().process_frame
