extends Node3D

func _ready() -> void:
	var holder: Node3D = Models.player(Color.RED)
	add_child(holder)
	await get_tree().process_frame
	var model: Node3D = holder.get_child(0)
	for factor in [1.0, 0.5, 0.25]:
		model.scale = Vector3.ONE * factor
		await get_tree().process_frame
		var box := _measure(holder)
		print("model.scale %.2f  ->  measured %.2f x %.2f x %.2f" % [
			factor, box.size.x, box.size.y, box.size.z])
	# where does the skeleton actually live?
	for node in _every(holder):
		if node is Skeleton3D:
			print("skeleton path: ", holder.get_path_to(node))
			print("skeleton global scale: ", node.global_transform.basis.get_scale())
		elif node is MeshInstance3D:
			print("mesh %-14s skeleton property = '%s'" % [node.name, node.skeleton])
	get_tree().quit()


func _measure(from: Node3D) -> AABB:
	var into := from.global_transform.affine_inverse()
	var box := AABB()
	var started := false
	for child in _every(from):
		if child is MeshInstance3D and child.mesh != null:
			var here: AABB = (into * child.global_transform) * child.mesh.get_aabb()
			box = here if not started else box.merge(here)
			started = true
	return box


func _every(node: Node) -> Array:
	var found := [node]
	for child in node.get_children():
		found.append_array(_every(child))
	return found
