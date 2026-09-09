extends Node

## What is inside the tennis racket model, so it can be loaded the way the badminton one
## is: by the name of the mesh node under the scene root.

func _ready() -> void:
	for path in [
		"res://assets/sketchfab/tennis_racket/tennis_racket.glb",
		Models.KIT,
	]:
		print("=== %s" % path)
		if not ResourceLoader.exists(path):
			print("   missing")
			continue
		var scene: Node = load(path).instantiate()
		add_child(scene)
		_walk(scene, 0)
		scene.queue_free()
	get_tree().quit()


func _walk(node: Node, depth: int) -> void:
	var size := ""
	if node is MeshInstance3D:
		var box: AABB = (node as MeshInstance3D).get_aabb()
		size = "   aabb %.2f x %.2f x %.2f" % [box.size.x, box.size.y, box.size.z]
	print("%s%s (%s)%s" % ["   ".repeat(depth + 1), node.name, node.get_class(), size])
	for child in node.get_children():
		_walk(child, depth + 1)
