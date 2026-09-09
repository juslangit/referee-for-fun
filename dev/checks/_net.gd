extends Node

## Fires shuttles at the net on purpose. One flat enough to hit it, one that should
## clear it, and one struck from below the tape that has no business getting over.

func _ready() -> void:
	var arena: Node = load("res://scenes/match.tscn").instantiate()
	arena.print_truth_while_testing = false
	add_child(arena)
	await get_tree().physics_frame
	arena._set_up_the_match(false)
	arena.begin_match()

	print("%-34s %-9s %-10s %s" % ["shot", "crossed", "landed z", "truth"])
	await _fire("flat and low, struck from 1.0 m", Vector3(0, 1.00, -2.0), 5.0, arena)
	await _fire("lifted properly", Vector3(0, 1.00, -2.0), 34.0, arena)
	await _fire("scraped off the floor", Vector3(0, 0.35, -1.2), 6.0, arena)
	await _fire("a normal clear from the back", Vector3(0, 2.40, -5.0), 32.0, arena)
	get_tree().quit()


func _fire(label: String, from: Vector3, angle: float, arena: Node) -> void:
	var shuttle: Shuttle = arena.serve(from, Vector3(0.0, 0.0, 3.0), angle, Sides.Team.RED)
	if shuttle == null:
		print("%-34s %s" % [label, "no shot at that angle reaches the target"])
		return

	var waited := 0
	while not shuttle.has_landed and waited < 1600:
		await get_tree().physics_frame
		waited += 1
	if not shuttle.has_landed:
		shuttle.force_landing()
		await get_tree().physics_frame

	var rally: Rally = arena.rally
	rally.record_landing(shuttle.landing_point)
	print("%-34s %-9s %-10.2f %s" % [
		label,
		"yes" if rally.crossed_the_net else "NO",
		shuttle.landing_point.z,
		rally.describe(),
	])
