extends Node

## The career screen with every ladder on it.
##
## One official, one reputation, four separate licences. Until now each sport's screen
## showed only its own ladder, so the fact that a disaster at the beach is waiting for
## you at the badminton hall was something a player had to work out for themselves.

func _ready() -> void:
	var arena: Node = load("res://scenes/match.tscn").instantiate()
	arena.print_truth_while_testing = false
	add_child(arena)
	await get_tree().physics_frame

	var career := Career.new()
	career.reputation = 0.68
	career.matches_refereed = 9
	# A career several sports deep, which is the only state this screen is for.
	career.sport = Career.BADMINTON
	career.tier = 3
	career.matches_at_tier = 2
	career.sport = Career.BEACH
	career.tier = 1
	career.matches_at_tier = 1
	career.sport = Career.INDOOR
	career.tier = 0
	career.matches_at_tier = 0
	# Tennis deliberately untouched, so the screen has to say so without starting one.
	career.grudge_name = "Wibowo"
	career.sport = Career.BADMINTON
	arena.career = career

	arena.ui._main_menu.visible = false
	arena.ui.show_career(career)
	await _shot("res://dev/shots/_shot_ladders.png")

	print("tennis started: %s   (must be false — looking is not playing)" % [
		career.progress.has(Career.TENNIS)])
	for which in Career.IN_ORDER:
		var standing := career.standing_in(which)
		print("   %-20s started %-6s tier %d" % [
			Career.name_of(which), standing["started"], standing["tier"]])
	print("saved")
	get_tree().quit()


func _shot(path: String) -> void:
	for f in 6:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
