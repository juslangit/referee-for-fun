class_name Pressure
extends RefCounted

## Why an umpire would ever lie.
##
## The game has always asked you to pick a side before the match and never given you a
## reason to. That is the wrong way round. A bent umpire is almost never somebody who
## woke up wanting to cheat — they are somebody who found themselves with a reason, and
## the reason arrived before the temptation did.
##
## The obvious reason is money, and money is deliberately not in this game. An envelope
## turns the umpire into a criminal, and once they are a criminal the only interesting
## question — *would you?* — has already been answered for the player. Everything here
## is instead a pressure an ordinary honest person would recognise, and **none of it is
## ever phrased as an instruction to cheat.** Nobody asks you to lie. They mention which
## result would be convenient, and then leave you alone in the chair with it.
##
## There are four, and they push in genuinely different directions:
##
##   TOURNAMENT wants a particular player to win, because the event needs them.
##   PROMOTION wants no controversy at all, which pushes you towards the popular call
##     rather than the correct one — the only pressure here that is not about a team.
##   GRUDGE wants somebody to lose, and pays you nothing whatsoever for it.
##   DEBT is your own first honest mistake, and it is the one you make for yourself.
##
## The important rule, and the thing that keeps this from being a bribe with the serial
## numbers filed off: **the reward is for the result, not for the lie.** If the player
## the tournament wanted wins the match fairly, you are thanked exactly the same. You
## can be honest and lucky. What the pressure actually does is make you care about the
## scoreline, and an umpire who cares about the scoreline is already halfway there.

enum Kind {
	## No pressure this match. Somebody has to referee the ordinary ones.
	NONE,
	## The event needs a particular name to go through.
	TOURNAMENT,
	## The people who decide appointments are in the hall, and they want a quiet match.
	PROMOTION,
	## Somebody out there is a player you have history with.
	GRUDGE,
	## Your own first wrong call, and the pull to put it right by getting a second one
	## wrong the other way. This one is not handed to you before the match — you make
	## it yourself, halfway through, without meaning to.
	DEBT,
}

enum Outcome {
	## The match is not over yet.
	PENDING,
	## The pressure got what it wanted.
	SATISFIED,
	## It did not.
	DEFIED,
}

## How likely a match is to come with a reason attached, by rung of the ladder. A
## school hall is nobody's problem; an international final is everybody's.
const CHANCE_BY_TIER := [0.15, 0.30, 0.45, 0.60, 0.80]

## How loud the hall has to get before the appointments panel counts it as a fuss.
## Sits just under the point where the crowd turns openly hostile, so a couple of
## close calls that annoy people are survivable and a pattern is not.
const QUIET_ENOUGH := 0.40

## How obvious a wrong call has to be before the umpire is allowed to know they made it.
##
## This number is load-bearing, and it is set high on purpose. The one rule this whole
## game is built on is that the screen never tells you whether you were right — the
## moment it does, there is nothing left to judge. A debt has to be something you
## *noticed*, so it is only ever taken on when the call was plain enough that the entire
## hall saw it too: a shuttle well out, given in, in front of everybody.
##
## Below this line you may well have got it wrong and you will never be told, exactly as
## before. The game is not opening its books here. It is telling you what the room
## already knows.
const DEBT_NOTICED := 0.55

## Players you might end up with history against. Not real athletes.
const NAMES := [
	"Rahim", "Sundara", "Petersen", "Wibowo", "Halim",
	"Novak", "Kwan", "Larsen", "Aditya", "Mensah",
	"Okafor", "Villanueva", "Bergstrom", "Nakamura",
]

var kind := Kind.NONE

## Who this pressure wants to win. NONE for PROMOTION, which wants a quiet match
## rather than a result, and for DEBT, which is set when the mistake happens.
var wants := Sides.Team.NONE

## The side with a reason to watch you closely. Their player challenges more and
## argues more, which is what having somebody's attention actually feels like.
var watched := Sides.Team.NONE

## The player's name, where there is one.
var who := ""

var headline := ""
var detail := ""

## The single line that stays with you. Shown on its own, in the colour of whoever
## stands to gain, because that is the part you will be thinking about at 19-all.
var ask := ""

var outcome := Outcome.PENDING

## Which way the umpire's mistakes leaned, once the match is over. NONE if they went
## both ways, which is what an honestly incompetent match looks like.
var leaned := Sides.Team.NONE


## The pressure this match comes with, if any.
##
## An outstanding grudge always wins, because it is already true and does not need to
## be invented. Otherwise the tournament or the appointments panel, and mostly neither.
static func for_match(career: Career) -> Pressure:
	if career != null and not career.grudge_name.is_empty():
		return _grudge(career)

	var tier: int = 0 if career == null else clampi(career.tier, 0, CHANCE_BY_TIER.size() - 1)
	if randf() > CHANCE_BY_TIER[tier]:
		return Pressure.new()

	# The panel only leans on you when there is something to lean on you about — that
	# is, when you are one match away from being moved up.
	if career != null and _promotion_is_close(career) and randf() < 0.5:
		return _promotion(career)
	return _tournament()


static func _promotion_is_close(career: Career) -> bool:
	if career.at_the_top():
		return false
	var here := career.venue()
	return career.matches_at_tier + 1 >= int(here["matches_needed"])


static func _tournament() -> Pressure:
	var pressure := Pressure.new()
	pressure.kind = Kind.TOURNAMENT
	pressure.wants = Sides.Team.RED if randf() < 0.5 else Sides.Team.BLUE
	pressure.watched = Sides.opponent(pressure.wants)
	pressure.who = NAMES.pick_random()

	var side := Sides.label(pressure.wants)
	var reasons := [
		{
			"headline": "A word before you go out",
			"detail": ("The tournament referee catches you by the scorers' table. Half the "
				+ "seats in this hall were sold on %s being in the final, and the sponsor's "
				+ "people are in the third row. He does not ask you for anything. He tells "
				+ "you the situation, pats your arm, and goes back to his clipboard."
				) % pressure.who,
		},
		{
			"headline": "The schedule is gone",
			"detail": ("You are ninety minutes behind and the hall has to be empty by ten. "
				+ "Everybody wants this one over. A short match is a convenient match, and "
				+ "%s in two straight games would be very short indeed.") % pressure.who,
		},
		{
			"headline": "Somebody flew a long way",
			"detail": ("%s is the reason the cameras came. Their federation paid for the "
				+ "trip, the broadcaster built the evening around them, and they are "
				+ "seeded to be here tomorrow. Nobody has said a word to you about it. "
				+ "You can feel it from the chair anyway.") % pressure.who,
		},
	]
	var picked: Dictionary = reasons.pick_random()
	pressure.headline = picked["headline"]
	pressure.detail = picked["detail"]
	pressure.ask = "The event needs %s (%s) to go through." % [pressure.who, side]
	return pressure


static func _promotion(career: Career) -> Pressure:
	var pressure := Pressure.new()
	pressure.kind = Kind.PROMOTION
	pressure.headline = "They are watching you, not the match"

	var next_up := "the next level"
	if not career.at_the_top():
		next_up = String(Career.LADDER[career.tier + 1]["name"])

	pressure.detail = ("Two people from the appointments panel are sitting behind the "
		+ "officials' table with your file open. This is the match that decides whether "
		+ "you go up to the %s. They are not marking your accuracy — nobody in that "
		+ "chair can mark your accuracy. They are marking whether anything happened. "
		+ "An umpire nobody argued with is an umpire they can send anywhere."
		) % next_up
	pressure.ask = "Give them a match nobody talks about."
	return pressure


static func _grudge(career: Career) -> Pressure:
	var pressure := Pressure.new()
	pressure.kind = Kind.GRUDGE
	pressure.who = career.grudge_name
	# They could be wearing either colour today. Players move; grudges do not.
	pressure.wants = Sides.Team.RED if randf() < 0.5 else Sides.Team.BLUE
	pressure.watched = Sides.opponent(pressure.wants)
	pressure.headline = "You know one of them"

	pressure.detail = ("%s is playing for %s tonight, and has not forgotten you. %s "
		+ "They shook your hand at the toss without looking up. You have the chair and "
		+ "they have the racket, and for the next hour every close call in this hall "
		+ "belongs to you.") % [
			pressure.who,
			Sides.label(pressure.watched),
			career.grudge_reason,
		]
	pressure.ask = "Nothing is riding on this except how you feel about %s." % pressure.who
	return pressure


## The debt you take on the first time you plainly get one wrong.
##
## Nobody hands you this one. You make the error honestly — the shuttle was fast, the
## angle was bad, you were sure — and now a player is a point down because of you, and
## there is an obvious way to put it right that involves getting a second one wrong on
## purpose. The game already makes that second lie cheap: suspicion charges you for
## being wrong in a *pattern*, so a mistake the other way genuinely does cost less than
## another one the same way. This is simply the moment the player is told.
##
## It is the most honest trap in the game, because the player builds it themselves.
static func debt_from(rally: Rally, owed_to: Sides.Team) -> Pressure:
	var pressure := Pressure.new()
	pressure.kind = Kind.DEBT
	pressure.wants = owed_to
	pressure.watched = owed_to
	pressure.headline = "You got that one wrong"
	pressure.detail = ("%s are a point down and it was not the shuttle's fault. There "
		+ "is a way to put that right and both of you know what it is."
		) % Sides.label(owed_to)
	pressure.ask = "%s are owed one." % Sides.label(owed_to)
	# Keeps the rally that caused it, so the reckoning can be specific.
	pressure.set_meta("margin", rally.margin)
	return pressure


func exists() -> bool:
	return kind != Kind.NONE


## Whether this pressure got what it wanted. Called once, when the match ends.
##
## `evened_up` is only meaningful for a debt: it says whether the umpire went on to get
## a second call wrong in the other direction, which the match watches for as it happens.
func resolve(board: Scoreboard, suspicion: Suspicion, evened_up := false) -> void:
	if absf(suspicion.lean) >= 0.15:
		leaned = Sides.Team.BLUE if suspicion.lean > 0.0 else Sides.Team.RED

	match kind:
		Kind.NONE:
			outcome = Outcome.PENDING
		Kind.TOURNAMENT:
			outcome = Outcome.SATISFIED if _won(board, wants) else Outcome.DEFIED
		Kind.PROMOTION:
			outcome = Outcome.SATISFIED if suspicion.peak < QUIET_ENOUGH else Outcome.DEFIED
		Kind.GRUDGE:
			# Satisfied means you got what you wanted out of them, which is the one
			# outcome in this game that is worth nothing at all.
			outcome = Outcome.SATISFIED if not _won(board, watched) else Outcome.DEFIED
		Kind.DEBT:
			outcome = Outcome.SATISFIED if evened_up else Outcome.DEFIED


func _won(board: Scoreboard, team: Sides.Team) -> bool:
	if board == null or team == Sides.Team.NONE:
		return false
	return int(board.games.get(team, 0)) > int(board.games.get(Sides.opponent(team), 0))


## What to tell the player afterwards. The match is over, so this is allowed to be blunt.
func verdict_line() -> String:
	match kind:
		Kind.TOURNAMENT:
			if outcome == Outcome.SATISFIED and leaned == wants:
				return "%s went through, and your mistakes all went their way. The referee thanks you warmly. He does not look at you while he does it." % who
			if outcome == Outcome.SATISFIED:
				return "%s went through on their own. The referee thanks you as though you had something to do with it." % who
			return "%s is out. Nobody says anything to you about it, which is worse." % who
		Kind.PROMOTION:
			if outcome == Outcome.SATISFIED:
				return "The panel closed your file early and went to get a coffee. Nothing happened out there, which is exactly what they came to see."
			return "The panel stayed to the end and wrote for a while afterwards."
		Kind.GRUDGE:
			if outcome == Outcome.SATISFIED and leaned == wants:
				return "%s lost, and you helped. You have wanted that for a month and it lasted about four seconds." % who
			if outcome == Outcome.SATISFIED:
				return "%s lost, fairly, and you had nothing to do with it. Best possible version of this." % who
			return "%s won. You shake their hand at the end and neither of you means it." % who
		Kind.DEBT:
			if outcome == Outcome.SATISFIED:
				return "You evened it up. Two wrong calls instead of one, and the score is where it would have been if you had made neither."
			return "You never gave it back. One wrong call, left standing, which is the most an honest umpire can hope for."
	return ""


## What one pressure did to the career, and the line to show for it.
##
## Note what is *not* here: nothing pays you for lying. The tournament thanks you when
## their player goes through, whether you helped or not, and the panel promotes you for
## a quiet match however honestly you kept it quiet. **The reward is always for the
## result.** That is the whole trick of the system — it never asks you to cheat, it only
## makes you care about something other than the truth, and leaves the rest to you.
func apply_to(career, lines: Array[String]) -> float:
	if not exists():
		return 0.0

	var satisfied := outcome == Outcome.SATISFIED
	lines.append(verdict_line())

	match kind:
		Kind.TOURNAMENT:
			if satisfied:
				# An extra match's credit at this level. You are useful, and useful
				# officials get appointed.
				career.matches_at_tier += 1
			else:
				# Not a punishment anybody would admit to. You simply stop being asked.
				career.matches_at_tier = 0
			return 0.0

		Kind.PROMOTION:
			if satisfied:
				career.panel_impressed = true
			else:
				career.matches_at_tier = maxi(0, career.matches_at_tier - 1)
			return 0.0

		Kind.GRUDGE:
			# The grudge is spent either way — you have had your match against them.
			career.grudge_name = ""
			career.grudge_reason = ""
			if satisfied and leaned == wants:
				lines.append("Nobody saw that. You will know about it for a while.")
				return -Career.DAMAGE_FROM_SETTLING_A_SCORE
			return 0.0

	# A debt costs nothing extra. Both wrong calls have already been paid for at the
	# time, and charging again for the second one would be charging twice for the
	# same lie. What it leaves behind is a player who remembers.
	return 0.0

