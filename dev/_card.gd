extends Node

## Photographs the game for the sport-selection card.
##
## Rendered through a SubViewport at the card's own size rather than by resizing the
## window, because the window will not go portrait on demand — asking for 560x780 on the
## command line produced a landscape picture with the net cord slicing across it.
##
## The pose is seeked rather than waited for. Playing the smash and taking a photograph a
## few frames later catches whatever part of the swing the animation happens to have
## reached; seeking to the contact frame and pausing catches the shot itself.

const WIDTH := 560
const HEIGHT := 780

func _ready() -> void:
	var arena: Node = load("res://scenes/match.tscn").instantiate()
	add_child(arena)
	await get_tree().physics_frame
	arena.ui.career_screen_requested.emit()
	await get_tree().process_frame
	arena.ui.match_requested.emit()
	await get_tree().process_frame
	arena._on_favour_chosen(Sides.Team.NONE)
	arena.court.dress(Venue.Tier.ARENA)
	arena.court.stands.set_density(1.0)
	arena.ui.visible = false
	for f in 6:
		await get_tree().process_frame

	var subject: Node3D = arena.players[0]
	var animator := Models.animator(subject)
	if animator != null and animator.has_animation("smash"):
		animator.play("smash")
		# The contact frame: arm overhead, racket up, the other hand still pointing at
		# the shuttle. Six frames into an eighteen frame clip at twenty-four a second.
		animator.seek(6.0 / 24.0, true)
		animator.pause()

	var frame := SubViewport.new()
	frame.size = Vector2i(WIDTH, HEIGHT)
	frame.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	frame.world_3d = get_viewport().find_world_3d()
	add_child(frame)

	var shot := Camera3D.new()
	shot.fov = 44.0
	frame.add_child(shot)
	var at: Vector3 = subject.global_position
	# In front of them and a little to one side, looking slightly up. A player faces the
	# net, so "in front" is the side the net is on — the first attempt sat behind them
	# and produced a very good photograph of a man's back.
	# Round to the side and up above the net cord. Straight in front put the tape across
	# the picture as a white band and cropped his feet; from here the net runs away
	# behind him instead of across the lens, and the whole figure fits with the racket.
	var facing := signf(Sides.half_sign(Sides.opponent(subject.team)))
	shot.global_position = at + Vector3(3.6, 1.95, 2.35 * facing)
	shot.look_at(at + Vector3(0.0, 1.15, 0.0), Vector3.UP)
	shot.current = true

	for f in 8:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	frame.get_texture().get_image().save_png("res://assets/ui/card_badminton.png")
	print("saved %dx%d card" % [WIDTH, HEIGHT])
	get_tree().quit()
