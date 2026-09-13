extends Node

## Luqman's "volleyball 1" serve, in the indoor hall, from close by.
##
## Run with --fixed-fps 120, or the frames are not at the times they are labelled with:
##
##     godot --path . res://dev/looks/_serveshot.tscn --fixed-fps 120
##
## A row of frames from a camera beside the server, timed from the whistle, and the
## distance from the right hand to the ball at the moment of contact. The serve clip and
## the toss are timed off the same number, Player.VB_SERVE_CONTACT; this is where it
## shows whether they actually meet.

const AT := [0.0, 0.2, 0.4, 0.55, Player.VB_SERVE_CONTACT, 0.8, 1.1, 1.5, 1.9, 2.3]
const W := 480
const H := 360


func _ready() -> void:
	var arena: Node = load("res://scenes/volleyball.tscn").instantiate()
	arena.print_truth_while_testing = false
	add_child(arena)
	await get_tree().physics_frame
	arena.career = Career.new()
	arena.career.sport = Career.INDOOR
	arena.career.tier = 3
	arena.settings.taught_indoor = true
	arena.ui.match_requested.emit()
	await get_tree().process_frame
	if arena.pressure.exists():
		arena.ui.briefing_acknowledged.emit()
		await get_tree().process_frame
	arena.begin_match()
	for f in 3:
		await get_tree().process_frame

	arena.start_rally()
	arena.ui.announce("", Color.WHITE)
	var server: Player = null
	for p in arena.players:
		if p._clip == "vb_serve":
			server = p
	if server == null:
		print("nobody is serving")
		get_tree().quit()
		return
	var start_spot := server.position

	# Beside the server and in front of them, three-quarters on, like the recording.
	var close := Camera3D.new()
	add_child(close)
	var facing := Vector3(sin(server.rotation.y), 0.0, cos(server.rotation.y))
	var side := facing.cross(Vector3.UP)
	close.global_position = server.global_position + facing * 3.2 + side * 1.8 + Vector3(0, 1.3, 0)
	close.look_at(server.global_position + Vector3(0, 1.2, 0), Vector3.UP)
	close.fov = 50.0
	close.make_current()

	var sheet := Image.create(W * 5, H * 2, false, Image.FORMAT_RGBA8)
	# Timed in game time, which only means something run with --fixed-fps: then every
	# frame is the same slice of the match however long it took to draw, and taking a
	# picture no longer lets the serve run on without it.
	for i in AT.size():
		while _t < AT[i]:
			await _frame()
		print("  %.2f s  server at %s, %.2f m from the spot, playing %s" % [
			AT[i], server.position, server.position.distance_to(start_spot), server._clip])
		var frame := await _grab()
		frame.convert(Image.FORMAT_RGBA8)
		frame.resize(W, H)
		sheet.blit_rect(frame, Rect2i(0, 0, W, H), Vector2i((i % 5) * W, (i / 5) * H))
	sheet.save_png("res://dev/shots/vb_serve_frames.png")
	_report_contact(server, arena.SERVE_HEIGHT)
	get_tree().quit()


## Seconds of game time since the whistle.
var _t := 0.0


func _frame() -> void:
	await get_tree().process_frame
	_t += get_process_delta_time()


## Where the hand is at the contact frame, against where the ball is served from.
##
## Measured by stopping the clip on the frame rather than catching it in passing: a
## frame is 42 ms, and the arm moves the better part of a metre across the two of them
## either side of contact.
func _report_contact(server: Player, serve_height: float) -> void:
	var skeleton := _skeleton(server)
	var animator: AnimationPlayer = server._animator
	animator.play("vb_serve")
	animator.seek(Player.VB_SERVE_CONTACT, true)
	animator.pause()
	var hand := skeleton.global_transform * skeleton.get_bone_global_pose(
		skeleton.find_bone("RightHand")).origin
	var facing := Vector3(sin(server.rotation.y), 0.0, cos(server.rotation.y))
	var offset := hand - server.global_position
	var ball := (server.global_position + facing * Player.VB_SERVE_REACH
		+ facing.cross(Vector3.UP) * Player.VB_SERVE_WIDE)
	ball.y = serve_height
	print("hand at contact: %.2f m up, %.2f m in front, %.2f m to the side" % [
		offset.y, offset.dot(facing), offset.dot(facing.cross(Vector3.UP))])
	print("ball at contact: %.2f m up, %.2f m in front, %.2f m to the side; wrist to ball %.2f m" % [
		serve_height, Player.VB_SERVE_REACH, Player.VB_SERVE_WIDE, hand.distance_to(ball)])


func _skeleton(node: Node) -> Skeleton3D:
	if node is Skeleton3D:
		return node
	for child in node.get_children():
		var found := _skeleton(child)
		if found != null:
			return found
	return null


func _grab() -> Image:
	for f in 2:
		await _frame()
	await RenderingServer.frame_post_draw
	return get_viewport().get_texture().get_image()
