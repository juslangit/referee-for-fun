extends Node

## Photographs a cutscene at set moments. Run windowed, with --fixed-fps so the moments are
## true (see 04-methods, "Timed screenshots need --fixed-fps"):
##
##   SCENE=walk_on  godot --path . res://dev/looks/_cutsceneshot.tscn --fixed-fps 60 --resolution 1600x900
##
## SCENE is walk_on, match_won, taken_off or moved_up; DOUBLES=1 for two a side. Pictures go
## to dev/shots/cut_<scene>_<seconds>.png.

const MOMENTS := {
	"walk_on": [1.0, 5.5, 8.5, 12.0, 15.5, 17.5, 20.5, 23.0],
	"match_won": [1.5, 3.5, 6.0, 8.0, 10.5, 13.0],
	"taken_off": [1.5, 3.5, 6.0, 7.5, 9.5, 11.5],
	"moved_up": [0.8, 2.5, 4.5, 6.5],
	# Not a scene: the umpire sat in the high chair, side-on and from the court, for
	# setting Cutscene.SEAT_HEIGHT.
	"seat": [0.6, 1.2],
}

var _clock := 0.0


func _ready() -> void:
	var which := OS.get_environment("SCENE")
	if which.is_empty():
		which = "walk_on"
	var arena: BadmintonMatch = load("res://scenes/match.tscn").instantiate()
	arena.cutscenes = true
	var doubles := OS.get_environment("DOUBLES") == "1"
	add_child(arena)
	await get_tree().physics_frame
	arena.career.doubles = doubles
	arena.rebuild_players()
	arena.ui.hide_menus()
	arena._umpire_view()
	var venue := arena.career.venue()
	arena.court.dress(venue["dressing"])
	arena.court.stands.set_density(venue["crowd"])
	arena.board = Scoreboard.new(false)
	arena.board.match_won.connect(arena._on_match_won)

	match which:
		"walk_on":
			arena._walk_on_then_begin()
		"match_won":
			arena.begin_match()
			await get_tree().create_timer(0.3).timeout
			arena.board.games[Sides.Team.BLUE] = 1
			arena.board.games[Sides.Team.RED] = 1
			arena.board.points[Sides.Team.RED] = 20
			arena.board.points[Sides.Team.BLUE] = 18
			arena.board.award(Sides.Team.RED)
		"taken_off":
			arena.begin_match()
			await get_tree().create_timer(0.3).timeout
			arena.suspicion.is_removed = true
			arena._on_removed_from_match()
		"seat":
			var scene := arena._make_cutscene()
			scene._open()
			var umpire := scene._official(scene._seat())
			umpire.rotation.y = -PI * 0.5
			umpire.sit()
			var eye := Vector3(OS.get_environment("EYE_X").to_float(), 1.6,
				OS.get_environment("EYE_Z").to_float())
			scene._aim(eye, Vector3(4.0, 1.6, 0.0), 40.0)
		"moved_up":
			arena.career.tier = mini(arena.career.tier + 1, arena.career.ladder().size() - 1)
			arena.cutscene = arena._make_cutscene()
			arena.cutscene.moved_up(arena.career.venue())

	var moments: Array = MOMENTS[which]
	for moment: float in moments:
		while _clock < moment:
			await get_tree().process_frame
			_clock += get_process_delta_time()
		await RenderingServer.frame_post_draw
		var path := "res://dev/shots/cut_%s%s_%04.1f.png" % [which, "_doubles" if doubles else "", moment]
		get_viewport().get_texture().get_image().save_png(path)
		print("saved ", path)
	get_tree().quit()
