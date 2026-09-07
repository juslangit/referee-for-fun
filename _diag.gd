extends Node

func _ready() -> void:
	var arena: Node = load("res://scenes/match.tscn").instantiate()
	add_child(arena)
	await get_tree().physics_frame
	for judge in arena.line_judges:
		var body: Node3D = judge.get_node("Body")
		print("%-16s seat %v  body global basis y-axis %v  rotation %v" % [
			judge.name, judge.position, body.global_transform.basis.y, body.global_rotation
		])
	get_tree().quit()
