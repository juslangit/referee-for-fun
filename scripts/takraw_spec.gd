class_name TakrawSpec
extends RefCounted

## ISTAF sepak takraw court dimensions, in metres — the Law of the Game 2024, Regu edition,
## Laws 1 to 4. The research behind every number is in dev/ref/takraw/research.md.
##
## The same contract as every other spec in this game: the court on screen is drawn from
## these numbers and the in/out truth is judged from them, so the line the player sees is
## the line the game judges against.
##
## Axes match the other sports: +Z runs down the length, +X across the width, +Y is up,
## and the net sits at z = 0.
##
## The court is **the badminton doubles court exactly**, 13.4 × 6.1 m, which is why sepak
## takraw fits this game's chair so well. What it adds is two kinds of circle, and they are
## the reason the referee's job is different: the serving side's feet are held in them until
## the ball is kicked, and a foot that leaves one is a fault only the officials are placed to
## see.

## Half the length. The full court is 13.4 m.
const HALF_LENGTH := 6.7

## Half the width. The full court is 6.1 m.
const HALF_WIDTH := 3.05

## Every line is at most 4 cm wide and drawn **inwards** from the court's edge (Law 1.1), so
## the lines are part of the court and a ball on one is in. The centre line is 2 cm.
const LINE_WIDTH := 0.04
const CENTRE_LINE_WIDTH := 0.02

## The service circle: radius 30 cm, its centre 2.45 m from the back line and in the middle
## of the width (Law 1.4). The tekong's standing foot must stay in it, on the floor, until
## the kick. Regu only — doubles serves from behind the back line.
const SERVICE_CIRCLE_RADIUS := 0.30
const SERVICE_CIRCLE_FROM_BACK := 2.45

## The quarter circles at the net: radius 90 cm, centred on the corner where each sideline
## meets the centre line (Law 1.3). The serving side's two inside players stand in them
## while the ball is thrown. Regu only.
const QUARTER_CIRCLE_RADIUS := 0.90

## The net: 1.52 m at the centre for men, 1.55 m at the posts, 70 cm deep (Laws 3.2, 3.5).
## The game plays the men's height, as it does in every sport.
const NET_HEIGHT := 1.52
const NET_HEIGHT_AT_POST := 1.55
const NET_DEPTH := 0.70

## The posts stand 30 cm outside each sideline, level with the centre line (Law 2.2).
const POST_X := HALF_WIDTH + 0.30

## The side bands: 5 cm tapes standing up from the net above each sideline. They are part
## of the net (Law 3.3), so the ball has to cross between them.
const SIDE_BAND_X := HALF_WIDTH
const SIDE_BAND_HEIGHT := 0.40

## The free zone: 3 m clear beyond every line, up to the low advertising boards (Law 1.5).
const FREE_ZONE := 3.0

## The ball: woven synthetic fibre, 41 to 43 cm round for men (Law 4), so about 13.4 cm
## across. On television it is yellow.
const BALL_RADIUS := 0.067

## How close to a boundary still counts as on it: far smaller than anything anybody could
## see, far larger than the error float arithmetic builds up over a rally.
const LINE_TOLERANCE := 0.0001


## Was the ball in? The lines are inside the court, so the boundary is the court's own edge.
static func is_in(landing: Vector3) -> bool:
	return (
		absf(landing.x) <= HALF_WIDTH + LINE_TOLERANCE
		and absf(landing.z) <= HALF_LENGTH + LINE_TOLERANCE
	)


## How far from the nearest line, in metres. Positive inside, negative outside. Not what
## decides in or out — `is_in` does — but how *obvious* the truth was, which is what a lie
## about it costs.
static func margin(landing: Vector3) -> float:
	var slack_x := HALF_WIDTH - absf(landing.x)
	var slack_z := HALF_LENGTH - absf(landing.z)
	if slack_x < 0.0 or slack_z < 0.0:
		var overshoot := Vector2(maxf(0.0, -slack_x), maxf(0.0, -slack_z))
		return -overshoot.length()
	return minf(slack_x, slack_z)


## The centre of a side's service circle. `side` is Sides.half_sign of that team.
static func service_circle(side: float) -> Vector3:
	return Vector3(0.0, 0.0, side * (HALF_LENGTH - SERVICE_CIRCLE_FROM_BACK))


## The centre of one of a side's quarter circles: the corner of sideline and centre line.
## `across` is -1 or +1 for which sideline.
static func quarter_circle(side: float, across: float) -> Vector3:
	return Vector3(across * HALF_WIDTH, 0.0, side * 0.0)


## Whether a ball crossed the net between the side bands. Outside them it is a fault
## however cleanly it lands.
static func between_the_bands(crossing_x: float) -> bool:
	return absf(crossing_x) <= SIDE_BAND_X + BALL_RADIUS
