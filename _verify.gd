extends Node

func _ready() -> void:
	print("--- CourtSpec judgement ---")
	var cases := [
		[Vector3(0.0, 0, 0.0), "dead centre"],
		[Vector3(3.05, 0, 0.0), "exactly on the doubles sideline"],
		[Vector3(3.07, 0, 0.0), "2 cm outside the sideline"],
		[Vector3(3.03, 0, 0.0), "2 cm inside the sideline"],
		[Vector3(0.0, 0, 6.70), "exactly on the back line"],
		[Vector3(0.0, 0, 6.90), "20 cm long"],
		[Vector3(0.0, 0, 7.70), "a metre long"],
		[Vector3(2.70, 0, 0.0), "inside doubles, outside singles"],
	]
	for c in cases:
		var p: Vector3 = c[0]
		printt(
			"%-34s" % c[1],
			"doubles: %-5s" % ("IN" if CourtSpec.is_in(p, true) else "OUT"),
			"margin %+.3f m" % CourtSpec.margin(p, true),
			"| singles: %-5s" % ("IN" if CourtSpec.is_in(p, false) else "OUT")
		)

	print("\n--- painted line positions (should sit INSIDE each boundary) ---")
	var court := Court.new()
	add_child(court)
	await get_tree().process_frame

	var seen := {}
	for child in court.get_children():
		if not child is MeshInstance3D:
			continue
		var instance := child as MeshInstance3D
		var mesh := instance.mesh as BoxMesh
		if mesh == null:
			continue
		var key: String = instance.name
		if key in ["HallFloor", "CourtMat", "NetMesh", "NetTape"]:
			continue
		var lo: Vector3 = instance.position - mesh.size * 0.5
		var hi: Vector3 = instance.position + mesh.size * 0.5
		if not seen.has(key):
			seen[key] = []
		seen[key].append("x [%+.3f .. %+.3f]  z [%+.3f .. %+.3f]" % [lo.x, hi.x, lo.z, hi.z])

	for key in seen:
		print(key)
		for line in seen[key]:
			print("    ", line)

	get_tree().quit()
