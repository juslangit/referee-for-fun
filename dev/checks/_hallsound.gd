extends Node

## Does the hall actually make a noise, and does it keep making it?
##
## Two things worth checking rather than assuming. Every file the game asks for has to
## exist — a missing one is silence, not an error. And the two crowd beds have to LOOP:
## they are the only continuous sound in the game, they are mp3 now, and an mp3 loops
## with a flag rather than with the sample positions a WAV uses.

func _ready() -> void:
	var hall := Sound.new()
	add_child(hall)
	await get_tree().process_frame

	print("the shared half of the hall")
	for entry in [
		["whistle", Sound.WHISTLE], ["crowd, settled", Sound.CALM],
		["crowd, restless", Sound.TENSE], ["applause", Sound.APPLAUSE],
		["groan", Sound.GROAN], ["a line judge calling out", Sound.JUDGE_OUT],
	]:
		var path: String = entry[1]
		var there := ResourceLoader.exists(path)
		var seconds := 0.0
		if there:
			var stream: AudioStream = load(path)
			seconds = stream.get_length()
		print("   %-26s %-30s %s  %5.1fs" % [
			entry[0], path.get_file(), "found" if there else "MISSING", seconds])

	print()
	print("the beds have to loop or the hall goes quiet")
	for entry in [["settled", Sound.CALM], ["restless", Sound.TENSE]]:
		var stream: AudioStream = load(entry[1])
		var loops := false
		if stream is AudioStreamMP3:
			loops = (Sound._looping(entry[1]) as AudioStreamMP3).loop
		elif stream is AudioStreamWAV:
			loops = (Sound._looping(entry[1]) as AudioStreamWAV).loop_mode != AudioStreamWAV.LOOP_DISABLED
		print("   %-10s %-34s loops: %s" % [entry[0], entry[1].get_file(), loops])

	print()
	print("and every sport's own kit")
	var missing := 0
	for sport in Sound.KITS:
		for which in ["soft", "hard", "land", "net", "steps"]:
			for path in Sound.KITS[sport].get(which, []):
				if not ResourceLoader.exists(String(path)):
					missing += 1
	print("   files that do not exist: %d   (must be 0)" % missing)
	get_tree().quit()
