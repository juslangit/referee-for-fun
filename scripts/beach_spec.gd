class_name BeachSpec
extends RefCounted

## Official FIVB beach volleyball court dimensions, in metres.
##
## The same contract as CourtSpec, and for the same reason: the court the player looks
## at is built from these numbers and the in/out judgement is made from these numbers,
## so the line on the sand is exactly the line the game judges against. If those ever
## disagreed the player would be lying without meaning to, which is the one bug this
## game cannot survive.
##
## Axes match badminton so everything downstream reads the same way: +Z runs down the
## length, +X across the width, +Y is up, and the net sits at z = 0.
##
## Two differences from badminton worth knowing, because they change how the game feels
## rather than only how it measures:
##
##   The court has **no service courts and no short service line.** A beach serve may
##   land anywhere in the opponent's half, so there is no equivalent of the doubles
##   long service line that caused so much trouble in badminton — the only boundary
##   that matters is the outside of the court.
##
##   The boundary lines are **ropes or tape lying on the sand, 5 to 8 cm wide**, and a
##   ball touching any part of one is IN. Same rule as badminton, wider line.

## Half the full court length. Full court is 16 m — shorter than an indoor court.
const HALF_LENGTH := 8.0

## Half the width. Full court is 8 m.
const HALF_WIDTH := 4.0

## The tape lying on the sand. Beach uses a wider line than badminton's painted 40 mm.
const LINE_WIDTH := 0.06

## Net height. The men's net; the women's is 2.24.
const NET_HEIGHT := 2.43

## How far down the net hangs from its top tape. A beach net is a metre deep.
const NET_DEPTH := 1.00

## The posts stand a metre outside the sideline, so nobody runs into them.
const POST_X := HALF_WIDTH + 1.0

## The antennae: flexible rods on the net, level with each sideline, marking the outer
## edge of the space a ball may legally cross through. A ball outside them is out even
## if it lands in the court, which is a call this game will eventually want.
const ANTENNA_X := HALF_WIDTH
const ANTENNA_HEIGHT := 0.80

## The free zone: the sand outside the lines that is still in play. A beach player may
## chase a ball well beyond the court and put it back, and the crowd sits behind it.
const FREE_ZONE := 5.0

## How close to the boundary still counts as on it. Same reasoning as badminton's:
## far smaller than anything anyone could see, far larger than the error that float
## arithmetic accumulates over a few hundred physics steps.
const LINE_TOLERANCE := 0.0001


## Was the ball in?
##
## A ball touching any part of a line is in, and the court is measured to the outer
## edge of the tape — so, as in badminton, the boundary is the nominal number with
## nothing to add or subtract.
static func is_in(landing: Vector3) -> bool:
	return (
		absf(landing.x) <= HALF_WIDTH + LINE_TOLERANCE
		and absf(landing.z) <= HALF_LENGTH + LINE_TOLERANCE
	)


## How far the ball was from the nearest line, in metres. Positive inside, negative out.
##
## The most important number in the sport as this game plays it: it is not what decides
## in or out — is_in() does that — it is what decides how *obvious* the truth was, and
## therefore what a lie about it costs.
static func margin(landing: Vector3) -> float:
	var slack_x := HALF_WIDTH - absf(landing.x)
	var slack_z := HALF_LENGTH - absf(landing.z)

	if slack_x < 0.0 or slack_z < 0.0:
		var overshoot := Vector2(maxf(0.0, -slack_x), maxf(0.0, -slack_z))
		return -overshoot.length()

	return minf(slack_x, slack_z)


## Whether a ball crossed the net inside the antennae. Outside them it is out of play
## however cleanly it lands, which is the one boundary in this sport that is vertical.
static func inside_the_antennae(crossing: Vector3) -> bool:
	return absf(crossing.x) <= ANTENNA_X + LINE_TOLERANCE
