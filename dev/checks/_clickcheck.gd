extends Node

## What is on top of the menu, and can it be clicked?
##
## Luqman reports buttons that do not respond before a volleyball match starts. A button
## that is visible and still unclickable means something invisible is sitting over it
## with MOUSE_FILTER_STOP, or the mouse is captured, or the tree is paused. This lists
## all three for both scenes so the difference between them is visible.

func _ready() -> void:
	await _every_screen_before_the_first_serve()
	print()
	await _look_at("res://scenes/beach.tscn", "BEACH, career screen at startup", true)
	print()
	await _look_at("res://scenes/match.tscn", "BADMINTON, career screen", false)
	get_tree().quit()


## The real question: is the mouse free on every screen that has a button on it?
##
## A captured mouse leaves buttons drawn, lit and completely dead, which is exactly what
## Luqman reported. The camera used to take the chair as soon as the match was asked
## for, two screens before the first serve.
func _every_screen_before_the_first_serve() -> void:
	print("=== every screen between the menu and the first serve")
	for path in ["res://scenes/beach.tscn", "res://scenes/match.tscn"]:
		var arena: Node = load(path).instantiate()
		arena.print_truth_while_testing = false
		add_child(arena)
		for f in 6:
			await get_tree().process_frame

		var beach: bool = path.ends_with("beach.tscn")
		var sport := "beach" if beach else "badminton"
		if not beach:
			arena.ui._main_menu.visible = false
			arena._on_career_screen_requested()
			await get_tree().process_frame

		print("  %-10s career screen        mouse %s" % [
			sport, _mouse_mode_name(Input.mouse_mode)])

		arena.ui.match_requested.emit()
		for f in 3:
			await get_tree().process_frame
		var briefed: bool = arena.pressure.exists()
		if briefed:
			print("  %-10s briefing (GO OUT)    mouse %s" % [
				sport, _mouse_mode_name(Input.mouse_mode)])
			arena.ui.briefing_acknowledged.emit()
			await get_tree().process_frame
		arena.begin_match()
		for f in 3:
			await get_tree().process_frame
		print("  %-10s in the chair         mouse %s  (captured is correct here)" % [
			sport, _mouse_mode_name(Input.mouse_mode)])

		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		arena.queue_free()
		await get_tree().process_frame


func _look_at(path: String, label: String, beach: bool) -> void:
	var arena: Node = load(path).instantiate()
	arena.print_truth_while_testing = false
	add_child(arena)
	for f in 6:
		await get_tree().process_frame

	if not beach:
		arena.ui._main_menu.visible = false
		arena._on_career_screen_requested()
		for f in 4:
			await get_tree().process_frame

	print("=== %s" % label)
	print("  mouse mode: %s   tree paused: %s" % [
		_mouse_mode_name(Input.mouse_mode), get_tree().paused])

	var blockers: Array[String] = []
	_walk(arena.ui, blockers, "")
	print("  visible controls that stop the mouse, in draw order:")
	for line in blockers:
		print("    %s" % line)

	arena.queue_free()
	await get_tree().process_frame


## Every visible Control that would swallow a click, with the area it covers.
func _walk(node: Node, into: Array[String], path: String) -> void:
	for child in node.get_children():
		var here := "%s/%s" % [path, child.name]
		if child is Control:
			var control := child as Control
			if control.visible and control.mouse_filter == Control.MOUSE_FILTER_STOP:
				var box := control.get_global_rect()
				into.append("%-46s %.0fx%.0f at %.0f,%.0f" % [
					here, box.size.x, box.size.y, box.position.x, box.position.y])
			if not control.visible:
				continue
		_walk(child, into, here)


func _mouse_mode_name(mode: int) -> String:
	match mode:
		Input.MOUSE_MODE_VISIBLE: return "VISIBLE"
		Input.MOUSE_MODE_CAPTURED: return "CAPTURED  <- nothing can be clicked"
		Input.MOUSE_MODE_HIDDEN: return "HIDDEN"
		Input.MOUSE_MODE_CONFINED: return "CONFINED"
	return str(mode)
