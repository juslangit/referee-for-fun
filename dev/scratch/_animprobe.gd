extends Node
func _ready() -> void:
	var arena: Node = load("res://scenes/match.tscn").instantiate()
	arena.print_truth_while_testing = false
	add_child(arena)
	for t in 8:
		await get_tree().create_timer(1.0).timeout
		for p in get_tree().get_nodes_in_group(Player.GROUP):
			var a: AnimationPlayer = p._animator
			var sk := Models.skeleton_of(p._figure) if p._figure else null
			var pose := sk.get_bone_pose_rotation(5) if sk else Quaternion()
			print("t=%d %s anim=%s playing=%s active=%s clip=%s measuring=%s pose=%s" % [t, p.name,
				a.current_animation if a else "NO ANIMATOR", a.is_playing() if a else false,
				a.active if a else false, p._clip, p._measuring, pose])
	get_tree().quit()
