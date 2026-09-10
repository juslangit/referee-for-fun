extends Node

## A picture of somebody in the stands shouting at the umpire.
##
## The bubble is the one thing on the interface that has to be in a particular place in
## the *hall* rather than on the screen, and `dev/checks/_bubble` cannot see whether it
## landed there: headless renders 64x64, which is smaller than the bubble, so the
## off-screen guard hides it and every number comes back nought. This runs windowed at
## the real resolution and writes the frame out to be looked at.

func _ready() -> void:
	var hall: Node = load("res://scenes/match.tscn").instantiate()
	hall.print_truth_while_testing = false
	add_child(hall)
	await get_tree().physics_frame

	hall.career = Career.new()
	hall.career.sport = Career.BADMINTON
	hall.career.tier = 3
	hall.career.reputation = 0.62
	hall.settings.taught = true
	hall._on_match_requested()
	if hall.pressure.exists():
		hall.ui.hide_briefing()
	hall.begin_match()
	for f in 6:
		await get_tree().process_frame

	# Straight to the loudest thing anybody says, rather than playing until a rally
	# happens to produce one. This is a photograph, not a test of when it fires.
	hall.ui.react("sustained booing from both ends", 6.0)
	hall.the_hall_says(Crowd._pick(Crowd.SAID_HOSTILITY))
	for f in 20:
		await get_tree().process_frame

	var ui: RefereeUI = hall.ui
	print("said: %s" % ui._bubble_label.text)
	print("anchored at %v" % ui._bubble_at)
	print("drawn at %v, size %v, opacity %.2f" % [
		ui._bubble.position, ui._bubble.size, ui._bubble.modulate.a])
	print("viewport %v" % get_viewport().get_visible_rect().size)

	await RenderingServer.frame_post_draw
	var out := "res://dev/shots/bubble.png"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://dev/shots"))
	get_viewport().get_texture().get_image().save_png(out)
	print("written to %s" % out)
	get_tree().quit()
