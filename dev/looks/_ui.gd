extends Node

## The interface at the three moments that matter: the title screen, the middle of a
## rally, and the moment the umpire accuses somebody.

func _ready() -> void:
	var arena: Node = load("res://scenes/match.tscn").instantiate()
	add_child(arena)
	await get_tree().physics_frame
	var ui: RefereeUI = arena.ui

	ui.show_main_menu(arena.career)
	await _shot("res://dev/shots/_shot_ui_menu.png")

	ui.hide_menus()
	arena._set_up_the_match(false)
	arena.begin_match()
	arena.court.dress(Venue.Tier.ARENA)
	arena.court.stands.set_density(1.0)
	arena.board.points[Sides.Team.RED] = 18
	arena.board.points[Sides.Team.BLUE] = 20
	arena.board.games[Sides.Team.RED] = 1
	arena.board.games[Sides.Team.BLUE] = 0
	ui.set_score(arena.board, Sides.Team.BLUE)
	ui.set_prompt("[1] IN     [2] OUT     [F] fault     [Tab] shuttle cam")
	ui.react("The hall is not happy with that one.")
	await _shot("res://dev/shots/_shot_ui_hud.png")

	ui.announce("OUT", Color(0.96, 0.45, 0.38), 9.0)
	ui.show_fault_panel(false)
	await _shot("res://dev/shots/_shot_ui_fault.png")
	print("saved")
	get_tree().quit()

func _shot(path: String) -> void:
	for f in 8:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
