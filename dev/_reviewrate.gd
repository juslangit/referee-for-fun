extends Node

## The review system measured directly rather than waited for.
##
## A short match produces only three or four close calls, so watching one and counting
## challenges tells you almost nothing — the first attempt reported zero and it was not
## clear whether that meant broken or unlucky. This asks the question ten thousand times
## instead, and then drives one review through the real code so the panel can be seen.

func _ready() -> void:
	var arena: Node = load("res://scenes/match.tscn").instantiate()
	add_child(arena)
	await get_tree().physics_frame
	arena.career.tier = 3
	arena.ui.match_requested.emit()
	await get_tree().process_frame
	arena._on_favour_chosen(Sides.Team.NONE)
	for f in 4:
		await get_tree().process_frame

	print("%-34s %10s %10s" % ["situation", "challenged", "expected"])
	_rate(arena, 0.05, true,  "a 5 cm lie")
	_rate(arena, 0.05, false, "a 5 cm call, correct")
	_rate(arena, 0.40, true,  "a 40 cm lie")
	_rate(arena, 0.40, false, "a 40 cm call, correct")

	# One real review, driven through _review() so the panel and the pricing are the
	# ones the game actually uses.
	var rally := _rally(0.05, true)
	arena.rally = rally
	var before: float = arena.suspicion.level
	arena.suspicion.register(rally)
	var after_call: float = arena.suspicion.level
	# Started without awaiting, so the panel can be photographed while it is up — the
	# suspense is most of the feature and a screenshot of it afterwards shows nothing.
	# Deferred rather than awaited. GDScript refuses to start a coroutine without
	# awaiting it, and awaiting this one means the panel has been and gone before there
	# is any chance to photograph it — and the suspense is most of the feature.
	arena._review.call_deferred(Sides.Team.BLUE)
	for f in 40:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://dev/shots/_shot_review_asked.png")
	while arena._reviewing:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var overturned := true
	print()
	print("drove one review through the real code")
	print("   the wrong call cost      %.3f" % (after_call - before))
	print("   being caught added       %.3f" % (arena.suspicion.level - after_call))
	print("   reviews left after it    RED %d  BLUE %d" % [
		arena.challenge.remaining(Sides.Team.RED),
		arena.challenge.remaining(Sides.Team.BLUE)])
	get_tree().quit()


func _rate(arena: Node, margin: float, lie: bool, label: String) -> void:
	var asked := 0
	for i in 10000:
		arena.challenge.reset()
		var rally := _rally(margin, lie)
		if arena.challenge.challenger(rally) != Sides.Team.NONE:
			asked += 1
	print("%-34s %9.1f%%" % [label, 100.0 * float(asked) / 10000.0])


## A settled rally with a known margin, called either truthfully or not.
func _rally(margin: float, lie: bool) -> Rally:
	var rally := Rally.new(Sides.Team.RED, true)
	# Landing that far inside the sideline, on BLUE's half.
	rally.record_landing(Vector3(CourtSpec.HALF_WIDTH_DOUBLES - margin, Court.SURFACE_Y, 3.0))
	rally.record_call(CallBook.get_call(&"out" if lie else &"in"))
	return rally
