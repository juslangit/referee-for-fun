extends Challenge

## For the trailer's review shot only: whoever a call goes against always asks for a review,
## while they have one left. Everything after that — the replay, the answer, the hall — is
## the game's own. A real side challenges a wrong call between a third and nine-tenths of
## the time, and a take that waits for one is a take that may have nothing in it.

func who_challenges(lost: Sides.Team, _wrong: bool, _visibility: float,
		_margin: float) -> Sides.Team:
	if lost == Sides.Team.NONE or remaining(lost) <= 0:
		return Sides.Team.NONE
	return lost
