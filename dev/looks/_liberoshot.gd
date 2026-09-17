extends Node

## The libero as the game actually dresses one: a real indoor volleyball match, driven
## the way a player drives it, photographed from the stand.
##
## Deliberately not a posed comparison. The previous look built two figures by hand and
## proved a texture worked; it proved nothing about the game, which went on strapping a
## box to the chest because nothing had been wired up. Luqman opened the volleyball and
## saw no change. This one goes through `volley_match.gd` so that a pass here means the
## thing on screen has changed.

func _ready() -> void:
	var arena: Node = load("res://scenes/volleyball.tscn").instantiate()
	arena.print_truth_while_testing = false
	add_child(arena)
	await get_tree().physics_frame
	arena.career = Career.new()
	arena.career.sport = Career.INDOOR
	arena.settings.taught_indoor = true
	arena.ui.match_requested.emit()
	await get_tree().process_frame
	if arena.pressure.exists():
		arena.ui.briefing_acknowledged.emit()
	arena.begin_match()
	for f in 6:
		await get_tree().physics_frame
	arena.ui.hide_menus()
	arena.ui.show_hud(false)

	var boxes := 0
	var kitted := 0
	for player in arena.players:
		if player.find_children("Vest", "MeshInstance3D", true, false).size() > 0:
			boxes += 1
		if player.find_children("Bib", "MeshInstance3D", true, false).size() > 0:
			boxes += 1
	print("boxes still strapped to anybody: %d  (must be 0)" % boxes)
	for team in [Sides.Team.RED, Sides.Team.BLUE]:
		var rota = arena.rota[team]
		print("%-5s libero index: %d" % [Sides.label(team), rota.libero])
	var overridden := 0
	for player in arena.players:
		for node in player.find_children("*", "MeshInstance3D", true, false):
			var mi := node as MeshInstance3D
			if mi.mesh == null:
				continue
			for surf in mi.mesh.get_surface_count():
				if mi.get_surface_override_material(surf) != null:
					overridden += 1
	print("surfaces wearing an overridden kit: %d" % overridden)
	for player in arena.players:
		var mine := 0
		var names: Array[String] = []
		for node in player.find_children("*", "MeshInstance3D", true, false):
			var mi := node as MeshInstance3D
			names.append("%s(%d surf,vis=%s)" % [mi.name, (mi.mesh.get_surface_count() if mi.mesh else 0), mi.visible])
			if mi.mesh == null:
				continue
			for surf in mi.mesh.get_surface_count():
				if mi.get_surface_override_material(surf) != null:
					mine += 1
		if mine > 0:
			print("  %s team=%s overridden=%d" % [player.name, Sides.label(player.team), mine])
			print("     meshes: %s" % ", ".join(names))
			for node in player.find_children("*", "MeshInstance3D", true, false):
				var mi := node as MeshInstance3D
				if mi.mesh == null:
					continue
				for surf in mi.mesh.get_surface_count():
					var over := mi.get_surface_override_material(surf)
					if over == null:
						continue
					var std := over as StandardMaterial3D
					print("     override class=%s albedo_texture=%s albedo_color=%s" % [
						over.get_class(),
						(std.albedo_texture.resource_path if std != null and std.albedo_texture != null else "<none>"),
						(std.albedo_color if std != null else "?")])
					var base := mi.get_active_material(surf)
					print("     active now class=%s" % base.get_class())

	# Framed on the blue libero rather than on the court in general. The first version
	# photographed the whole hall and the libero happened to be behind two team-mates,
	# which looked exactly like the kit not working.
	var libero: Node3D = null
	var found := 0
	for player in arena.players:
		if player.team == Sides.Team.BLUE:
			if found == arena.rota[Sides.Team.BLUE].libero:
				libero = player
				break
			found += 1
	var at: Vector3 = libero.global_position if libero != null else Vector3(0.0, 1.0, 3.0)
	print("blue libero stands at %.1f, %.1f  node=%s" % [at.x, at.z,
		(libero.name if libero != null else "<none>")])
	# Which node actually got the kit, so the two can be compared.
	for player in arena.players:
		for node in player.find_children("*", "MeshInstance3D", true, false):
			var mi := node as MeshInstance3D
			if mi.mesh == null:
				continue
			for surf in mi.mesh.get_surface_count():
				if mi.get_surface_override_material(surf) != null:
					print("  kit is on node=%s team=%s at %.1f, %.1f" % [
						player.name, Sides.label(player.team),
						player.global_position.x, player.global_position.z])
	# The libero alone, close. At under two metres with a 45 degree lens a team-mate
	# standing in front fills the frame completely, which looks exactly like a libero
	# who has not changed shirt — that cost an hour once already.
	# `CROWDED=1` keeps everybody in, to judge whether the shirt reads on a full court.
	if not OS.has_environment("CROWDED"):
		for player in arena.players:
			player.visible = (player == libero)

	var eye := Camera3D.new()
	arena.add_child(eye)
	eye.look_at_from_position(at + Vector3(1.0, 1.1, 1.9), at + Vector3(0.0, 1.0, 0.0), Vector3.UP)
	eye.fov = 45.0
	eye.current = true
	for f in 10:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://dev/shots/_shot_libero_ingame.png")
	get_tree().quit()
