extends Node

## The one selected button, and what happens when it moves.
##
## Three shots: the title screen as it opens, the selection arrowed down two, and the
## same screen with the pointer over a *different* button from the one the keyboard left
## — which is the state that used to light two buttons at once.

func _ready() -> void:
	var hall: Node = load("res://scenes/match.tscn").instantiate()
	hall.print_truth_while_testing = false
	add_child(hall)
	await get_tree().physics_frame
	hall.career = Career.new()
	var ui: RefereeUI = hall.ui
	ui.hide_menus()
	ui.show_main_menu(hall.career)
	await _settle()
	print("as it opens:      %s" % _lit(ui))
	await _shot("res://dev/shots/_shot_selection_open.png")

	var here := get_viewport().gui_get_focus_owner() as Button
	for step in 2:
		var next := here.find_valid_focus_neighbor(SIDE_BOTTOM)
		if next == null:
			break
		next.grab_focus()
		await _settle()
		here = get_viewport().gui_get_focus_owner() as Button
	print("arrowed down two: %s" % _lit(ui))
	await _shot("res://dev/shots/_shot_selection_moved.png")

	# Now the pointer, onto the last button, while the keyboard sits on the third.
	var quit := _named(ui, "QUIT")
	quit.mouse_entered.emit()
	await _settle()
	print("pointer on QUIT:  %s" % _lit(ui))
	await _shot("res://dev/shots/_shot_selection_hover.png")
	get_tree().quit()


## Every button that is not fully at rest, with how lit it is.
func _lit(ui: RefereeUI) -> String:
	var on: Array[String] = []
	for node in ui._main_menu.find_children("*", "Button", true, false):
		var b := node as Button
		var t: float = b.get_meta(&"lit", 0.0)
		if t > 0.01:
			on.append("%s %.2f" % [b.text, t])
	return "nothing lit" if on.is_empty() else ", ".join(on)


func _named(ui: RefereeUI, text: String) -> Button:
	for node in ui._main_menu.find_children("*", "Button", true, false):
		if (node as Button).text == text:
			return node as Button
	return null


func _settle() -> void:
	# Past the end of the tween, so a shot is never taken mid-fade.
	await get_tree().create_timer(0.4).timeout


func _shot(path: String) -> void:
	for f in 4:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
