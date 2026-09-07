extends Node

## Checks that the shuttle flies like a shuttlecock and that its landing point is
## recorded accurately. Run headless — nothing here is part of the game.

var _dt := 0.0

func _ready() -> void:
	_dt = 1.0 / float(Engine.physics_ticks_per_second)
	var arena: Node = load("res://scenes/match.tscn").instantiate()
	add_child(arena)
	await get_tree().physics_frame

	print("physics ticks/second: ", Engine.physics_ticks_per_second)
	print("\n--- flight tests ---")
	print("%-26s %8s %8s %8s %8s %9s" % ["shot", "apex m", "range m", "time s", "land m/s", "verdict"])

	# A shuttle dropped from high up should settle at terminal velocity, 6.8 m/s,
	# no matter how far it falls. This is the number the whole flight model hangs on.
	await _report("dropped from 20 m", arena, Vector3(0, 20, 0), Vector3.ZERO)

	# A smash leaves the racket at around 100 m/s. It must be dead by the time it
	# lands — if it still arrives fast, the drag is wrong.
	await _report("smash, 100 m/s", arena, Vector3(0, 2.8, -3.0), Vector3(0, -6, 26).normalized() * 100.0)

	# A high clear is hit up and deep, aiming for the back line.
	await _report("high clear, 30 m/s", arena, Vector3(0, 2.0, -5.5), Vector3(0, 0.95, 0.55).normalized() * 30.0)

	# A net drop barely travels. It should fall just past the net.
	await _report("net drop, 6 m/s", arena, Vector3(0, 1.7, -0.6), Vector3(0, 0.15, 1.0).normalized() * 6.0)

	print("\n--- landing accuracy ---")
	# Drop a shuttle straight down onto known spots and check the recorded point.
	for target in [Vector3(3.05, 0, 0.0), Vector3(3.07, 0, 0.0), Vector3(0.0, 0, 6.69), Vector3(0.0, 0, 7.70)]:
		var shuttle := Shuttle.new()
		arena.add_child(shuttle)
		shuttle.launch(Vector3(target.x, 6.0, target.z), Vector3.ZERO)
		while not shuttle.has_landed:
			await get_tree().physics_frame
		var rally := Rally.new(true)
		rally.record_landing(shuttle.landing_point)
		var error := Vector2(shuttle.landing_point.x - target.x, shuttle.landing_point.z - target.z).length()
		print("aimed (%+.3f, %+.3f)  ->  %-26s  error %.4f m" % [target.x, target.z, rally.describe(), error])
		shuttle.queue_free()

	get_tree().quit()


func _report(label: String, arena: Node, from: Vector3, velocity: Vector3) -> void:
	var shuttle := Shuttle.new()
	arena.add_child(shuttle)
	shuttle.launch(from, velocity)

	var elapsed := 0.0
	var apex := from.y
	while not shuttle.has_landed and elapsed < 30.0:
		apex = maxf(apex, shuttle.global_position.y)
		await get_tree().physics_frame
		elapsed += _dt

	var travelled := Vector2(shuttle.landing_point.x - from.x, shuttle.landing_point.z - from.z).length()
	var rally := Rally.new(true)
	rally.record_landing(shuttle.landing_point)
	print("%-26s %8.2f %8.2f %8.2f %8.2f %9s" % [
		label, apex, travelled, elapsed, shuttle.landing_speed, "IN" if rally.was_in else "OUT"
	])
	shuttle.queue_free()
