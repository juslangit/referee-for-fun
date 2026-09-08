extends Node

## Can the umpire actually see a service court error from the chair?
##
## The call is only fair if the answer is yes. Two pictures from the same seat: the four
## of them lined up correctly, and the same serve with the server in the wrong box.

func _ready() -> void:
	var arena: Node = load("res://scenes/match.tscn").instantiate()
	arena.print_truth_while_testing = false
	add_child(arena)
	await get_tree().physics_frame
	arena.ui.hide_menus()
	arena._umpire_view()
	arena.ui.set_prompt("SPACE  whistle          W  service court          F  cards")

	# RED serving at nought, so the right-hand court is correct.
	arena.board = Scoreboard.new(false)
	arena.serving = Sides.Team.RED
	arena.board.points[Sides.Team.RED] = 0
	arena.board.points[Sides.Team.BLUE] = 0
	arena._update_score()
	var court: float = arena.service_court(Sides.Team.RED)

	arena._stand_for_serve(court)
	await _settle()
	await _shot("res://dev/shots/court_correct.png")

	arena._stand_for_serve(court, Sides.Team.RED)
	await _settle()
	await _shot("res://dev/shots/court_wrong_server.png")

	arena._stand_for_serve(court, Sides.Team.BLUE)
	await _settle()
	await _shot("res://dev/shots/court_wrong_receiver.png")

	print("saved 3")
	get_tree().quit()


## The players walk to where they have been sent, so the picture has to wait for them.
func _settle() -> void:
	for f in 90:
		await get_tree().physics_frame


func _shot(path: String) -> void:
	for f in 6:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
