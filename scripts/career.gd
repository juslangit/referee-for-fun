class_name Career
extends RefCounted

## A refereeing career, and the thing that finally gives cheating a cost that
## outlives the match it happened in.
##
## Until now every match started from nothing. You could be thrown off court for
## inventing three red cards and the next match would greet you as a stranger. A
## reputation that follows you between matches is what turns a run of small lies into
## a decision worth making: each one spends something you cannot easily earn back,
## and when it runs out there is no next match at all.
##
## The ladder also decides how closely you are watched. A school hall has nobody
## officiating but you and nobody much watching either. An international final has
## line judges, a camera on the line, and a room full of people who came to see this
## particular match. **The same lie is nearly free at the bottom and career-ending at
## the top**, which is the whole reason to climb.

const SAVE_PATH := "user://career.json"

## Every match repairs a little and costs a little, and the two are always both
## applied. That is deliberate, and it is the whole shape of a career.
##
## Repairing only after a spotless match made reputation a ratchet that turned one
## way: an umpire who shaved a couple of close calls a match could never get back a
## single point, and died in eight matches having done nothing dramatic. With both
## applied there is a break-even — about 0.13 of suspicion a match — **below which
## you can cheat quietly forever, and above which you are spending a career you
## cannot earn back fast enough.** Finding that line is the game.
const REPAIR_EACH_MATCH := 0.06
const DAMAGE_FROM_SUSPICION := 0.45

## What being thrown off a match costs on top of all that. Enough that two removals
## will end most careers on their own.
const DAMAGE_FROM_REMOVAL := 0.35

## The venues, in order.
##
## `scrutiny` multiplies everything suspicion charges you. `matches_needed` is how
## many you have to get through without being thrown off before they move you up, and
## `reputation_needed` is the character reference required to go with it.
const LADDER := [
	{
		"name": "School hall",
		"crowd": 0.18,
		"blurb": "Two line judges, a camera, and nobody much watching.",
		"line_judges": true,
		"shuttle_cam": true,
		"hawk_eye": false,
		"quick": true,
		"dressing": Venue.Tier.SCHOOL,
		"scrutiny": 0.65,
		"matches_needed": 2,
		"reputation_needed": 0.40,
	},
	{
		"name": "District championship",
		"crowd": 0.35,
		"blurb": "Two line judges now. Somebody is keeping score of more than the score.",
		"line_judges": true,
		"shuttle_cam": true,
		"hawk_eye": false,
		"quick": true,
		"dressing": Venue.Tier.SCHOOL,
		"scrutiny": 0.85,
		"matches_needed": 2,
		"reputation_needed": 0.50,
	},
	{
		"name": "State open",
		"crowd": 0.55,
		"blurb": "Full matches, best of three. Long enough for a pattern to show.",
		"line_judges": true,
		"shuttle_cam": true,
		"hawk_eye": false,
		"quick": false,
		"dressing": Venue.Tier.REGIONAL,
		"scrutiny": 1.0,
		"matches_needed": 3,
		"reputation_needed": 0.55,
	},
	{
		"name": "National championship",
		"crowd": 0.8,
		"blurb": "A proper hall, and a crowd big enough to hear when it turns.",
		"line_judges": true,
		"shuttle_cam": true,
		"hawk_eye": true,
		"quick": false,
		"dressing": Venue.Tier.REGIONAL,
		"scrutiny": 1.25,
		"matches_needed": 3,
		"reputation_needed": 0.60,
	},
	{
		"name": "International final",
		"crowd": 1.0,
		"blurb": "Every call you make will be looked at again by somebody.",
		"line_judges": true,
		"shuttle_cam": true,
		"hawk_eye": true,
		"quick": false,
		"dressing": Venue.Tier.ARENA,
		"scrutiny": 1.55,
		"matches_needed": 0,
		"reputation_needed": 1.0,
	},
]

var tier := 0
var reputation := 1.0
var matches_at_tier := 0
var matches_refereed := 0
var times_removed := 0
var is_over := false

## Set for one screen after a match, so the result can say what just happened.
var last_result := ""


func venue() -> Dictionary:
	return LADDER[clampi(tier, 0, LADDER.size() - 1)]


func at_the_top() -> bool:
	return tier >= LADDER.size() - 1


## Folds one finished match into the career, and returns what to tell the player.
func finish_match(suspicion_level: float, removed: bool) -> String:
	matches_refereed += 1

	var change := REPAIR_EACH_MATCH - suspicion_level * DAMAGE_FROM_SUSPICION
	if removed:
		change -= DAMAGE_FROM_REMOVAL
		times_removed += 1

	reputation = clampf(reputation + change, 0.0, 1.0)

	var lines: Array[String] = []

	if removed:
		lines.append("Taken off the match.")
	elif change > 0.0:
		lines.append("A quiet match. Nobody had anything to say about you.")
	elif change > -0.05:
		lines.append("You got through it. It cost you a little.")
	else:
		lines.append("You got through it, but that was expensive.")

	if reputation <= 0.0:
		is_over = true
		lines.append("Your reputation is gone. Nobody will appoint you again.")
		last_result = "\n".join(lines)
		return last_result

	# Only matches you saw out count towards moving up.
	if not removed:
		matches_at_tier += 1

	var here := venue()
	var needed: int = here["matches_needed"]
	var bar: float = here["reputation_needed"]

	if not at_the_top() and matches_at_tier >= needed and reputation >= bar:
		tier += 1
		matches_at_tier = 0
		lines.append("You have been moved up to the %s." % LADDER[tier]["name"])
	elif not at_the_top() and matches_at_tier >= needed:
		lines.append("They would move you up, but not with a reputation like that.")

	last_result = "\n".join(lines)
	return last_result


# --- saving --------------------------------------------------------------------

func save() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("Could not write the career to %s" % SAVE_PATH)
		return
	file.store_string(JSON.stringify({
		"tier": tier,
		"reputation": reputation,
		"matches_at_tier": matches_at_tier,
		"matches_refereed": matches_refereed,
		"times_removed": times_removed,
		"is_over": is_over,
	}, "\t"))


static func load_or_start() -> Career:
	var career := Career.new()
	if not FileAccess.file_exists(SAVE_PATH):
		return career

	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		return career

	var parsed = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		return career

	career.tier = int(parsed.get("tier", 0))
	career.reputation = float(parsed.get("reputation", 1.0))
	career.matches_at_tier = int(parsed.get("matches_at_tier", 0))
	career.matches_refereed = int(parsed.get("matches_refereed", 0))
	career.times_removed = int(parsed.get("times_removed", 0))
	career.is_over = bool(parsed.get("is_over", false))
	return career


## Wipes the save and starts again. Used when a career has ended.
static func start_again() -> Career:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	return Career.new()
