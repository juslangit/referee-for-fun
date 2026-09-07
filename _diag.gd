extends Node

func _ready() -> void:
	var arena: Node = load("res://scenes/match.tscn").instantiate()
	add_child(arena)
	await get_tree().physics_frame
	var judge: LineJudge = arena.line_judge
	print("line judge global position: ", judge.global_position)
	print("visible: ", judge.visible, "  children: ", judge.get_children().size())
	for child in judge.get_children():
		var extra := ""
		if child is MeshInstance3D:
			extra = "  mesh=%s  pos=%v  visible=%s" % [child.mesh.get_class(), child.position, child.visible]
		print("  - ", child.name, " (", child.get_class(), ")", extra)
	print("camera at ", arena.camera.global_position, " fov ", arena.camera.fov)
	var to_judge: Vector3 = judge.global_position - arena.camera.global_position
	print("distance to judge: %.2f m" % to_judge.length())
	get_tree().quit()
