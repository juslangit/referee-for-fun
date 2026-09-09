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

## What settling a grudge costs you, on top of whatever the wrong calls already cost.
##
## Charged only when you actually leaned on the match to do it. Nobody finds out — this
## is not the hall noticing, it is the fact that an umpire who has once refereed a man
## out of a tournament for personal reasons is a different umpire afterwards. It is the
## only thing in this game you are charged for that has no witness.
const DAMAGE_FROM_SETTLING_A_SCORE := 0.10

## How badly you have to have robbed somebody before they remember your name.
const GRUDGE_FROM_LEAN := 0.30

## Which sports there are. The id is what the save file and the sport menu use.
const BADMINTON := &"badminton"
const BEACH := &"beach"
const INDOOR := &"indoor"

## The venues, in order, for each sport.
##
## **One reputation, a ladder each.** You are one official with one name, so being
## caught at a beach tournament means arriving at the badminton hall already suspect —
## but you climb each sport separately, because a licence is per sport and nobody is
## promoted to an international volleyball final on the strength of their badminton.
##
## `scrutiny` multiplies everything suspicion charges you. `matches_needed` is how
## many you have to get through without being thrown off before they move you up, and
## `reputation_needed` is the character reference required to go with it.
const BADMINTON_LADDER := [
	{
		"name": "School hall",
		"crowd": 0.18,
		"blurb": "Two line judges, a camera, and nobody much watching.",
		"line_judges": true,
		"close_cam": true,
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
		"close_cam": true,
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
		"close_cam": true,
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
		"close_cam": true,
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
		"close_cam": true,
		"hawk_eye": true,
		"quick": false,
		"dressing": Venue.Tier.ARENA,
		"scrutiny": 1.55,
		"matches_needed": 0,
		"reputation_needed": 1.0,
	},
]

## Beach volleyball. Two a side, outdoors, and a shorter climb to a bigger stage than
## badminton has — there are far fewer beach tournaments in the world, so the ones that
## exist are watched harder.
const BEACH_LADDER := [
	{
		"name": "Beach club court",
		"crowd": 0.14,
		"blurb": "A public court with a rope round it. Somebody's dad is keeping score.",
		"line_judges": false,
		"close_cam": true,
		"hawk_eye": false,
		"quick": true,
		"dressing": Venue.Tier.SCHOOL,
		"scrutiny": 0.60,
		"matches_needed": 2,
		"reputation_needed": 0.40,
	},
	{
		"name": "Regional beach open",
		"crowd": 0.34,
		"blurb": "Two line judges and a scoreboard that works. People have brought chairs.",
		"line_judges": true,
		"close_cam": true,
		"hawk_eye": false,
		"quick": true,
		"dressing": Venue.Tier.SCHOOL,
		"scrutiny": 0.85,
		"matches_needed": 2,
		"reputation_needed": 0.50,
	},
	{
		"name": "National beach series",
		"crowd": 0.56,
		"blurb": "Best of three, and a stand along one side that fills up by the second set.",
		"line_judges": true,
		"close_cam": true,
		"hawk_eye": false,
		"quick": false,
		"dressing": Venue.Tier.REGIONAL,
		"scrutiny": 1.05,
		"matches_needed": 3,
		"reputation_needed": 0.55,
	},
	{
		"name": "World tour",
		"crowd": 0.82,
		"blurb": "Stadium sand, a full stand, and both sides carrying a video challenge.",
		"line_judges": true,
		"close_cam": true,
		"hawk_eye": true,
		"quick": false,
		"dressing": Venue.Tier.REGIONAL,
		"scrutiny": 1.30,
		"matches_needed": 3,
		"reputation_needed": 0.60,
	},
	{
		"name": "World tour finals",
		"crowd": 1.0,
		"blurb": "Every touch you give or do not give will be looked at again by somebody.",
		"line_judges": true,
		"close_cam": true,
		"hawk_eye": true,
		"quick": false,
		"dressing": Venue.Tier.ARENA,
		"scrutiny": 1.60,
		"matches_needed": 0,
		"reputation_needed": 1.0,
	},
]

## Indoor volleyball. A hall sport, so the venues are the badminton ladder's kind of
## place rather than the beach's — but the scrutiny climbs faster, because six players a
## side means six times as many people who know exactly where they were standing.
const INDOOR_LADDER := [
	{
		"name": "Sports hall",
		"crowd": 0.16,
		"blurb": "A school hall with the badminton posts still stacked against the wall.",
		# Two of them from the first rung, as badminton's school hall has. Indoor
		# volleyball is refereed by a crew even at league level, and a first venue with
		# nobody on the lines reads as a bug rather than as a small occasion.
		"line_judges": true,
		"close_cam": true,
		"hawk_eye": false,
		"quick": true,
		"dressing": Venue.Tier.SCHOOL,
		"scrutiny": 0.65,
		"matches_needed": 2,
		"reputation_needed": 0.40,
	},
	{
		"name": "Regional league",
		"crowd": 0.36,
		"blurb": "Two benches who have both brought a scoresheet and know how to read it.",
		"line_judges": true,
		"close_cam": true,
		"hawk_eye": false,
		"quick": true,
		"dressing": Venue.Tier.SCHOOL,
		"scrutiny": 0.90,
		"matches_needed": 2,
		"reputation_needed": 0.50,
	},
	{
		"name": "National league",
		"crowd": 0.58,
		"blurb": "Best of five. Long enough for a lineup to catch you out twice.",
		"line_judges": true,
		"close_cam": true,
		"hawk_eye": false,
		"quick": false,
		"dressing": Venue.Tier.REGIONAL,
		"scrutiny": 1.10,
		"matches_needed": 3,
		"reputation_needed": 0.55,
	},
	{
		"name": "Champions cup",
		"crowd": 0.84,
		"blurb": "Both coaches have the rotation on a tablet and neither of them blinks.",
		"line_judges": true,
		"close_cam": true,
		"hawk_eye": true,
		"quick": false,
		"dressing": Venue.Tier.REGIONAL,
		"scrutiny": 1.35,
		"matches_needed": 3,
		"reputation_needed": 0.60,
	},
	{
		"name": "World championship",
		"crowd": 1.0,
		"blurb": "Everything you say about where six people were standing will be checked.",
		"line_judges": true,
		"close_cam": true,
		"hawk_eye": true,
		"quick": false,
		"dressing": Venue.Tier.ARENA,
		"scrutiny": 1.60,
		"matches_needed": 0,
		"reputation_needed": 1.0,
	},
]

const LADDERS := {
	BADMINTON: BADMINTON_LADDER,
	BEACH: BEACH_LADDER,
	INDOOR: INDOOR_LADDER,
}


## Which sport this career is currently being asked about. Set by the sport menu, and
## saved, so coming back to the game puts you where you left off.
var sport := BADMINTON

## Where you have got to in each sport: tier, matches at that tier, and whether the
## appointments panel has vouched for you there. Reputation is deliberately *not* in
## here — there is only one of you.
var progress := {}

## Where you are on the ladder of the sport you are currently refereeing.
##
## These read and write through `progress`, so every caller that was written when there
## was only one sport still says `career.tier` and still means the right thing.
var tier: int:
	get:
		return int(_here()["tier"])
	set(value):
		_here()["tier"] = value

var matches_at_tier: int:
	get:
		return int(_here()["matches_at_tier"])
	set(value):
		_here()["matches_at_tier"] = value

## Set when the appointments panel watched a quiet match. It waives the character
## reference for one promotion — you did not persuade them you were accurate, because
## nobody can see that. You persuaded them you were no trouble. Per sport, because it
## is a particular sport's panel that was in the room.
var panel_impressed: bool:
	get:
		return bool(_here()["panel_impressed"])
	set(value):
		_here()["panel_impressed"] = value


## This sport's row of `progress`, made if it is not there yet.
func _here() -> Dictionary:
	if not progress.has(sport):
		progress[sport] = {"tier": 0, "matches_at_tier": 0, "panel_impressed": false}
	return progress[sport]


## Every sport's ladder, and this one's.
static func ladder_for(which: StringName) -> Array:
	return LADDERS.get(which, BADMINTON_LADDER)


func ladder() -> Array:
	return ladder_for(sport)


var reputation := 1.0
var matches_refereed := 0
var times_removed := 0
var is_over := false

## A player who has not forgotten something you did to them, and what it was. Carried
## between matches, which is the point of it: the consequence of a match you refereed
## badly turns up in a later one as a temptation to do it again.
var grudge_name := ""
var grudge_reason := ""

## Set for one screen after a match, so the result can say what just happened.
var last_result := ""


func venue() -> Dictionary:
	var rungs := ladder()
	return rungs[clampi(tier, 0, rungs.size() - 1)]


func at_the_top() -> bool:
	return tier >= ladder().size() - 1


## Folds one finished match into the career, and returns what to tell the player.
func finish_match(suspicion_level: float, removed: bool, pressures: Array = []) -> String:
	matches_refereed += 1

	var change := REPAIR_EACH_MATCH - suspicion_level * DAMAGE_FROM_SUSPICION
	if removed:
		change -= DAMAGE_FROM_REMOVAL
		times_removed += 1

	var lines: Array[String] = []

	# What the people leaning on you made of it. Applied before the promotion is
	# considered, because two of them change whether there is one.
	#
	# Each pressure knows what it does to a career; this file does not know what kinds
	# of pressure exist. That is not tidiness for its own sake — Pressure has to name
	# Career to read the ladder, so if Career named Pressure back neither would compile.
	for pressure in pressures:
		change += pressure.apply_to(self, lines)

	reputation = clampf(reputation + change, 0.0, 1.0)

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

	var vouched_for := reputation >= bar or panel_impressed

	if not at_the_top() and matches_at_tier >= needed and vouched_for:
		if reputation < bar:
			lines.append("The panel put their name to you. Nobody read the rest of the file.")
		tier += 1
		matches_at_tier = 0
		panel_impressed = false
		lines.append("You have been moved up to the %s." % ladder()[tier]["name"])
	elif not at_the_top() and matches_at_tier >= needed:
		lines.append("They would move you up, but not with a reputation like that.")

	last_result = "\n".join(lines)
	return last_result


## Whether this match made somebody an enemy, and who.
##
## Called after the reckoning. A grudge forms when the umpire visibly robbed one side
## more than once and did it consistently — a single unlucky call is forgotten, and
## mistakes that went both ways read as a bad night rather than a bent one.
func remember_grudge(name: String, wrong_calls: int, stolen: int, lean: float) -> void:
	if not grudge_name.is_empty():
		return
	if stolen < 1 or absf(lean) < GRUDGE_FROM_LEAN:
		return

	grudge_name = name
	if stolen >= 3:
		grudge_reason = "You took three rallies off them in one match and they counted every one."
	elif wrong_calls >= 3:
		grudge_reason = "They spent a whole match querying your calls and you never gave them one."
	else:
		grudge_reason = "You called a shuttle out that they knew was in, at 19-all, and they said so to a camera."


# --- saving --------------------------------------------------------------------

func save() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		push_warning("Could not write the career to %s" % SAVE_PATH)
		return
	file.store_string(JSON.stringify({
		"version": 2,
		"sport": String(sport),
		"progress": progress,
		"reputation": reputation,
		"matches_refereed": matches_refereed,
		"times_removed": times_removed,
		"is_over": is_over,
		"grudge_name": grudge_name,
		"grudge_reason": grudge_reason,
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

	career.reputation = float(parsed.get("reputation", 1.0))
	career.matches_refereed = int(parsed.get("matches_refereed", 0))
	career.times_removed = int(parsed.get("times_removed", 0))
	career.is_over = bool(parsed.get("is_over", false))
	career.grudge_name = String(parsed.get("grudge_name", ""))
	career.grudge_reason = String(parsed.get("grudge_reason", ""))
	career.sport = StringName(parsed.get("sport", String(BADMINTON)))

	if parsed.has("progress"):
		# JSON has no integers and no StringNames, so everything comes back as a float
		# keyed by a plain String. Rebuilt rather than assigned, or `tier` comes out as
		# 2.0 and every comparison against a rung index quietly stops working.
		for name in parsed["progress"]:
			var row: Dictionary = parsed["progress"][name]
			career.progress[StringName(name)] = {
				"tier": int(row.get("tier", 0)),
				"matches_at_tier": int(row.get("matches_at_tier", 0)),
				"panel_impressed": bool(row.get("panel_impressed", false)),
			}
		return career

	# A save from before there was more than one sport. Everything in it was badminton.
	career.progress[BADMINTON] = {
		"tier": int(parsed.get("tier", 0)),
		"matches_at_tier": int(parsed.get("matches_at_tier", 0)),
		"panel_impressed": bool(parsed.get("panel_impressed", false)),
	}
	return career


## Wipes the save and starts again. Used when a career has ended.
static func start_again() -> Career:
	if FileAccess.file_exists(SAVE_PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	return Career.new()
