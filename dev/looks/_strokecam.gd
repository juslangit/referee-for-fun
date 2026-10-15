extends Node

## Live badminton rallies, photographed at every contact from a camera beside the striker,
## each frame named after the stroke that played it. For checking by eye that the stroke on
## screen is the one the situation calls for (dev/looks/_movelog has the numbers).
##
##     godot --path . res://dev/looks/_strokecam.tscn --fixed-fps 60 --resolution 960x720
##     SPORT=tennis   SHOTS=24   OUT=strokes   (the folder under dev/shots)   CLIPS=bd_smash,bd_clear (only these)

const STRIKES := &"strike"


func _ready() -> void:
	var want := int(OS.get_environment("SHOTS")) if OS.has_environment("SHOTS") else 24
	var out := "res://dev/shots/%s" % (OS.get_environment("OUT") if OS.has_environment("OUT") else "strokes")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out))
	# Any sport: SPORT=tennis|table_tennis|indoor|beach|takraw, badminton when not given.
	var sports := {
		"badminton": ["res://scenes/match.tscn", Career.BADMINTON],
		"beach": ["res://scenes/beach.tscn", Career.BEACH],
		"indoor": ["res://scenes/volleyball.tscn", Career.INDOOR],
		"tennis": ["res://scenes/tennis.tscn", Career.TENNIS],
		"table_tennis": ["res://scenes/table_tennis.tscn", Career.TABLE_TENNIS],
		"takraw": ["res://scenes/sepak_takraw.tscn", Career.TAKRAW],
	}
	var sport: String = OS.get_environment("SPORT") if sports.has(OS.get_environment("SPORT")) else "badminton"
	var arena: Node = load(str(sports[sport][0])).instantiate()
	arena.print_truth_while_testing = false
	add_child(arena)
	await get_tree().physics_frame
	arena.career = Career.new()
	arena.career.sport = sports[sport][1]
	for flag in ["taught", "taught_beach", "taught_indoor", "taught_tennis",
			"taught_table_tennis", "taught_takraw"]:
		arena.settings.set(flag, true)
	if arena.has_method("rebuild_players"):
		arena.rebuild_players()
	arena.ui.match_requested.emit()
	await get_tree().process_frame
	if arena.pressure.exists():
		arena.ui.briefing_acknowledged.emit()
		await get_tree().process_frame
	arena.begin_match()
	for layer in arena.find_children("*", "CanvasLayer", true, false):
		(layer as CanvasLayer).visible = false
	var cam := Camera3D.new()
	cam.fov = 50.0
	add_child(cam)

	var taken := 0
	var before := int(arena.sound.heard.get(STRIKES, 0))
	for frame in 60000:
		await get_tree().physics_frame
		for layer in arena.find_children("*", "CanvasLayer", true, false):
			(layer as CanvasLayer).visible = false
		var ball: Node3D = arena.ball_in_play()
		var struck := int(arena.sound.heard.get(STRIKES, 0))
		if struck > before and ball != null and is_instance_valid(ball):
			var who: Player = null
			var best := 3.0
			for p in arena.players:
				var d: float = p.hitting_point().distance_to(ball.global_position)
				if d < best:
					best = d
					who = p
			var only := OS.get_environment("CLIPS").split(",", false)
			if who != null and not only.is_empty() and not only.has(who.playing_clip()):
				who = null
			if who != null:
				# From the opponent's side, off to the striker's right, at chest height.
				var facing: float = who.across_the_net()
				var forward := Vector3(sin(facing), 0.0, cos(facing))
				var right := Vector3(-cos(facing), 0.0, sin(facing))
				var at := who.global_position + Vector3(0, 1.1, 0)
				cam.global_position = at + forward * 3.6 + right * 1.6 + Vector3(0, 0.5, 0)
				cam.look_at(at)
				cam.current = true
				await RenderingServer.frame_post_draw
				var name := "%02d_%s_gap%.2f" % [taken, who.playing_clip(), best]
				get_viewport().get_texture().get_image().save_png(
					"%s/%s.png" % [out, name])
				print("saved ", name)
				taken += 1
				if taken >= want:
					break
		before = struck
		if arena._phase == arena.Phase.READY:
			arena.start_rally()
		elif arena._phase == arena.Phase.AWAITING_CALL:
			arena._awaiting_since = Time.get_ticks_msec()
			arena.make_call(&"in" if arena.current_rally().was_in else &"out")
			if arena.board.is_over:
				arena.begin_match()
	get_tree().quit()
