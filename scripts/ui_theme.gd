class_name UiTheme
extends RefCounted

## The look of the whole interface, in one place.
##
## It is dressed as a sports broadcast, because that is what the player is inside: the
## score sits in a bug at the top of the screen the way it does on television, panels
## are flat charcoal cards with a coloured edge, and the two teams are never named
## without their colour next to them. The point is not decoration. An umpire has to
## read the score and the prompt in the middle of a rally, and a broadcast graphic is
## a design that has already been solved for exactly that — high contrast, heavy type,
## nothing thin, nothing that needs looking at twice.
##
## Everything lives on a Theme rather than on the individual controls. Six hundred
## lines of per-control font size overrides is how the interface got small and stayed
## small: there was no single number to change.

## The palette. Deliberately few colours — a broadcast graphic that uses six is a mess.
const INK := Color(0.055, 0.062, 0.078)
const CARD := Color(0.105, 0.118, 0.145)
const RAISED := Color(0.152, 0.170, 0.205)
const EDGE := Color(0.255, 0.285, 0.340)
const CHALK := Color(0.955, 0.960, 0.975)
const MUTED := Color(0.660, 0.700, 0.760)
const ACCENT := Color(1.000, 0.760, 0.180)
const RED := Color(0.880, 0.240, 0.220)
const BLUE := Color(0.250, 0.520, 0.920)

## Every size in the interface is a multiple of these, so the whole thing grows and
## shrinks together. They were roughly two thirds of this and the interface was too
## small to read from a chair.
const HUGE := 66
const TITLE := 46
const HEADING := 30
const BODY := 26
const SMALL := 22

## How tall a button is and how wide the wide ones are. A button you have to aim at is
## a button you will miss in the middle of a rally.
const BUTTON_HEIGHT := 66
const BUTTON_WIDTH := 460


static func build() -> Theme:
	var theme := Theme.new()
	theme.default_font_size = BODY

	_style_buttons(theme)
	_style_panels(theme)
	theme.set_color("font_color", "Label", CHALK)
	theme.set_font_size("font_size", "Label", BODY)
	return theme


static func _style_buttons(theme: Theme) -> void:
	# A bar of colour down the leading edge that brightens on hover. It reads as a
	# broadcast caption, and it gives the button an obvious focus state without
	# resorting to an outline, which at this size looks like a mistake.
	theme.set_stylebox("normal", "Button", _button_style(RAISED, ACCENT.darkened(0.45)))
	theme.set_stylebox("hover", "Button", _button_style(RAISED.lightened(0.14), ACCENT))
	theme.set_stylebox("pressed", "Button", _button_style(RAISED.darkened(0.22), ACCENT))
	theme.set_stylebox("focus", "Button", _button_style(RAISED.lightened(0.06), ACCENT))
	theme.set_stylebox("disabled", "Button", _button_style(CARD, EDGE.darkened(0.4)))

	theme.set_color("font_color", "Button", CHALK)
	theme.set_color("font_hover_color", "Button", Color.WHITE)
	theme.set_color("font_pressed_color", "Button", ACCENT)
	theme.set_color("font_focus_color", "Button", Color.WHITE)
	theme.set_color("font_disabled_color", "Button", MUTED.darkened(0.35))
	theme.set_font_size("font_size", "Button", HEADING)
	theme.set_constant("h_separation", "Button", 12)


static func _button_style(fill: Color, edge: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.set_content_margin_all(14)
	box.content_margin_left = 26
	box.content_margin_right = 26
	# Square, except for a hint on the trailing corners. Sport graphics are not round.
	box.corner_radius_top_right = 4
	box.corner_radius_bottom_right = 4
	box.border_width_left = 7
	box.border_color = edge
	return box


static func _style_panels(theme: Theme) -> void:
	var card := StyleBoxFlat.new()
	card.bg_color = CARD
	card.set_content_margin_all(28)
	card.border_width_top = 4
	card.border_color = ACCENT
	card.corner_radius_bottom_left = 5
	card.corner_radius_bottom_right = 5
	theme.set_stylebox("panel", "PanelContainer", card)

	var plain := StyleBoxFlat.new()
	plain.bg_color = CARD
	plain.set_content_margin_all(20)
	theme.set_stylebox("panel", "Panel", plain)


## A plate for a line of HUD text: dark, slightly transparent, with a coloured edge.
## Used for anything that has to stay readable over a lit green court, which is
## everything — white text on that background is legible about half the time.
static func plate(edge := ACCENT, alpha := 0.80) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(INK.r, INK.g, INK.b, alpha)
	box.content_margin_left = 26
	box.content_margin_right = 26
	box.content_margin_top = 12
	box.content_margin_bottom = 12
	box.border_width_left = 6
	box.border_color = edge
	return box


## A solid block of a team's colour, for the score bug.
static func block(colour: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = colour
	box.content_margin_left = 20
	box.content_margin_right = 20
	box.content_margin_top = 8
	box.content_margin_bottom = 8
	return box
