extends Node

## Is the room audible in every sport?
##
## The game's central rule is that there is no suspicion meter — the only thing telling
## the player how much trouble they are in is the room. So a sport whose crowd bed never
## responds to suspicion, and which makes no sound when the ball is hit or lands, is a
## sport playing the design with half of it missing.

func _ready() -> void:
	for scene in ["res://scenes/match.tscn", "res://scenes/beach.tscn",
			"res://scenes/volleyball.tscn"]:
		await _listen(scene)
	get_tree().quit()


func _listen(scene: String) -> void:
	var arena: Node = load(scene).instantiate()
	arena.print_truth_while_testing = false
	add_child(arena)
	await get_tree().physics_frame

	var sport := "badminton"
	if scene.ends_with("beach.tscn"):
		sport = "beach"
	elif scene.ends_with("volleyball.tscn"):
		sport = "indoor"

	var bed_follows: bool = arena.suspicion.level_changed.is_connected(arena.sound.set_mood)
	# `_mood` eases towards `_wanted_mood` over several frames, so the target is what
	# says whether the signal arrived; reading the eased value one frame later says
	# only that easing is gradual.
	arena.suspicion.level_changed.emit(0.75)
	await get_tree().process_frame
	print("%-10s bed follows suspicion: %-4s   at 0.75 the mix is asked for %.2f" % [
		sport, "yes" if bed_follows else "NO", arena.sound._wanted_mood])
	# A ball is heard landing either once, by the match, or on every bounce, by the ball.
	print("           hears the ball struck: %-4s  hears it land: %s" % [
		"yes" if _uses(scene, "sound.strike") else "NO",
		"yes" if _uses(scene, "sound.landing") or _uses(scene, "sound.bounce") else "NO"])

	arena.queue_free()
	await get_tree().process_frame




## Whether that sport's match script actually plays the sound.
func _uses(scene: String, call: String) -> bool:
	var script := "res://scripts/match.gd"
	if scene.ends_with("beach.tscn"):
		script = "res://scripts/beach_match.gd"
	elif scene.ends_with("volleyball.tscn"):
		script = "res://scripts/volley_match.gd"
	return FileAccess.get_file_as_string(script).contains(call)
