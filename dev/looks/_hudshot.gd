extends Node

## The whole in-match HUD for one sport, part way into a close match, with everything that
## can be up at once actually up: the score bug with a finished game or set and a point
## tab, the reviews, the call prompt, the line judge, the meter, the commentary and the
## hall's line. Made for the broadcast redesign of 2026-09-15, so each sport's bug can be
## compared with its television.
##
##     SPORT=tennis godot --path . res://dev/looks/_hudshot.tscn
##
## SPORT is badminton (default), beach, indoor, tennis or table_tennis.

const SCENES := {
	"badminton": ["res://scenes/match.tscn", Career.BADMINTON],
	"beach": ["res://scenes/beach.tscn", Career.BEACH],
	"indoor": ["res://scenes/volleyball.tscn", Career.INDOOR],
	"tennis": ["res://scenes/tennis.tscn", Career.TENNIS],
	"table_tennis": ["res://scenes/table_tennis.tscn", Career.TABLE_TENNIS],
}

## Points to hand out, in order, as [red, blue] runs: enough for one finished game or set
## and a close one after it.
const RUNS := {
	"badminton": [[21, 18], [20, 19]],
	"beach": [[21, 17], [20, 18]],
	"indoor": [[25, 21], [24, 22]],
	"table_tennis": [[11, 8], [10, 9]],
}

const PROMPTS := {
	"badminton": "LEFT CLICK  in    RIGHT CLICK  out    L  let    W  service court    F  fault or card",
	"beach": "LEFT CLICK  in    RIGHT CLICK  out    T  touch    F  fault",
	"indoor": "LEFT CLICK  in    RIGHT CLICK  out    T  touch    F  fault or rotation",
	"tennis": "LEFT CLICK  in    RIGHT CLICK  out    F  a fault",
	"table_tennis": "LEFT CLICK  in    RIGHT CLICK  out    F  a fault",
}


func _ready() -> void:
	var which := OS.get_environment("SPORT") if OS.has_environment("SPORT") else "badminton"
	var arena: Node = load(SCENES[which][0]).instantiate()
	arena.print_truth_while_testing = false
	add_child(arena)
	await get_tree().physics_frame
	arena.career = Career.new()
	arena.career.sport = SCENES[which][1]
	# The top rung: full-length matches, and Hawk-Eye, so there are reviews to show.
	arena.career.tier = Career.ladder_for(arena.career.sport).size() - 1
	for flag in ["taught", "taught_beach", "taught_indoor", "taught_tennis", "taught_table_tennis"]:
		arena.settings.set(flag, true)
	arena.ui.match_requested.emit()
	await get_tree().process_frame
	if arena.pressure.exists():
		arena.ui.briefing_acknowledged.emit()
		arena.ui.hide_briefing()
		await get_tree().process_frame
	arena.begin_match()
	for f in 30:
		await get_tree().process_frame

	var board: Scoreboard = arena.board
	if which == "tennis":
		_tennis(board as TennisScore)
	else:
		for run in RUNS[which]:
			_play_to(board, run[0], run[1])
	arena.ui.set_score(board, Sides.Team.RED)
	arena.ui.set_reviews(2, 1, true)
	arena.ui.set_prompt(PROMPTS[which])
	arena.ui.show_commentary(Commentary.CHANNEL, Commentary.AISHA,
		"I've sat in that chair. When a whole hall reacts like that, you've lost them.")
	arena.ui.react("\"Are you WATCHING this?\"", 30.0)
	arena.ui.show_line_judge(false, 30.0)
	arena.ui.show_reputation(0.62, -0.04, true)
	for f in 40:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var path := "res://dev/shots/hud_%s.png" % which
	get_viewport().get_texture().get_image().save_png(path)
	print("saved %s   tab: %s" % [path, arena.ui._score_bug.point_tab(board, Sides.Team.RED)])
	get_tree().quit()


## Alternates points so neither side wins the game before both numbers are reached.
func _play_to(board: Scoreboard, red: int, blue: int) -> void:
	var r := 0
	var b := 0
	while r < red or b < blue:
		if b < blue and (b < r or r >= red):
			board.award(Sides.Team.BLUE)
			b += 1
		else:
			board.award(Sides.Team.RED)
			r += 1


## One set 6-4 to RED, then 3-2 in games and 40-30 in points.
func _tennis(board: TennisScore) -> void:
	for game in [0, 1, 0, 1, 0, 1, 0, 1, 0, 0, 0, 1, 0, 1, 0]:
		for p in 4:
			board.award(Sides.Team.RED if game == 0 else Sides.Team.BLUE)
	for p in 2:
		board.award(Sides.Team.RED)
		board.award(Sides.Team.BLUE)
	board.award(Sides.Team.RED)
