extends Node

## Photographs each finished sport for its card on the selection screen.
##
## There used to be one of these, for badminton, and the reasoning written beside it was
## that a real picture means a real sport while the rest are pictograms of sports that do
## not exist yet. That was right when one card in six was playable. With four of them
## finished the photograph stopped reading as "this one is real" and started reading as
## "this one does not match", so the other three get the same treatment.
##
## Rendered through a SubViewport at the card's own size rather than by resizing the
## window, because the window will not go portrait on demand. The pose is seeked rather
## than waited for: playing a smash and photographing a few frames later catches whatever
## part of the swing the clip happened to reach.

const WIDTH := 560
const HEIGHT := 780

## Each sport: the scene, the clip to freeze, how far into it, and where to stand.
const CARDS := [
	{
		"id": "badminton", "scene": "res://scenes/match.tscn", "sport": &"badminton",
		"clip": "smash", "at": 6.0 / 24.0,
		"offset": Vector3(3.6, 1.95, 2.35), "look": 1.15,
	},
	{
		"id": "beachvolleyball", "scene": "res://scenes/beach.tscn", "sport": &"beach",
		"clip": "vb_spike", "at": 8.0 / 24.0,
		"offset": Vector3(3.9, 2.15, 2.6), "look": 1.35,
	},
	{
		"id": "volleyball", "scene": "res://scenes/volleyball.tscn", "sport": &"indoor",
		"clip": "vb_spike", "at": 8.0 / 24.0,
		"offset": Vector3(3.9, 2.15, 2.6), "look": 1.35,
	},
	{
		"id": "tennis", "scene": "res://scenes/tennis.tscn", "sport": &"tennis",
		"clip": "smash", "at": 6.0 / 24.0,
		"offset": Vector3(3.7, 2.0, 2.5), "look": 1.20,
	},
]


func _ready() -> void:
	for card in CARDS:
		await _photograph(card)
	print("saved %d cards" % CARDS.size())
	get_tree().quit()


func _photograph(card: Dictionary) -> void:
	var arena: Node = load(card["scene"]).instantiate()
	arena.print_truth_while_testing = false
	add_child(arena)
	await get_tree().physics_frame

	arena.career = Career.new()
	arena.career.sport = card["sport"]
	arena.career.tier = 4
	if card["sport"] == &"badminton":
		arena.ui.career_screen_requested.emit()
		await get_tree().process_frame
		arena.ui.match_requested.emit()
		await get_tree().process_frame
		arena.begin_match()
		arena.court.dress(Venue.Tier.ARENA)
		arena.court.stands.set_density(1.0)
	else:
		arena.settings.taught_beach = true
		arena.settings.taught_indoor = true
		arena.settings.taught_tennis = true
		arena.ui.match_requested.emit()
		await get_tree().process_frame
		if arena.pressure.exists():
			arena.ui.briefing_acknowledged.emit()
			await get_tree().process_frame
		arena.begin_match()
	arena.ui.visible = false
	for f in 8:
		await get_tree().process_frame

	var subject: Node3D = arena.players[0]
	var animator := Models.animator(subject)
	if animator != null and animator.has_animation(card["clip"]):
		animator.play(card["clip"])
		animator.seek(card["at"], true)
		animator.pause()
	for f in 2:
		await get_tree().process_frame

	var frame := SubViewport.new()
	frame.size = Vector2i(WIDTH, HEIGHT)
	frame.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	frame.world_3d = get_viewport().find_world_3d()
	add_child(frame)

	var shot := Camera3D.new()
	shot.fov = 44.0
	frame.add_child(shot)
	var at: Vector3 = subject.global_position
	# In front of them and round to one side, above the tape. A player faces the net, so
	# "in front" is whichever side the net is on — the first attempt at this sat behind
	# the subject and produced a very good photograph of a man's back.
	var facing := signf(Sides.half_sign(Sides.opponent(subject.team)))
	var offset: Vector3 = card["offset"]
	shot.global_position = at + Vector3(offset.x, offset.y, offset.z * facing)
	shot.look_at(at + Vector3(0.0, float(card["look"]), 0.0), Vector3.UP)
	shot.current = true

	for f in 8:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	frame.get_texture().get_image().save_png(
		"res://assets/ui/card_%s.png" % card["id"])
	print("   card_%s.png" % card["id"])
	frame.queue_free()
	arena.queue_free()
	await get_tree().process_frame
