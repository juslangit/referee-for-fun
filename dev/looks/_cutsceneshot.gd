extends Node

## Photographs a cutscene at set moments. Run windowed, with --fixed-fps so the moments are
## true (see 04-methods, "Timed screenshots need --fixed-fps"):
##
##   SCENE=walk_on  godot --path . res://dev/looks/_cutsceneshot.tscn --fixed-fps 60 --resolution 1600x900
##
## SCENE is walk_on, match_won, taken_off or moved_up; DOUBLES=1 for two a side. Pictures go
## to dev/shots/cut_<scene>_<seconds>.png. SPORT=tennis (and, as they arrive, the other
## sports) photographs that sport's scenes instead, to cut_<sport>_<scene>_<seconds>.png.

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


const SCENES := {
	"tennis": ["res://scenes/tennis.tscn", Career.TENNIS],
	"table_tennis": ["res://scenes/table_tennis.tscn", Career.TABLE_TENNIS],
	"indoor": ["res://scenes/volleyball.tscn", Career.INDOOR],
	"beach": ["res://scenes/beach.tscn", Career.BEACH],
}

## A little longer for the sports whose scenes cover more ground.
const LONGER := {
	"walk_on": [1.0, 4.5, 7.0, 10.0, 12.5, 14.5, 17.0, 19.5, 22.0],
	"match_won": [1.5, 3.5, 6.0, 8.5, 11.0, 14.0, 16.0],
	"taken_off": [1.5, 4.0, 6.5, 8.5, 10.5, 12.5],
	"moved_up": [0.8, 2.5, 4.5, 6.5],
	"seat": [0.6, 1.2],
}


func _ready() -> void:
	var which := OS.get_environment("SCENE")
	if which.is_empty():
		which = "walk_on"
	var sport := OS.get_environment("SPORT")
	if SCENES.has(sport):
		await _another_sport(sport, which)
		return
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


func _another_sport(sport: String, which: String) -> void:
	var doubles := OS.get_environment("DOUBLES") == "1"
	var arena: OfficiatedMatch = load(SCENES[sport][0]).instantiate()
	arena.print_truth_while_testing = false
	arena.cutscenes = false
	add_child(arena)
	await get_tree().physics_frame
	arena.career = Career.new()
	arena.career.sport = SCENES[sport][1]
	arena.career.doubles = doubles
	arena.career.tier = int(OS.get_environment("TIER")) if OS.has_environment("TIER") else 2
	arena._on_match_requested()
	if arena.pressure.exists():
		arena.ui.hide_briefing()
	await get_tree().process_frame

	match which:
		"walk_on":
			arena.cutscenes = true
			arena._walk_on_then_begin()
		"match_won":
			arena.begin_match()
			arena.cutscenes = true
			await get_tree().create_timer(0.3).timeout
			var tennis := arena.board as TennisScore
			if tennis != null:
				tennis.finished_sets.append({Sides.Team.RED: 6, Sides.Team.BLUE: 4})
				tennis.sets[Sides.Team.RED] = tennis.sets_needed - 1
				tennis.games[Sides.Team.RED] = 5
				tennis.games[Sides.Team.BLUE] = 3
				tennis.points[Sides.Team.RED] = 3
			var awarded := 0
			while not arena.board.is_over and awarded < 400:
				arena.board.award(Sides.Team.BLUE if awarded % 7 == 3 else Sides.Team.RED)
				awarded += 1
		"taken_off":
			arena.begin_match()
			arena.cutscenes = true
			await get_tree().create_timer(0.3).timeout
			arena.suspicion.is_removed = true
			arena.finish("TAKEN OFF THE MATCH", Color(0.96, 0.42, 0.36), true)
		"seat":
			arena.cutscenes = true
			var scene := arena._make_cutscene()
			scene._open()
			var umpire := scene._official(scene._seat())
			umpire.rotation.y = -PI * 0.5
			umpire.sit()
			var eye := Vector3(OS.get_environment("EYE_X").to_float(), 2.0,
				OS.get_environment("EYE_Z").to_float())
			scene._aim(eye, scene._seat() + Vector3(0.0, 0.8, 0.0), 40.0)
		"moved_up":
			arena.cutscenes = true
			arena.career.tier = mini(arena.career.tier + 1, arena.career.ladder().size() - 1)
			arena.cutscene = arena._make_cutscene()
			arena.cutscene.moved_up(arena.career.venue())

	# AT=0.5,1,2 photographs those moments instead, for finding where a scene really is.
	var moments: Array = LONGER[which]
	if OS.has_environment("AT"):
		moments = Array(OS.get_environment("AT").split(",")).map(func(v: String) -> float: return v.to_float())
	for moment: float in moments:
		while _clock < moment:
			await get_tree().process_frame
			_clock += get_process_delta_time()
		await RenderingServer.frame_post_draw
		var path := "res://dev/shots/cut_%s_%s%s_%04.1f.png" % [sport, which, "_doubles" if doubles else "", moment]
		get_viewport().get_texture().get_image().save_png(path)
		print("saved ", path)
	get_tree().quit()
