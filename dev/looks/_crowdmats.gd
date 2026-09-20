extends Node

## What the baked crowd's materials are actually called once they have been through
## Blender's exporter and Godot's importer. Instance colour is now allowed to touch only
## the shirt, and that is selected by name, so the names have to be known rather than
## assumed.

func _ready() -> void:
	for path in ["res://assets/characters/crowd_a_sit.glb",
			"res://assets/characters/crowd_a_stand.glb"]:
		var model: Node3D = load(path).instantiate()
		add_child(model)
		print(path.get_file())
		_walk(model)
	get_tree().quit()


func _walk(node: Node) -> void:
	if node is MeshInstance3D:
		var piece := node as MeshInstance3D
		if piece.mesh != null:
			for i in piece.mesh.get_surface_count():
				var paint: Material = piece.get_active_material(i)
				print("   surface %d: %s" % [i, paint.resource_name if paint else "none"])
	for child in node.get_children():
		_walk(child)
