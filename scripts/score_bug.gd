class_name ScoreBug
extends MarginContainer

## The score in the corner of the screen, laid out the way each sport's own television
## lays it out.
##
## Until 2026-09-15 every sport shared one bug — two team blocks and the points between
## them across the top of the screen — which is how no broadcast of any of these sports
## actually looks. Luqman asked for the in-game interface to follow the real ones, and
## the real ones are not the same as each other (studied from 2025 match footage):
##
## - **Badminton**, BWF World Tour: top left, one row per side, a light name plate, a
##   shuttle beside the server, each finished game in a pale cell and the game being
##   played in a bright one.
## - **Both volleyballs**, FIVB Beach Pro Tour and the Nations League: one wide strip at the
##   bottom centre, mirrored — team, sets won, points, and the same again the other way.
## - **Tennis**, the tour broadcasts: bottom left, one row per player on a dark plate,
##   finished sets as plain numbers, the games of this set in a lit box, then the points
##   in the language tennis counts in.
## - **Table tennis**, WTT: bottom left, dark plate, the games won in a coloured column and
##   the points beside them.
##
## No flags, no seeds and no logos: this game has no countries or tournaments of its own
## to put there, and licensed branding is out of scope. The team colour stands where a
## flag would be.
##
## A tab hangs off the bug at game, set or match point, which every one of those
## broadcasts does. It says nothing the scoreboard in the hall does not already say.

enum Layout { STACK, STRIP }

const ROW_HEIGHT := 58
const CELL_WIDTH := 58
const NAME_WIDTH := 150

var sport: StringName = Career.BADMINTON
var layout := Layout.STACK

## Everything below is rebuilt when the sport changes and refilled on every point.
var _rows: Dictionary = {}
var _strip: Dictionary = {}
var _body: Container
var _reviews: HBoxContainer
var _reviews_red: Label
var _reviews_blue: Label
var _tab: PanelContainer
var _tab_label: Label

var _last_board: Scoreboard
var _last_serving := Sides.Team.NONE


func _init() -> void:
	name = "ScoreBug"
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
	_build()


## Which sport's broadcast to copy. Rebuilds, and puts itself where that sport's bug goes.
func use_sport(which: StringName) -> void:
	if which == sport and _body != null:
		return
	sport = which
	layout = Layout.STRIP if which == Career.BEACH or which == Career.INDOOR else Layout.STACK
	if is_inside_tree():
		_build()
		if _last_board != null:
			show_score(_last_board, _last_serving)


## Where on the screen this sport's bug sits, as an anchor preset and the offsets from it.
## Read by RefereeUI, which also has to move the commentary out of the way of it.
func corner() -> int:
	match sport:
		# ISTAF's world feed puts sepak takraw's bug top left, as the BWF does badminton's.
		Career.BADMINTON, Career.TAKRAW: return Control.PRESET_TOP_LEFT
		Career.BEACH, Career.INDOOR: return Control.PRESET_CENTER_BOTTOM
		_: return Control.PRESET_BOTTOM_LEFT


func _build() -> void:
	# Removed as well as freed: a container sizes itself to its children, and one merely
	# queued for freeing still counts until the end of the frame.
	for child in get_children():
		remove_child(child)
		child.queue_free()
	_rows.clear()
	_strip.clear()

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 0)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(column)
	_body = column

	# The point tab sits on top of a bug at the bottom of the screen, and under one at the
	# top, so it always hangs into the picture rather than off the edge of it.
	_tab = _make_tab()
	var reviews := _make_reviews()
	var at_top := corner() == Control.PRESET_TOP_LEFT
	if not at_top:
		column.add_child(_tab)
		column.add_child(reviews)
	if layout == Layout.STRIP:
		column.add_child(_build_strip())
	else:
		var stack := VBoxContainer.new()
		stack.add_theme_constant_override("separation", 3)
		stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
		column.add_child(stack)
		for team in [Sides.Team.RED, Sides.Team.BLUE]:
			stack.add_child(_build_row(team))
	if at_top:
		column.add_child(reviews)
		column.add_child(_tab)
	if layout == Layout.STRIP:
		_tab.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		reviews.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_tab.visible = false
	reviews.visible = false


# --- one row per side: badminton, tennis, table tennis ------------------------------

func _build_row(team: Sides.Team) -> HBoxContainer:
	var light := sport == Career.BADMINTON
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 0)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var chip := ColorRect.new()
	chip.color = Sides.colour(team)
	chip.custom_minimum_size = Vector2(16, ROW_HEIGHT)
	row.add_child(chip)

	var plate := PanelContainer.new()
	var skin := UiTheme.block(UiTheme.PAPER if light else Color(0.07, 0.09, 0.14, 0.94))
	skin.content_margin_left = 18
	skin.content_margin_right = 10
	skin.content_margin_top = 0
	skin.content_margin_bottom = 0
	plate.add_theme_stylebox_override("panel", skin)
	plate.custom_minimum_size = Vector2(NAME_WIDTH + 60, ROW_HEIGHT)
	row.add_child(plate)
	var inside := HBoxContainer.new()
	inside.add_theme_constant_override("separation", 8)
	plate.add_child(inside)
	var name_label := UiTheme.label(Sides.label(team), UiTheme.HEADING + 4,
		UiTheme.INK if light else UiTheme.CHALK, UiTheme.heavy())
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inside.add_child(name_label)
	var serve := ServeMark.new()
	serve.kind = sport
	serve.custom_minimum_size = Vector2(34, ROW_HEIGHT)
	serve.visible_mark = false
	inside.add_child(serve)

	# Finished games or sets. Badminton and tennis show them; WTT shows only the count.
	var finished := HBoxContainer.new()
	finished.add_theme_constant_override("separation", 0)
	row.add_child(finished)

	var games: Label = null
	if sport == Career.TABLE_TENNIS:
		games = _cell(row, "0", Sides.colour(team), Color.WHITE, CELL_WIDTH)
	var current := _cell(row, "0", Sides.colour(team) if light else UiTheme.RAISED,
		Color.WHITE, CELL_WIDTH + 8)
	var points: Label = null
	if sport == Career.TENNIS:
		points = _cell(row, "0", UiTheme.PAPER, UiTheme.INK, CELL_WIDTH + 16)
	if sport == Career.TABLE_TENNIS:
		# WTT puts the points on the dark plate and the games in colour, so the cell called
		# "current" here is the points.
		(current.get_parent() as PanelContainer).add_theme_stylebox_override("panel",
			_cell_skin(Color(0.07, 0.09, 0.14, 0.94)))

	_rows[team] = {"serve": serve, "finished": finished, "current": current,
		"points": points, "games": games, "light": light}
	return row


func _cell(row: HBoxContainer, text: String, fill: Color, ink: Color, width: int) -> Label:
	var cell := PanelContainer.new()
	cell.add_theme_stylebox_override("panel", _cell_skin(fill))
	cell.custom_minimum_size = Vector2(width, ROW_HEIGHT)
	row.add_child(cell)
	var label := UiTheme.label(text, UiTheme.HEADING + 8, ink, UiTheme.heavy())
	cell.add_child(label)
	return label


func _cell_skin(fill: Color) -> StyleBoxFlat:
	var skin := UiTheme.block(fill)
	skin.content_margin_left = 8
	skin.content_margin_right = 8
	skin.content_margin_top = 0
	skin.content_margin_bottom = 0
	return skin


# --- the volleyball strip -----------------------------------------------------------

func _build_strip() -> PanelContainer:
	var plate := PanelContainer.new()
	var skin := UiTheme.block(Color(0.07, 0.09, 0.14, 0.94))
	skin.set_content_margin_all(0)
	skin.border_width_bottom = 4
	skin.border_color = UiTheme.ACCENT
	plate.add_theme_stylebox_override("panel", skin)
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 0)
	plate.add_child(row)

	for team in [Sides.Team.RED, Sides.Team.BLUE]:
		var left: bool = team == Sides.Team.RED
		var parts := {}
		var bar := ColorRect.new()
		bar.color = Sides.colour(team)
		bar.custom_minimum_size = Vector2(14, ROW_HEIGHT + 16)

		var code := UiTheme.label(Sides.label(team), UiTheme.HEADING + 6, UiTheme.CHALK,
			UiTheme.display())
		code.custom_minimum_size = Vector2(118, 0)

		var serve := ServeMark.new()
		serve.kind = sport
		serve.custom_minimum_size = Vector2(36, 0)
		serve.visible_mark = false

		var sets_box := VBoxContainer.new()
		sets_box.alignment = BoxContainer.ALIGNMENT_CENTER
		sets_box.add_theme_constant_override("separation", -6)
		sets_box.custom_minimum_size = Vector2(64, 0)
		var sets_word := UiTheme.label("SETS", UiTheme.SMALL - 8, UiTheme.MUTED, UiTheme.heavy())
		sets_box.add_child(sets_word)
		var sets := UiTheme.label("0", UiTheme.HEADING, UiTheme.CHALK, UiTheme.heavy())
		sets_box.add_child(sets)

		var points_plate := PanelContainer.new()
		points_plate.add_theme_stylebox_override("panel", _cell_skin(Sides.colour(team).darkened(0.15)))
		points_plate.custom_minimum_size = Vector2(96, ROW_HEIGHT + 16)
		var points := UiTheme.label("0", UiTheme.HUGE - 16, Color.WHITE, UiTheme.heavy())
		points_plate.add_child(points)

		var order: Array = [bar, code, serve, sets_box, points_plate]
		if not left:
			order.reverse()
		for part in order:
			row.add_child(part)
		parts = {"serve": serve, "sets": sets, "points": points}
		_strip[team] = parts

		if left:
			var middle := VBoxContainer.new()
			middle.alignment = BoxContainer.ALIGNMENT_CENTER
			middle.custom_minimum_size = Vector2(96, 0)
			middle.add_theme_constant_override("separation", -8)
			middle.add_child(UiTheme.label("SET", UiTheme.SMALL - 6, UiTheme.MUTED, UiTheme.heavy()))
			var number := UiTheme.label("1", UiTheme.HEADING + 4, UiTheme.ACCENT, UiTheme.display())
			middle.add_child(number)
			row.add_child(middle)
			_strip["set"] = number
	return plate


# --- the tabs ----------------------------------------------------------------------

func _make_tab() -> PanelContainer:
	var tab := PanelContainer.new()
	var skin := UiTheme.slant(UiTheme.ACCENT)
	skin.content_margin_top = 2
	skin.content_margin_bottom = 2
	skin.content_margin_left = 20
	skin.content_margin_right = 20
	tab.add_theme_stylebox_override("panel", skin)
	tab.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_tab_label = UiTheme.label("", UiTheme.SMALL, UiTheme.INK, UiTheme.heavy())
	tab.add_child(_tab_label)
	return tab


## How many reviews each side still holds. Shown because it is the whole of the threat: an
## umpire who cannot see that RED has two challenges left does not know whether the next
## close call is worth lying about.
func _make_reviews() -> PanelContainer:
	var plate := PanelContainer.new()
	var skin := UiTheme.block(Color(UiTheme.INK.r, UiTheme.INK.g, UiTheme.INK.b, 0.88))
	skin.content_margin_top = 2
	skin.content_margin_bottom = 2
	skin.content_margin_left = 16
	skin.content_margin_right = 16
	skin.border_width_left = 5
	skin.border_color = UiTheme.ACCENT
	plate.add_theme_stylebox_override("panel", skin)
	plate.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_reviews = HBoxContainer.new()
	_reviews.add_theme_constant_override("separation", 12)
	plate.add_child(_reviews)
	_reviews.add_child(UiTheme.label("REVIEWS", UiTheme.SMALL, UiTheme.MUTED, UiTheme.heavy()))
	_reviews.add_child(UiTheme.label("RED", UiTheme.SMALL, UiTheme.RED, UiTheme.heavy()))
	_reviews_red = UiTheme.label("", UiTheme.SMALL, UiTheme.CHALK, UiTheme.heavy())
	_reviews.add_child(_reviews_red)
	_reviews.add_child(UiTheme.label("BLUE", UiTheme.SMALL, UiTheme.BLUE, UiTheme.heavy()))
	_reviews_blue = UiTheme.label("", UiTheme.SMALL, UiTheme.CHALK, UiTheme.heavy())
	_reviews.add_child(_reviews_blue)
	return plate


# --- filling it in ------------------------------------------------------------------

func show_score(board: Scoreboard, serving: Sides.Team) -> void:
	_last_board = board
	_last_serving = serving
	if _body == null:
		return
	if layout == Layout.STRIP:
		_fill_strip(board, serving)
	else:
		for team in [Sides.Team.RED, Sides.Team.BLUE]:
			_fill_row(board, serving, team)
	_fill_tab(board, serving)


func _fill_row(board: Scoreboard, serving: Sides.Team, team: Sides.Team) -> void:
	var parts: Dictionary = _rows.get(team, {})
	if parts.is_empty():
		return
	(parts["serve"] as ServeMark).visible_mark = serving == team

	var finished: HBoxContainer = parts["finished"]
	for child in finished.get_children():
		finished.remove_child(child)
		child.queue_free()
	var tennis := board as TennisScore
	if sport != Career.TABLE_TENNIS:
		for done in board.finished_sets:
			var mine: int = done[team]
			var theirs: int = done[Sides.opponent(team)]
			var won := mine > theirs
			var fill := UiTheme.PALE if parts["light"] else Color(0.10, 0.13, 0.19, 0.94)
			var ink := UiTheme.INK if parts["light"] else (UiTheme.CHALK if won else UiTheme.MUTED)
			_cell(finished, str(mine), fill, ink, CELL_WIDTH)

	var current: Label = parts["current"]
	if tennis != null:
		current.text = str(tennis.games[team])
		(parts["points"] as Label).text = tennis_points(tennis, team)
	elif sport == Career.TABLE_TENNIS:
		(parts["games"] as Label).text = str(board.games[team])
		current.text = str(board.points[team])
	else:
		current.text = str(board.points[team])


func _fill_strip(board: Scoreboard, serving: Sides.Team) -> void:
	for team in [Sides.Team.RED, Sides.Team.BLUE]:
		var parts: Dictionary = _strip.get(team, {})
		if parts.is_empty():
			continue
		(parts["serve"] as ServeMark).visible_mark = serving == team
		(parts["sets"] as Label).text = str(board.games[team])
		(parts["points"] as Label).text = str(board.points[team])
	var number: Label = _strip.get("set")
	if number != null:
		number.text = str(mini(board.finished_sets.size() + 1,
			board.games_needed * 2 - 1))


## One player's points in tennis, as a tour bug shows them: 0, 15, 30, 40 and AD, or plain
## numbers in a tiebreak. At deuce both read 40; the side with the advantage reads AD and
## the other goes blank, which is how the bug says it without spelling the word out.
static func tennis_points(board: TennisScore, team: Sides.Team) -> String:
	var mine: int = board.points[team]
	var theirs: int = board.points[Sides.opponent(team)]
	if board.in_tiebreak:
		return str(mine)
	if mine >= 3 and theirs >= 3:
		if mine == theirs:
			return "40"
		return "AD" if mine > theirs else ""
	return TennisScore.CALLED[mini(mine, 3)]


func _fill_tab(board: Scoreboard, serving: Sides.Team) -> void:
	if _tab == null:
		return
	var text := point_tab(board, serving)
	_tab_label.text = text
	_tab.visible = not text.is_empty()


## GAME POINT, SET POINT or MATCH POINT, or nothing. Worked out by asking the scoreboard
## what one more point would do, for each side, and putting the numbers straight back.
func point_tab(board: Scoreboard, serving: Sides.Team) -> String:
	if board == null or board.is_over:
		return ""
	var best := ""
	for team in [serving, Sides.opponent(serving)]:
		if team == Sides.Team.NONE:
			continue
		var tab := _what_one_point_wins(board, team)
		if tab == "MATCH POINT":
			return tab
		if best.is_empty():
			best = tab
	return best


func _what_one_point_wins(board: Scoreboard, team: Sides.Team) -> String:
	var tennis := board as TennisScore
	board.points[team] += 1
	var wins_game: bool = board._has_won_game(team)
	board.points[team] -= 1
	if not wins_game:
		return ""

	if tennis != null:
		tennis.games[team] += 1
		var wins_set: bool = tennis._has_won_set(team)
		tennis.games[team] -= 1
		if not wins_set:
			return ""
		return "MATCH POINT" if tennis.sets[team] + 1 >= tennis.sets_needed else "SET POINT"

	if board.games[team] + 1 >= board.games_needed:
		return "MATCH POINT"
	return "SET POINT" if layout == Layout.STRIP or sport == Career.TAKRAW else "GAME POINT"


func show_reviews(red: int, blue: int, enabled: bool) -> void:
	if _reviews == null:
		return
	var plate := _reviews.get_parent() as Control
	plate.visible = enabled
	if not enabled:
		return
	_reviews_red.text = _dots(red)
	_reviews_blue.text = _dots(blue)


## Filled for a review still held, hollow for one spent.
static func _dots(left: int) -> String:
	return "●".repeat(left) + "○".repeat(maxi(0, Challenge.PER_GAME - left))


## What each sport marks the server with, drawn rather than typed.
class ServeMark extends Control:
	var kind: StringName = Career.BADMINTON
	var visible_mark := false:
		set(value):
			visible_mark = value
			queue_redraw()

	func _draw() -> void:
		if not visible_mark:
			return
		var c := size * 0.5
		var r := minf(size.x, size.y) * 0.30
		match kind:
			Career.BADMINTON:
				# A shuttle, cork down and to the left, the way the BWF bug draws it.
				draw_colored_polygon(PackedVector2Array([
					c + Vector2(-r * 0.9, -r * 1.1), c + Vector2(r * 0.9, -r * 1.1),
					c + Vector2(r * 0.25, r * 0.5), c + Vector2(-r * 0.25, r * 0.5)]),
					UiTheme.RED)
				draw_circle(c + Vector2(0, r * 0.75), r * 0.38, UiTheme.RED)
			Career.TENNIS:
				draw_circle(c, r, Color(0.86, 0.94, 0.25))
				draw_arc(c + Vector2(-r * 1.2, 0), r * 0.95, -0.9, 0.9, 12, Color.WHITE, 2.0)
			Career.TABLE_TENNIS:
				draw_colored_polygon(PackedVector2Array([
					c + Vector2(r, -r), c + Vector2(r, r), c + Vector2(-r * 0.8, 0)]),
					UiTheme.ACCENT)
			Career.TAKRAW:
				# ISTAF's feed marks the serving team with a small orange arrow.
				draw_colored_polygon(PackedVector2Array([
					c + Vector2(-r * 0.8, -r), c + Vector2(-r * 0.8, r), c + Vector2(r, 0)]),
					Color(1.0, 0.55, 0.10))
			_:
				draw_circle(c, r, Color.WHITE)
				draw_arc(c, r, 0.0, TAU, 20, UiTheme.INK, 2.0)
				draw_arc(c + Vector2(r * 0.9, -r * 0.4), r, 2.2, 3.9, 10, UiTheme.BLUE, 2.5)
				draw_arc(c + Vector2(-r * 0.9, -r * 0.4), r, -0.8, 0.9, 10, UiTheme.ACCENT, 2.5)
