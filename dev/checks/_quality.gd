extends Node

## Does the quality setting change what is drawn, and does it leave the game alone?
##
##   godot --headless --path . res://dev/checks/_quality.tscn
##
## Added 2026-09-21 with the setting itself. Every venue holds 60 fps on the machine this
## is built on, which is the machine nobody else has, so there is a way to ask for less.
##
## The point of the check is the second half. A graphics setting that quietly makes the
## game easier or harder to referee is not a graphics setting — so this asserts that the
## haze, the lamp shadows and the crowd change, and that the **lamps themselves, their
## throw and the light on the court do not**. An official who cannot see the far corner
## has a broken game, not a fast one.

var _failures: Array[String] = []


func _ready() -> void:
	var readings := []
	for rung in Settings.QUALITY_NAMES.size():
		readings.append(await _look_at(rung))

	print("")
	print("%-12s %5s %7s %8s %9s %9s" % [
		"", "haze", "shadows", "crowd", "lamps", "throw m"])
	for rung in readings.size():
		var seen: Dictionary = readings[rung]
		print("%-12s %5s %7d %8d %9d %9.2f" % [
			Settings.QUALITY_NAMES[rung], seen["haze"], seen["shadows"], seen["crowd"],
			seen["lamps"], seen["throw"]])

	var full: Dictionary = readings[0]
	var lightest: Dictionary = readings[readings.size() - 1]

	_expect(bool(full["haze"]) and not bool(lightest["haze"]),
		"the haze goes when a lighter hall is asked for")
	_expect(int(full["shadows"]) > 0 and int(lightest["shadows"]) == 0,
		"the lamp shadows go at the lightest setting")
	_expect(int(lightest["crowd"]) < int(full["crowd"]),
		"fewer people are drawn (%d of %d)" % [lightest["crowd"], full["crowd"]])

	# And the half that must not move.
	_expect(int(full["lamps"]) == int(lightest["lamps"]),
		"the same lamps light the court either way (%d and %d)" % [
			full["lamps"], lightest["lamps"]])
	_expect(absf(float(full["throw"]) - float(lightest["throw"])) < 0.01,
		"the beams throw just as far (%.2f m and %.2f m)" % [full["throw"], lightest["throw"]])

	print("")
	if _failures.is_empty():
		print("PASS  a lighter hall is scenery only — the court is lit the same either way")
	else:
		for failure in _failures:
			print("FAIL  %s" % failure)
	get_tree().quit()


func _expect(ok: bool, what: String) -> void:
	print("   %s  %s" % ["ok  " if ok else "FAIL", what])
	if not ok:
		_failures.append(what)


func _look_at(rung: int) -> Dictionary:
	var arena: Node = load("res://scenes/match.tscn").instantiate()
	arena.print_truth_while_testing = false
	add_child(arena)
	for f in 8:
		await get_tree().physics_frame

	# Set on the match's **own** settings, not on a fresh one. A match loads the player's
	# settings and calls `apply()`, and `apply()` is the only thing that writes
	# `Settings.drawing` — so a rung set before the scene is built is overwritten by the
	# saved one a moment later. The first version of this check did that and reported the
	# setting as having no effect at all.
	arena.settings.quality = rung
	arena.settings.apply()

	arena.court.dress(Venue.Tier.ARENA)
	arena.court.stands.set_density(1.0)
	for f in 4:
		await get_tree().physics_frame

	var haze := false
	var shadows := 0
	var lamps := 0
	var throw := 0.0
	for node in _every(arena):
		if node is WorldEnvironment:
			var air: Environment = (node as WorldEnvironment).environment
			if air != null and air.volumetric_fog_enabled:
				haze = true
		elif node is SpotLight3D:
			var beam := node as SpotLight3D
			lamps += 1
			throw = maxf(throw, beam.spot_range)
			if beam.shadow_enabled:
				shadows += 1

	var crowd := 0
	for node in _every(arena):
		if node is MultiMeshInstance3D and String(node.name).begins_with("Crowd"):
			crowd += (node as MultiMeshInstance3D).multimesh.visible_instance_count

	arena.queue_free()
	await get_tree().process_frame
	return {"haze": haze, "shadows": shadows, "crowd": crowd, "lamps": lamps, "throw": throw}


func _every(node: Node) -> Array[Node]:
	var all: Array[Node] = []
	for child in node.get_children():
		all.append(child)
		all.append_array(_every(child))
	return all
