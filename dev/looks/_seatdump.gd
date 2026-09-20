extends Node

## What is actually inside a downloaded seat model: the nodes, their meshes, how many
## triangles each one has and where it sits. A bank of seats and a single seat need
## different handling, and the file name does not say which it is.

const LOOK_AT := "res://assets/sketchfab/low_poly_stadium_sports_arena_seats/low_poly_stadium_sports_arena_seats.glb"


func _ready() -> void:
	var path := OS.get_environment("MODEL")
	if path.is_empty():
		path = LOOK_AT
	var model: Node3D = load(path).instantiate()
	add_child(model)
	print(path.get_file())
	_walk(model, 0)
	get_tree().quit()


func _walk(node: Node, depth: int) -> void:
	var line := "%s%s  [%s]" % ["  ".repeat(depth), node.name, node.get_class()]
	if node is MeshInstance3D:
		var piece := node as MeshInstance3D
		if piece.mesh != null:
			var tris := 0
			for s in piece.mesh.get_surface_count():
				tris += piece.mesh.surface_get_array_index_len(s) / 3
			var box := piece.mesh.get_aabb()
			line += "  %d tris  size %.2f x %.2f x %.2f  at %.2f,%.2f,%.2f" % [
				tris, box.size.x, box.size.y, box.size.z,
				box.position.x, box.position.y, box.position.z]
	print(line)
	for child in node.get_children():
		_walk(child, depth + 1)
