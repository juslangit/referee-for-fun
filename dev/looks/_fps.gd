extends Node

## How fast does each venue run, and where does the time go?
##
## Windowed, because headless draws nothing and so costs nothing. Vsync is switched off
## for the run so the number is what the machine can do rather than the screen's refresh
## rate. Every venue plays real rallies, called honestly, so the players, the ball, the
## crowd and the lights are all doing what they do in a real match.
##
## Then, in the heaviest venue, each suspect is switched off on its own — the volumetric
## fog, the anti-aliasing, the shadows, full-resolution rendering — so each one's cost is
## a measured number rather than a guess.
##
##   ONLY=badminton   measure one sport
##   SECONDS=6        how long each sample runs

const SCENES := [
	["badminton", "res://scenes/match.tscn", Career.BADMINTON, [0, 2, 4]],
	["beach", "res://scenes/beach.tscn", Career.BEACH, [0, 4]],
	["indoor", "res://scenes/volleyball.tscn", Career.INDOOR, [0, 4]],
	["tennis", "res://scenes/tennis.tscn", Career.TENNIS, [0, 4]],
	["table_tennis", "res://scenes/table_tennis.tscn", Career.TABLE_TENNIS, [0, 4]],
]

var SAVE := Career.save_path()

var _seconds := 6.0
var _rid: RID


func _ready() -> void:
	var saved := FileAccess.get_file_as_string(SAVE) if FileAccess.file_exists(SAVE) else ""
	if OS.has_environment("SECONDS"):
		_seconds = float(OS.get_environment("SECONDS"))
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	_rid = get_viewport().get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(_rid, true)

	print("window %v   render %v   refresh %d Hz" % [
		DisplayServer.window_get_size(), get_viewport().get_visible_rect().size,
		roundi(DisplayServer.screen_get_refresh_rate())])
	print("%-13s %4s %-24s %6s %8s %7s %7s %7s %6s %9s" % [
		"sport", "tier", "venue", "fps", "worst1%", "cpu ms", "phys ms", "gpu ms",
		"draws", "triangles"])

	var only := OS.get_environment("ONLY")
	for entry in SCENES:
		if only != "" and entry[0] != only:
			continue
		for tier in entry[3]:
			var arena: OfficiatedMatch = await _open(entry[1], entry[2], tier)
			var row := await _measure(arena)
			print("%-13s %4d %-24s %6.0f %8.1f %7.2f %7.2f %7.2f %6d %9d" % [
				entry[0], tier, String(arena.career.venue()["name"]).left(24),
				row["fps"], row["worst"], row["cpu"], row["physics"], row["gpu"],
				row["draws"], row["triangles"]])
			arena.queue_free()
			await get_tree().process_frame

	if only == "" or only == "badminton":
		await _what_each_thing_costs()

	if saved.is_empty():
		if FileAccess.file_exists(SAVE):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE))
	else:
		FileAccess.open(SAVE, FileAccess.WRITE).store_string(saved)
	get_tree().quit()


## The top badminton venue, with one thing switched off at a time.
func _what_each_thing_costs() -> void:
	print("")
	print("badminton, top venue, one thing off at a time")
	print("%-30s %6s %8s %7s" % ["", "fps", "worst1%", "gpu ms"])
	var trials := [
		["everything on", func(_a: Node) -> void: pass],
		["no volumetric fog", func(a: Node) -> void: _environment(a).volumetric_fog_enabled = false],
		["no fog at all", func(a: Node) -> void:
			_environment(a).volumetric_fog_enabled = false
			_environment(a).fog_enabled = false],
		["no MSAA", func(_a: Node) -> void: get_viewport().msaa_3d = Viewport.MSAA_DISABLED],
		["no shadows", func(a: Node) -> void:
			for light in _every(a, "Light3D"):
				light.shadow_enabled = false],
		["no crowd", func(a: Node) -> void:
			for stands in _every(a, "Node3D"):
				if stands is Stands:
					stands.visible = false],
		["no players or line judges", func(a: Node) -> void:
			for player in a.players:
				player.visible = false
			for judge in a.line_judges:
				judge.visible = false],
		["no truss or lamp fittings", func(a: Node) -> void:
			for node in a.find_children("Truss", "", true, false):
				node.visible = false
			for lamps in a.find_children("Lamps", "", true, false):
				for fitting in lamps.get_children():
					if not fitting is Light3D:
						fitting.visible = false],
		["no court lamps", func(a: Node) -> void:
			for light in _every(a, "SpotLight3D"):
				light.visible = false],
		["no lamp shadows", func(a: Node) -> void:
			for light in _every(a, "SpotLight3D"):
				light.shadow_enabled = false],
		["no sun shadow", func(a: Node) -> void:
			for light in _every(a, "DirectionalLight3D"):
				light.shadow_enabled = false],
		["no second court", func(a: Node) -> void:
			for node in a.find_children("SecondCourt", "", true, false):
				node.visible = false],
		["no venue at all", func(a: Node) -> void:
			for node in a.find_children("Venue", "", true, false):
				node.visible = false],
		["overhead camera paused", func(a: Node) -> void:
			for cam in _every(a, "Node3D"):
				if cam is ShuttleCam:
					cam.viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED],
		["half the lamps, twice as bright", func(a: Node) -> void: _keep_lamps(a, 0)],
		["four lamps", func(a: Node) -> void: _keep_lamps(a, 2)],
		["four lamps, no MSAA", func(a: Node) -> void:
			_keep_lamps(a, 2)
			get_viewport().msaa_3d = Viewport.MSAA_DISABLED],
		["four lamps, 85% resolution", func(a: Node) -> void:
			_keep_lamps(a, 2)
			get_viewport().scaling_3d_scale = 0.85],
		["four lamps, no MSAA, 85%", func(a: Node) -> void:
			_keep_lamps(a, 2)
			get_viewport().msaa_3d = Viewport.MSAA_DISABLED
			get_viewport().scaling_3d_scale = 0.85],
		["four lamps, FXAA, 85%", func(a: Node) -> void:
			_keep_lamps(a, 2)
			get_viewport().msaa_3d = Viewport.MSAA_DISABLED
			get_viewport().screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA
			get_viewport().scaling_3d_scale = 0.85],
		["four lamps, no MSAA, 75%", func(a: Node) -> void:
			_keep_lamps(a, 2)
			get_viewport().msaa_3d = Viewport.MSAA_DISABLED
			get_viewport().scaling_3d_scale = 0.75],
		["four lamps, FXAA, 75%", func(a: Node) -> void:
			_keep_lamps(a, 2)
			get_viewport().msaa_3d = Viewport.MSAA_DISABLED
			get_viewport().screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA
			get_viewport().scaling_3d_scale = 0.75],
		["four lamps, FXAA, 85%, no haze", func(a: Node) -> void:
			_keep_lamps(a, 2)
			_environment(a).volumetric_fog_enabled = false
			get_viewport().msaa_3d = Viewport.MSAA_DISABLED
			get_viewport().screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA
			get_viewport().scaling_3d_scale = 0.85],
		# The upscalers, set by number rather than by name: an enum name this build does not
		# have is a parse error, and a parse error leaves this scene running for ever.
		# 0 bilinear, 1 FSR 1, 3 MetalFX spatial.
		["upscale: FXAA, 75%, bilinear", func(_a: Node) -> void: _upscale(0, 0.75)],
		["upscale: FXAA, 75%, FSR", func(_a: Node) -> void: _upscale(1, 0.75)],
		["upscale: FXAA, 75%, MetalFX", func(_a: Node) -> void: _upscale(3, 0.75)],
		["upscale: FXAA, 85%, MetalFX", func(_a: Node) -> void: _upscale(3, 0.85)],
		["3D at 75% resolution", func(_a: Node) -> void: get_viewport().scaling_3d_scale = 0.75],
		["3D at 50% resolution", func(_a: Node) -> void: get_viewport().scaling_3d_scale = 0.5],
		["no fog, no MSAA, 75%", func(a: Node) -> void:
			_environment(a).volumetric_fog_enabled = false
			get_viewport().msaa_3d = Viewport.MSAA_DISABLED
			get_viewport().scaling_3d_scale = 0.75],
	]
	# TRIALS=lamp,everything runs only the trials whose names contain one of those words.
	# An Array rather than the PackedStringArray split() returns, which has no any(). A
	# parse error here does not stop the scene — it loads as a bare Node that never quits.
	var wanted: Array = Array(OS.get_environment("TRIALS").split(",", false))
	for trial in trials:
		if not wanted.is_empty() and not wanted.any(func(w: String) -> bool: return w in trial[0]):
			continue
		var arena: OfficiatedMatch = await _open("res://scenes/match.tscn", Career.BADMINTON, 4)
		trial[1].call(arena)
		var row := await _measure(arena)
		print("%-30s %6.0f %8.1f %7.2f" % [trial[0], row["fps"], row["worst"], row["gpu"]])
		# SHOTS=1 keeps a picture from the chair of each trial, to see what it cost.
		if OS.has_environment("SHOTS"):
			await RenderingServer.frame_post_draw
			get_viewport().get_texture().get_image().save_png(
				"res://dev/shots/fps_%s.png" % String(trial[0]).replace(" ", "_").replace(",", ""))
		arena.queue_free()
		# Back to whatever the project itself says, not to hard-coded values: once the
		# project's own defaults change, resetting to "MSAA and 100%" would time every later
		# trial against a game nobody is playing.
		get_viewport().msaa_3d = ProjectSettings.get_setting("rendering/anti_aliasing/quality/msaa_3d")
		get_viewport().screen_space_aa = ProjectSettings.get_setting(
			"rendering/anti_aliasing/quality/screen_space_aa")
		get_viewport().scaling_3d_mode = ProjectSettings.get_setting("rendering/scaling_3d/mode")
		get_viewport().scaling_3d_scale = ProjectSettings.get_setting("rendering/scaling_3d/scale")
		await get_tree().process_frame


func _measure(arena: OfficiatedMatch) -> Dictionary:
	# A second and a half to settle: shaders compile on first sight and would make the
	# first frames look far worse than any match ever does.
	await _play(arena, 1.5, [])
	var frames: Array[float] = []
	var sums := {"cpu": 0.0, "physics": 0.0, "gpu": 0.0, "draws": 0.0, "triangles": 0.0}
	await _play(arena, _seconds, frames, sums)
	var n := maxf(1.0, float(frames.size()))
	var total := 0.0
	for f in frames:
		total += f
	var sorted := frames.duplicate()
	sorted.sort()
	var worst_count := maxi(1, sorted.size() / 100)
	var worst := 0.0
	for i in worst_count:
		worst += sorted[sorted.size() - 1 - i]
	return {
		"fps": n / maxf(0.001, total),
		"worst": 1000.0 * worst / float(worst_count),
		"cpu": sums["cpu"] / n,
		"physics": sums["physics"] / n,
		"gpu": sums["gpu"] / n,
		"draws": int(sums["draws"] / n),
		"triangles": int(sums["triangles"] / n),
	}


## Plays honest rallies for `seconds`, recording each frame if asked.
func _play(arena: OfficiatedMatch, seconds: float, frames: Array[float], sums := {}) -> void:
	var left := seconds
	while left > 0.0:
		await get_tree().process_frame
		var delta := get_process_delta_time()
		left -= delta
		if arena._phase == arena.Phase.READY:
			arena.start_rally()
		elif arena._phase == arena.Phase.AWAITING_CALL and arena.current_rally() != null:
			var rally = arena.current_rally()
			arena.make_call(&"in" if rally.was_in else &"out")
		if sums.is_empty():
			continue
		frames.append(delta)
		sums["cpu"] += Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
		sums["physics"] += Performance.get_monitor(Performance.TIME_PHYSICS_PROCESS) * 1000.0
		sums["gpu"] += RenderingServer.viewport_get_measured_render_time_gpu(_rid)
		sums["draws"] += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
		sums["triangles"] += Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)


func _open(scene: String, sport: StringName, tier: int) -> OfficiatedMatch:
	var arena: OfficiatedMatch = load(scene).instantiate()
	arena.print_truth_while_testing = false
	add_child(arena)
	await get_tree().physics_frame
	arena.career = Career.new()
	arena.career.sport = sport
	arena.career.tier = tier
	arena.settings.taught = true
	arena.settings.taught_beach = true
	arena.settings.taught_indoor = true
	arena.settings.taught_tennis = true
	arena.settings.taught_table_tennis = true
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
	# Nobody challenges during a timing run. A badminton review does not finish (see
	# dev/checks/_badmintonreview), and a stalled match would time nothing.
	arena.has_challenge = false
	for f in 4:
		await get_tree().process_frame
	return arena


## Lights the court with fewer real lamps, each brighter by as many as were dropped, so
## the court gets the same light in total. Every fitting stays on the truss.
##
## `pairs` of 0 keeps every other lamp, alternating sides. Otherwise it keeps that many
## facing pairs, spaced evenly along the court.
func _keep_lamps(arena: Node, pairs: int) -> void:
	var lamps := _every(arena, "SpotLight3D")
	var keep := []
	if pairs == 0:
		for i in lamps.size():
			if (i / 2) % 2 == i % 2:
				keep.append(i)
	else:
		var along := lamps.size() / 2
		for p in pairs:
			var pair := roundi(float(along - 1) * (float(p) + 0.5) / float(pairs))
			keep.append(pair * 2)
			keep.append(pair * 2 + 1)
	var brighter := float(lamps.size()) / float(maxi(1, keep.size()))
	for i in lamps.size():
		if i in keep:
			lamps[i].light_energy *= brighter
		else:
			lamps[i].visible = false


## FXAA in place of MSAA, and the 3D drawn at `scale` and brought up to the screen by
## upscaler `mode`. The interface is drawn separately at full size either way.
func _upscale(mode: int, scale: float) -> void:
	get_viewport().msaa_3d = Viewport.MSAA_DISABLED
	get_viewport().screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA
	get_viewport().scaling_3d_mode = mode as Viewport.Scaling3DMode
	get_viewport().scaling_3d_scale = scale


func _environment(arena: Node) -> Environment:
	for node in _every(arena, "WorldEnvironment"):
		return node.environment
	return get_viewport().find_world_3d().environment


func _every(root: Node, type: String) -> Array:
	var found := []
	for node in root.find_children("*", type, true, false):
		found.append(node)
	return found
