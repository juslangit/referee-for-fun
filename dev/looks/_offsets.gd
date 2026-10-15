extends Node

## Where each stroke puts the racket head at its moment of contact, against the generic spot
## a badminton player stands off the shuttle. For tuning tools/meshy/badminton_strokes.py so
## that each stroke meets the shuttle where the athlete actually stands for it.
##
##     SCENE=sepak_takraw godot --headless --path . res://dev/looks/_offsets.tscn

func _ready() -> void:
	var scene := OS.get_environment("SCENE") if OS.has_environment("SCENE") else "match"
	var arena: Node = load("res://scenes/%s.tscn" % scene).instantiate()
	arena.print_truth_while_testing = false
	add_child(arena)
	for f in 90:
		await get_tree().process_frame
	var player: Player = arena.players[0]
	var offsets: Dictionary = player._contact_offset
	var behind := player.reach * Player.STANCE_BEHIND
	var aside := player.reach * Player.STANCE_ASIDE
	print("reach %.2f: the shuttle stands %.2f m in front and %.2f m to the side of the feet" % [player.reach, behind, aside])
	for clip in offsets:
		var o: Vector3 = offsets[clip]
		# Model frame: +X their left, +Z in front.
		print("%-16s side %+.2f (right is -)  front %+.2f  height %.2f  out %.2f" % [
			clip, o.x, o.z, o.y, Vector2(o.x, o.z).length()])
	get_tree().quit()
