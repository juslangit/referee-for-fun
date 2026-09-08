extends Node3D

func _ready() -> void:
	for entry in [["player", Models.player(Sides.Team.RED)], ["official", Models.official()],
			["racket", Models.racket()], ["shuttlecock", Models.shuttlecock()]]:
		var made: Node3D = entry[1]
		if made == null:
			print("%-12s NULL" % entry[0])
			continue
		add_child(made)
		await get_tree().process_frame
		Models.settle(made)
		if entry[0] == "player":
			Models.dress_player(made)
		var box := _world_bounds(made)
		print("%-12s size %5.2f x %5.2f x %5.2f   bottom y %+.3f   centre (%+.2f, %+.2f)" % [
			entry[0], box.size.x, box.size.y, box.size.z, box.position.y,
			box.get_center().x, box.get_center().z
		])
	get_tree().quit()


func _world_bounds(node: Node) -> AABB:
	var box := AABB()
	var started := false
	for child in _every(node):
		if child is MeshInstance3D and child.mesh != null:
			var here: AABB = child.global_transform * child.mesh.get_aabb()
			box = here if not started else box.merge(here)
			started = true
	return box


func _every(node: Node) -> Array:
	var found := [node]
	for child in node.get_children():
		found.append_array(_every(child))
	return found
