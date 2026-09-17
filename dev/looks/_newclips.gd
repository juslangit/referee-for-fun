extends Node

## Every clip the new character can play, held at the frame that matters.
##
## The clips were not generated. They are the ones already in the project, authored on
## Meshy's own 24-joint skeleton by `tools/meshy/rig_clips.py`, and the character made
## on 2026-09-17 came off the same rig — so all 33 transferred for nothing. This is the
## proof of that, and the only way to judge whether a pose actually reads.
##
## `ONLY=vb_,sit` to photograph a subset.

var MODEL := OS.get_environment("MODEL") if not OS.get_environment("MODEL").is_empty() else "res://assets/meshy/official_new/official_new_animated.glb"
var SHOTS := OS.get_environment("SHOTS") if not OS.get_environment("SHOTS").is_empty() else "res://dev/shots/newclips"

## Where in each clip to stop. A serve caught at frame 0 is a man standing still.
var AT := float(OS.get_environment("AT")) if not OS.get_environment("AT").is_empty() else 0.55


func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SHOTS))
	var only := OS.get_environment("ONLY")

	var world := Node3D.new()
	add_child(world)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-42.0, -38.0, 0.0)
	light.light_energy = 1.5
	world.add_child(light)
	var fill := DirectionalLight3D.new()
	fill.rotation_degrees = Vector3(-18.0, 140.0, 0.0)
	fill.light_energy = 0.5
	world.add_child(fill)
	# A WorldEnvironment rather than a ColorRect. 2D always draws over 3D, and
	# `show_behind_parent` only orders siblings within the 2D layer — the first attempt
	# put a flat rectangle over the whole shot and photographed 33 identical blanks.
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.10, 0.12, 0.15)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.45, 0.48, 0.55)
	env.ambient_light_energy = 0.7
	var holder := WorldEnvironment.new()
	holder.environment = env
	world.add_child(holder)

	var figure: Node3D = load(MODEL).instantiate()
	world.add_child(figure)
	var player: AnimationPlayer = figure.find_children("*", "AnimationPlayer", true, false)[0]

	var eye := Camera3D.new()
	world.add_child(eye)
	eye.look_at_from_position(Vector3(2.2, 1.05, 2.8), Vector3(0.0, 0.95, 0.0), Vector3.UP)
	eye.fov = 46.0
	eye.current = true

	var names := player.get_animation_list()
	print("%d clips on the new character" % names.size())
	var taken := 0
	for name in names:
		if not only.is_empty():
			var wanted := false
			for part in only.split(","):
				if name.begins_with(part):
					wanted = true
			if not wanted:
				continue
		var clip := player.get_animation(name)
		player.play(name)
		player.seek(clip.length * AT, true)
		player.advance(0.0)
		for f in 3:
			await get_tree().process_frame
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("%s/%s.png" % [SHOTS, name])
		taken += 1
		print("   %-18s %5.2f s  %s" % [name, clip.length, "loops" if clip.loop_mode != Animation.LOOP_NONE else "once"])
	print("wrote %d pictures into %s" % [taken, SHOTS])
	get_tree().quit()
