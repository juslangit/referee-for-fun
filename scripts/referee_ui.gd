class_name RefereeUI
extends CanvasLayer

## Everything the player sees that is not the court.
##
## One rule governs this whole file: it is never told where the shuttle landed. It
## shows the score, the call that was made, and who got the point — all things the
## hall can see. Whether the call was true is not among them. The moment this screen
## can tell the player they got it right, the game stops being about judgement.

signal briefing_acknowledged()
signal punishment_chosen(id: StringName, team: Sides.Team)
signal match_requested()
signal play_requested()
signal sport_chosen(id: StringName)
signal format_chosen(doubles: bool)
signal settings_requested()

## BACK, when the settings were opened from a paused match rather than from the title
## screen. The two go to different places and the sheet is the same sheet.
signal settings_closed()
signal main_menu_requested()
signal look_speed_changed(radians_per_pixel: float)
signal teaching_requested()
signal teaching_finished()
signal career_restart_requested()
signal continue_requested()
signal new_career_requested()
signal career_screen_requested()
signal history_requested()
signal resume_requested()
signal walk_out_requested()
signal quit_requested()

## The replay of the worst calls: on to the next one, or past all of them.
signal replay_next()
signal replay_skip_all()
## SKIP during a cutscene, for the mouse. The keys are the cutscene's own.
signal cutscene_skip()

## Sizes live in UiTheme so the whole interface grows together. It used to be a list
## of numbers here, each one adjusted separately, which is how it ended up too small to
## read from where the player is actually sitting.
const TITLE_SIZE := UiTheme.TITLE
const BUTTON_SIZE := UiTheme.HEADING
const SCORE_SIZE := UiTheme.TITLE
const MESSAGE_SIZE := UiTheme.HUGE
const PROMPT_SIZE := UiTheme.BODY
const REACTION_SIZE := UiTheme.BODY
const BANNER_SIZE := UiTheme.HEADING

## The reputation meter: how long it fades in, how long it stays, how long it fades out.
## Three seconds all told, which is long enough to read and short enough that it is gone
## again before the next serve.
const METER_FADE_IN := 0.4
const METER_HOLD := 2.2
const METER_FADE_OUT := 0.4

## How wide the bar is, and where the colour of the fill changes.
## How wide the reason note on the left is allowed to be before it wraps, and how far
## in from the edge of the screen it sits. Narrow on purpose: it is read at a glance
## out of the corner of the eye while the next serve is being walked back to.
## The bubble over a spectator's head: how wide it may get before it wraps, how far
## its point sits above their hair, and how big the tail is.
const BUBBLE_MAX_WIDTH := 360
const BUBBLE_LIFT := 14
const BUBBLE_TAIL := 11
const BUBBLE_FADE := 0.25
const BUBBLE_HOLD := 2.4

## How wide each of the two footer buttons is.
const FOOTER_BUTTON_WIDTH := 300

## Every button on the title screen is this wide, whatever its word is.
const TITLE_BUTTON_WIDTH := 420

const REASON_WIDTH := 380
const REASON_INSET := 44

const METER_WIDTH := 340
const METER_HEIGHT := 26
const METER_SAFE := 0.60
const METER_SHAKY := 0.30

## Everything is parented to this rather than to the layer, because a Theme travels
## down a Control tree and a CanvasLayer is not a Control. One assignment here styles
## every button, label and panel in the game.
var _root: Control
var _hud: Control

## The sports, in the order they appear. Every card is a photograph of this game,
## rendered by dev/looks/_cards.gd.
##
## A sport that is not built yet can still sit in the row with "ready": false — it is
## drawn dim, with COMING SOON under the name, and its art should be one of the
## public-domain Olympic pictograms in assets/ui/ (see ATTRIBUTION.md), so a real picture
## always means a sport you can actually walk into. Basketball sat here like that until
## 2026-09-11 and was taken out: it needs a referee who walks, not one in a chair.
##
## Since 2026-09-15 each tile shows an illustrated athlete rather than the render: the five
## were drawn together on one OpenArt sheet (dev/ref/ui-redesign/sheet_portraits.png) so
## they match, and cut apart by tools/ui/prepare_art.gd. `art` is still the render, kept
## for anything that wants a picture of the game itself.
##
## Replaced on 2026-09-16: `portrait` is now an action poster per sport — the smash, the
## spike, the serve, the loop, the bicycle kick — drawn one at a time against that same
## sheet as the style reference, and fitted to the tile by tools/ui/prepare_action_posters.gd.
## The standing versions are in git history at 4022360 if they are ever wanted back.
const SPORTS := [
	{"id": &"badminton", "name": "Badminton", "art": "res://assets/ui/card_badminton.png",
		"portrait": "res://assets/ui/portrait_badminton.png",
		"band": Color(0.20, 0.55, 0.30), "tint": Color(0.16, 0.44, 0.30), "ready": true},
	{"id": &"beach", "name": "Beach Volleyball",
		"art": "res://assets/ui/card_beachvolleyball.png",
		"portrait": "res://assets/ui/portrait_beachvolleyball.png",
		"band": Color(0.86, 0.58, 0.24), "tint": Color(0.78, 0.52, 0.20), "ready": true},
	{"id": &"indoor", "name": "Volleyball", "art": "res://assets/ui/card_volleyball.png",
		"portrait": "res://assets/ui/portrait_volleyball.png",
		"band": Color(0.50, 0.30, 0.66), "tint": Color(0.44, 0.24, 0.52), "ready": true},
	{"id": &"tennis", "name": "Tennis", "art": "res://assets/ui/card_tennis.png",
		"portrait": "res://assets/ui/portrait_tennis.png",
		"band": Color(0.22, 0.46, 0.76), "tint": Color(0.20, 0.38, 0.58), "ready": true},
	{"id": &"table_tennis", "name": "Table Tennis",
		"art": "res://assets/ui/card_tabletennis.png",
		"portrait": "res://assets/ui/portrait_tabletennis.png",
		"band": Color(0.74, 0.34, 0.22), "tint": Color(0.60, 0.34, 0.16), "ready": true},
	# Drawn alone on 2026-09-15 with the sheet as its style reference, and fitted to the
	# sheet's framing by tools/ui/prepare_art.gd.
	{"id": &"takraw", "name": "Sepak Takraw",
		"art": "res://assets/ui/card_takraw.png",
		"portrait": "res://assets/ui/portrait_takraw.png",
		"band": Color(0.80, 0.62, 0.08), "tint": Color(0.62, 0.48, 0.06), "ready": true},
]

## How big one card is on the sport screen. Tall — a sport reads better as a portrait of
## somebody playing it than as a square. On the title screen the tiles stretch to fill
## the row instead, so the five always span the screen whatever size the window is.
##
## Narrowed when the sixth sport arrived: six cards and their gaps have to fit a 1280-pixel
## window, which is the smallest the game is played in.
const CARD := Vector2(184.0, 340.0)

## Which part of a portrait a tile shows.
##
## The standing portraits were cropped to a band — from just above the head down past the
## hands — because the bottom two fifths of them were nothing but legs. The action posters
## that replaced them on 2026-09-16 have to be shown whole: a badminton smash is in the
## air, a tennis serve reaches out of the top of any band, and the takraw bicycle kick is
## upside down with the player's head at the BOTTOM of the picture, so the old crop
## beheaded it. `prepare_action_posters.gd` already frames each figure on the tile, and
## the tile's job now is to show what it framed.
const PORTRAIT_TOP := 0.0
const PORTRAIT_TALL := 0.0

## The title screen's logo, drawn on OpenArt and keyed by tools/ui/prepare_art.gd.
const TITLE_LOGO := "res://assets/ui/title_logo.png"

var _main_menu: Control
var _main_menu_column: VBoxContainer
var _sport_menu: Control
var _format_menu: Control
var _format_column: VBoxContainer
var _settings_menu: Control
var _pause_menu: Control
var _career_panel: Control
var _career_column: VBoxContainer
var _ending_button: Button

## The screen that gives you a reason before it asks you the question.
var _close_cam_caption: Label
var _briefing: Control
var _briefing_headline: Label
var _briefing_detail: Label
var _briefing_ask: Label
var _ending: Control
var _ending_headline: Label
var _ending_detail: Label
var _score_bug: ScoreBug
var _prompt_label: Label
var _prompt_keys: HBoxContainer
var _prompt_plate: PanelContainer
var _message_label: Label
var _reaction_label: Label
var _banner_label: Label
var _fault_panel: Control
var _fault_rows: VBoxContainer
var _shuttle_cam_panel: Control
var _shuttle_cam_view: TextureRect
var _message_timer := 0.0
var _reaction_timer := 0.0
var _banner_timer := 0.0

## What the line judge called, and how long it stays up.
var _judge_label: Label
var _judge_plate: PanelContainer
var _judge_timer := 0.0

## The reputation meter, and where it is in its three seconds. `_meter_left` counts down
## through fade-in, hold and fade-out together, so re-triggering it while it is already
## up simply refills the clock rather than starting the fade again — which matters,
## because calls come close together and a meter that re-faded would flicker.
var _meter: PanelContainer
var _meter_bar: ProgressBar
var _meter_value: Label
var _meter_fill: StyleBoxFlat
var _meter_left := 0.0
var _meter_shown := 0.0

var _reason: PanelContainer
var _reason_label: Label
var _reason_left := 0.0
var _reason_shown := 0.0

## What the note said when the match was paused, so it can be put back afterwards.
##
## Pausing takes it down, because a sentence in the corner sitting across the RESUME
## button is worse than no sentence. But the note has no clock and comes down only when
## the umpire whistles the next rally, so a pause that simply deleted it threw away the
## one thing the player had not finished reading — and a player who opens the settings
## to turn the crowd down is exactly the player who was still looking at it.
var _reason_paused := ""

## Whether the note is sitting there waiting to be read rather than counting down.
var _reason_holding := false

## The pause menu's free exit, and the line under it. Both hidden once the match has
## begun to matter.
var _leave_button: Button
var _leave_note: Label


func _ready() -> void:
	layer = 10
	# Keeps running while the game is paused, or nothing could unpause it.
	process_mode = Node.PROCESS_MODE_ALWAYS

	_root = Control.new()
	_root.name = "Screen"
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.theme = UiTheme.build()
	add_child(_root)

	_build_main_menu()
	_build_sport_menu()
	_build_format_menu()
	_build_review()
	_build_pause_menu()
	_build_career_panel()
	_build_history_panel()
	_build_briefing()
	_build_hud()
	_build_ending()
	_build_shuttle_cam()
	_build_fault_panel()
	_build_broadcast()
	# Last, so they sit over everything: the replay comes before the result, and the
	# paper comes after it.
	_build_replay()
	_build_newspaper()
	_briefing.visible = false

	# Last of all, so every button above is already in the tree when it starts listening.
	var clicks := UiSound.new()
	clicks.name = "UiSound"
	add_child(clicks)


# --- keyboard ---------------------------------------------------------------------
#
# Every menu in this game could only ever be worked with a mouse. The theme has had a
# distinct focus state for its buttons since it was written — `_style_buttons()` sets a
# lit `focus` stylebox and a white `font_focus_color`, and the comment above it says in
# so many words that it "gives the button an obvious focus state" — and Godot moves focus
# between controls on the arrow keys and presses the focused one on `ui_accept` without
# being asked. All of that was already true and none of it was reachable, because
# **nothing ever took focus in the first place**, and with nothing focused the arrow keys
# have nowhere to start from.
#
# So this is two calls rather than a navigation system: take focus when a menu opens,
# give it back when the menu closes.
#
# Giving it back is not tidiness. `match.gd` starts a rally on SPACE in `Phase.READY`,
# and a focused Button eats `ui_accept` before `_unhandled_input` ever sees it. A button
# left focused behind a match would swallow the serve key and press REFEREE THIS MATCH
# again instead, which would look exactly like the serve key having stopped working.


## Focus the first button a player would reach for: the first one in tree order that is
## actually on screen and actually pressable.
##
## Tree order rather than position, because every menu here is built top to bottom with
## its main action first — PLAY, REFEREE THIS MATCH, RESUME — so the first button is the
## one already meant to be the default. Godot works out the arrow-key neighbours from the
## layout on its own.
##
## `_is_dying()` is the part that took two goes to get right, and it is worth writing down
## because nothing about it is visible from the outside.
##
## The title screen and the career screen rebuild themselves by calling `queue_free()` on
## the children of their column. `queue_free()` does not take a node out of the tree — it
## takes it out at the *end of the frame*. So for the whole of the frame in which a menu
## is rebuilt, the old buttons are still present, still visible, still findable, sitting
## in front of the new ones in tree order. Focus landed on one of those and then
## evaporated a frame later when it was freed.
##
## The first attempt at a guard asked the button itself, and that is not enough: what was
## queued is the *wrapper container* the button sits in, so `is_queued_for_deletion()` on
## the button answers false while its parent is on its way out. The question has to be
## asked of every ancestor up to the menu's own root.
##
## Symptom, for anyone who meets it again: the menu is focused the first time it is ever
## opened and dead every time after, because the first time there is nothing stale to
## find. A probe printed ten buttons on a five-button screen, which is what gave it away.
func _focus_first(root: Node) -> void:
	if root == null:
		return
	for node in root.find_children("*", "Button", true, false):
		var button := node as Button
		if button.disabled or not button.is_visible_in_tree():
			continue
		if _is_dying(button, root):
			continue
		button.grab_focus()
		return


## Is this node, or anything it hangs from up to `root`, already on its way out?
func _is_dying(node: Node, root: Node) -> bool:
	var walk := node
	while walk != null:
		if walk.is_queued_for_deletion():
			return true
		if walk == root:
			return false
		walk = walk.get_parent()
	return false


## Let go, so that no button is listening when the match wants the keyboard back.
func _release_focus() -> void:
	var viewport := get_viewport()
	if viewport == null:
		return
	var held := viewport.gui_get_focus_owner()
	if held != null:
		held.release_focus()


func _unhandled_input(event: InputEvent) -> void:
	# Escape closes the pause menu. It has to be handled here rather than in the
	# match, because the match is paused and is not being given input at all.
	if not _pause_menu.visible:
		return
	if event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		resume_requested.emit()
		get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	_message_timer = _tick(delta, _message_timer, _message_label)
	_reaction_timer = _tick(delta, _reaction_timer, _reaction_label)
	_banner_timer = _tick(delta, _banner_timer, _banner_label)
	_judge_timer = _tick(delta, _judge_timer, _judge_label)
	if _judge_plate != null and _judge_timer <= 0.0:
		_judge_plate.visible = false
	_tick_the_meter(delta)
	_tick_the_reason(delta)
	_tick_the_bubble(delta)


func _tick(delta: float, timer: float, label: Label) -> float:
	if timer <= 0.0:
		return 0.0
	timer -= delta
	if timer <= 0.0:
		label.text = ""
	return timer


# --- pre-match -----------------------------------------------------------------

# --- the front of the game -----------------------------------------------------

## The panels all share a shape: a dark sheet over the court with a column of things
## in the middle of it. This builds that much, and the caller fills in the column.
## `shade` is the sheet drawn over the hall behind a menu. It is deliberately light now:
## the arena it covers is already a dark room, and stacking a heavy black sheet on top
## of it turned the backdrop to mud. The card itself is opaque, so the sheet only has to
## settle the surroundings, not hide them.
func _build_sheet(sheet_name: String, shade := Color(0.03, 0.04, 0.06, 0.45)) -> Array:
	var sheet := Control.new()
	sheet.name = sheet_name
	sheet.set_anchors_preset(Control.PRESET_FULL_RECT)
	sheet.visible = false
	sheet.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(sheet)

	var backdrop := ColorRect.new()
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.color = shade
	sheet.add_child(backdrop)

	# The contents sit on a card rather than floating on the dimmed court. A broadcast
	# graphic is always a solid shape with an edge on it; text alone over a photograph
	# is what a placeholder looks like.
	var card := PanelContainer.new()
	card.set_anchors_preset(Control.PRESET_CENTER)
	card.grow_horizontal = Control.GROW_DIRECTION_BOTH
	card.grow_vertical = Control.GROW_DIRECTION_BOTH
	sheet.add_child(card)

	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 16)
	column.custom_minimum_size = Vector2(UiTheme.BUTTON_WIDTH + 90, 0)
	card.add_child(column)

	return [sheet, column]


## The title screen is a sports game's home screen rather than a card of buttons: the
## logo and the two corner buttons along the top, your career as the one big tile, and
## every sport one click away along the bottom. The hall stays lit behind all of it —
## the old centred card covered the best-looking thing in the game with a grey rectangle.
func _build_main_menu() -> void:
	_main_menu = Control.new()
	_main_menu.name = "MainMenu"
	_main_menu.set_anchors_preset(Control.PRESET_FULL_RECT)
	_main_menu.visible = false
	_main_menu.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(_main_menu)

	# Dark along the top and the bottom, where the type and the tiles sit, and clear
	# through the middle, where the hall is.
	var shade := TextureRect.new()
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	shade.stretch_mode = TextureRect.STRETCH_SCALE
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var ramp := Gradient.new()
	ramp.offsets = PackedFloat32Array([0.0, 0.30, 0.55, 1.0])
	ramp.colors = PackedColorArray([
		Color(0.02, 0.03, 0.05, 0.78), Color(0.02, 0.03, 0.05, 0.30),
		Color(0.02, 0.03, 0.05, 0.35), Color(0.02, 0.03, 0.05, 0.86)])
	var picture := GradientTexture2D.new()
	picture.gradient = ramp
	picture.fill_from = Vector2(0.5, 0.0)
	picture.fill_to = Vector2(0.5, 1.0)
	shade.texture = picture
	_main_menu.add_child(shade)

	var frame := MarginContainer.new()
	frame.set_anchors_preset(Control.PRESET_FULL_RECT)
	frame.add_theme_constant_override("margin_left", 64)
	frame.add_theme_constant_override("margin_right", 64)
	frame.add_theme_constant_override("margin_top", 40)
	frame.add_theme_constant_override("margin_bottom", 44)
	_main_menu.add_child(frame)

	_main_menu_column = VBoxContainer.new()
	_main_menu_column.add_theme_constant_override("separation", 24)
	frame.add_child(_main_menu_column)


## The title screen: the logo, and five things you can do.
##
## This screen has now been all three ways round. It began saying nothing about the
## career at all, on the grounds that it made the front of the game read as a save-game
## manager. On 2026-09-15 Luqman chose the opposite — a sports game's home screen, with a
## large CONTINUE CAREER tile, a lesson tile beside it and all six sports in a row along
## the bottom. On 2026-09-17 he asked for the sports to come off it: *"i think it is best
## the sports selection should be in other menu, not the same as main menu"*, and picked
## a plain title screen over keeping the tiles.
##
## What that revealed is that the sport menu was already built and already finished —
## `_build_sport_menu()` draws "WHICH SPORT?" with all six cards and a working footer —
## and nothing had ever linked to it going forwards. `play_requested` was emitted only by
## `_open()`, which is the *back* navigation, so the only way to reach that screen was to
## already have been past it. The six tiles here were doing its job in its place. So this
## change is not a new screen; it is one button restored to an orphaned one.
##
## What is deliberately lost: the old tile said CONTINUE CAREER, START YOUR CAREER or
## CAREER OVER depending on the save, and showed the venue and reputation. The career
## screen behind this button says all of it and says it better. A title screen that
## reports your standing before you have asked is the save-game manager problem again.
##
## The score bug goes away with this screen. It is a broadcast graphic for a match in
## progress, and leaving it up over the title read as though a game were already running.
func show_main_menu(career: Career) -> void:
	_arrive(AT_MAIN)
	if _hud != null:
		_hud.visible = false
	for child in _main_menu_column.get_children():
		child.queue_free()

	# The shade behind this screen is dark top and bottom and clear through the middle,
	# where the hall is. Pushing from both ends keeps the type in the dark and leaves the
	# court visible between the logo and the buttons.
	_main_menu_column.add_child(_stretch())

	# --- the title.
	var title := VBoxContainer.new()
	title.add_theme_constant_override("separation", 6)
	_main_menu_column.add_child(_centred(title))
	var logo := TextureRect.new()
	logo.name = "TitleLogo"
	logo.texture = load(TITLE_LOGO)
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT
	logo.custom_minimum_size = Vector2(640, 100)
	title.add_child(logo)
	var tagline := _make_label(
		"You are the umpire. The game knows the truth. You do not have to tell it.",
		UiTheme.SMALL, UiTheme.MUTED)
	tagline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_child(tagline)

	_main_menu_column.add_child(_stretch())

	# --- the five things you can do, in the order you are likely to want them.
	#
	# PLAY goes to WHICH SPORT?, which is what `play_requested` has always meant; the
	# screen it opens simply had nothing pointing at it until now.
	var stack := VBoxContainer.new()
	stack.name = "TitleButtons"
	stack.add_theme_constant_override("separation", 12)
	_main_menu_column.add_child(_centred(stack))

	var play := _title_button("PLAY", func() -> void:
		_main_menu.visible = false
		play_requested.emit())
	# The one gold button on the screen, the same way REFEREE THIS MATCH is the one gold
	# button on the career screen: whatever else is offered, this is the way in.
	play.add_theme_color_override("font_color", UiTheme.INK)
	play.add_theme_color_override("font_hover_color", UiTheme.INK)
	play.add_theme_color_override("font_focus_color", UiTheme.INK)
	var gold := UiTheme.slant(UiTheme.ACCENT)
	gold.content_margin_top = 14
	gold.content_margin_bottom = 14
	play.add_theme_stylebox_override("normal", gold)
	var lit := UiTheme.slant(UiTheme.ACCENT.lightened(0.25))
	lit.content_margin_top = 14
	lit.content_margin_bottom = 14
	for state in ["hover", "focus", "pressed"]:
		play.add_theme_stylebox_override(state, lit)
	stack.add_child(play)

	# CAREER has to put this screen away itself. PLAY and HOW TO REFEREE are answered by
	# handlers that call `hide_menus()`, but `_on_career_screen_requested()` only raises
	# the career panel — the old career tile hid the menu for exactly this reason.
	stack.add_child(_title_button("CAREER", func() -> void:
		_main_menu.visible = false
		career_screen_requested.emit()))
	stack.add_child(_title_button("HOW TO REFEREE", func() -> void:
		teaching_requested.emit()))
	stack.add_child(_title_button("SETTINGS", func() -> void:
		settings_requested.emit()))
	stack.add_child(_title_button("QUIT", func() -> void:
		quit_requested.emit()))

	_main_menu_column.add_child(_stretch())

	_main_menu.visible = true
	_focus_first(_main_menu)


## One button on the title screen. Wider than a footer button and all of them the same
## width, because a stack of buttons that each fit their own word reads as a list of
## different things rather than one menu.
func _title_button(text: String, on_press: Callable) -> Button:
	var button := Button.new()
	button.name = "Title_%s" % text.replace(" ", "")
	button.text = text
	button.custom_minimum_size = Vector2(TITLE_BUTTON_WIDTH, UiTheme.BUTTON_HEIGHT)
	button.pressed.connect(on_press)
	return button


## Empty space that takes whatever is left over.
func _stretch() -> Control:
	var space := Control.new()
	space.size_flags_vertical = Control.SIZE_EXPAND_FILL
	space.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return space


# --- choosing a sport -----------------------------------------------------------

## The row of sports. One card each: a picture, and the name under it.
##
## Every sport in SPORTS gets a card. One marked not ready is drawn dim with COMING SOON
## under its name and cannot be pressed.
func _build_sport_menu() -> void:
	var built := _build_sheet("SportMenu", Color(0.03, 0.04, 0.06, 0.55))
	_sport_menu = built[0]
	var column: VBoxContainer = built[1]
	column.custom_minimum_size = Vector2(0, 0)

	column.add_child(_make_label("WHICH SPORT?", TITLE_SIZE, UiTheme.CHALK))
	column.add_child(_gap(6))
	column.add_child(_make_label(
		"Six sports. One name to keep across all of them.",
		PROMPT_SIZE, UiTheme.MUTED
	))
	column.add_child(_gap(22))

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	column.add_child(row)
	for sport in SPORTS:
		row.add_child(_sport_card(sport))

	column.add_child(_gap(22))
	column.add_child(_menu_footer(AT_SPORTS))


# --- one a side or two ----------------------------------------------------------

## Asked only for the two sports that have both, and asked rather than assumed.
##
## Singles and doubles are not the same game with fewer people in it. The court is a
## different width — badminton's singles sidelines are 42 cm inside the doubles ones, and
## a shuttle landing between them is in for one game and out for the other. The service
## court is a different length. And in badminton the serving order changes completely:
## in doubles the side keeps the serve and the two of them alternate courts, in singles
## the server's own score decides which box they serve from.
##
## So the referee's job is different, and being asked which job it is belongs at the
## front of the game rather than in a settings screen somewhere.
func _build_format_menu() -> void:
	var built := _build_sheet("FormatMenu", Color(0.03, 0.04, 0.06, 0.55))
	_format_menu = built[0]
	_format_column = built[1]


## `sport` names the game so the question reads as a question about that sport.
func show_format_menu(sport: StringName) -> void:
	_format_sport = sport
	_arrive(AT_FORMAT)
	for child in _format_column.get_children():
		child.queue_free()
	if _hud != null:
		_hud.visible = false
	hide_sport_menu()

	_format_column.add_child(_make_label(
		"%s" % Career.name_of(sport).to_upper(), TITLE_SIZE, UiTheme.CHALK))
	_format_column.add_child(_gap(6))
	_format_column.add_child(_make_label(
		"Three a side or two? They are different jobs." if sport == Career.TAKRAW
			else "One a side or two? They are different jobs.", PROMPT_SIZE, UiTheme.MUTED))
	_format_column.add_child(_gap(20))

	var singles := "the narrow court, and the server's score says which box"
	var doubles := "the full width, and a serving order to keep track of"
	var first_word := "SINGLES"
	if sport == Career.TENNIS:
		singles = "the narrow court — the tramlines are out"
		doubles = "the tramlines are live, except on the serve"
	elif sport == Career.TAKRAW:
		# Sepak takraw's "one a side" does not exist. Its two formats are regu, three a side
		# with a tekong serving from a circle, and doubles, served from behind the back line.
		first_word = "REGU"
		singles = "three a side — the tekong's foot in the circle, two at the net"
		doubles = "two a side — served from behind the back line, partners take turns"

	_format_column.add_child(_centred(_make_wide_button(first_word, func() -> void:
		format_chosen.emit(false))))
	_format_column.add_child(_make_label(singles, PROMPT_SIZE - 2, UiTheme.MUTED))
	_format_column.add_child(_gap(10))
	_format_column.add_child(_centred(_make_wide_button("DOUBLES", func() -> void:
		format_chosen.emit(true))))
	_format_column.add_child(_make_label(doubles, PROMPT_SIZE - 2, UiTheme.MUTED))

	_format_column.add_child(_gap(20))
	_format_column.add_child(_menu_footer(AT_FORMAT))
	_format_menu.visible = true
	_focus_first(_format_menu)


func hide_format_menu() -> void:
	if _format_menu != null:
		_format_menu.visible = false


## One sport: its name on a band of the sport's colour across the top, the athlete under
## it. `yours` marks the sport the career is in, with a gold tag on the band.
func _sport_card(sport: Dictionary, yours := false) -> Button:
	var ready: bool = sport["ready"]
	var card := Button.new()
	card.name = "Sport_%s" % sport["id"]
	card.custom_minimum_size = CARD
	card.disabled = not ready
	card.tooltip_text = "" if ready else "Not built yet"
	if ready:
		card.pressed.connect(func() -> void:
			_main_menu.visible = false
			sport_chosen.emit(sport["id"]))

	var face := StyleBoxFlat.new()
	face.bg_color = Color(0.110, 0.118, 0.141, 0.96)
	face.set_content_margin_all(0)
	if yours:
		face.set_border_width_all(4)
		face.border_color = UiTheme.ACCENT.darkened(0.3)
	card.add_theme_stylebox_override("normal", face)
	card.add_theme_stylebox_override("disabled", face)
	var lit := face.duplicate()
	lit.set_border_width_all(6)
	lit.border_color = UiTheme.ACCENT
	card.add_theme_stylebox_override("hover", lit)
	card.add_theme_stylebox_override("focus", lit)
	card.add_theme_stylebox_override("pressed", lit)

	var stack := VBoxContainer.new()
	stack.set_anchors_preset(Control.PRESET_FULL_RECT)
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_theme_constant_override("separation", 0)
	card.add_child(stack)

	var band := PanelContainer.new()
	band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var colour: Color = sport["band"]
	band.add_theme_stylebox_override("panel", UiTheme.block(colour if ready else colour.darkened(0.55)))
	stack.add_child(band)
	var name_row := HBoxContainer.new()
	name_row.alignment = BoxContainer.ALIGNMENT_CENTER
	name_row.add_theme_constant_override("separation", 10)
	name_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	band.add_child(name_row)
	# Two names are too long for a card six can fit across a 1280 window, and a name cut to
	# "SEPAK TAKR..." is worse than a name a size smaller.
	var letters := String(sport["name"]).length()
	var name_size := UiTheme.BODY if letters <= 11 else (UiTheme.SMALL - 2 if letters <= 13 else UiTheme.SMALL - 7)
	var caption := UiTheme.label(String(sport["name"]).to_upper(), name_size,
		Color.WHITE if ready else UiTheme.MUTED, UiTheme.heavy())
	# Every band the same height whatever size its name is set in.
	caption.custom_minimum_size.y = UiTheme.BODY * 1.75
	caption.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caption.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	caption.clip_text = true
	caption.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_row.add_child(caption)

	var picture := TextureRect.new()
	picture.size_flags_vertical = Control.SIZE_EXPAND_FILL
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	# Fitted inside the tile rather than filling it. One card builds both screens, and the
	# two are different shapes: the sport menu's is the tall CARD, the title screen's is
	# whatever is left of the row after everything above it, which is short and wide. A
	# picture that FILLS a short tile is cropped top and bottom, and an action poster
	# cannot afford that — it took the badminton player's feet off and the takraw player's
	# head, he being upside down. Fitting costs a margin at the sides on the title screen,
	# and on the sport menu costs almost nothing, the poster being within 3% of the card's
	# own shape. The margin is invisible either way: the posters are drawn on the same flat
	# charcoal the tile behind them is painted.
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	picture.texture = _portrait(sport)
	if not ready:
		picture.modulate = Color(1.0, 1.0, 1.0, 0.34)
	picture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	stack.add_child(picture)

	if yours:
		var tag := PanelContainer.new()
		tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var skin := UiTheme.slant(UiTheme.ACCENT)
		skin.content_margin_top = 2
		skin.content_margin_bottom = 2
		skin.content_margin_left = 14
		skin.content_margin_right = 14
		tag.add_theme_stylebox_override("panel", skin)
		tag.add_child(UiTheme.label("YOUR CAREER", UiTheme.SMALL - 4, UiTheme.INK, UiTheme.heavy()))
		tag.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
		tag.grow_horizontal = Control.GROW_DIRECTION_BEGIN
		tag.grow_vertical = Control.GROW_DIRECTION_BEGIN
		tag.offset_right = -12
		tag.offset_bottom = -12
		card.add_child(tag)

	if not ready:
		stack.add_child(UiTheme.label("COMING SOON", UiTheme.SMALL, UiTheme.MUTED, UiTheme.heavy()))
	return card


## The part of a sport's portrait a tile shows. Falls back to the render if the portrait
## is missing, so a checkout without the art still has a picture on every tile.
func _portrait(sport: Dictionary) -> Texture2D:
	var path: String = sport.get("portrait", "")
	if path.is_empty() or not ResourceLoader.exists(path):
		return load(sport["art"]) if ResourceLoader.exists(sport["art"]) else null
	var whole: Texture2D = load(path)
	if PORTRAIT_TALL <= 0.0:
		return whole
	var crop := AtlasTexture.new()
	crop.atlas = whole
	crop.region = Rect2(0.0, PORTRAIT_TOP, whole.get_width(),
		minf(PORTRAIT_TALL, whole.get_height() - PORTRAIT_TOP))
	return crop


func show_sport_menu() -> void:
	_arrive(AT_SPORTS)
	if _hud != null:
		_hud.visible = false
	_sport_menu.visible = true
	_focus_first(_sport_menu)


func hide_sport_menu() -> void:
	_sport_menu.visible = false
	_release_focus()


# --- the review ------------------------------------------------------------------

## The Hawk-Eye panel: the one place the game shows the player what really happened.
##
## Everything else here is built on never telling them. The rule is stated at the top of
## this file and it holds — but a review is not the game confessing, it is the hall
## finding out, and the umpire is simply in the room when it does. That is the whole
## point of the feature: the truth arriving in public, at a size nobody can argue with,
## whether or not the umpire wanted it.
var _review: Control
var _review_headline: Label
var _review_note: Label
var _review_view: TextureRect
var _review_verdict: Label
var _review_hint: Label
var _review_bar: PanelContainer


func _build_review() -> void:
	var built := _build_sheet("Review", Color(0.02, 0.03, 0.05, 0.66))
	_review = built[0]
	var column: VBoxContainer = built[1]

	# Laid out the way the BWF and FIVB review graphics are: a strip saying what this is,
	# the picture, and the answer in a big white bar at the bottom in heavy black type.
	var strip := HBoxContainer.new()
	strip.alignment = BoxContainer.ALIGNMENT_CENTER
	strip.add_theme_constant_override("separation", 0)
	column.add_child(strip)
	var tag := PanelContainer.new()
	tag.add_theme_stylebox_override("panel", UiTheme.slant(UiTheme.ACCENT))
	tag.add_child(UiTheme.label("OFFICIAL REVIEW", UiTheme.HEADING, UiTheme.INK, UiTheme.display()))
	strip.add_child(tag)
	var who := PanelContainer.new()
	who.add_theme_stylebox_override("panel", UiTheme.slant(UiTheme.INK))
	_review_headline = UiTheme.label("", UiTheme.HEADING, UiTheme.CHALK, UiTheme.heavy())
	who.add_child(_review_headline)
	strip.add_child(who)
	_review_note = _make_label("", UiTheme.SMALL, UiTheme.MUTED)
	column.add_child(_review_note)
	column.add_child(_gap(8))

	_review_view = TextureRect.new()
	_review_view.custom_minimum_size = Vector2(400, 400)
	_review_view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_review_view.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	column.add_child(_centred(_review_view))

	column.add_child(_gap(8))
	_review_bar = PanelContainer.new()
	var bar := UiTheme.block(UiTheme.PAPER)
	bar.content_margin_top = 4
	bar.content_margin_bottom = 4
	_review_bar.add_theme_stylebox_override("panel", bar)
	_review_verdict = UiTheme.label("", UiTheme.HUGE - 8, UiTheme.INK, UiTheme.display())
	_review_bar.add_child(_review_verdict)
	column.add_child(_review_bar)

	# Only filled once the answer is up. Before that there is nothing to wave on.
	_review_hint = _make_label("", UiTheme.SMALL, UiTheme.MUTED)
	column.add_child(_review_hint)


## Opens the review. The verdict is deliberately not filled in yet — the pause between
## the challenge and the answer is the whole of the drama, and an umpire who has just
## lied should have to sit through it.
func show_review(team: Sides.Team, reviews_left: int, view: Texture2D) -> void:
	_review_headline.text = "CHALLENGED BY %s" % Sides.label(team)
	_review_headline.get_parent().add_theme_stylebox_override("panel", UiTheme.slant(Sides.colour(team)))
	_review_note.text = "%s has %d review%s left" % [
		Sides.label(team), reviews_left, "" if reviews_left == 1 else "s"]
	_review_view.texture = view
	_review_verdict.text = "REVIEWING\u2026"
	_review_verdict.add_theme_color_override("font_color", UiTheme.MUTED.darkened(0.3))
	_review_bar.add_theme_stylebox_override("panel", _verdict_bar(UiTheme.PAPER))
	_review_hint.text = ""
	_review.visible = true


## The line under the verdict telling the official they may wave it on. Set only once
## the answer is up: the wait before that is the whole point of a review.
func set_review_hint(text: String) -> void:
	_review_hint.text = text


func set_review_verdict(text: String, tint: Color) -> void:
	_review_verdict.text = text.to_upper()
	# The answer in black on white, with the colour it was given as the bar's edge — the
	# broadcast puts the verdict on a plain bar so it can be read from the back of a hall.
	_review_verdict.add_theme_color_override("font_color", UiTheme.INK)
	var bar := _verdict_bar(UiTheme.PAPER)
	bar.border_width_left = 14
	bar.border_width_right = 14
	bar.border_color = tint
	_review_bar.add_theme_stylebox_override("panel", bar)


func _verdict_bar(fill: Color) -> StyleBoxFlat:
	var bar := UiTheme.block(fill)
	bar.content_margin_top = 4
	bar.content_margin_bottom = 4
	return bar


func hide_review() -> void:
	if _review != null:
		_review.visible = false


# --- teaching -------------------------------------------------------------------

## What the game never told anybody.
##
## Everything this game asks of you is invisible unless somebody says it out loud. It
## wants you to spot a carry, which is a hesitation in a stroke lasting a fifth of a
## second; it wants you to know that a shuttle failing to cross the net is called OUT
## however far inside the lines it lands; and it wants all of that from a player who may
## never have watched a badminton match, let alone refereed one.
##
## Until this screen existed the entire instruction was a single line of key bindings.
## Luqman could not tell whether the game was scoring him unfairly or whether he was
## simply missing things — and it turned out to be both, which is exactly the confusion
## that not explaining yourself produces.
const BADMINTON_LESSONS := [
	{
		"title": "THE JOB",
		"body": "You are the umpire, and you never leave the chair.\n\n"
			+ "The game plays a real rally and records exactly where the shuttle came "
			+ "down, to the millimetre. Nobody else in the building will say what "
			+ "happened. You will.\n\n"
			+ "You can tell the truth. Nothing here requires you to.",
		"keys": [
			["SPACE", "call the score and play"],
			["LEFT CLICK", "in"],
			["RIGHT CLICK", "out"],
			["L", "let — play it again"],
			["W", "service court error"],
			["F", "a fault, or a card"],
			["ESC", "pause"],
		],
	},
	{
		"title": "IN AND OUT",
		"art": "res://assets/ui/court_map.png",
		"body": "Green is the court. A shuttle landing anywhere on it is IN — including "
			+ "on a line, because the lines belong to the court. Red is outside it.\n\n"
			+ "The narrow strips down each side are in play too. This is doubles.\n\n"
			+ "And the one that catches people out: a shuttle that never gets over the "
			+ "net is a fault against whoever hit it. Call OUT — however far inside the "
			+ "lines it landed.",
	},
	{
		"title": "THE FAULTS",
		"body": "Press F, then point at whoever did it.\n\n"
			+ "NET TOUCH   the net shakes. Somebody was touching it with the shuttle "
			+ "still live.\n\n"
			+ "CARRY   the shuttle hesitates on the racket instead of leaving it "
			+ "cleanly. Easy to miss. That is the point of it.\n\n"
			+ "DOUBLE HIT   the same side strikes it twice in a row.\n\n"
			+ "OBSTRUCTION   a player reaches over the net.\n\n"
			+ "Missing one is not free. If the point then goes to the side that cheated, "
			+ "the hall saw what you did not.",
	},
	{
		"title": "THE SERVE",
		"body": "A serve is the one moment in badminton when everything stops. Both "
			+ "players are still, nobody is scrambling, and the whole hall is watching "
			+ "one person do one thing slowly. Three things can be wrong with it, and "
			+ "all three are on the F panel.\n\n"
			+ "ABOVE 1.15   the whole shuttle must be below 1.15 metres when it is "
			+ "struck. Not the server's waist — a fixed height, measured, since 2018. A "
			+ "waist is an argument; a number is a fact.\n\n"
			+ "RACKET UP   the shaft must be pointing downwards at the moment of "
			+ "contact. If the head is up, it is a fault however good the serve was.\n\n"
			+ "FOOT MOVED   both feet stay still, and on the floor, from the start of "
			+ "the service until it is delivered.\n\n"
			+ "A real match gives these their own official, sitting at the side of the "
			+ "court with nothing else to look at. You do not get one. But you also have "
			+ "nowhere to hide: everybody was watching the same thing you were, which "
			+ "makes a service fault you invent the least deniable call in the sport.",
	},
	{
		"title": "THE SERVICE COURTS",
		"body": "Before every serve, look at where the four of them are standing.\n\n"
			+ "The server's own score decides which box they serve from. An EVEN score "
			+ "— nought, two, four — and they serve from their RIGHT-hand court. An ODD "
			+ "score, and they serve from their LEFT. The receiver stands diagonally "
			+ "opposite them, and the two partners keep out of it.\n\n"
			+ "The quick way to see it from the chair: server and receiver should be "
			+ "DIAGONAL — one of them near you, one of them away from you. If the two of "
			+ "them are level with each other, somebody is in the wrong box, and the "
			+ "server's score tells you which.\n\n"
			+ "When somebody gets that wrong, press W.\n\n"
			+ "Say it before you call play and the serve is simply taken again. Say it "
			+ "after the rally and it is too late to undo anything: the error is "
			+ "corrected and the score stands, exactly as the law has it.\n\n"
			+ "This one cannot win anybody a point, which makes it the only call here "
			+ "you have nothing to gain by lying about — and the only one whose answer "
			+ "was in front of you the whole time, if you were looking.",
	},
	{
		"title": "WHO IS WATCHING",
		"body": "Two line judges sit at opposite corners. They call their own lines, and "
			+ "on the close ones they are wrong about as often as a coin. Agree with a "
			+ "mistake and it is shared with an official in plain sight. Overrule them "
			+ "and the hall has just watched two officials disagree, with only your call "
			+ "left standing.\n\n"
			+ "The shuttle cam shows you the landing from directly overhead once it is "
			+ "down.\n\n"
			+ "At the bigger tournaments the players can challenge you. Each side gets "
			+ "two reviews a game, and a successful one is handed back. The hall watches "
			+ "the landing on a screen and then everybody knows — including about the "
			+ "close ones you were relying on nobody being sure about. Being caught that "
			+ "way costs far more than the same call going unchallenged.",
	},
	{
		"title": "YOUR NAME",
		"body": "Nothing in this game counts your mistakes for you. What you get while "
			+ "you referee is the room — how it sounds, and whether it comes out of its "
			+ "seat — and one number, which is this one.\n\n"
			+ "REPUTATION is your name, out of a hundred, and it follows you from match "
			+ "to match and from sport to sport. It is the only thing here that outlives "
			+ "the match it happened in.\n\n"
			+ "The bar appears at the bottom of the screen ONLY WHEN IT MOVES, for about "
			+ "three seconds, and then it is gone. So it is never something to stare at. "
			+ "It catches your eye at the moment a call has just cost you something, "
			+ "which is the only moment worth knowing about.\n\n"
			+ "It falls when you are wrong, and it creeps back up when you referee "
			+ "cleanly. It does not tell you whether anybody BELIEVED a particular call "
			+ "— nothing will ever tell you that. It tells you what the night has cost "
			+ "you so far.\n\n"
			+ "A quiet match repairs a little of it. A match with three invented cards in it does not.\n\n"
			+ "Run it down to nothing and nobody will appoint you again.",
	},
]


## Beach volleyball's own lesson.
##
## It needs one for the same reason badminton did, and more urgently: this sport's
## signature call is a thing nobody can see, made with a key nobody would guess. A
## player who picks beach volleyball and is never told what TOUCH means is being asked
## to judge the one call the whole design rests on with no idea it exists — which is
## exactly the shape of the bug that made fair play feel unfair before.
const BEACH_LESSONS := [
	{
		"title": "THE JOB",
		"body": "You are the first referee, up on the stand beside the net.\n\n"
			+ "Two a side, on sand, in the open air. The game plays a real rally and "
			+ "records exactly where the ball came down, to the millimetre. Nobody else "
			+ "here will say what happened. You will.\n\n"
			+ "You can tell the truth. Nothing here requires you to.",
		"keys": [
			["SPACE", "whistle the serve"],
			["LEFT CLICK", "in"],
			["RIGHT CLICK", "out"],
			["T", "touched — see page three"],
			["F", "a fault"],
			["ESC", "pause"],
		],
	},
	{
		"title": "IN AND OUT",
		"body": "The court is sixteen metres by eight, and the tape lying on the sand "
			+ "is part of it. A ball touching any part of a line is IN.\n\n"
			+ "There are no service courts. A serve may land anywhere in the other "
			+ "half, so there is nothing to remember about who serves from where.\n\n"
			+ "The sand outside the lines is still in play. A player may chase a ball "
			+ "five metres past the tape and put it back, and the rally goes on — being "
			+ "outside the court is only the ball's problem, never the player's.",
	},
	{
		"title": "THE TOUCH",
		"body": "This is the call this sport is about, and it is worth reading twice.\n\n"
			+ "The ball is attacked, it flies out past the block, and it lands well "
			+ "outside the court. Everybody saw that. What nobody saw is whether it "
			+ "grazed a blocker's fingers on the way.\n\n"
			+ "If it did, the blockers touched it last, so going out is their mistake: "
			+ "press T for TOUCH and the point goes to the attackers. If it did not, "
			+ "the attackers hit it out: call OUT and the point goes to the blockers.\n\n"
			+ "The same ball, the same landing, and two opposite points — decided by "
			+ "you. Nobody in this venue is in any position to argue, which cuts both "
			+ "ways: it is the easiest call in the game to get away with, and the one "
			+ "that costs the most when a slow-motion camera disagrees with you.",
	},
	{
		"title": "FAULTS, AND WHO IS WATCHING",
		"body": "Press F, then point at whoever did it.\n\n"
			+ "OUTSIDE THE ANTENNA   the ball crossed the net outside one of the two "
			+ "rods standing on the tape. It is out however cleanly it then lands, and "
			+ "it is the only boundary in this sport that is vertical — so it is the "
			+ "only one that leaves nothing in the sand to walk over and argue about "
			+ "afterwards. You are level with the rod. Nobody else is.\n"
			+ "NET TOUCH   somebody touched the net while the ball was live.\n"
			+ "CENTRE LINE   a foot went fully under the net into the other court.\n"
			+ "FOUR HITS   one side touched it four times. Three is the limit.\n"
			+ "DOUBLE and LIFT   the set came off two hands unevenly, or rested in them "
			+ "a moment too long. Judged far more tightly here than indoors, and two "
			+ "honest referees genuinely disagree about it.\n"
			+ "FOOT FAULT   the server stood on or over the end line.\n\n"
			+ "When the ball comes down you get an overhead view of it against the tape, "
			+ "in the corner of the screen. Use it. It is the only thing in this sport "
			+ "that will ever tell you something you could not see from the stand.\n\n"
			+ "From the world tour up, both sides carry two challenges a set. They can "
			+ "put your line calls and your touches on a screen, and a successful one is "
			+ "handed back — so a pair with one left is still dangerous.",
	},
	{
		"title": "YOUR NAME",
		"body": "Nothing in this game counts your mistakes for you. What you get while "
			+ "you referee is the room — how it sounds, and whether it comes out of its "
			+ "seat — and one number, which is this one.\n\n"
			+ "REPUTATION is your name, out of a hundred, and it follows you from match "
			+ "to match and from sport to sport. It is the only thing here that outlives "
			+ "the match it happened in.\n\n"
			+ "The bar appears at the bottom of the screen ONLY WHEN IT MOVES, for about "
			+ "three seconds, and then it is gone. So it is never something to stare at. "
			+ "It catches your eye at the moment a call has just cost you something, "
			+ "which is the only moment worth knowing about.\n\n"
			+ "It falls when you are wrong, and it creeps back up when you referee "
			+ "cleanly. It does not tell you whether anybody BELIEVED a particular call "
			+ "— nothing will ever tell you that. It tells you what the night has cost "
			+ "you so far.\n\n"
			+ "Denying a touch nobody could see is the cheapest thing you can do here. It is still not free, and it adds up.\n\n"
			+ "Run it down to nothing and nobody will appoint you again.",
	},
]

## Indoor volleyball's lesson, and the longest of the three, because this is the only
## sport in the game that asks the referee to know something before the ball is served.
const INDOOR_LESSONS := [
	{
		"title": "THE JOB",
		"body": "You are the first referee, on the stand beside the net.\n\n"
			+ "Six a side, indoors. Everything beach volleyball asks of you it asks of "
			+ "you here too — where the ball landed, whether a block touched it, whether "
			+ "a set was clean.\n\n"
			+ "And one thing more, which is the reason this is the hardest chair in the "
			+ "game to sit in.",
		"keys": [
			["SPACE", "whistle the serve"],
			["LEFT CLICK", "in"],
			["RIGHT CLICK", "out"],
			["T", "touched"],
			["F", "a fault, including the rotation"],
			["ESC", "pause"],
		],
	},
	{
		"title": "THE ROTATION",
		"body": "Six players stand in six positions, numbered the way the sport numbers "
			+ "them — anticlockwise from the server's corner:\n\n"
			+ "        4    3    2      the front row, nearest the net\n"
			+ "        5    6    1      the back row; 1 serves\n\n"
			+ "Whoever is in position 1 serves. When a side wins the serve back, all six "
			+ "move one place clockwise, so 2 goes to 1 and everybody follows. A side "
			+ "that keeps serving does NOT rotate — that is the part most people get "
			+ "wrong.\n\n"
			+ "At the moment the serve is struck, each front-row player must be nearer "
			+ "the net than the back-row player behind them, and within each row they "
			+ "must be in left, centre, right order across the court. After the ball is "
			+ "struck they may go anywhere.\n\n"
			+ "Get this wrong and it is OUT OF ROTATION, or WRONG SERVER if the ball was "
			+ "hit by somebody who was not in position 1.",
	},
	{
		"title": "WHAT THAT MEANS FOR YOU",
		"body": "Every other call in this game is about something you can see happening. "
			+ "This one is about something you had to be watching for twenty seconds "
			+ "before it mattered.\n\n"
			+ "So it cuts both ways. If you were paying attention, a rotation fault is "
			+ "the most certain call in the sport — six people were in their order or "
			+ "they were not, and both benches know which.\n\n"
			+ "Which is exactly why inventing one is the least deniable thing you can "
			+ "do. There is no close call to hide behind. A lineup is written down.\n\n"
			+ "BACK ROW ATTACK is the same rule in the air: a back-row player may hit "
			+ "the ball down from above the net, but only if they took off from behind "
			+ "the attack line, three metres back. In front of it, it is a fault — and "
			+ "unlike the rest of this, everybody in the hall is looking at it.",
	},
	{
		"title": "THE LIBERO",
		"body": "One player on each side wears a different shirt. That is not decoration "
			+ "— it is so that you can pick them out without thinking, because there are "
			+ "three things they alone may not do.\n\n"
			+ "They may not attack the ball above the net.\n"
			+ "They may not serve.\n"
			+ "They may not set the ball overhand from in front of the attack line for "
			+ "somebody else to attack.\n\n"
			+ "They also never leave the back court. If the rotation would carry them to "
			+ "the front row they come off, and somebody else comes on.\n\n"
			+ "Press F and point at them for LIBERO.",
	},
	{
		"title": "FAULTS, AND WHO IS WATCHING",
		"body": "Press F, then point at whoever did it.\n\n"
			+ "NET TOUCH, CENTRE LINE, FOUR HITS, DOUBLE, LIFT and FOOT FAULT are the "
			+ "same as they are on the sand, and so is OUTSIDE THE ANTENNA — the ball "
			+ "crossing the net outside one of the rods, which is out however cleanly it "
			+ "lands and leaves no mark on the floor for anybody to check.\n\n"
			+ "When the ball lands you get an overhead view of it against the line. That "
			+ "settles where it came down; nothing settles where six people were "
			+ "standing except you.\n\n"
			+ "From the champions cup up, both sides carry challenges. They can put your "
			+ "line calls and your touches on a screen — but NOT your rotation calls. A "
			+ "camera looks at the ball. Where six people were standing is settled by "
			+ "the scoresheet, which means a rotation call is your word and stays your "
			+ "word.",
	},
	{
		"title": "YOUR NAME",
		"body": "Nothing in this game counts your mistakes for you. What you get while "
			+ "you referee is the room — how it sounds, and whether it comes out of its "
			+ "seat — and one number, which is this one.\n\n"
			+ "REPUTATION is your name, out of a hundred, and it follows you from match "
			+ "to match and from sport to sport. It is the only thing here that outlives "
			+ "the match it happened in.\n\n"
			+ "The bar appears at the bottom of the screen ONLY WHEN IT MOVES, for about "
			+ "three seconds, and then it is gone. So it is never something to stare at. "
			+ "It catches your eye at the moment a call has just cost you something, "
			+ "which is the only moment worth knowing about.\n\n"
			+ "It falls when you are wrong, and it creeps back up when you referee "
			+ "cleanly. It does not tell you whether anybody BELIEVED a particular call "
			+ "— nothing will ever tell you that. It tells you what the night has cost "
			+ "you so far.\n\n"
			+ "A rotation you invented costs more of it than any line call ever will, because a lineup is written down.\n\n"
			+ "Run it down to nothing and nobody will appoint you again.",
	},
]


## Sepak takraw's lesson. The job it teaches that no other sport has is the serve: the feet in
## the circles, judged before the ball has even been kicked.
const TAKRAW_LESSONS := [
	{
		"title": "THE JOB",
		"body": "You are the referee, on the tall chair beside the net.\n\n"
			+ "Sepak takraw is played with the feet, the knees, the chest and the head. Three "
			+ "a side in regu, two in doubles, up to three touches a side, and the attack is a "
			+ "bicycle kick over a net lower than a badminton net.\n\n"
			+ "There is no whistle in this sport. You call the score out loud, and the serving "
			+ "side may not throw the ball until you have.",
		"keys": [
			["SPACE", "call the score"],
			["LEFT CLICK", "in"],
			["RIGHT CLICK", "out"],
			["T", "touched the block"],
			["F", "a fault"],
			["ESC", "pause"],
		],
	},
	{
		"title": "THE SERVE",
		"body": "In regu, look DOWN before you look at the ball.\n\n"
			+ "The tekong, the server, stands at the back with the standing foot in the "
			+ "SERVICE CIRCLE. It must stay inside the circle and on the floor until the other "
			+ "foot kicks the ball.\n\n"
			+ "The two inside players stand at the net, each in a QUARTER CIRCLE. One of them "
			+ "throws the ball to the tekong. While it is thrown, neither may lift a foot or "
			+ "step on their line.\n\n"
			+ "A foot out of its circle is SERVICE FAULT for the tekong and INSIDE FAULT for "
			+ "the inside players. The receiving side may stand anywhere.\n\n"
			+ "In doubles there are no circles: the server throws to himself from behind the "
			+ "back line and must not touch it, and the partner must keep still with their arms "
			+ "down.",
	},
	{
		"title": "FAULTS",
		"body": "Press F, then say who did it.\n\n"
			+ "ARM — the ball touched an arm or a hand, anywhere from the shoulder down. Their "
			+ "arms are out for balance on every kick, so look for the ball changing direction.\n"
			+ "NET — any part of a player touched the net, a post or your chair.\n"
			+ "CROSSING — a player's body went into the other court, over or under the net. "
			+ "Following through after a kick is allowed; landing over there is not.\n"
			+ "FOUR TOUCHES — one side played it more than three times. One player may take "
			+ "all three.\n\n"
			+ "TOUCH is for a spike that goes out off a blocker's back or legs: their point "
			+ "lost, not the attacker's.",
	},
	{
		"title": "THE SCORE",
		"body": "Every rally is a point. A set is won at 15.\n\n"
			+ "At 14-14 you announce SETTING UP TO SEVENTEEN, and the first side to 17 wins. "
			+ "There is no two-point lead in this sport: 17-16 wins a set.\n\n"
			+ "The serve changes sides after EVERY point, whoever wins it. Best of three sets.\n\n"
			+ "From the takraw league up, the benches can challenge your line and service "
			+ "calls on video.",
	},
	{
		"title": "YOUR NAME",
		"body": "Nothing in this game counts your mistakes for you. What you get while you "
			+ "referee is the room — how it sounds, and whether it comes out of its seats — "
			+ "and one number, which is this one.\n\n"
			+ "REPUTATION is your name, out of a hundred, and it follows you from match to "
			+ "match and from sport to sport. It is the only thing here that outlives the "
			+ "match it happened in.\n\n"
			+ "The bar appears at the bottom of the screen ONLY WHEN IT MOVES, for about three "
			+ "seconds, and then it is gone. It catches your eye at the moment a call has just "
			+ "cost you something, which is the only moment worth knowing about. It falls when "
			+ "you are wrong and creeps back up when you referee cleanly.\n\n"
			+ "It does not tell you whether anybody BELIEVED a particular call — nothing will "
			+ "ever tell you that. It tells you what the night has cost you so far.\n\n"
			+ "A foot you invented out of a circle costs more than a close line call, because "
			+ "everybody in the hall can look at where the foot was.\n\n"
			+ "Run it down to nothing and nobody will appoint you again.",
	},
]


## Tennis's lesson, and the only one in the game that has to teach a *scoring system*
## before it can teach a call — because in this sport what a call costs depends entirely
## on what the score was when you made it.
const TENNIS_LESSONS := [
	{
		"title": "THE JOB",
		"body": "You are the chair umpire, at the net, on the high seat.\n\n"
			+ "Singles. The game plays a real point and records exactly where the ball "
			+ "came down, to the millimetre. There are line judges below you and they "
			+ "are often right.\n\n"
			+ "You are not asked about every ball. A serve down the middle of the box is "
			+ "played and nobody says a word. You are asked when there is a question — "
			+ "and when there is one, everybody in the place turns and looks at you.",
		"keys": [
			["SPACE", "call the players to play"],
			["LEFT CLICK", "in"],
			["RIGHT CLICK", "out, or a fault on a serve"],
			["L", "let — see page three"],
			["F", "a fault"],
			["ESC", "pause"],
		],
	},
	{
		"title": "THE SCORE, AND WHY IT MATTERS TO YOU",
		"body": "Points are called 15, 30, 40, and then the game. Three each is DEUCE, "
			+ "and from there somebody has to win two in a row. Six games win a set, by "
			+ "two; at six-all they play a tiebreak to seven.\n\n"
			+ "Read that again, because it is the whole reason this sport is in this "
			+ "game.\n\n"
			+ "**A point is not a point.** A wrong call at 40-0 costs somebody a point "
			+ "they were never going to miss. The same call at deuce in a tiebreak is "
			+ "the match, and the player, the crowd and you all know it while it is "
			+ "happening.\n\n"
			+ "Nothing in the game charges you extra for the second one. Everybody in "
			+ "the stadium does.",
	},
	{
		"title": "THE SERVE — AND THE FIRST AND SECOND",
		"body": "A point starts with a first serve. If it misses, the server gets a "
			+ "second. If that misses too it is a double fault and the point is gone.\n\n"
			+ "So the same call costs two completely different things:\n\n"
			+ "On a FIRST serve, calling a fault takes a serve away. No point changes "
			+ "hands. Nobody argues much.\n"
			+ "On a SECOND serve, calling a fault is the point.\n\n"
			+ "That gap is the most useful thing in this sport to a bent umpire, and the "
			+ "easiest thing to spot on a scoresheet afterwards. A careful one shades "
			+ "first serves all afternoon. A greedy one takes a second, once, and it is "
			+ "the only call anybody remembers.\n\n"
			+ "A serve must land in the box diagonally opposite the server, short of the "
			+ "service line and inside the SINGLES sideline — even in doubles. The "
			+ "tramlines are never part of a service box.",
	},
	{
		"title": "THE NET CORD",
		"body": "This is the call this sport is about, and it is decided by a sound.\n\n"
			+ "If a serve touches the top of the net on its way over and still lands in "
			+ "the box, it is a LET: nothing happened, and the serve is played again at "
			+ "the same number. If it touches and misses the box, it is simply a fault.\n\n"
			+ "Press L to call it.\n\n"
			+ "You are a metre from the tape. Nobody else in the building is. A ball that "
			+ "grazes the cord and carries on unchanged made a noise that you heard and "
			+ "they did not — which cuts both ways: it is the easiest call in tennis to "
			+ "invent, and denying a real one quietly takes a first serve off a man who "
			+ "was entitled to it again.\n\n"
			+ "Watch the net as well as listen. A cord that was really clipped shivers.",
	},
	{
		"title": "FAULTS, AND WHO IS WATCHING",
		"body": "Press F, then point at whoever did it.\n\n"
			+ "FOOT FAULT   the server's foot on or over the baseline at contact. You "
			+ "are looking down the length of that line from the chair, which is the "
			+ "worst angle in the sport for it.\n"
			+ "NOT UP   the ball bounced twice before they reached it.\n"
			+ "TOUCHED THE NET   a player or a racket touched the net while the ball was "
			+ "live. They lose the point whatever the ball then did.\n"
			+ "THROUGH THE NET   they played the ball before it had crossed to their "
			+ "side.\n\n"
			+ "The line judges below you call the lines they are responsible for. Agree "
			+ "with one who has just got it wrong and the mistake is shared with an "
			+ "official standing in plain sight. Contradict one and the court has "
			+ "watched two officials disagree in public, with only your call counting.\n\n"
			+ "From the tour main draw up, both players carry challenges, and a screen "
			+ "will draw your line calls to the millimetre in front of everybody.",
	},
	{
		"title": "YOUR NAME",
		"body": "Nothing in this game counts your mistakes for you. What you get while "
			+ "you referee is the room — how it sounds, and whether it comes out of its "
			+ "seat — and one number, which is this one.\n\n"
			+ "REPUTATION is your name, out of a hundred, and it follows you from match "
			+ "to match and from sport to sport. It is the only thing here that outlives "
			+ "the match it happened in.\n\n"
			+ "The bar appears at the bottom of the screen ONLY WHEN IT MOVES, for about "
			+ "three seconds, and then it is gone. So it is never something to stare at. "
			+ "It catches your eye at the moment a call has just cost you something, "
			+ "which is the only moment worth knowing about.\n\n"
			+ "It falls when you are wrong, and it creeps back up when you referee "
			+ "cleanly. It does not tell you whether anybody BELIEVED a particular call "
			+ "— nothing will ever tell you that. It tells you what the night has cost "
			+ "you so far.\n\n"
			+ "Shading a first serve is cheap, because it only costs a serve. Taking a second is not.\n\n"
			+ "Run it down to nothing and nobody will appoint you again.",
	},
]

var _lesson := 0
var _lessons: Array = BADMINTON_LESSONS

const TABLE_TENNIS_LESSONS := [
	{
		"title": "THE JOB",
		"body": "You are the umpire, in a chair beside the net, level with the top of "
			+ "the table.\n\n"
			+ "Singles, to eleven. The game plays a real point and records exactly where "
			+ "the ball came down, to the millimetre.\n\n"
			+ "There are no line judges. Not at this level, not at the World "
			+ "Championships, not anywhere — the table is 2.74 metres long and there is "
			+ "nowhere to put a second official that you cannot already see. Every truth "
			+ "in this match goes through you and nobody else. There is nobody to agree "
			+ "with, and nobody to blame.",
		"keys": [
			["SPACE", "call the score and start the point"],
			["LEFT CLICK", "in"],
			["RIGHT CLICK", "out, or a fault on a serve"],
			["L", "let — see page four"],
			["F", "a fault"],
			["ESC", "pause"],
		],
	},
	{
		"title": "THE SCORE, AND WHOSE SERVE IT IS",
		"body": "Games are to eleven, and you must win by two. From ten-all it goes on "
			+ "until somebody is two clear.\n\n"
			+ "The serve changes hands EVERY TWO POINTS. From ten-all it changes every "
			+ "single point.\n\n"
			+ "That second sentence is your job. Nobody else in the hall is keeping "
			+ "track of it — the players are playing, and the crowd is watching the ball "
			+ "— and everybody will notice the instant you get it wrong. You call the "
			+ "score out before every point, server's number first, and that call is the "
			+ "official record of it.\n\n"
			+ "Nothing in this game charges you for losing count. The hall does.",
	},
	{
		"title": "THE SERVE, AND THE STRICTEST LAW IN THIS GAME",
		"body": "There is no second serve. A serve that misses is the point, gone.\n\n"
			+ "The ball must sit on an open FLAT PALM, be thrown up at least 16 "
			+ "centimetres, and stay VISIBLE TO THE RECEIVER from the moment it leaves "
			+ "the hand until it is struck. Then it must bounce once on the server's own "
			+ "half and once on the receiver's.\n\n"
			+ "Press F and call ILLEGAL SERVICE.\n\n"
			+ "Look at who that law protects. The receiver cannot possibly see a serve "
			+ "hidden behind the server's own shoulder — that is what hiding it means. "
			+ "You are the only person in the building placed to check any of it, on "
			+ "every single point, for the whole match.\n\n"
			+ "Which is also to say: you are the only person who can quietly stop "
			+ "checking.",
	},
	{
		"title": "THE NET, AND THE EDGE",
		"body": "TWO calls, and they are what this sport is.\n\n"
			+ "THE NET. A serve that touches the net and still lands good is a LET and "
			+ "is played again. Press L. It costs nobody anything, which makes it the "
			+ "cheapest thing here to invent — and watch the net as well as listen, "
			+ "because a net that was really clipped shivers.\n\n"
			+ "THE EDGE. A ball that clips the TOP EDGE of the table is IN. A ball that "
			+ "clips the vertical SIDE, a centimetre lower, is OUT. Two centimetres "
			+ "apart. They sound almost the same. They happen at twenty metres a "
			+ "second.\n\n"
			+ "You are sitting level with the surface, which is the only place in the "
			+ "hall the difference between them can be seen from at all. Both players "
			+ "will be certain, and one of them will be wrong.",
	},
	{
		"title": "THE OTHER FAULTS",
		"body": "Press F, then point at whoever did it.\n\n"
			+ "TWO BOUNCES   the ball bounced twice on their half before they got to "
			+ "it.\n"
			+ "FREE HAND ON THE TABLE   the hand not holding the bat touched the "
			+ "playing surface while the ball was live. They lose the point whatever "
			+ "happened next.\n"
			+ "STRUCK IN THE AIR   they hit the ball before it had bounced on their "
			+ "side.\n\n"
			+ "All three happen at the table, a metre and a half from your chair, and "
			+ "all three are gone in a fifth of a second. Nobody is going to hand you a "
			+ "replay at the community centre.\n\n"
			+ "From the world tour up there is a match referee sitting two metres away "
			+ "who can come to the table, and at the Worlds there are eight cameras on a "
			+ "ball 40 millimetres across.",
	},
	{
		"title": "YOUR NAME",
		"body": "Nothing in this game counts your mistakes for you. What you get while "
			+ "you referee is the room — how it sounds, and whether it comes out of its "
			+ "seat — and one number, which is this one.\n\n"
			+ "REPUTATION is your name, out of a hundred, and it follows you from match "
			+ "to match and from sport to sport. It is the only thing here that outlives "
			+ "the match it happened in.\n\n"
			+ "The bar appears at the bottom of the screen ONLY WHEN IT MOVES, for about "
			+ "three seconds, and then it is gone. So it is never something to stare "
			+ "at.\n\n"
			+ "It falls when you are wrong, and it creeps back up when you referee "
			+ "cleanly. It does not tell you whether anybody BELIEVED a particular call "
			+ "— nothing will ever tell you that.\n\n"
			+ "In every other sport in this game you can hide a bad call behind a line "
			+ "judge who said the same thing. Here you cannot. Everything the hall "
			+ "believes about this match is something you told them.\n\n"
			+ "Run it down to nothing and nobody will appoint you again.",
	},
]

var _teaching: Control
var _lesson_buttons: HBoxContainer


## `sport` picks which lesson. The two sports share the screen and share nothing else
## about what they need explaining.
func show_teaching(sport := Career.BADMINTON) -> void:
	match sport:
		Career.BEACH: _lessons = BEACH_LESSONS
		Career.INDOOR: _lessons = INDOOR_LESSONS
		Career.TENNIS: _lessons = TENNIS_LESSONS
		Career.TABLE_TENNIS: _lessons = TABLE_TENNIS_LESSONS
		Career.TAKRAW: _lessons = TAKRAW_LESSONS
		_: _lessons = BADMINTON_LESSONS
	_arrive(AT_TEACHING)
	if _hud != null:
		_hud.visible = false
	_lesson = 0
	_draw_lesson()
	_teaching.visible = true
	_focus_first(_teaching)


func hide_teaching() -> void:
	if _teaching != null:
		_teaching.visible = false


func _draw_lesson() -> void:
	if _teaching != null:
		_teaching.queue_free()
	var built := _build_sheet("Teaching", Color(0.03, 0.04, 0.06, 0.66))
	_teaching = built[0]
	var column: VBoxContainer = built[1]

	# The page goes inside a scroll view rather than being trimmed to fit. Tuning the
	# picture and the type until it happened to fit a 900-pixel window worked twice and
	# broke twice, and it would break again on somebody else's screen — a page whose only
	# job is to be read must not be able to put its own title above the top edge.
	var card := column.get_parent()
	card.remove_child(column)

	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 12)
	card.add_child(stack)

	var scroller := ScrollContainer.new()
	scroller.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroller.custom_minimum_size = Vector2(
		720, minf(660.0, get_viewport().get_visible_rect().size.y * 0.66))
	stack.add_child(scroller)
	scroller.add_child(column)
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	# The buttons live outside the scroll view. Inside it, NEXT sat below the fold on the
	# longer pages and the reader had to scroll to find out there was a next page.
	_lesson_buttons = HBoxContainer.new()
	_lesson_buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	_lesson_buttons.add_theme_constant_override("separation", 14)
	stack.add_child(_lesson_buttons)
	# Sized to fit a 900-pixel-tall window with the buttons still on screen. The first
	# attempt ran off both ends of the display: the title was above the top edge and GOT
	# IT was below the bottom one, which on a page whose whole job is to be read is not a
	# small mistake.
	column.custom_minimum_size = Vector2(700, 0)

	var lesson: Dictionary = _lessons[_lesson]
	column.add_child(_make_label(lesson["title"], TITLE_SIZE, UiTheme.CHALK))
	column.add_child(_gap(4))
	column.add_child(_make_label(
		"%d of %d" % [_lesson + 1, _lessons.size()], UiTheme.SMALL, UiTheme.MUTED))
	column.add_child(_gap(14))

	if lesson.has("art") and ResourceLoader.exists(lesson["art"]):
		var picture := TextureRect.new()
		picture.texture = load(lesson["art"])
		picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		picture.custom_minimum_size = Vector2(520, 288)
		column.add_child(picture)
		column.add_child(_gap(14))

	var body := _make_label(lesson["body"], UiTheme.SMALL, UiTheme.CHALK)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.custom_minimum_size = Vector2(660, 0)
	body.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	column.add_child(body)

	if lesson.has("keys"):
		column.add_child(_gap(14))
		for pair in lesson["keys"]:
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 20)
			var key_cell := HBoxContainer.new()
			key_cell.alignment = BoxContainer.ALIGNMENT_END
			key_cell.custom_minimum_size = Vector2(200, 0)
			var cap := PanelContainer.new()
			var face := UiTheme.block(UiTheme.PAPER)
			face.content_margin_left = 12
			face.content_margin_right = 12
			face.content_margin_top = 0
			face.content_margin_bottom = 0
			cap.add_theme_stylebox_override("panel", face)
			cap.add_child(UiTheme.label(pair[0], UiTheme.SMALL - 2, UiTheme.INK, UiTheme.heavy()))
			key_cell.add_child(cap)
			row.add_child(key_cell)
			var meaning := _make_label(pair[1], UiTheme.SMALL, UiTheme.MUTED)
			meaning.custom_minimum_size = Vector2(420, 0)
			meaning.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
			row.add_child(meaning)
			column.add_child(row)

	var buttons := _lesson_buttons
	if _lesson > 0:
		var back := Button.new()
		back.text = "BACK"
		back.custom_minimum_size = Vector2(200, UiTheme.BUTTON_HEIGHT)
		back.pressed.connect(func() -> void:
			_lesson -= 1
			_draw_lesson()
			_teaching.visible = true)
		buttons.add_child(back)

	# And a way off the lesson entirely, rather than only forwards through it. The page
	# BACK above steps between pages; this one leaves.
	buttons.add_child(_footer_button("BACK", func() -> void:
		hide_teaching()
		go_back()))
	buttons.add_child(_footer_button("MAIN MENU", func() -> void:
		hide_teaching()
		main_menu_requested.emit()))

	var onward := Button.new()
	onward.text = "NEXT" if _lesson < _lessons.size() - 1 else "GOT IT"
	onward.custom_minimum_size = Vector2(280, UiTheme.BUTTON_HEIGHT)
	onward.pressed.connect(func() -> void:
		if _lesson < _lessons.size() - 1:
			_lesson += 1
			_draw_lesson()
			_teaching.visible = true
		else:
			teaching_finished.emit())
	buttons.add_child(onward)


# --- settings -------------------------------------------------------------------

## Volume, mouse speed and the window. Everything takes effect as it is dragged and is
## written to disk straight away — a setting you have to confirm, or restart for, is one
## people assume is broken.
func _build_settings_menu(settings: Settings) -> void:
	if _settings_menu != null:
		_settings_menu.queue_free()
	var built := _build_sheet("Settings", Color(0.03, 0.04, 0.06, 0.60))
	_settings_menu = built[0]
	var column: VBoxContainer = built[1]

	column.add_child(_make_label("SETTINGS", TITLE_SIZE, UiTheme.CHALK))
	column.add_child(_gap(18))

	column.add_child(_slider_row("Overall volume", settings.master, 0.0, 1.0,
		func(value: float) -> void:
			settings.master = value
			settings.apply()
			settings.save()))
	column.add_child(_slider_row("Crowd", settings.crowd, 0.0, 1.0,
		func(value: float) -> void:
			settings.crowd = value
			settings.apply()
			settings.save()))
	column.add_child(_slider_row("Whistle and play", settings.effects, 0.0, 1.0,
		func(value: float) -> void:
			settings.effects = value
			settings.apply()
			settings.save()))

	column.add_child(_gap(14))
	column.add_child(_slider_row("Mouse look speed", settings.sensitivity,
		Settings.SENSITIVITY_MIN, Settings.SENSITIVITY_MAX,
		func(value: float) -> void:
			settings.sensitivity = value
			settings.save()
			look_speed_changed.emit(value)))

	column.add_child(_gap(14))
	var window := CheckButton.new()
	window.text = "Fullscreen"
	window.button_pressed = settings.fullscreen
	window.toggled.connect(func(pressed: bool) -> void:
		settings.fullscreen = pressed
		settings.apply()
		settings.save())
	column.add_child(_centred(window))

	column.add_child(_gap(22))
	if _settings_over_a_match:
		# Opened from the pause menu, so there is one way out and it is back to the
		# match. The footer belongs to the menus, and a match is not one of them.
		column.add_child(_centred(_make_wide_button("BACK TO THE MATCH", func() -> void:
			settings_closed.emit())))
	else:
		# It used to send you to the title screen whichever screen had opened it, so
		# opening the settings from the career screen quietly threw the career screen
		# away. BACK now means the screen you came from.
		column.add_child(_menu_footer(AT_SETTINGS))


## One labelled slider, with the value written out beside it. The number matters: a bare
## slider tells you where the handle is and nothing about what it means.
func _slider_row(label: String, value: float, lowest: float, highest: float,
		on_change: Callable) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	row.alignment = BoxContainer.ALIGNMENT_CENTER

	var name_label := _make_label(label, UiTheme.BODY, UiTheme.MUTED)
	name_label.custom_minimum_size = Vector2(300, 0)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(name_label)

	var slider := HSlider.new()
	slider.min_value = lowest
	slider.max_value = highest
	slider.step = (highest - lowest) / 40.0
	slider.value = value
	slider.custom_minimum_size = Vector2(330, 40)
	slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(slider)

	var readout := _make_label("", UiTheme.BODY, UiTheme.CHALK)
	readout.custom_minimum_size = Vector2(90, 0)
	readout.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	row.add_child(readout)

	var show_value := func(current: float) -> void:
		readout.text = "%d%%" % roundi((current - lowest) / maxf(0.0001, highest - lowest) * 100.0)
	show_value.call(value)
	slider.value_changed.connect(func(current: float) -> void:
		show_value.call(current)
		on_change.call(current))
	return row


## Where BACK goes: the title screen, or the pause menu it was opened over.
var _settings_over_a_match := false


## `over_a_match` is whether this was opened from the pause menu.
##
## Settings used to be reachable only from the title screen, which meant the one moment
## a player actually discovers the crowd is too loud — halfway through a match, with a
## hall roaring at them — was the one moment they could not do anything about it. The
## only way out was to walk out, and walking out counts the same as being thrown off.
func show_settings(settings: Settings, over_a_match := false) -> void:
	_settings_over_a_match = over_a_match
	# Only the menu route goes on the trail. Settings opened over a match is a sheet on
	# top of a paused game, not a place the player has walked to.
	if not over_a_match:
		_arrive(AT_SETTINGS)
	if _hud != null:
		_hud.visible = false
	_build_settings_menu(settings)
	_settings_menu.visible = true
	_focus_first(_settings_menu)


func hide_settings() -> void:
	if _settings_menu != null:
		_settings_menu.visible = false


func is_settings_open() -> bool:
	return _settings_menu != null and _settings_menu.visible


func _build_pause_menu() -> void:
	var built := _build_sheet("PauseMenu", Color(0.04, 0.05, 0.07, 0.86))
	_pause_menu = built[0]
	var column: VBoxContainer = built[1]

	column.add_child(_make_label("PAUSED", TITLE_SIZE, Color(0.96, 0.96, 0.94)))
	column.add_child(_gap(22))
	column.add_child(_centred(_make_wide_button("RESUME", func() -> void: resume_requested.emit())))

	# The volume, from inside the match rather than only from the title screen.
	column.add_child(_gap(6))
	column.add_child(_centred(_make_wide_button("SETTINGS", func() -> void:
		settings_requested.emit())))

	# A way out that costs nothing, offered only before the match has begun to matter.
	#
	# Until now the only exits were WALK OUT, which counts the same as being thrown off,
	# and QUIT, which closes the game — so somebody who opened the wrong sport had to
	# damage a career to get out of it. This appears only while no call has been made
	# yet, because a free exit from a match already going badly would be a way to dodge
	# every consequence in the game.
	column.add_child(_gap(6))
	_leave_button = _make_wide_button("BACK TO THE MENU", func() -> void:
		main_menu_requested.emit())
	column.add_child(_centred(_leave_button))
	_leave_note = _make_label(
		"Nothing has happened yet. Leaving now costs nothing.",
		PROMPT_SIZE - 1, Color(0.55, 0.62, 0.55)
	)
	column.add_child(_leave_note)

	column.add_child(_gap(6))
	column.add_child(_centred(_make_wide_button("WALK OUT", func() -> void: walk_out_requested.emit())))
	column.add_child(_make_label(
		"Walking out counts the same as being removed.",
		PROMPT_SIZE - 1, Color(0.60, 0.55, 0.55)
	))
	column.add_child(_gap(6))
	column.add_child(_centred(_make_wide_button("QUIT", func() -> void: quit_requested.emit())))


## `can_leave_freely` is whether the match has yet cost anybody anything — in practice,
## whether a single call has been made.
func show_pause_menu(can_leave_freely := false) -> void:
	# Whatever was still fading in the middle of the screen would otherwise sit
	# straight across the RESUME button.
	clear_messages()
	hide_reputation()
	if _reason != null and _reason.visible and _reason_holding:
		_reason_paused = _reason_label.text
	hide_reason()
	hide_bubble()
	if _leave_button != null:
		_leave_button.visible = can_leave_freely
		_leave_note.visible = can_leave_freely
	_pause_menu.visible = true
	_focus_first(_pause_menu)



# --- the reputation meter -------------------------------------------------------
#
# It shows only when it moves, for three seconds, and then it is gone.
#
# This is a change of mind about something the game used to say in every lesson: that
# there is no meter anywhere and the crowd is the only thing telling you how much
# trouble you are in. The crowd is still there and still does that job — it is the
# only thing that answers you *back*. What the meter adds is the other half: what a
# night of small lies has actually cost your name, at the moment it costs it, rather
# than as a number on a screen after there is nothing left to decide.
#
# It shows a projection rather than a stored value. Reputation still settles once, when
# the match ends; this is where it would land if you walked off now.

func _build_reputation_meter() -> PanelContainer:
	_meter = PanelContainer.new()
	_meter.name = "ReputationMeter"
	_meter.add_theme_stylebox_override("panel", UiTheme.plate(UiTheme.ACCENT, 0.86))
	# Above the prompt line and above the crowd's line, which is the order they belong
	# in: what you must do, what the room thinks, and what it has cost you.
	#
	# It grows upwards from its anchor rather than both ways. Growing both ways put
	# half the panel below the bottom of the screen, so the bar was cut in two and the
	# whole thing sat on top of the reaction line.
	#
	# Top right since 2026-09-15, under the line judge's chip. At the bottom centre it sat
	# on top of the line judge's call, and the bottom right belongs to the ball camera.
	_pin(_meter, Control.PRESET_TOP_RIGHT, HUD_INSET_X, HUD_INSET_Y + 96)
	_meter.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_meter.modulate = Color(1, 1, 1, 0)
	_meter.visible = false

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 8)
	_meter.add_child(column)

	var heading := _make_label("REPUTATION", UiTheme.SMALL, UiTheme.MUTED)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	column.add_child(heading)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_child(row)

	_meter_bar = ProgressBar.new()
	_meter_bar.custom_minimum_size = Vector2(METER_WIDTH, METER_HEIGHT)
	_meter_bar.min_value = 0.0
	_meter_bar.max_value = 100.0
	_meter_bar.show_percentage = false

	var track := StyleBoxFlat.new()
	track.bg_color = UiTheme.INK
	track.border_width_left = 2
	track.border_width_right = 2
	track.border_width_top = 2
	track.border_width_bottom = 2
	track.border_color = UiTheme.EDGE
	_meter_bar.add_theme_stylebox_override("background", track)

	_meter_fill = StyleBoxFlat.new()
	_meter_fill.bg_color = UiTheme.CHALK
	_meter_bar.add_theme_stylebox_override("fill", _meter_fill)
	row.add_child(_meter_bar)

	# The number and which way it just went, which is the part that is actually news.
	_meter_value = _make_label("", UiTheme.HEADING, UiTheme.CHALK)
	_meter_value.custom_minimum_size = Vector2(104, 0)
	_meter_value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(_meter_value)

	return _meter


## Puts the meter up, or refills its clock if it is already up.
##
## `value` is where reputation stands from nought to one; `moved` is how far it just
## went, in the same units, signed. A move of zero is not shown at all — the meter is
## only ever news.
## `regardless` shows it even though nothing has moved, which is how the start of a
## match and the end of a set put it up. Everywhere else a move of nothing is not news
## and the meter stays down.
func show_reputation(value: float, moved: float, regardless := false) -> void:
	if _meter == null or _hud == null or not _hud.visible:
		return
	if is_zero_approx(moved) and not regardless:
		return

	var out_of_100 := roundi(clampf(value, 0.0, 1.0) * 100.0)
	var band := _meter_colour(value)
	_meter_fill.bg_color = band
	_meter_bar.value = float(out_of_100)
	_meter.add_theme_stylebox_override("panel", UiTheme.plate(band, 0.86))

	# Down is the news, so down is the colour the eye goes to.
	# No arrow when nothing moved: this is where you stand, not news about a change.
	if is_zero_approx(moved):
		_meter_value.text = "%d" % out_of_100
		_meter_value.add_theme_color_override("font_color", band)
	else:
		var arrow := "\u25b2" if moved > 0.0 else "\u25bc"
		_meter_value.text = "%s %d" % [arrow, out_of_100]
		_meter_value.add_theme_color_override("font_color",
			Color(0.55, 0.85, 0.60) if moved > 0.0 else Color(0.96, 0.42, 0.36))

	_meter.visible = true
	# Refilled rather than restarted: if it is already showing, it stays showing and
	# simply gets its full hold back.
	_meter_left = METER_FADE_IN + METER_HOLD + METER_FADE_OUT
	if _meter_shown < 1.0 and _meter.modulate.a > 0.0:
		# Already part way in. Keep the opacity it has rather than snapping back to
		# nothing, which is what a restart would look like.
		_meter_left -= METER_FADE_IN * _meter_shown


## The bar's colour, which is the whole of what it says at a glance.
func _meter_colour(value: float) -> Color:
	if value >= METER_SAFE:
		return Color(0.55, 0.85, 0.60)
	if value >= METER_SHAKY:
		return UiTheme.ACCENT
	return Color(0.96, 0.42, 0.36)


func _tick_the_meter(delta: float) -> void:
	if _meter == null or _meter_left <= 0.0:
		return
	_meter_left -= delta
	if _meter_left <= 0.0:
		_meter.visible = false
		_meter.modulate.a = 0.0
		_meter_shown = 0.0
		return

	# Fade out at the end, fade in at the start, and full opacity in between.
	if _meter_left <= METER_FADE_OUT:
		_meter_shown = _meter_left / METER_FADE_OUT
	else:
		var since := (METER_FADE_IN + METER_HOLD + METER_FADE_OUT) - _meter_left
		_meter_shown = clampf(since / METER_FADE_IN, 0.0, 1.0)
	_meter.modulate.a = _meter_shown


func hide_reputation() -> void:
	if _meter == null:
		return
	_meter.visible = false
	_meter.modulate.a = 0.0
	_meter_left = 0.0
	_meter_shown = 0.0

# --- why it moved ----------------------------------------------------------------

## The note on the left that says what the hall is reacting to.
##
## It exists because the meter on its own is a number that moves for no stated cause,
## and a player who cannot tell what cost them cannot referee any differently next
## time. It never says whether the call was right — see the note over the strings in
## `Suspicion`, which is where the wording is kept and where that rule is enforced.
##
## On the left rather than under the meter for two reasons. The middle of the screen
## is where the game announces things to the hall, and this is not addressed to the
## hall. And the eye that has just gone to the bottom centre for the number should
## find the sentence somewhere else, so the two are read as two facts rather than one
## caption.
func _build_reason_note() -> PanelContainer:
	_reason = PanelContainer.new()
	_reason.name = "ReasonNote"
	_reason.add_theme_stylebox_override("panel", UiTheme.plate(UiTheme.ACCENT, 0.86))
	_reason.set_anchors_preset(Control.PRESET_CENTER_LEFT)
	_reason.grow_horizontal = Control.GROW_DIRECTION_END
	_reason.grow_vertical = Control.GROW_DIRECTION_BOTH
	_reason.position = Vector2(REASON_INSET, 0)
	_reason.custom_minimum_size = Vector2(REASON_WIDTH, 0)
	_reason.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_reason.modulate = Color(1, 1, 1, 0)
	_reason.visible = false

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	_reason.add_child(column)

	var heading := _make_label("THE HALL", UiTheme.SMALL, UiTheme.MUTED)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	column.add_child(heading)

	_reason_label = _make_label("", UiTheme.BODY, UiTheme.CHALK)
	_reason_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_reason_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_reason_label.custom_minimum_size = Vector2(REASON_WIDTH, 0)
	column.add_child(_reason_label)

	return _reason


## Puts the note up and leaves it up.
##
## Unlike the meter it has no clock. The meter is a number and is read in a glance; a
## sentence is not, and three seconds is the wrong amount of time for one — long enough
## to be distracting during the next rally and short enough to be missed by anybody who
## happened to be watching the court. So it waits, and the umpire dismisses it by
## whistling the next rally, which is the one gesture that already means "I have
## finished with the last one".
##
## An empty reason puts nothing on screen rather than an empty box: not every route
## into the meter has something to say, and a blank panel would look like a bug.
func show_reason(text: String) -> void:
	if _reason == null or _hud == null or not _hud.visible:
		return
	if text.strip_edges().is_empty():
		return
	_reason_label.text = text
	_reason.visible = true
	_reason_holding = true


## The whistle has gone, so the note goes with it.
##
## It fades from wherever it had got to rather than from full, so dismissing one that
## is still fading in does not make it brighten first and then leave.
func dismiss_reason() -> void:
	if _reason == null or not _reason.visible or not _reason_holding:
		return
	_reason_holding = false
	_reason_left = METER_FADE_OUT * _reason_shown


func _tick_the_reason(delta: float) -> void:
	if _reason == null or not _reason.visible:
		return

	if _reason_holding:
		_reason_shown = minf(1.0, _reason_shown + delta / METER_FADE_IN)
		_reason.modulate.a = _reason_shown
		return

	_reason_left -= delta
	if _reason_left <= 0.0:
		hide_reason()
		return
	_reason_shown = _reason_left / METER_FADE_OUT
	_reason.modulate.a = _reason_shown


# --- what one person in the stands says ------------------------------------------

## The camera the bubble is measured against, set once when the match builds its hall.
##
## The UI is a CanvasLayer and knows nothing about the 3D world, which is right for
## everything else on it — the score, the prompt, the meter and the note are all in
## screen space and stay where they are put. The bubble is the one thing that has to
## follow a place in the hall, so it gets the one reference it needs and nothing more.
var chair_camera: Camera3D

## Three of them, not one.
##
## A hall that has made its mind up about you is not one person shouting: it is several,
## from different parts of the stand, over each other. One bubble at a time made the
## loudest moment in the game look like the quietest, because a room of three hundred
## people produced exactly as many voices as a school gym with nine.
const VOICES := 3

var _bubbles: Array[PanelContainer] = []
var _bubble_labels: Array[Label] = []
var _bubble_tails: Array[Polygon2D] = []
var _bubble_ats: Array[Vector3] = []
var _bubble_lefts: Array[float] = []
var _bubble_showns: Array[float] = []


## The bubble over a spectator's head, and the tail that points at them.
##
## Screen space rather than a Label3D in the hall, and that is the whole reason this
## reads at all. The stands are dark and a long way off — the far one is twenty metres
## from the chair — so text drawn in the world arrives four pixels high and edge-on. A
## panel that merely *follows* the head keeps a size a person can read from any seat in
## the room while still belonging to somebody.
# --- the broadcast ------------------------------------------------------------------

## The commentary caption, bottom left, the way a broadcast puts up a lower third — or top
## left in tennis and table tennis, whose score bugs take the bottom left (see
## `_place_for_the_sport`).
##
## It is the one panel with a red edge and a LIVE tag, because it is the one voice that is
## neither the game talking to the umpire (the amber plates) nor somebody in the hall (the
## white bubbles): it is people on television talking *about* the umpire.
const COMMENTARY_WIDTH := 460

var _commentary: PanelContainer
var _commentary_channel: Label
var _commentary_speaker: Label
var _commentary_line: Label


func _build_commentary() -> PanelContainer:
	_commentary = PanelContainer.new()
	_commentary.name = "Commentary"
	_commentary.add_theme_stylebox_override("panel", UiTheme.plate(UiTheme.RED, 0.86))
	_pin(_commentary, Control.PRESET_BOTTOM_LEFT, HUD_INSET_X, BOTTOM_LIFT)
	_commentary.custom_minimum_size = Vector2(COMMENTARY_WIDTH, 0)
	_commentary.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_commentary.visible = false

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 6)
	_commentary.add_child(column)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 12)
	column.add_child(top)
	var live := PanelContainer.new()
	var tag := UiTheme.block(UiTheme.RED)
	tag.content_margin_left = 10
	tag.content_margin_right = 10
	tag.content_margin_top = 2
	tag.content_margin_bottom = 2
	live.add_theme_stylebox_override("panel", tag)
	live.add_child(_make_label("\u25cf LIVE", UiTheme.SMALL, Color.WHITE))
	top.add_child(live)
	_commentary_channel = _make_label("", UiTheme.SMALL, UiTheme.MUTED)
	top.add_child(_commentary_channel)

	_commentary_speaker = _make_label("", UiTheme.SMALL, UiTheme.ACCENT)
	_commentary_speaker.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	column.add_child(_commentary_speaker)

	_commentary_line = _make_label("", UiTheme.BODY, UiTheme.CHALK)
	_commentary_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_commentary_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_commentary_line.custom_minimum_size = Vector2(COMMENTARY_WIDTH, 0)
	column.add_child(_commentary_line)
	return _commentary


func show_commentary(channel: String, speaker: String, line: String) -> void:
	if _commentary == null:
		return
	_commentary_channel.text = channel
	_commentary_speaker.text = speaker
	_commentary_line.text = line
	# It grows upwards from its bottom edge. Collapsed first, so a one-line caption after a
	# two-line one does not keep the taller box. Offsets, not `position`: once the HUD has a
	# size, `position` is measured from its top-left and the caption would leave the screen.
	if _commentary_at_top:
		_commentary.offset_bottom = _commentary.offset_top
	else:
		_commentary.offset_top = _commentary.offset_bottom
	_commentary.offset_right = _commentary.offset_left
	_commentary.visible = true


func hide_commentary() -> void:
	if _commentary != null:
		_commentary.visible = false


## What the broadcast currently has up, for the checks. Empty when nothing is.
func commentary_showing() -> String:
	if _commentary == null or not _commentary.visible:
		return ""
	return "%s: %s" % [_commentary_speaker.text, _commentary_line.text]


func _build_bubbles() -> Control:
	var holder := Control.new()
	holder.name = "CrowdBubbles"
	holder.set_anchors_preset(Control.PRESET_FULL_RECT)
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for i in VOICES:
		holder.add_child(_build_bubble(i))
	return holder


func _build_bubble(index: int) -> PanelContainer:
	var bubble := PanelContainer.new()
	bubble.name = "CrowdBubble%d" % index
	# A white bubble with dark type in it, which is not what anything else on this
	# interface looks like and is deliberate. Every other panel is a dark plate with a
	# coloured edge, because every other panel is the game talking to the umpire. This
	# is a person in the hall talking, it is read against a dark room from twenty metres
	# away, and the first version — a dark plate with ink text on it, from reusing the
	# house style without thinking — was very nearly invisible in the frame.
	var skin := StyleBoxFlat.new()
	skin.bg_color = UiTheme.CHALK
	skin.set_corner_radius_all(14)
	skin.set_border_width_all(2)
	skin.border_color = UiTheme.INK
	skin.content_margin_left = 18
	skin.content_margin_right = 18
	skin.content_margin_top = 10
	skin.content_margin_bottom = 10
	bubble.add_theme_stylebox_override("panel", skin)
	bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bubble.modulate = Color(1, 1, 1, 0)
	bubble.visible = false
	bubble.z_index = 1

	var label := _make_label("", UiTheme.HEADING, UiTheme.INK)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(BUBBLE_MAX_WIDTH, 0)
	bubble.add_child(label)

	# Drawn as a child of the bubble so it moves with it and inherits its fade, and
	# pointing straight down because the bubble is always directly over the head.
	var tail := Polygon2D.new()
	tail.color = UiTheme.CHALK
	tail.polygon = PackedVector2Array([
		Vector2(-BUBBLE_TAIL, 0.0), Vector2(BUBBLE_TAIL, 0.0),
		Vector2(0.0, BUBBLE_TAIL * 1.5),
	])
	bubble.add_child(tail)

	_bubbles.append(bubble)
	_bubble_labels.append(label)
	_bubble_tails.append(tail)
	_bubble_ats.append(Vector3.INF)
	_bubble_lefts.append(0.0)
	_bubble_showns.append(0.0)
	return bubble


## Puts a line in somebody's mouth. `at` is the world point just above their head.
##
## An empty line or a speaker off in the infinite distance both mean "nobody said
## anything", which is a real answer — a quiet lie draws no shout at all, and the hall
## is only allowed to be certain about the things it could actually see.
##
## Takes the quietest slot when all three are busy, so a fourth voice replaces the one
## that has been on screen longest rather than being dropped. In practice three is
## enough: the hall only ever speaks with more than one voice when it is hostile.
func say_from_the_crowd(line: String, at: Vector3) -> void:
	if _bubbles.is_empty() or _hud == null or not _hud.visible:
		return
	if line.is_empty() or at == Vector3.INF:
		return

	var slot := 0
	var quietest := INF
	for i in _bubbles.size():
		if _bubble_lefts[i] <= 0.0:
			slot = i
			break
		if _bubble_lefts[i] < quietest:
			quietest = _bubble_lefts[i]
			slot = i

	_bubble_labels[slot].text = line
	_bubble_ats[slot] = at
	_bubbles[slot].visible = true
	_bubble_lefts[slot] = BUBBLE_FADE + BUBBLE_HOLD + BUBBLE_FADE
	_follow_the_bubble(slot)


func hide_bubble() -> void:
	for i in _bubbles.size():
		_bubbles[i].visible = false
		_bubbles[i].modulate.a = 0.0
		_bubble_lefts[i] = 0.0
		_bubble_showns[i] = 0.0
		_bubble_ats[i] = Vector3.INF


## Keeps a bubble over its speaker while the umpire looks around.
##
## Hidden rather than clamped when the speaker goes off screen or behind the chair. A
## bubble pinned to the edge of the screen claims somebody is shouting from a place
## nobody is sitting, and the player turning their head is exactly the moment they
## would notice.
func _follow_the_bubble(i: int) -> void:
	var bubble := _bubbles[i]
	if not bubble.visible:
		return
	if chair_camera == null or not is_instance_valid(chair_camera):
		return
	if chair_camera.is_position_behind(_bubble_ats[i]):
		bubble.modulate.a = 0.0
		return

	var point := chair_camera.unproject_position(_bubble_ats[i])
	var size := bubble.get_combined_minimum_size()
	var screen := get_viewport().get_visible_rect().size
	var place := Vector2(point.x - size.x * 0.5, point.y - size.y - BUBBLE_LIFT)

	if (point.x < 0.0 or point.x > screen.x or place.y < 0.0
			or point.y > screen.y):
		bubble.modulate.a = 0.0
		return

	bubble.position = place
	bubble.size = size
	_bubble_tails[i].position = Vector2(size.x * 0.5, size.y)
	bubble.modulate.a = _bubble_showns[i]


func _tick_the_bubble(delta: float) -> void:
	for i in _bubbles.size():
		if _bubble_lefts[i] <= 0.0:
			continue
		_bubble_lefts[i] -= delta
		if _bubble_lefts[i] <= 0.0:
			_bubbles[i].visible = false
			_bubbles[i].modulate.a = 0.0
			_bubble_showns[i] = 0.0
			_bubble_ats[i] = Vector3.INF
			continue

		if _bubble_lefts[i] <= BUBBLE_FADE:
			_bubble_showns[i] = _bubble_lefts[i] / BUBBLE_FADE
		else:
			var since := (BUBBLE_FADE + BUBBLE_HOLD + BUBBLE_FADE) - _bubble_lefts[i]
			_bubble_showns[i] = clampf(since / BUBBLE_FADE, 0.0, 1.0)
		_follow_the_bubble(i)


func hide_reason() -> void:
	if _reason == null:
		return
	_reason.visible = false
	_reason.modulate.a = 0.0
	_reason_left = 0.0
	_reason_shown = 0.0
	_reason_holding = false



## Wipes the announcement, the crowd's line and the banner immediately.
func clear_messages() -> void:
	_message_label.text = ""
	_reaction_label.text = ""
	_banner_label.text = ""
	_message_timer = 0.0
	_reaction_timer = 0.0
	_banner_timer = 0.0
	hide_line_judge()
	hide_reputation()
	hide_reason()
	hide_bubble()


func hide_pause_menu() -> void:
	_release_focus()
	_pause_menu.visible = false
	# Back to whatever the umpire was still reading when they paused. The shout is not
	# put back with it: a bubble is somebody speaking at a moment, and that moment has
	# gone, whereas the note is a standing fact about what the last call cost.
	if _reason_paused != "":
		show_reason(_reason_paused)
		_reason_paused = ""


func _centred(control: Control) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(control)
	return row


# --- what the number is made of --------------------------------------------------

## Every match this official has refereed, newest first.
##
## Reputation is one figure standing for a whole career, and it was the only record there
## was: somebody who had climbed to a national championship and somebody who had been
## thrown off two beach matches could arrive at the same 62 with nothing to tell them
## apart. This is the difference between them.
##
## It states the truth, which almost nothing else in this game does — but only about
## matches that are over. Nothing here can help you with a call you have not made yet.
var _history_panel: Control
var _history_column: VBoxContainer


func _build_history_panel() -> void:
	var built := _build_sheet("History", Color(0.04, 0.05, 0.07, 0.95))
	_history_panel = built[0]
	_history_column = built[1]


func show_history(career: Career) -> void:
	_arrive(AT_HISTORY)
	for child in _history_column.get_children():
		child.queue_free()
	if _hud != null:
		_hud.visible = false
	hide_career()

	_history_column.add_child(_make_label(
		"EVERY MATCH SO FAR", TITLE_SIZE - 4, UiTheme.CHALK))
	_history_column.add_child(_make_label(
		"%d refereed, %d walked away from." % [
			career.matches_refereed, career.times_removed],
		PROMPT_SIZE, UiTheme.MUTED))
	_history_column.add_child(_gap(14))

	var table := GridContainer.new()
	table.columns = 6
	table.add_theme_constant_override("h_separation", 30)
	table.add_theme_constant_override("v_separation", 6)
	_history_column.add_child(_centred(table))
	for heading in ["SPORT", "VENUE", "FORMAT", "COST", "LEFT", ""]:
		var label := UiTheme.label(heading, UiTheme.SMALL, UiTheme.ACCENT, UiTheme.heavy())
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		table.add_child(label)
	for row in career.history:
		for cell in _history_row(row):
			table.add_child(cell)

	_history_column.add_child(_gap(18))
	_history_column.add_child(_menu_footer(AT_HISTORY))
	_history_panel.visible = true
	_focus_first(_history_panel)


## One match. The cost is what it did to your name, which is the only number here that
## is about you rather than about the match.
func _history_row(row: Dictionary) -> Array[Label]:
	var change := float(row.get("change", 0.0))
	var removed := bool(row.get("removed", false))
	var format := "—"
	if bool(row.get("asked", false)):
		format = "doubles" if bool(row.get("doubles", true)) else "singles"

	var cells := [
		Career.name_of(StringName(row.get("sport", ""))),
		String(row.get("venue", "")),
		format,
		"%+.2f" % change,
		str(roundi(float(row.get("reputation", 0.0)) * 100.0)),
		"thrown off" if removed else "",
	]

	var tint := Color(0.74, 0.77, 0.82)
	if removed:
		tint = Color(0.96, 0.42, 0.36)
	elif change > 0.0:
		tint = Color(0.62, 0.82, 0.66)
	elif change < -0.05:
		tint = Color(0.92, 0.72, 0.50)
	var labels: Array[Label] = []
	for cell in cells:
		var label := UiTheme.label(cell, UiTheme.SMALL + 2, tint)
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		labels.append(label)
	return labels


func hide_history() -> void:
	if _history_panel != null:
		_history_panel.visible = false


# --- the career ----------------------------------------------------------------

func _build_career_panel() -> void:
	_career_panel = Control.new()
	_career_panel.name = "CareerPanel"
	_career_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_career_panel.visible = false
	_career_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(_career_panel)

	var backdrop := ColorRect.new()
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0.03, 0.04, 0.06, 0.62)
	_career_panel.add_child(backdrop)

	var card := PanelContainer.new()
	card.set_anchors_preset(Control.PRESET_CENTER)
	card.grow_horizontal = Control.GROW_DIRECTION_BOTH
	card.grow_vertical = Control.GROW_DIRECTION_BOTH
	_career_panel.add_child(card)

	_career_column = VBoxContainer.new()
	_career_column.alignment = BoxContainer.ALIGNMENT_CENTER
	_career_column.add_theme_constant_override("separation", 7)
	_career_column.custom_minimum_size = Vector2(1000, 0)
	card.add_child(_career_column)


## Draws the ladder, with where you are on it and what that is worth.
func show_career(career: Career) -> void:
	_arrive(AT_CAREER)
	for child in _career_column.get_children():
		child.queue_free()

	_career_panel.visible = true

	if career.is_over:
		_career_column.add_child(_make_label("YOUR CAREER IS OVER", TITLE_SIZE, Color(0.96, 0.42, 0.36)))
		_career_column.add_child(_make_label(
			"%d matches, thrown off %d of them." % [career.matches_refereed, career.times_removed],
			PROMPT_SIZE + 2, Color(0.78, 0.78, 0.80)
		))
		_career_column.add_child(_gap(18))
		_career_column.add_child(_centred(_make_wide_button("START AGAIN", func() -> void:
			career_restart_requested.emit()
		)))
		_career_column.add_child(_gap(16))
		_career_column.add_child(_menu_footer(AT_CAREER))
		_focus_first(_career_panel)
		return

	_career_column.add_child(_make_label("YOUR CAREER", TITLE_SIZE - 4, Color(0.95, 0.95, 0.93)))
	_career_column.add_child(_gap(4))

	# Two columns: this sport's ladder on the left, all five on the right. Stacked, the
	# screen came to more than a thousand pixels and ran off both ends of a laptop.
	var halves := HBoxContainer.new()
	halves.add_theme_constant_override("separation", 48)
	halves.alignment = BoxContainer.ALIGNMENT_CENTER
	_career_column.add_child(halves)
	var left := VBoxContainer.new()
	left.add_theme_constant_override("separation", 6)
	halves.add_child(left)
	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 6)
	right.alignment = BoxContainer.ALIGNMENT_CENTER
	halves.add_child(right)

	# The ladder as a broadcast bracket: one plate a rung, the rung you are on lit gold,
	# the ones behind you ticked off, the ones ahead dim.
	left.add_child(UiTheme.label(Career.name_of(career.sport).to_upper(), UiTheme.SMALL,
		UiTheme.ACCENT, UiTheme.heavy()))
	var rungs := career.ladder()
	for i in rungs.size():
		var rung: Dictionary = rungs[i]
		left.add_child(_rung_plate(String(rung["name"]),
			&"cleared" if i < career.tier else (&"here" if i == career.tier else &"ahead")))

	_career_column.add_child(_gap(6))
	_career_column.add_child(_make_label(
		str(career.venue()["blurb"]), PROMPT_SIZE, Color(0.70, 0.72, 0.76)
	))
	_career_column.add_child(UiTheme.label(
		"REPUTATION  %d / 100     \u2022     %s" % [
			roundi(career.reputation * 100.0),
			Career.format_of(career.sport, career.venue()["quick"]).to_upper(),
		],
		UiTheme.HEADING, UiTheme.CHALK, UiTheme.heavy()))

	# Anybody out there who has not forgotten you. This is the only place a grudge
	# shows up before you are standing in front of it, and it is here rather than on
	# the briefing alone because the point of a grudge is that you carry it between
	# matches — knowing it is coming is most of what it does.
	if not career.grudge_name.is_empty():
		_career_column.add_child(_gap(8))
		_career_column.add_child(_make_label(
			"%s is still in this draw." % career.grudge_name,
			PROMPT_SIZE, Color(0.90, 0.62, 0.44)
		))

	_add_the_other_ladders(career, right)

	_career_column.add_child(_gap(12))
	var actions := HBoxContainer.new()
	actions.alignment = BoxContainer.ALIGNMENT_CENTER
	actions.add_theme_constant_override("separation", 16)
	_career_column.add_child(actions)
	# The button only reports the choice; the match decides what happens to the
	# screen. Hiding it in here means the flow only works when a human clicks.
	var go := _make_wide_button("REFEREE THIS MATCH", func() -> void:
		match_requested.emit()
	)
	go.custom_minimum_size.x = 380
	go.add_theme_color_override("font_color", UiTheme.INK)
	go.add_theme_color_override("font_hover_color", UiTheme.INK)
	go.add_theme_color_override("font_focus_color", UiTheme.INK)
	var gold := UiTheme.slant(UiTheme.ACCENT)
	gold.content_margin_top = 14
	gold.content_margin_bottom = 14
	go.add_theme_stylebox_override("normal", gold)
	var lit := UiTheme.slant(UiTheme.ACCENT.lightened(0.25))
	lit.content_margin_top = 14
	lit.content_margin_bottom = 14
	go.add_theme_stylebox_override("hover", lit)
	go.add_theme_stylebox_override("focus", lit)
	go.add_theme_stylebox_override("pressed", lit)
	actions.add_child(go)
	# And a way back to the rules of whichever sport this is.
	#
	# The lesson used to be shown once, on the way into a first match, and then be
	# unreachable — the title screen's HOW TO REFEREE only ever had badminton's. That is
	# worst for indoor volleyball, whose lesson is the only one in the game explaining
	# something the player has to carry in their head rather than look at.
	var lessons := _make_wide_button("HOW TO REFEREE", func() -> void:
		teaching_requested.emit()
	)
	lessons.custom_minimum_size.x = 300
	actions.add_child(lessons)
	# And what the reputation at the top of this screen is actually made of.
	if not career.history.is_empty():
		var history := _make_wide_button("EVERY MATCH SO FAR", func() -> void:
			history_requested.emit()
		)
		history.custom_minimum_size.x = 320
		actions.add_child(history)

	# A career you can end on purpose, and not only one that ends on you.
	#
	# START AGAIN existed, but only in the `is_over` branch above, so the single way to
	# clear a career that was still alive was to quit the game and delete `career.json`
	# by hand. The signal it emits has been wired up in both `match.gd` and
	# `officiated_match.gd` the whole time; only the button was missing.
	#
	# Two clicks rather than one. A dead career has nothing left to lose and gets a
	# single press, but a living one is somebody's evenings, and the second press names
	# how many matches are about to go so that what is being thrown away is on the
	# button itself rather than left to be remembered. Nothing needs to disarm it: this
	# screen is rebuilt from scratch every time `show_career` runs, so leaving and coming
	# back is already a cancel.
	_career_column.add_child(_gap(8))
	var wipe := Button.new()
	wipe.name = "StartAgain"
	wipe.text = "START AGAIN"
	wipe.custom_minimum_size = Vector2(FOOTER_BUTTON_WIDTH, UiTheme.BUTTON_HEIGHT)
	var armed := {"yes": false}
	wipe.pressed.connect(func() -> void:
		if armed["yes"]:
			career_restart_requested.emit()
			return
		armed["yes"] = true
		wipe.text = "SURE? %d %s GO" % [
			career.matches_refereed,
			"MATCH" if career.matches_refereed == 1 else "MATCHES",
		]
		wipe.add_theme_color_override("font_color", Color(0.96, 0.42, 0.36))
		wipe.custom_minimum_size.x = FOOTER_BUTTON_WIDTH + 120)
	_career_column.add_child(_centred(wipe))

	# The screen had no way off it at all until now: no BACK, no MAIN MENU, and the only
	# exits were forward into a match or sideways into the lesson and the history. A
	# player who opened it to look at the ladder had to referee a match to leave.
	_career_column.add_child(_gap(8))
	_career_column.add_child(_menu_footer(AT_CAREER))
	_focus_first(_career_panel)


## All five ladders at once, under the one you are standing on.
##
## You are one official with one name and five separate licences, and until now there
## was nowhere that said so — each sport's screen showed its own ladder and the fact
## that a disaster at the beach is waiting for you at the badminton hall was something
## the player had to work out. The reputation at the top of this screen is the shared
## number; these are the four things it is spent on.
func _add_the_other_ladders(career: Career, into: VBoxContainer) -> void:
	into.add_child(UiTheme.label(
		"ONE NAME, SIX LADDERS", UiTheme.SMALL, UiTheme.ACCENT, UiTheme.heavy()))

	# A grid rather than padded strings: the columns used to be lined up with spaces, which
	# only ever worked in a font where every letter is the same width.
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 34)
	grid.add_theme_constant_override("v_separation", 4)
	into.add_child(grid)
	for which in Career.IN_ORDER:
		var standing := career.standing_in(which)
		var rungs := Career.ladder_for(which)
		var here := int(standing["tier"])
		var tint := Color(0.50, 0.53, 0.58)
		var rung_name := "not started yet"
		var played_text := ""
		if standing["started"]:
			var played := int(standing["matches_at_tier"])
			rung_name = String(rungs[clampi(here, 0, rungs.size() - 1)]["name"])
			played_text = "%d at this rung" % played if played > 0 else "just arrived"
			tint = Color(0.74, 0.77, 0.82)
		if which == career.sport:
			tint = UiTheme.ACCENT
		for cell in [Career.name_of(which).to_upper(), rung_name, played_text]:
			var label := UiTheme.label(cell, UiTheme.SMALL + 2, tint,
				UiTheme.heavy() if cell == Career.name_of(which).to_upper() else null)
			label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
			grid.add_child(label)


## One rung of the ladder. `state` is cleared, here or ahead.
func _rung_plate(rung_name: String, state: StringName) -> Control:
	var plate := PanelContainer.new()
	var fill := Color(UiTheme.RAISED.r, UiTheme.RAISED.g, UiTheme.RAISED.b, 0.7)
	var ink := UiTheme.MUTED.darkened(0.25)
	var mark := ""
	match state:
		&"here":
			fill = UiTheme.ACCENT
			ink = UiTheme.INK
			mark = "\u25b6  "
		&"cleared":
			ink = Color(0.62, 0.78, 0.64)
			mark = "\u2713  "
	var skin := UiTheme.slant(fill, UiTheme.LEAN * 0.6)
	skin.content_margin_top = 0
	skin.content_margin_bottom = 0
	plate.add_theme_stylebox_override("panel", skin)
	plate.custom_minimum_size = Vector2(520, 0)
	plate.add_child(UiTheme.label(mark + rung_name.to_upper(), UiTheme.BODY, ink, UiTheme.heavy()))
	return _centred(plate)


## Whether the career ladder is the screen currently showing.
func career_is_showing() -> bool:
	return _career_panel != null and _career_panel.visible


func hide_career() -> void:
	_career_panel.visible = false


## Clears every front-of-game screen. Called wherever a match begins, so that no
## route in can leave a menu sitting over the court — which each of these panels has
## managed to do in turn.
## Shows or hides the score bug and the prompts.
##
## `hide_menus` turns the HUD on, because it is what a match beginning calls. A scene
## that opens *into* a menu has to say so, or it draws a 0-0 score over the career
## ladder before a ball has been served.
func show_hud(shown: bool) -> void:
	if _hud != null:
		_hud.visible = shown


func hide_menus() -> void:
	_release_focus()
	_reason_paused = ""
	if _hud != null:
		_hud.visible = true
	hide_sport_menu()
	hide_format_menu()
	hide_settings()
	hide_teaching()
	hide_history()
	_main_menu.visible = false
	_career_panel.visible = false
	_pause_menu.visible = false
	_briefing.visible = false


func _gap(height: int) -> Control:
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, height)
	return spacer


# --- getting back out of a screen -------------------------------------------------

## Which screens exist to navigate between, as they appear on the trail.
##
## In-match overlays are deliberately not on this list: the pause menu, the briefing,
## the fault panel, the review and the ending are moments in a match rather than places
## you have walked to, and each already has its own defined way out. Putting a MAIN MENU
## button on a briefing would abandon a match with one click and no warning.
const AT_MAIN := &"main"
const AT_SPORTS := &"sports"
const AT_FORMAT := &"format"
const AT_CAREER := &"career"
const AT_HISTORY := &"history"
const AT_TEACHING := &"teaching"
const AT_SETTINGS := &"settings"

## Where the player has walked, current screen last.
##
## A trail rather than a stack of pushes, because the menus are a small graph rather
## than a tree: the lesson and the settings are both reachable from the title screen and
## from the career screen, and the career screen is reachable from the history screen
## that is reachable from it. A plain push would have grown for ever going round that
## loop, and BACK from the settings would have gone to whichever screen opened them the
## *first* time rather than this time.
var _trail: Array[StringName] = []

## Which sport the format menu is asking about, so BACK can return to it.
var _format_sport := Career.BADMINTON


## Records arriving at a screen. Called by each `show_` so the trail is kept in one
## place rather than at every call site that opens something.
func _arrive(where: StringName) -> void:
	if where == AT_MAIN:
		_trail = [AT_MAIN]
		return
	# The title screen is a full screen of its own now rather than a card in the middle,
	# so a screen opened over it has to take it down or it shows through.
	if _main_menu != null:
		_main_menu.visible = false
	if _trail.is_empty():
		_trail = [AT_MAIN]
	# Arriving somewhere already behind you is a step back to it, not a new step, which
	# is what stops career -> history -> career growing the trail for ever.
	var already := _trail.find(where)
	if already >= 0:
		_trail.resize(already + 1)
		return
	_trail.append(where)


## Back to wherever the player came from, and to the title screen if that is nowhere.
func go_back() -> void:
	if _trail.size() < 2:
		main_menu_requested.emit()
		return
	var to := _trail[_trail.size() - 2]
	_trail.resize(_trail.size() - 1)
	_open(to)


func _open(where: StringName) -> void:
	match where:
		AT_SPORTS: play_requested.emit()
		AT_CAREER: career_screen_requested.emit()
		AT_HISTORY: history_requested.emit()
		AT_TEACHING: teaching_requested.emit()
		AT_SETTINGS: settings_requested.emit()
		AT_FORMAT: show_format_menu(_format_sport)
		_: main_menu_requested.emit()


## Takes a screen down. Each `show_` puts a screen up over whatever was there, so the
## one being left has to be closed by name — there is no single "hide everything" that
## does not also put the HUD back up in the middle of a menu.
func _leave(where: StringName) -> void:
	match where:
		AT_SPORTS: hide_sport_menu()
		AT_FORMAT: hide_format_menu()
		AT_CAREER: hide_career()
		AT_HISTORY: hide_history()
		AT_TEACHING: hide_teaching()
		AT_SETTINGS: hide_settings()


## The two buttons every screen but the title gets, in the same place on every one.
##
## Both, even where they lead to the same screen — the sport menu sits directly under
## the title, so its BACK and its MAIN MENU do the same thing. That is deliberate:
## a footer whose buttons move about depending on how deep you happen to be is worse
## than one that is always the same two words in the same two places.
func _menu_footer(from: StringName) -> Control:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	row.add_child(_footer_button("BACK", func() -> void:
		_leave(from)
		go_back()))
	row.add_child(_footer_button("MAIN MENU", func() -> void:
		_leave(from)
		main_menu_requested.emit()))
	return row


## Narrower than a `_make_wide_button`, because two of those side by side come to more
## than nine hundred pixels and crowd out the screen they are underneath.
func _footer_button(text: String, on_press: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(FOOTER_BUTTON_WIDTH, UiTheme.BUTTON_HEIGHT)
	button.pressed.connect(on_press)
	return button


func _make_wide_button(text: String, on_press: Callable) -> Button:
	var button := Button.new()
	button.text = text
	button.custom_minimum_size = Vector2(UiTheme.BUTTON_WIDTH, UiTheme.BUTTON_HEIGHT)
	button.pressed.connect(on_press)
	var row := button
	return row


# --- the reason ----------------------------------------------------------------
#
# The screen that turns "pick a side" into a decision. Everything on it is something
# somebody said to the umpire in a corridor, and none of it is an instruction. The
# player is left to draw the conclusion, which is exactly the position the real job
# puts you in.

func _build_briefing() -> void:
	_briefing = Control.new()
	_briefing.name = "Briefing"
	_briefing.set_anchors_preset(Control.PRESET_FULL_RECT)
	_briefing.mouse_filter = Control.MOUSE_FILTER_STOP
	_briefing.visible = false
	_root.add_child(_briefing)

	var backdrop := ColorRect.new()
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0.02, 0.03, 0.05, 0.72)
	_briefing.add_child(backdrop)

	var card := PanelContainer.new()
	card.set_anchors_preset(Control.PRESET_CENTER)
	card.grow_horizontal = Control.GROW_DIRECTION_BOTH
	card.grow_vertical = Control.GROW_DIRECTION_BOTH
	_briefing.add_child(card)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 16)
	# Wide enough that a paragraph is a paragraph rather than a column of two words.
	column.custom_minimum_size = Vector2(720, 0)
	card.add_child(column)

	var tag := PanelContainer.new()
	tag.add_theme_stylebox_override("panel", UiTheme.slant(UiTheme.ACCENT))
	tag.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	tag.add_child(UiTheme.label("BEFORE THE MATCH", UiTheme.SMALL, UiTheme.INK, UiTheme.heavy()))
	column.add_child(tag)
	_briefing_headline = _make_label("", TITLE_SIZE, Color(0.96, 0.94, 0.88))
	_briefing_headline.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_briefing_headline.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_briefing_headline.custom_minimum_size = Vector2(720, 0)
	column.add_child(_briefing_headline)

	# The body is the only long prose in the game, so it wraps and is left-aligned.
	# Centred ragged text reads as a poster; this is meant to read as somebody talking.
	_briefing_detail = _make_label("", PROMPT_SIZE, Color(0.74, 0.76, 0.80))
	_briefing_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_briefing_detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	_briefing_detail.custom_minimum_size = Vector2(720, 0)
	column.add_child(_briefing_detail)

	column.add_child(_gap(6))

	# The one line you will still be thinking about at 19-all, in the colour of
	# whoever stands to gain by it.
	_briefing_ask = _make_label("", BUTTON_SIZE, Color(0.95, 0.90, 0.60))
	_briefing_ask.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_briefing_ask.custom_minimum_size = Vector2(720, 0)
	column.add_child(_briefing_ask)

	column.add_child(_gap(10))

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_child(row)
	row.add_child(_make_wide_button("GO OUT", func() -> void: briefing_acknowledged.emit()))



func show_briefing(pressure: Pressure) -> void:
	_briefing_headline.text = pressure.headline.to_upper()
	_briefing_detail.text = pressure.detail
	_briefing_ask.text = pressure.ask
	_briefing_ask.add_theme_color_override("font_color",
		Sides.colour(pressure.wants) if pressure.wants != Sides.Team.NONE
		else Color(0.95, 0.90, 0.60))
	_briefing.visible = true
	_focus_first(_briefing)


func hide_briefing() -> void:
	_briefing.visible = false
	_release_focus()


## The match starts the moment the briefing is dismissed, or straight away when there
## is no briefing.
##
## There used to be a screen here asking WHO DO YOU WANT TO WIN, answered before a ball
## was served. It was cut on purpose. Being asked to declare a favourite made the game
## tell you what kind of referee to be before you had seen anything, and most people do
## not sit down wanting a result — they sit down wanting to get it right, and find out
## later what they are willing to do. A reason to lean now only ever arrives from
## outside, in a briefing, and only sometimes.


# --- in-match ------------------------------------------------------------------

func _build_hud() -> void:
	var hud := Control.new()
	_hud = hud
	hud.name = "Hud"
	hud.set_anchors_preset(Control.PRESET_FULL_RECT)
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(hud)

	# Where everything sits, since the broadcast redesign of 2026-09-15:
	#
	#   the score bug        where that sport's television puts it (ScoreBug.corner)
	#   the line judge       top right, a chip, the way a broadcast flags a call
	#   the reputation meter top right, under the line judge
	#   the commentary       bottom left, or top left when the bug has the bottom left
	#   the prompt           bottom centre, as key caps
	#   the hall's line      above the prompt
	#   the ball camera      bottom right, where it always was
	#
	# Every corner holds one thing. Before this the line judge, the meter, the hall's line
	# and the prompt were stacked up the middle of the bottom edge and the meter sat on
	# top of the line judge's call.
	_score_bug = ScoreBug.new()
	hud.add_child(_score_bug)

	_message_label = _make_label("", MESSAGE_SIZE, Color(0.98, 0.94, 0.72))
	_message_label.set_anchors_preset(Control.PRESET_CENTER)
	_message_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_message_label.grow_vertical = Control.GROW_DIRECTION_BOTH
	_message_label.position = Vector2(0, -70)
	_message_label.add_theme_constant_override("outline_size", 14)
	_message_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	hud.add_child(_message_label)

	hud.add_child(_build_prompt())

	# What the hall is doing. For a long time this was the *only* feedback the player
	# ever got about how much trouble they were in. The reputation meter below now says
	# what it has cost — but only when it changes, and only for three seconds, so the
	# room is still the thing you read continuously and the meter is only ever news.
	_reaction_label = _make_label("", REACTION_SIZE, Color(0.86, 0.80, 0.66))
	_reaction_label.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_reaction_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_reaction_label.offset_top = -REACTION_LIFT
	_reaction_label.offset_bottom = -REACTION_LIFT
	_reaction_label.add_theme_constant_override("outline_size", 10)
	_reaction_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	hud.add_child(_reaction_label)

	# What the line judge said, in words, near the middle of the screen.
	#
	# The bubble over their head is not enough on its own. A badminton court is small and
	# both judges are in shot; a tennis court is twenty-four metres long and its judges
	# sit at the corners, fourteen metres from the chair and usually outside an eighty
	# degree view — so their call was going up where nobody could see it, which read as
	# them having nothing to say.
	#
	# Top right since 2026-09-15, as a chip: LINE JUDGE in grey and the call itself in its
	# colour, which is how a broadcast flags a line call rather than a sentence along the
	# bottom.
	_judge_label = UiTheme.label("", UiTheme.HEADING + 4, UiTheme.CHALK, UiTheme.heavy())
	_judge_plate = PanelContainer.new()
	_judge_plate.name = "LineJudge"
	_judge_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var judge_row := HBoxContainer.new()
	judge_row.add_theme_constant_override("separation", 14)
	_judge_plate.add_child(judge_row)
	judge_row.add_child(UiTheme.label("LINE JUDGE", UiTheme.HEADING, UiTheme.MUTED, UiTheme.heavy()))
	judge_row.add_child(_judge_label)
	_pin(_judge_plate, Control.PRESET_TOP_RIGHT, HUD_INSET_X, HUD_INSET_Y)
	hud.add_child(_judge_plate)
	_judge_plate.visible = false

	_banner_label = _make_label("", BANNER_SIZE, Color(0.96, 0.42, 0.36))
	_banner_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_banner_label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_banner_label.position = Vector2(0, 76)
	hud.add_child(_banner_label)

	hud.add_child(_build_reputation_meter())
	hud.add_child(_build_reason_note())
	hud.add_child(_build_bubbles())
	hud.add_child(_build_commentary())
	_place_for_the_sport()


## How far in from the edges of the screen the HUD's corner pieces sit.
const HUD_INSET_X := 44
const HUD_INSET_Y := 28

## How far up the bottom-edge pieces sit: above the prompt, which has the very bottom.
const BOTTOM_LIFT := 96
const REACTION_LIFT := 150
const REACTION_LIFT_OVER_STRIP := 290

## Which sport the HUD is dressed for. Set by the match when it builds its interface;
## badminton's by default, because the badminton hall builds this before any sport has
## been chosen.
var score_sport: StringName = Career.BADMINTON:
	set(value):
		score_sport = value
		if _score_bug != null:
			_score_bug.use_sport(value)
			_place_for_the_sport()


## Anchors a HUD piece to a corner and lets it grow into the screen from there.
##
## Offsets rather than `position`, which is only right while the HUD still has no size.
func _pin(piece: Control, preset: int, x: int, y: int) -> void:
	piece.set_anchors_preset(preset)
	var right := preset in [Control.PRESET_TOP_RIGHT, Control.PRESET_BOTTOM_RIGHT, Control.PRESET_CENTER_RIGHT]
	var bottom := preset in [Control.PRESET_BOTTOM_LEFT, Control.PRESET_BOTTOM_RIGHT, Control.PRESET_CENTER_BOTTOM]
	var centre := preset in [Control.PRESET_CENTER_TOP, Control.PRESET_CENTER_BOTTOM]
	piece.grow_horizontal = (Control.GROW_DIRECTION_BOTH if centre
		else Control.GROW_DIRECTION_BEGIN if right else Control.GROW_DIRECTION_END)
	piece.grow_vertical = Control.GROW_DIRECTION_BEGIN if bottom else Control.GROW_DIRECTION_END
	var dx := 0 if centre else (-x if right else x)
	var dy := -y if bottom else y
	piece.offset_left = dx
	piece.offset_right = dx
	piece.offset_top = dy
	piece.offset_bottom = dy


## Puts the score bug where this sport's television has it, and moves the commentary to
## whichever left-hand corner the bug has left free.
func _place_for_the_sport() -> void:
	if _score_bug == null:
		return
	var corner: int = _score_bug.corner()
	if corner == Control.PRESET_TOP_LEFT:
		_pin(_score_bug, corner, HUD_INSET_X, HUD_INSET_Y)
	else:
		_pin(_score_bug, corner, HUD_INSET_X, BOTTOM_LIFT)
	_commentary_at_top = corner == Control.PRESET_BOTTOM_LEFT
	# The hall's line sits over the middle of the bottom edge, which is where both
	# volleyballs keep their score. Over a strip it goes above the whole of it.
	if _reaction_label != null:
		var lift := REACTION_LIFT_OVER_STRIP if corner == Control.PRESET_CENTER_BOTTOM else REACTION_LIFT
		_reaction_label.offset_top = -lift
		_reaction_label.offset_bottom = -lift
	if _commentary != null:
		if _commentary_at_top:
			_pin(_commentary, Control.PRESET_TOP_LEFT, HUD_INSET_X, HUD_INSET_Y)
		else:
			_pin(_commentary, Control.PRESET_BOTTOM_LEFT, HUD_INSET_X, BOTTOM_LIFT)


var _commentary_at_top := false


## The prompt: what the keys do right now, as key caps along the bottom of the screen.
##
## It used to be one line of text with the gaps doing the work — "LEFT CLICK  in    RIGHT
## CLICK  out" — which the match still sends, unchanged. It is split back into its pairs
## here: two spaces between a key and what it does, three or more between pairs. Anything
## that is not a pair ("watch it") is shown as it came.
func _build_prompt() -> PanelContainer:
	_prompt_plate = PanelContainer.new()
	_prompt_plate.name = "Prompt"
	var skin := UiTheme.block(Color(UiTheme.INK.r, UiTheme.INK.g, UiTheme.INK.b, 0.86))
	skin.content_margin_left = 18
	skin.content_margin_right = 18
	skin.content_margin_top = 8
	skin.content_margin_bottom = 8
	skin.border_width_top = 3
	skin.border_color = UiTheme.ACCENT
	_prompt_plate.add_theme_stylebox_override("panel", skin)
	_prompt_plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_prompt_keys = HBoxContainer.new()
	_prompt_keys.add_theme_constant_override("separation", 26)
	_prompt_plate.add_child(_prompt_keys)
	# Kept for anything that reads the prompt as a sentence.
	_prompt_label = Label.new()
	_prompt_label.visible = false
	_prompt_plate.add_child(_prompt_label)
	_pin(_prompt_plate, Control.PRESET_CENTER_BOTTOM, 0, 18)
	_prompt_plate.visible = false
	return _prompt_plate


## The score, in whichever sport's broadcast layout this HUD is dressed for. See ScoreBug.
func set_score(board: Scoreboard, serving: Sides.Team) -> void:
	_score_bug.show_score(board, serving)


## The reviews each side has left, or nothing at all at the venues without Hawk-Eye —
## where the absence is itself information, because it means nobody can check you.
func set_reviews(red: int, blue: int, enabled: bool) -> void:
	_score_bug.show_reviews(red, blue, enabled)


func set_prompt(text: String) -> void:
	_prompt_label.text = text
	for child in _prompt_keys.get_children():
		_prompt_keys.remove_child(child)
		child.queue_free()
	_prompt_plate.visible = not text.strip_edges().is_empty()

	var pairs := RegEx.create_from_string("\\s{3,}")
	for part in pairs.sub(text.strip_edges(), "\t", true).split("\t", false):
		var split := part.find("  ")
		var key := part.substr(0, split).strip_edges() if split > 0 else ""
		var does := part.substr(split).strip_edges() if split > 0 else part.strip_edges()
		if key != key.to_upper():
			key = ""
			does = part.strip_edges()
		var pair := HBoxContainer.new()
		pair.add_theme_constant_override("separation", 10)
		if not key.is_empty():
			var cap := PanelContainer.new()
			var face := UiTheme.block(UiTheme.PAPER)
			face.content_margin_left = 12
			face.content_margin_right = 12
			face.content_margin_top = 0
			face.content_margin_bottom = 0
			face.border_width_bottom = 4
			face.border_color = _prompt_edge(does)
			cap.add_theme_stylebox_override("panel", face)
			cap.add_child(UiTheme.label(key, UiTheme.SMALL, UiTheme.INK, UiTheme.heavy()))
			pair.add_child(cap)
		pair.add_child(UiTheme.label(does.to_upper() if not key.is_empty() else does,
			UiTheme.BODY, UiTheme.CHALK, UiTheme.strong()))
		_prompt_keys.add_child(pair)


## Key caps with what they do, for the screens that have keys but no prompt bar.
func _key_hints(pairs: Array) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 20)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for pair in pairs:
		var cap := PanelContainer.new()
		var face := UiTheme.block(UiTheme.PAPER)
		face.content_margin_left = 10
		face.content_margin_right = 10
		face.content_margin_top = 0
		face.content_margin_bottom = 0
		cap.add_theme_stylebox_override("panel", face)
		cap.add_child(UiTheme.label(pair[0], UiTheme.SMALL - 2, UiTheme.INK, UiTheme.heavy()))
		row.add_child(cap)
		row.add_child(UiTheme.label(String(pair[1]).to_upper(), UiTheme.SMALL, UiTheme.MUTED, UiTheme.strong()))
	return row


## The line under a key cap: green for the calls that let play stand, red for the calls
## that stop it, and grey for everything else.
func _prompt_edge(does: String) -> Color:
	var word := does.strip_edges().to_lower()
	if word in ["in", "good"]:
		return UiTheme.GOOD
	if word in ["out", "fault"]:
		return UiTheme.BAD
	return UiTheme.PALE


## Shows what the umpire announced. Deliberately says nothing about whether it was
## true — only what was said, and what it did to the score.
func announce(text: String, tint: Color, seconds := 1.8) -> void:
	_message_label.text = text
	_message_label.add_theme_color_override("font_color", tint)
	_message_timer = seconds


## What the hall did in response to the call. Says nothing about whether the call
## was right — only what the people watching thought of it.
func react(line: String, seconds := 2.6) -> void:
	if line.is_empty():
		return
	_reaction_label.text = line
	_reaction_timer = seconds


## What the line judge called. `says_in` colours it: a judge who says a ball was good is
## agreeing with nobody in particular, and one who calls it out has just put a number on
## the board that you are about to either echo or contradict in public.
func show_line_judge(says_in: bool, seconds := 2.4) -> void:
	if _judge_label == null:
		return
	_judge_label.text = "IN" if says_in else "OUT"
	_judge_label.add_theme_color_override("font_color", UiTheme.GOOD if says_in else UiTheme.BAD)
	var chip := UiTheme.plate(UiTheme.GOOD if says_in else UiTheme.BAD, 0.88)
	chip.border_width_left = 8
	chip.skew = Vector2(UiTheme.LEAN, 0.0)
	_judge_plate.add_theme_stylebox_override("panel", chip)
	_judge_plate.visible = true
	_judge_timer = seconds


func hide_line_judge() -> void:
	if _judge_plate != null:
		_judge_plate.visible = false
	_judge_timer = 0.0


func show_banner(text: String, seconds := 5.0) -> void:
	_banner_label.text = text
	_banner_timer = seconds


# --- accusing somebody ---------------------------------------------------------
#
# Every one of these calls has to name a side, which is the awkward part: IN and OUT
# are about the shuttle, but a fault is about a person. Rather than invent a key
# combination for "net touch, against blue", the umpire points — and pointing at
# somebody is exactly the gesture being made.

func _build_fault_panel() -> void:
	_fault_panel = Control.new()
	_fault_panel.name = "FaultPanel"
	_fault_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fault_panel.visible = false
	_fault_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(_fault_panel)

	var backdrop := ColorRect.new()
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0.04, 0.05, 0.07, 0.62)
	_fault_panel.add_child(backdrop)

	var card := PanelContainer.new()
	card.set_anchors_preset(Control.PRESET_CENTER)
	card.grow_horizontal = Control.GROW_DIRECTION_BOTH
	card.grow_vertical = Control.GROW_DIRECTION_BOTH
	_fault_panel.add_child(card)
	_fault_rows = VBoxContainer.new()
	_fault_rows.alignment = BoxContainer.ALIGNMENT_CENTER
	_fault_rows.add_theme_constant_override("separation", 10)
	card.add_child(_fault_rows)


## Builds the list fresh each time, because between rallies there is no rally to
## fault anybody over — only misconduct, which can be punished whenever you like.
## Which sport's faults the panel offers. Badminton's by default; the two volleyballs
## set their own, because "four hits" means nothing on a badminton court and "carry"
## means nothing on a volleyball one.
var fault_book: Array = CallBook.faults()


## Whether this sport hands out cards. Badminton does; neither volleyball has them
## modelled yet, and offering a card the game cannot price would be worse than not
## offering one at all.
var offers_cards := true


func show_fault_panel(cards_only: bool) -> void:
	for child in _fault_rows.get_children():
		child.queue_free()

	_fault_rows.add_child(_make_label(
		"CARDS" if cards_only else "FAULT — AGAINST WHOM?", TITLE_SIZE - 6, Color(0.95, 0.95, 0.93)
	))
	_fault_rows.add_child(_make_label(
		"BLUE is on your left, RED on your right.        ESC to say nothing.",
		PROMPT_SIZE, Color(0.62, 0.64, 0.68)
	))

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 10)
	_fault_rows.add_child(spacer)

	if not cards_only:
		for call in fault_book:
			_fault_rows.add_child(_make_accusation_row(call.label, call.id, Color(0.90, 0.88, 0.84)))

	if offers_cards:
		_fault_rows.add_child(
			_make_accusation_row("YELLOW CARD", &"yellow", Color(0.95, 0.85, 0.30)))
		_fault_rows.add_child(
			_make_accusation_row("RED CARD", &"red", Color(0.94, 0.36, 0.32)))

	_fault_panel.visible = true


func _make_accusation_row(label: String, id: StringName, tint: Color) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 10)

	var name_label := _make_label(label, PROMPT_SIZE + 3, tint)
	name_label.custom_minimum_size = Vector2(320, 58)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(name_label)

	for team in [Sides.Team.BLUE, Sides.Team.RED]:
		var button := Button.new()
		button.text = Sides.label(team)
		button.custom_minimum_size = Vector2(170, 58)
		button.add_theme_color_override("font_color", Color.WHITE)
		button.add_theme_color_override("font_hover_color", Color.WHITE)
		var face := UiTheme.slant(Sides.colour(team).darkened(0.25))
		face.content_margin_top = 6
		face.content_margin_bottom = 6
		button.add_theme_stylebox_override("normal", face)
		var lit := UiTheme.slant(Sides.colour(team))
		lit.content_margin_top = 6
		lit.content_margin_bottom = 6
		button.add_theme_stylebox_override("hover", lit)
		button.add_theme_stylebox_override("focus", lit)
		button.add_theme_stylebox_override("pressed", lit)
		button.pressed.connect(func() -> void: punishment_chosen.emit(id, team))
		row.add_child(button)

	return row


func hide_fault_panel() -> void:
	_fault_panel.visible = false


func is_fault_panel_open() -> bool:
	return _fault_panel.visible


# --- the shuttle camera --------------------------------------------------------

func _build_shuttle_cam() -> void:
	_shuttle_cam_panel = Control.new()
	_shuttle_cam_panel.name = "ShuttleCam"
	_shuttle_cam_panel.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_shuttle_cam_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_shuttle_cam_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_shuttle_cam_panel.position = Vector2(-ShuttleCam.WIDTH - 26, -ShuttleCam.HEIGHT - 52)
	_shuttle_cam_panel.custom_minimum_size = Vector2(ShuttleCam.WIDTH, ShuttleCam.HEIGHT + 24)
	_shuttle_cam_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_shuttle_cam_panel.visible = false
	_root.add_child(_shuttle_cam_panel)

	var frame := ColorRect.new()
	frame.color = Color(0.04, 0.05, 0.06, 0.9)
	frame.position = Vector2(-3, -3)
	frame.size = Vector2(ShuttleCam.WIDTH + 6, ShuttleCam.HEIGHT + 6)
	_shuttle_cam_panel.add_child(frame)

	_shuttle_cam_view = TextureRect.new()
	_shuttle_cam_view.size = Vector2(ShuttleCam.WIDTH, ShuttleCam.HEIGHT)
	_shuttle_cam_view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_shuttle_cam_view.stretch_mode = TextureRect.STRETCH_SCALE
	_shuttle_cam_panel.add_child(_shuttle_cam_view)

	_close_cam_caption = _make_label(
		"SHUTTLE CAM", PROMPT_SIZE - 3, Color(0.72, 0.74, 0.78))
	_close_cam_caption.position = Vector2(0, ShuttleCam.HEIGHT + 4)
	_close_cam_caption.size = Vector2(ShuttleCam.WIDTH, 18)
	_shuttle_cam_panel.add_child(_close_cam_caption)


## Shows the line camera's view of where the shuttle came down. The picture is
## deliberately small: it settles the obvious ones and settles nothing else, which
## is the only way it can exist without answering the question for the player.
## The camera on the line, whatever is flying over it.
##
## Named for the shuttlecock because badminton was the only sport when it was written.
## Both volleyballs use the same panel for a ball, so these are the names to call it by;
## the shuttle_cam pair below remain as badminton's.
func show_close_cam(view: Texture2D, caption := "BALL CAM") -> void:
	if _close_cam_caption != null:
		_close_cam_caption.text = caption
	show_shuttle_cam(view)


func hide_close_cam() -> void:
	hide_shuttle_cam()


func show_shuttle_cam(view: Texture2D) -> void:
	if _shuttle_cam_view.texture != view:
		_shuttle_cam_view.texture = view
	_shuttle_cam_panel.visible = true


func hide_shuttle_cam() -> void:
	_shuttle_cam_panel.visible = false


# --- the end of the match ------------------------------------------------------

func _build_ending() -> void:
	_ending = Control.new()
	_ending.name = "Ending"
	_ending.set_anchors_preset(Control.PRESET_FULL_RECT)
	_ending.visible = false
	_ending.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(_ending)

	var backdrop := ColorRect.new()
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0.06, 0.03, 0.04, 0.96)
	_ending.add_child(backdrop)

	var card := PanelContainer.new()
	card.set_anchors_preset(Control.PRESET_CENTER)
	card.grow_horizontal = Control.GROW_DIRECTION_BOTH
	card.grow_vertical = Control.GROW_DIRECTION_BOTH
	_ending.add_child(card)
	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 22)
	column.custom_minimum_size = Vector2(900, 0)
	card.add_child(column)

	var tag := PanelContainer.new()
	tag.add_theme_stylebox_override("panel", UiTheme.slant(UiTheme.ACCENT))
	tag.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	tag.add_child(UiTheme.label("FULL TIME", UiTheme.HEADING, UiTheme.INK, UiTheme.display()))
	column.add_child(tag)
	_ending_headline = UiTheme.label("", UiTheme.HUGE, Color(0.96, 0.42, 0.36), UiTheme.display())
	column.add_child(_ending_headline)

	_ending_detail = _make_label("", PROMPT_SIZE + 2, Color(0.80, 0.80, 0.82))
	column.add_child(_ending_detail)

	column.add_child(_gap(18))
	_ending_button = _make_wide_button("CONTINUE", _after_the_result)
	var centred := HBoxContainer.new()
	centred.alignment = BoxContainer.ALIGNMENT_CENTER
	centred.add_child(_ending_button)
	column.add_child(centred)


## The reckoning. Once the match is over the truth is finally allowed on screen —
## this is the only place in the whole game where that is true.
## The last screen, and the only one allowed to state the truth.
##
## It puts everything else away first. Every other `show_*` in this file does that and
## this one did not — it set `_ending.visible = true` twice and hid nothing — so whatever
## happened to be on screen when the match ended stayed behind it: the score bug, the
## review that was still up at the moment you were taken off, and, coming from the title
## screen, the whole main menu reading through the sheet.
##
## `hide_menus` is deliberately not used. It turns the HUD back **on**, because it is
## what a match beginning calls.
func show_ending(headline: String, detail: String, tint := Color(0.96, 0.42, 0.36)) -> void:
	hide_sport_menu()
	hide_format_menu()
	hide_settings()
	hide_teaching()
	hide_career()
	hide_history()
	hide_review()
	hide_fault_panel()
	hide_close_cam()
	hide_briefing()
	hide_reputation()
	hide_reason()
	hide_bubble()
	hide_line_judge()
	hide_replay()
	clear_messages()
	_main_menu.visible = false
	_pause_menu.visible = false
	if _hud != null:
		_hud.visible = false

	_ending_headline.text = headline
	_ending_headline.add_theme_color_override("font_color", tint)
	_ending_detail.text = detail
	_ending.visible = true
	_focus_first(_ending)



## Takes the result screen down without going anywhere: the new hall is shown behind it
## before CONTINUE moves on.
func hide_ending() -> void:
	_ending.visible = false

# --- the replay of the worst calls ----------------------------------------------
#
# Played over an empty court after the final whistle and before the result. It is part of
# the end of the match, so it is allowed to say what was true — see `show_ending`. Laid
# out like a broadcast replay: what it is in the top left, the picture that settles it in
# the top right, and the words along the bottom.

const REPLAY_VIEW := 400
const REPLAY_INSET := 36

var _replay: Control
var _replay_title: Label
var _replay_count: Label
var _replay_said: Label
var _replay_truth: Label
var _replay_close: PanelContainer
var _replay_view: TextureRect


func _build_replay() -> void:
	_replay = Control.new()
	_replay.name = "Replay"
	_replay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_replay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_replay.visible = false
	_root.add_child(_replay)

	var badge := PanelContainer.new()
	badge.add_theme_stylebox_override("panel", UiTheme.plate(UiTheme.ACCENT, 0.90))
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	badge.position = Vector2(REPLAY_INSET, REPLAY_INSET)
	_replay.add_child(badge)
	var badge_stack := VBoxContainer.new()
	badge_stack.add_theme_constant_override("separation", 2)
	badge.add_child(badge_stack)
	var what := PanelContainer.new()
	what.add_theme_stylebox_override("panel", UiTheme.slant(UiTheme.ACCENT))
	what.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	what.add_child(UiTheme.label("REPLAY  \u2022  BALL TRACKING", UiTheme.SMALL, UiTheme.INK, UiTheme.heavy()))
	badge_stack.add_child(what)
	_replay_title = _make_label("", UiTheme.TITLE, UiTheme.CHALK)
	_replay_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	badge_stack.add_child(_replay_title)
	_replay_count = _make_label("", UiTheme.SMALL, UiTheme.MUTED)
	_replay_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	badge_stack.add_child(_replay_count)

	# The overhead picture, top right, shown only once the ball is down.
	_replay_close = PanelContainer.new()
	_replay_close.add_theme_stylebox_override("panel", UiTheme.plate(UiTheme.ACCENT, 0.90))
	_replay_close.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_replay_close.anchor_left = 1.0
	_replay_close.anchor_right = 1.0
	_replay_close.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_replay_close.offset_left = -REPLAY_INSET
	_replay_close.offset_right = -REPLAY_INSET
	_replay_close.offset_top = REPLAY_INSET
	_replay_close.visible = false
	_replay.add_child(_replay_close)
	var close_stack := VBoxContainer.new()
	close_stack.add_theme_constant_override("separation", 6)
	_replay_close.add_child(close_stack)
	close_stack.add_child(UiTheme.label("WHERE IT CAME DOWN", UiTheme.SMALL, UiTheme.ACCENT, UiTheme.heavy()))
	_replay_view = TextureRect.new()
	_replay_view.custom_minimum_size = Vector2(REPLAY_VIEW, REPLAY_VIEW)
	_replay_view.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_replay_view.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	close_stack.add_child(_replay_view)

	# The words, bottom centre: what you said, and underneath it what was true.
	var caption := PanelContainer.new()
	caption.add_theme_stylebox_override("panel", UiTheme.plate(UiTheme.ACCENT, 0.90))
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caption.anchor_left = 0.5
	caption.anchor_right = 0.5
	caption.anchor_top = 1.0
	caption.anchor_bottom = 1.0
	caption.grow_horizontal = Control.GROW_DIRECTION_BOTH
	caption.grow_vertical = Control.GROW_DIRECTION_BEGIN
	caption.offset_top = -REPLAY_INSET
	caption.offset_bottom = -REPLAY_INSET
	_replay.add_child(caption)
	var lines := VBoxContainer.new()
	lines.add_theme_constant_override("separation", 6)
	caption.add_child(lines)
	_replay_said = _make_label("", UiTheme.HEADING, UiTheme.CHALK)
	lines.add_child(_replay_said)
	_replay_truth = _make_label("", UiTheme.HEADING, UiTheme.ACCENT)
	lines.add_child(_replay_truth)
	lines.add_child(_centred(_key_hints([["SPACE", "next"], ["ESC", "skip them all"]])))

	# A way past them for the mouse as well, bottom right, out of the caption's way.
	var skip := _footer_button("SKIP REPLAYS", func() -> void: replay_skip_all.emit())
	skip.anchor_left = 1.0
	skip.anchor_right = 1.0
	skip.anchor_top = 1.0
	skip.anchor_bottom = 1.0
	skip.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	skip.grow_vertical = Control.GROW_DIRECTION_BEGIN
	skip.offset_left = -REPLAY_INSET
	skip.offset_right = -REPLAY_INSET
	skip.offset_top = -REPLAY_INSET
	skip.offset_bottom = -REPLAY_INSET
	_replay.add_child(skip)


## Puts up one replay, with only what you said filled in. The truth waits for the ball to
## come down — see `set_replay_truth`.
func show_replay(title: String, count: String, said: String) -> void:
	hide_close_cam()
	hide_review()
	hide_reputation()
	hide_reason()
	hide_bubble()
	hide_line_judge()
	clear_messages()
	if _hud != null:
		_hud.visible = false
	_replay_title.text = title
	_replay_count.text = count
	_replay_said.text = said
	_replay_truth.text = ""
	_replay_close.visible = false
	_replay.visible = true


func set_replay_truth(text: String) -> void:
	_replay_truth.text = text


func show_replay_close_up(view: Texture2D) -> void:
	_replay_view.texture = view
	_replay_close.visible = true


func hide_replay_close_up() -> void:
	_replay_close.visible = false


func hide_replay() -> void:
	if _replay != null:
		_replay.visible = false


# --- the next morning's paper ----------------------------------------------------
#
# Shown after the result screen, because it is the morning after. Printed in ink on paper
# rather than in the broadcast style of everything else, because it is the one thing in
# the game that is not happening in the hall.

const PAPER := Color(0.945, 0.925, 0.870)
const NEWSPRINT := Color(0.10, 0.10, 0.11)
const NEWSPRINT_GREY := Color(0.33, 0.32, 0.31)
const NEWSPRINT_RED := Color(0.70, 0.12, 0.09)
const FRONT_PAGE_WIDTH := 1180
const INSIDE_PAGE_WIDTH := 820
const PHOTO := 380

var _paper: Control
var _paper_column: VBoxContainer
var _paper_story := {}
var _paper_photo: Texture2D


func _build_newspaper() -> void:
	_paper = Control.new()
	_paper.name = "Newspaper"
	_paper.set_anchors_preset(Control.PRESET_FULL_RECT)
	_paper.mouse_filter = Control.MOUSE_FILTER_STOP
	_paper.visible = false
	_root.add_child(_paper)

	var backdrop := ColorRect.new()
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.color = Color(0.03, 0.03, 0.04, 0.97)
	_paper.add_child(backdrop)

	var centre := CenterContainer.new()
	centre.set_anchors_preset(Control.PRESET_FULL_RECT)
	_paper.add_child(centre)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override("separation", 22)
	centre.add_child(stack)

	var sheet := PanelContainer.new()
	var newsprint := StyleBoxFlat.new()
	newsprint.bg_color = PAPER
	newsprint.content_margin_left = 44
	newsprint.content_margin_right = 44
	newsprint.content_margin_top = 30
	newsprint.content_margin_bottom = 34
	newsprint.shadow_color = Color(0.0, 0.0, 0.0, 0.55)
	newsprint.shadow_size = 18
	sheet.add_theme_stylebox_override("panel", newsprint)
	stack.add_child(sheet)
	_paper_column = VBoxContainer.new()
	_paper_column.add_theme_constant_override("separation", 10)
	sheet.add_child(_paper_column)

	stack.add_child(_centred(_make_wide_button("CONTINUE", func() -> void:
		_paper.visible = false
		_paper_story = {}
		_paper_photo = null
		continue_requested.emit())))


## Holds the paper until the result screen has been read. `photo` is the overhead picture
## of the worst call, or null.
func queue_newspaper(story: Dictionary, photo: Texture2D) -> void:
	_paper_story = story
	_paper_photo = photo


func has_newspaper_waiting() -> bool:
	return not _paper_story.is_empty()


## CONTINUE on the result screen: the paper if there is one, and on otherwise.
func _after_the_result() -> void:
	if has_newspaper_waiting():
		_show_newspaper()
		return
	continue_requested.emit()


func _show_newspaper() -> void:
	for child in _paper_column.get_children():
		child.queue_free()
	var story := _paper_story
	var front: bool = story["front_page"]
	var width := FRONT_PAGE_WIDTH if front else INSIDE_PAGE_WIDTH

	_paper_column.add_child(_ink(story["title"], 76 if front else 42, _serif(true), NEWSPRINT,
		width, HORIZONTAL_ALIGNMENT_CENTER))
	_paper_column.add_child(_rule(width, 3))
	var dateline := HBoxContainer.new()
	var date := _ink(story["date"], 18, _serif(), NEWSPRINT_GREY)
	date.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dateline.add_child(date)
	dateline.add_child(_ink(story["section"], 18, _serif(true), NEWSPRINT_GREY))
	_paper_column.add_child(dateline)
	_paper_column.add_child(_rule(width, 1))
	_paper_column.add_child(_gap(4))

	_paper_column.add_child(_ink(story["kicker"], 24, _heavy(), NEWSPRINT_RED))
	_paper_column.add_child(_ink(story["headline"], 68 if front else 46, _heavy(), NEWSPRINT,
		width))
	if story["standfirst"] != "":
		_paper_column.add_child(_ink(story["standfirst"], 28, _serif(true), NEWSPRINT_GREY,
			width))
	_paper_column.add_child(_rule(width, 1))

	var body: Array = story["body"]
	if front and _paper_photo != null:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 26)
		var picture_column := VBoxContainer.new()
		picture_column.add_theme_constant_override("separation", 6)
		var picture := TextureRect.new()
		picture.texture = _paper_photo
		picture.custom_minimum_size = Vector2(PHOTO, PHOTO)
		picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
		picture_column.add_child(picture)
		picture_column.add_child(_ink(story["caption"], 18, _serif(), NEWSPRINT_GREY, PHOTO))
		row.add_child(picture_column)
		row.add_child(_paragraphs(body, width - PHOTO - 26))
		_paper_column.add_child(row)
	else:
		_paper_column.add_child(_paragraphs(body, width))

	_paper.visible = true


## The body of a story, one label a paragraph so there is air between them.
func _paragraphs(body: Array, width: int) -> VBoxContainer:
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	for paragraph in body:
		column.add_child(_ink(paragraph, 23, _serif(), NEWSPRINT, width))
	return column


## A label printed in ink. A width of zero means "as wide as the words".
func _ink(text: String, size: int, font: Font, colour: Color, width := 0,
		align := HORIZONTAL_ALIGNMENT_LEFT) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", colour)
	label.horizontal_alignment = align
	if width > 0:
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.custom_minimum_size = Vector2(width, 0)
	return label


func _rule(width: int, thickness: int) -> ColorRect:
	var line := ColorRect.new()
	line.color = NEWSPRINT
	line.custom_minimum_size = Vector2(width, thickness)
	return line


## The body type. Whatever serif the machine has; every desktop has one of these.
static func _serif(bold := false) -> SystemFont:
	var font := SystemFont.new()
	font.font_names = PackedStringArray(
		["Georgia", "Times New Roman", "Times", "Liberation Serif", "DejaVu Serif", "serif"])
	font.font_weight = 700 if bold else 400
	return font


## The headline type: condensed and heavy, the way a tabloid shouts. Since the broadcast
## redesign it is the game's own condensed face rather than whatever Impact the machine
## has — the paper stays a paper, set like a sports back page, and the story itself keeps
## its serif.
static func _heavy() -> Font:
	return UiTheme.heavy()



## Wraps a label in a dark plate and anchors the pair where it belongs.
func _plate_for(label: Label, preset: int, offset: Vector2, alpha := 0.80) -> PanelContainer:
	var plate := PanelContainer.new()
	plate.add_theme_stylebox_override("panel", UiTheme.plate(UiTheme.ACCENT, alpha))
	plate.set_anchors_preset(preset)
	plate.grow_horizontal = Control.GROW_DIRECTION_BOTH
	plate.grow_vertical = Control.GROW_DIRECTION_BOTH
	plate.position = offset
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.add_child(label)
	return plate


## The typeface follows the size, so no call site has to choose one: a title is in the
## slanted display cut, a heading in the heavy condensed one, and anything smaller is a
## sentence and gets the face built for reading.
func _make_label(text: String, size: int, colour: Color) -> Label:
	var font: Font = null
	if size >= UiTheme.TITLE - 6:
		font = UiTheme.display()
	elif size >= UiTheme.HEADING:
		font = UiTheme.heavy()
	return UiTheme.label(text, size, colour, font)


# --- the broadcast, over a cutscene ---------------------------------------------
#
# What the walk-on, the handshakes, being taken off and being moved up are dressed in:
# black bars top and bottom, and a lower third the way television puts a name on screen.
# The lower third is built from blocks, so the same caption can say a venue's name on its
# own or put RED and BLUE side by side in their colours — the teams are never named
# without their colour next to them anywhere else in the game either.

## How much of the screen each letterbox bar takes.
const LETTERBOX := 0.105
const BROADCAST_INSET := 48
const CAPTION_FADE := 0.25

var _broadcast: Control
var _bar_top: ColorRect
var _bar_bottom: ColorRect
var _lower_third: VBoxContainer
var _lower_kicker: Label
var _lower_blocks: HBoxContainer
var _lower_detail: Label
var _blackout: ColorRect
var _caption_tween: Tween


func _build_broadcast() -> void:
	_broadcast = Control.new()
	_broadcast.name = "Broadcast"
	_broadcast.set_anchors_preset(Control.PRESET_FULL_RECT)
	_broadcast.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_broadcast.visible = false
	_root.add_child(_broadcast)

	_bar_top = ColorRect.new()
	_bar_top.color = Color.BLACK
	_bar_top.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bar_top.anchor_right = 1.0
	_bar_top.anchor_bottom = LETTERBOX
	_broadcast.add_child(_bar_top)

	_bar_bottom = ColorRect.new()
	_bar_bottom.color = Color.BLACK
	_bar_bottom.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bar_bottom.anchor_top = 1.0 - LETTERBOX
	_bar_bottom.anchor_right = 1.0
	_bar_bottom.anchor_bottom = 1.0
	_broadcast.add_child(_bar_bottom)

	# Bottom left, sitting on the lower bar the way a name strap sits on the picture.
	_lower_third = VBoxContainer.new()
	_lower_third.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lower_third.add_theme_constant_override("separation", 0)
	_lower_third.anchor_top = 1.0 - LETTERBOX
	_lower_third.anchor_bottom = 1.0 - LETTERBOX
	_lower_third.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_lower_third.offset_left = BROADCAST_INSET
	_lower_third.offset_top = -18
	_lower_third.offset_bottom = -18
	_broadcast.add_child(_lower_third)

	var kicker_plate := PanelContainer.new()
	kicker_plate.add_theme_stylebox_override("panel", UiTheme.slant(UiTheme.ACCENT))
	kicker_plate.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_lower_third.add_child(kicker_plate)
	_lower_kicker = UiTheme.label("", UiTheme.SMALL, UiTheme.INK, UiTheme.heavy())
	kicker_plate.add_child(_lower_kicker)

	_lower_blocks = HBoxContainer.new()
	_lower_blocks.add_theme_constant_override("separation", 0)
	_lower_third.add_child(_lower_blocks)

	var detail_plate := PanelContainer.new()
	detail_plate.add_theme_stylebox_override("panel", UiTheme.block(UiTheme.CARD))
	detail_plate.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_lower_third.add_child(detail_plate)
	_lower_detail = _make_label("", UiTheme.BODY, UiTheme.CHALK)
	_lower_detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	detail_plate.add_child(_lower_detail)

	# Skipping, bottom right in the bar: the keys for the keyboard, a button for the mouse.
	var skip_row := HBoxContainer.new()
	skip_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	skip_row.add_theme_constant_override("separation", 22)
	skip_row.alignment = BoxContainer.ALIGNMENT_END
	skip_row.anchor_left = 1.0
	skip_row.anchor_right = 1.0
	skip_row.anchor_top = 1.0 - LETTERBOX * 0.5
	skip_row.anchor_bottom = 1.0 - LETTERBOX * 0.5
	skip_row.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	skip_row.grow_vertical = Control.GROW_DIRECTION_BOTH
	skip_row.offset_left = -BROADCAST_INSET
	skip_row.offset_right = -BROADCAST_INSET
	_broadcast.add_child(skip_row)
	skip_row.add_child(_key_hints([["SPACE", "skip"]]))
	skip_row.add_child(_footer_button("SKIP", func() -> void: cutscene_skip.emit()))

	# Over everything else in the broadcast, for a cut that needs to hide a jump.
	_blackout = ColorRect.new()
	_blackout.color = Color(0.0, 0.0, 0.0, 0.0)
	_blackout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_blackout.set_anchors_preset(Control.PRESET_FULL_RECT)
	_broadcast.add_child(_blackout)


## Bars on, the match's own screen furniture off.
func show_broadcast() -> void:
	hide_close_cam()
	hide_reputation()
	hide_reason()
	hide_bubble()
	hide_line_judge()
	clear_messages()
	set_prompt("")
	if _hud != null:
		_hud.visible = false
	hide_caption()
	_blackout.color.a = 0.0
	_broadcast.visible = true


func hide_broadcast() -> void:
	_broadcast.visible = false
	hide_caption()


func is_broadcasting() -> bool:
	return _broadcast != null and _broadcast.visible


## A lower third. `blocks` is a list of [text, colour] pairs laid side by side; a block
## with no colour is plain white type on the dark card.
func caption(kicker: String, blocks: Array, detail := "") -> void:
	_lower_kicker.text = "  %s  " % kicker
	_lower_kicker.get_parent().visible = not kicker.is_empty()
	for child in _lower_blocks.get_children():
		child.queue_free()
	for pair: Array in blocks:
		var plate := PanelContainer.new()
		var coloured := pair.size() > 1 and pair[1] is Color
		plate.add_theme_stylebox_override("panel",
			UiTheme.block(pair[1] if coloured else UiTheme.INK))
		var words := _make_label(pair[0], UiTheme.HUGE if blocks.size() == 1 else UiTheme.TITLE,
			UiTheme.CHALK)
		plate.add_child(words)
		_lower_blocks.add_child(plate)
	_lower_detail.text = detail
	_lower_detail.get_parent().visible = not detail.is_empty()

	if _caption_tween != null:
		_caption_tween.kill()
	_lower_third.modulate.a = 0.0
	_lower_third.visible = true
	_caption_tween = create_tween()
	_caption_tween.tween_property(_lower_third, "modulate:a", 1.0, CAPTION_FADE)


func hide_caption() -> void:
	if _caption_tween != null:
		_caption_tween.kill()
		_caption_tween = null
	if _lower_third != null:
		_lower_third.visible = false


## To black over `seconds`, or back from it.
func blackout(dark: bool, seconds: float) -> Tween:
	var tween := create_tween()
	tween.tween_property(_blackout, "color:a", 1.0 if dark else 0.0, maxf(seconds, 0.01))
	return tween

