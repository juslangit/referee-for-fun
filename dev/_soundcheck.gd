extends Node

## Does the audio actually load and run? I cannot listen to it, so this checks the
## things that would be silently wrong: a stream that failed to load, a crowd bed that
## is not looping, and a mood crossfade that does not move.

func _ready() -> void:
	var arena: Node = load("res://scenes/match.tscn").instantiate()
	add_child(arena)
	await get_tree().physics_frame
	arena.ui.career_screen_requested.emit()
	await get_tree().process_frame
	arena.ui.match_requested.emit()
	await get_tree().process_frame
	arena.begin_match()
	for f in 6:
		await get_tree().process_frame

	var sound: Sound = arena.sound
	print("%-16s %-9s %-10s %s" % ["player", "stream", "playing", "loop"])
	for child in sound.get_children():
		var stream: AudioStream = child.stream
		var loop := "-"
		if stream is AudioStreamWAV:
			loop = "%s to %d" % [(stream as AudioStreamWAV).loop_mode, (stream as AudioStreamWAV).loop_end]
		print("%-16s %-9s %-10s %s" % [
			child.name, "ok" if stream != null else "MISSING",
			child.playing if child.has_method("is_playing") or true else "?", loop])

	print()
	for level in [0.0, 0.5, 1.0]:
		sound.set_mood(level)
		for f in 90:
			await get_tree().process_frame
		print("mood %.1f -> calm %6.1f dB, tense %6.1f dB" % [
			level, sound._calm.volume_db, sound._tense.volume_db])

	sound.whistle()
	sound.strike(Vector3(0, 1.5, 2), true)
	sound.landing(Vector3(1, 0, 3))
	sound.react(false)
	await get_tree().process_frame
	print()
	print("one-shots fired without error")
	get_tree().quit()
