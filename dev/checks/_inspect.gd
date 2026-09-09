extends Node

const MODELS := [
	"res://assets/sketchfab/olympic_athlete/olympic_athlete.glb",
	"res://assets/sketchfab/male_character_in_caual_clothing/male_character_in_caual_clothing.glb",
	"res://assets/sketchfab/badminton_racket_and_shuttlecock_low_poly/badminton_racket_and_shuttlecock_low_poly.glb",
]

func _ready() -> void:
	for path in MODELS:
		print("\n=== ", path.get_file())
		var scene := load(path)
		if scene == null:
			print("  could not load")
			continue
		var model: Node = scene.instantiate()
		add_child(model)
		_walk(model, 1)
	get_tree().quit()


func _walk(node: Node, depth: int) -> void:
	var pad := "  ".repeat(depth)
	var extra := ""
	if node is MeshInstance3D and node.mesh != null:
		var box: AABB = node.mesh.get_aabb()
		extra = "  mesh %d surfaces, aabb %.2f x %.2f x %.2f" % [
			node.mesh.get_surface_count(), box.size.x, box.size.y, box.size.z
		]
	elif node is Skeleton3D:
		extra = "  %d bones" % node.get_bone_count()
	print("%s- %s (%s)%s" % [pad, node.name, node.get_class(), extra])
	for child in node.get_children():
		_walk(child, depth + 1)
