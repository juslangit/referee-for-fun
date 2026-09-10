extends Node

## Does every sound the game asks for actually exist?
##
## `Sound` checks `ResourceLoader.exists()` before it plays anything and returns quietly
## when the answer is no. That is the right behaviour in a build — a missing file should
## not crash a match — and the worst possible one to discover a mistake with, because a
## wrong path is not an error. It is silence, in a game whose crowd is the only feedback
## the player gets. So every path `sound.gd` names is read out of the source and loaded
## here, and one that does not load fails.
##
## Written when the Freesound previews were replaced with originals on 2026-09-10, which
## changed eight file extensions from .mp3 to .wav in one go.

const SOURCE := "res://scripts/sound.gd"


func _ready() -> void:
	var text := FileAccess.get_file_as_string(SOURCE)
	var found := RegEx.new()
	found.compile("res://assets/audio/[A-Za-z0-9_]+\\.(mp3|wav|ogg)")

	var paths: Array[String] = []
	for hit in found.search_all(text):
		var path := hit.get_string()
		if not paths.has(path):
			paths.append(path)

	var bad := 0
	print("every sound sound.gd names, loaded")
	for path: String in paths:
		var ok := ResourceLoader.exists(path)
		var length := 0.0
		if ok:
			var stream := load(path) as AudioStream
			ok = stream != null
			if ok:
				length = stream.get_length()
				ok = length > 0.0
		print("   %-44s %s" % [path.trim_prefix("res://assets/audio/"),
			"%.2f s" % length if ok else "MISSING OR EMPTY   <--"])
		if not ok:
			bad += 1

	print("")
	if paths.is_empty():
		print("found no sound paths in %s at all   <-- the pattern is wrong" % SOURCE)
		bad += 1
	if bad == 0:
		print("all %d sounds load" % paths.size())
	else:
		print("%d PROBLEM(S) — a missing sound is silence, not an error" % bad)
	get_tree().quit()
