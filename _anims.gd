extends Node

const MODELS := [
	"res://assets/sketchfab/low_poly_man/low_poly_man.glb",
	"res://assets/sketchfab/low_poly_woman/low_poly_woman.glb",
]

func _ready() -> void:
	for path in MODELS:
		print("\n=== ", path.get_file())
		if not ResourceLoader.exists(path):
			print("  missing")
			continue
		var model: Node = load(path).instantiate()
		add_child(model)
		for node in _every(model):
			if node is AnimationPlayer:
				for name in node.get_animation_list():
					var clip: Animation = node.get_animation(name)
					print("  animation %-28s %.2f s   loop %s" % [name, clip.length, clip.loop_mode != Animation.LOOP_NONE])
			elif node is Skeleton3D:
				print("  skeleton with %d bones" % node.get_bone_count())
				var interesting := []
				for b in node.get_bone_count():
					var bone_name: String = node.get_bone_name(b)
					var lower := bone_name.to_lower()
					if lower.contains("hand") or lower.contains("arm") or lower.contains("hips") or lower.contains("root"):
						interesting.append(bone_name)
				print("    bones of interest: ", ", ".join(interesting))
			elif node is MeshInstance3D and node.mesh != null:
				var box: AABB = node.mesh.get_aabb()
				print("  mesh %-22s %.2f x %.2f x %.2f" % [node.name, box.size.x, box.size.y, box.size.z])
	get_tree().quit()


func _every(node: Node) -> Array:
	var found := [node]
	for child in node.get_children():
		found.append_array(_every(child))
	return found
