class_name VolleySpec
extends RefCounted

## Official FIVB indoor volleyball court dimensions, in metres.
##
## Same contract as CourtSpec and BeachSpec: the court the player looks at is built from
## these numbers and the in/out judgement is made from these numbers, so the line on the
## floor is exactly the line the game judges against.
##
## Axes as everywhere else: +Z down the length, +X across, +Y up, net at z = 0.
##
## Bigger than the beach court in every direction — 18 by 9 against 16 by 8 — and it has
## a line the beach does not: the **attack line**, three metres back from the net. That
## line is the whole reason indoor volleyball is harder to referee than beach. It does
## nothing to the ball. It only matters in relation to *who* is standing behind it, and
## who that is changes every time a side wins the serve back.

## Half the full court length. Full court is 18 m.
const HALF_LENGTH := 9.0

## Half the width. Full court is 9 m.
const HALF_WIDTH := 4.5

## How far the attack line is from the net. A back-row player may not attack the ball
## above the net if they took off in front of this.
const ATTACK_LINE := 3.0

## Painted line width. Indoor uses 5 cm.
const LINE_WIDTH := 0.05

## Net height at the centre. The men's net; the women's is 2.24.
const NET_HEIGHT := 2.43
const NET_DEPTH := 1.00

## The posts stand a metre outside the sideline.
const POST_X := HALF_WIDTH + 1.0

## The antennae, level with each sideline. A ball crossing outside one is out however
## cleanly it lands.
const ANTENNA_X := HALF_WIDTH
const ANTENNA_HEIGHT := 0.80

## The free zone, which is in play. Smaller than the beach's, because there is a wall.
const FREE_ZONE := 4.0

## How close to the boundary still counts as on it. Same reasoning as the other two.
const LINE_TOLERANCE := 0.0001


static func is_in(landing: Vector3) -> bool:
	return (
		absf(landing.x) <= HALF_WIDTH + LINE_TOLERANCE
		and absf(landing.z) <= HALF_LENGTH + LINE_TOLERANCE
	)


static func margin(landing: Vector3) -> float:
	var slack_x := HALF_WIDTH - absf(landing.x)
	var slack_z := HALF_LENGTH - absf(landing.z)
	if slack_x < 0.0 or slack_z < 0.0:
		var overshoot := Vector2(maxf(0.0, -slack_x), maxf(0.0, -slack_z))
		return -overshoot.length()
	return minf(slack_x, slack_z)


## Whether a point on the floor is in front of the attack line — the front zone, where
## a back-row player may not take off to attack.
static func in_front_zone(point: Vector3, half: float) -> bool:
	return absf(point.z) < ATTACK_LINE and signf(point.z) == signf(half)


static func inside_the_antennae(crossing: Vector3) -> bool:
	return absf(crossing.x) <= ANTENNA_X + LINE_TOLERANCE
