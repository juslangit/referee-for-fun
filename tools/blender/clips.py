"""The animations, as poses.

A clip is a list of `(frame, pose)`. A pose names bones and gives each an XYZ
rotation in degrees; any bone not named goes back to rest. `root` and `hips` may take
six numbers instead of three — three degrees of rotation and then a local offset — so
a character can crouch, bob or lunge without the feet leaving the floor.

Bones point head-to-tail along their own Y. For an upright bone like the spine that
means X bends it forward and back, Z twists it. For an arm hanging down it is the
other way about. Rather than reason about that, these numbers were set by rendering
the poses and looking at them, which is in `preview_poses.py`.

Frame 1 is the start of every clip and, for anything that loops, the last frame
repeats it.
"""

# A right-handed player. R is the racket arm.

_STAND = {}

_READY = {
    "hips": (0, 0, 0, 0, -0.055, 0),
    "spine": (12, 0, 0),
    "chest": (5, 0, 0),
    "head": (-9, 0, 0),
    "thigh.L": (-26, 0, 0), "shin.L": (44, 0, 0), "foot.L": (-18, 0, 0),
    "thigh.R": (-26, 0, 0), "shin.R": (44, 0, 0), "foot.R": (-18, 0, 0),
    "upper_arm.R": (-52, 0, -26), "forearm.R": (-64, 0, 0),
    "upper_arm.L": (-30, 0, 18), "forearm.L": (-40, 0, 0),
}


def _pose(base, **changes):
    """A pose built from another one, so a swing can say only what a swing changes."""
    made = dict(base)
    made.update(changes)
    return made


CLIPS = {
    # Standing about between rallies, breathing.
    "idle": dict(loop=True, keys=[
        (1, {"spine": (3, 0, 0), "head": (-2, 0, 0),
             "upper_arm.L": (0, 0, 6), "upper_arm.R": (0, 0, -6)}),
        (40, {"spine": (5, 0, 2), "head": (-4, 0, -2), "chest": (2, 0, 0),
              "upper_arm.L": (-4, 0, 8), "upper_arm.R": (-4, 0, -8)}),
        (80, {"spine": (3, 0, 0), "head": (-2, 0, 0),
              "upper_arm.L": (0, 0, 6), "upper_arm.R": (0, 0, -6)}),
    ]),

    # Waiting for the serve: knees bent, weight forward, racket up.
    "ready": dict(loop=True, keys=[
        (1, _READY),
        (26, _pose(_READY, hips=(0, 0, 0, 0, -0.075, 0), spine=(15, 0, 0),
                   **{"upper_arm.R": (-56, 0, -28)})),
        (52, _READY),
    ]),

    # Chasing the shuttle.
    "run": dict(loop=True, keys=[
        (1, {"spine": (16, 0, 0), "head": (-12, 0, 0), "hips": (0, 0, 0, 0, -0.02, 0),
             "thigh.L": (-42, 0, 0), "shin.L": (30, 0, 0), "foot.L": (-14, 0, 0),
             "thigh.R": (30, 0, 0), "shin.R": (58, 0, 0), "foot.R": (10, 0, 0),
             "upper_arm.L": (-58, 0, 12), "forearm.L": (-72, 0, 0),
             "upper_arm.R": (44, 0, -12), "forearm.R": (-52, 0, 0)}),
        (9, {"spine": (16, 0, 0), "head": (-12, 0, 0), "hips": (0, 0, 0, 0, -0.06, 0),
             "thigh.L": (-8, 0, 0), "shin.L": (20, 0, 0),
             "thigh.R": (-4, 0, 0), "shin.R": (34, 0, 0),
             "upper_arm.L": (-20, 0, 10), "forearm.L": (-60, 0, 0),
             "upper_arm.R": (10, 0, -10), "forearm.R": (-58, 0, 0)}),
        (17, {"spine": (16, 0, 0), "head": (-12, 0, 0), "hips": (0, 0, 0, 0, -0.02, 0),
              "thigh.L": (30, 0, 0), "shin.L": (58, 0, 0), "foot.L": (10, 0, 0),
              "thigh.R": (-42, 0, 0), "shin.R": (30, 0, 0), "foot.R": (-14, 0, 0),
              "upper_arm.L": (44, 0, 12), "forearm.L": (-52, 0, 0),
              "upper_arm.R": (-58, 0, -12), "forearm.R": (-72, 0, 0)}),
        (25, {"spine": (16, 0, 0), "head": (-12, 0, 0), "hips": (0, 0, 0, 0, -0.06, 0),
              "thigh.L": (-4, 0, 0), "shin.L": (34, 0, 0),
              "thigh.R": (-8, 0, 0), "shin.R": (20, 0, 0),
              "upper_arm.L": (10, 0, 10), "forearm.L": (-58, 0, 0),
              "upper_arm.R": (-20, 0, -10), "forearm.R": (-60, 0, 0)}),
        (33, {"spine": (16, 0, 0), "head": (-12, 0, 0), "hips": (0, 0, 0, 0, -0.02, 0),
              "thigh.L": (-42, 0, 0), "shin.L": (30, 0, 0), "foot.L": (-14, 0, 0),
              "thigh.R": (30, 0, 0), "shin.R": (58, 0, 0), "foot.R": (10, 0, 0),
              "upper_arm.L": (-58, 0, 12), "forearm.L": (-72, 0, 0),
              "upper_arm.R": (44, 0, -12), "forearm.R": (-52, 0, 0)}),
    ]),

    # Getting somewhere in a hurry, without the panic.
    "walk": dict(loop=True, keys=[
        (1, {"spine": (5, 0, 0),
             "thigh.L": (-22, 0, 0), "shin.L": (10, 0, 0),
             "thigh.R": (18, 0, 0), "shin.R": (26, 0, 0),
             "upper_arm.L": (-20, 0, 8), "upper_arm.R": (16, 0, -8)}),
        (16, {"spine": (5, 0, 0), "hips": (0, 0, 0, 0, -0.02, 0),
              "thigh.L": (0, 0, 0), "shin.L": (12, 0, 0),
              "thigh.R": (0, 0, 0), "shin.R": (14, 0, 0),
              "upper_arm.L": (0, 0, 8), "upper_arm.R": (0, 0, -8)}),
        (32, {"spine": (5, 0, 0),
              "thigh.L": (18, 0, 0), "shin.L": (26, 0, 0),
              "thigh.R": (-22, 0, 0), "shin.R": (10, 0, 0),
              "upper_arm.L": (16, 0, 8), "upper_arm.R": (-20, 0, -8)}),
        (48, {"spine": (5, 0, 0), "hips": (0, 0, 0, 0, -0.02, 0),
              "thigh.L": (0, 0, 0), "shin.L": (14, 0, 0),
              "thigh.R": (0, 0, 0), "shin.R": (12, 0, 0),
              "upper_arm.L": (0, 0, 8), "upper_arm.R": (0, 0, -8)}),
        (64, {"spine": (5, 0, 0),
              "thigh.L": (-22, 0, 0), "shin.L": (10, 0, 0),
              "thigh.R": (18, 0, 0), "shin.R": (26, 0, 0),
              "upper_arm.L": (-20, 0, 8), "upper_arm.R": (16, 0, -8)}),
    ]),

    # Reaching for a drop shot at the net.
    "lunge": dict(loop=False, keys=[
        (1, _READY),
        (10, {"hips": (0, 0, 0, 0, -0.16, 0), "spine": (30, 0, 0), "chest": (8, 0, 0),
              "head": (-22, 0, 0),
              "thigh.R": (-64, 0, 0), "shin.R": (54, 0, 0), "foot.R": (-26, 0, 0),
              "thigh.L": (22, 0, 0), "shin.L": (16, 0, 0), "foot.L": (18, 0, 0),
              "upper_arm.R": (-88, 0, -34), "forearm.R": (-24, 0, 0),
              "upper_arm.L": (30, 0, 30)}),
        (34, {"hips": (0, 0, 0, 0, -0.17, 0), "spine": (32, 0, 0), "head": (-24, 0, 0),
              "thigh.R": (-66, 0, 0), "shin.R": (56, 0, 0), "foot.R": (-26, 0, 0),
              "thigh.L": (24, 0, 0), "shin.L": (16, 0, 0), "foot.L": (18, 0, 0),
              "upper_arm.R": (-92, 0, -34), "forearm.R": (-20, 0, 0),
              "upper_arm.L": (32, 0, 30)}),
        (54, _READY),
    ]),

    # A forehand from the racket side.
    "forehand": dict(loop=False, keys=[
        (1, _READY),
        (8, _pose(_READY, chest=(0, -26, 0), spine=(8, -18, 0),
                  **{
                     "upper_arm.R": (-38, 0, -70), "forearm.R": (-86, 0, 0),
                     "upper_arm.L": (-20, 0, 34)})),
        (18, _pose(_READY, chest=(0, 30, 0), spine=(14, 22, 0),
                   **{
                      "upper_arm.R": (-96, 0, 30), "forearm.R": (-10, 0, 0),
                      "upper_arm.L": (18, 0, 10)})),
        (40, _READY),
    ]),

    # A backhand, across the body.
    "backhand": dict(loop=False, keys=[
        (1, _READY),
        (8, _pose(_READY, chest=(0, 30, 0), spine=(10, 20, 0),
                  **{
                     "upper_arm.R": (-70, 0, 62), "forearm.R": (-96, 0, 0),
                     "upper_arm.L": (10, 0, -20)})),
        (18, _pose(_READY, chest=(0, -26, 0), spine=(12, -18, 0),
                   **{
                      "upper_arm.R": (-92, 0, -34), "forearm.R": (-14, 0, 0),
                      "upper_arm.L": (16, 0, 26)})),
        (40, _READY),
    ]),

    # Overhead. The one shot in badminton everybody recognises.
    "smash": dict(loop=False, keys=[
        (1, _READY),
        (10, {"hips": (0, 0, 0, 0, -0.03, 0), "spine": (-22, -14, 0),
              "chest": (-12, -18, 0), "head": (12, 0, 0),
              "thigh.R": (-14, 0, 0), "shin.R": (26, 0, 0),
              "thigh.L": (-30, 0, 0), "shin.L": (36, 0, 0),
              "upper_arm.R": (-16, 0, -128), "forearm.R": (-100, 0, 0),
              "upper_arm.L": (-30, 0, 96), "forearm.L": (-30, 0, 0)}),
        (19, {"hips": (0, 0, 0, 0, -0.01, 0), "spine": (26, 10, 0),
              "chest": (14, 12, 0), "head": (-20, 0, 0),
              "thigh.R": (-20, 0, 0), "shin.R": (30, 0, 0),
              "thigh.L": (-18, 0, 0), "shin.L": (28, 0, 0),
              "upper_arm.R": (-118, 0, -8), "forearm.R": (-16, 0, 0),
              "upper_arm.L": (34, 0, 22)}),
        (46, _READY),
    ]),

    # A low serve, which is how most rallies actually start.
    "serve": dict(loop=False, keys=[
        (1, {"spine": (6, -10, 0), "head": (-8, 0, 0),
             "thigh.L": (-12, 0, 0), "shin.L": (18, 0, 0),
             "thigh.R": (-6, 0, 0), "shin.R": (10, 0, 0),
             "upper_arm.R": (-30, 0, -48), "forearm.R": (-72, 0, 0),
             "upper_arm.L": (-56, 0, 26), "forearm.L": (-46, 0, 0)}),
        (14, {"spine": (10, 8, 0), "head": (-12, 0, 0),
              "thigh.L": (-14, 0, 0), "shin.L": (20, 0, 0),
              "upper_arm.R": (-72, 0, 10), "forearm.R": (-26, 0, 0),
              "upper_arm.L": (-16, 0, 18)}),
        (40, _READY),
    ]),

    # Winning a point.
    "celebrate": dict(loop=False, keys=[
        (1, _STAND),
        (9, {"spine": (-14, 0, 0), "chest": (-8, 0, 0), "head": (16, 0, 0),
             "thigh.L": (-16, 0, 0), "shin.L": (22, 0, 0),
             "thigh.R": (-16, 0, 0), "shin.R": (22, 0, 0),
             "upper_arm.L": (-30, 0, 116), "forearm.L": (-92, 0, 0),
             "upper_arm.R": (-30, 0, -116), "forearm.R": (-92, 0, 0)}),
        (22, {"spine": (-18, 0, 0), "head": (18, 0, 0),
              "upper_arm.L": (-20, 0, 128), "forearm.L": (-46, 0, 0),
              "upper_arm.R": (-20, 0, -128), "forearm.R": (-46, 0, 0)}),
        (52, _STAND),
    ]),

    # Between rallies, out of breath.
    "tired": dict(loop=True, keys=[
        (1, {"spine": (26, 0, 0), "chest": (10, 0, 0), "head": (-26, 0, 0),
             "hips": (0, 0, 0, 0, -0.03, 0),
             "thigh.L": (-16, 0, 0), "shin.L": (20, 0, 0),
             "thigh.R": (-16, 0, 0), "shin.R": (20, 0, 0),
             "upper_arm.L": (-16, 0, 54), "forearm.L": (-104, 0, 0),
             "upper_arm.R": (-16, 0, -54), "forearm.R": (-104, 0, 0)}),
        (44, {"spine": (22, 0, 0), "chest": (14, 0, 0), "head": (-20, 0, 0),
              "hips": (0, 0, 0, 0, -0.015, 0),
              "thigh.L": (-14, 0, 0), "shin.L": (18, 0, 0),
              "thigh.R": (-14, 0, 0), "shin.R": (18, 0, 0),
              "upper_arm.L": (-12, 0, 52), "forearm.L": (-100, 0, 0),
              "upper_arm.R": (-12, 0, -52), "forearm.R": (-100, 0, 0)}),
        (88, {"spine": (26, 0, 0), "chest": (10, 0, 0), "head": (-26, 0, 0),
              "hips": (0, 0, 0, 0, -0.03, 0),
              "thigh.L": (-16, 0, 0), "shin.L": (20, 0, 0),
              "thigh.R": (-16, 0, 0), "shin.R": (20, 0, 0),
              "upper_arm.L": (-16, 0, 54), "forearm.L": (-104, 0, 0),
              "upper_arm.R": (-16, 0, -54), "forearm.R": (-104, 0, 0)}),
    ]),

    # Turning on the chair. The one animation that is about the player rather than
    # the game, and the only time anybody looks at the umpire.
    "argue": dict(loop=True, keys=[
        (1, {"spine": (8, -14, 0), "chest": (4, -10, 0), "head": (-6, -16, 0),
             "upper_arm.R": (-96, 0, -26), "forearm.R": (-14, 0, 0),
             "upper_arm.L": (-16, 0, 30), "forearm.L": (-70, 0, 0)}),
        (14, {"spine": (12, -16, 0), "chest": (6, -12, 0), "head": (-10, -18, 0),
              "upper_arm.R": (-112, 0, -18), "forearm.R": (-6, 0, 0),
              "upper_arm.L": (-24, 0, 40), "forearm.L": (-84, 0, 0)}),
        (30, {"spine": (8, -14, 0), "chest": (4, -10, 0), "head": (-6, -16, 0),
              "upper_arm.R": (-96, 0, -26), "forearm.R": (-14, 0, 0),
              "upper_arm.L": (-16, 0, 30), "forearm.L": (-70, 0, 0)}),
        (46, {"spine": (14, -18, 0), "chest": (8, -12, 0), "head": (-12, -20, 0),
              "upper_arm.R": (-120, 0, -12), "forearm.R": (-4, 0, 0),
              "upper_arm.L": (-28, 0, 44), "forearm.L": (-90, 0, 0)}),
        (62, {"spine": (8, -14, 0), "chest": (4, -10, 0), "head": (-6, -16, 0),
              "upper_arm.R": (-96, 0, -26), "forearm.R": (-14, 0, 0),
              "upper_arm.L": (-16, 0, 30), "forearm.L": (-70, 0, 0)}),
    ]),
}


# The crowd. Seated, because they are sitting in the stands — which means the legs
# stay folded in every clip and only the top half does anything.

_SEATED = {
    "hips": (0, 0, 0, 0, -0.24, 0),
    "spine": (8, 0, 0),
    "thigh.L": (-84, 0, 0), "shin.L": (84, 0, 0), "foot.L": (-6, 0, 0),
    "thigh.R": (-84, 0, 0), "shin.R": (84, 0, 0), "foot.R": (-6, 0, 0),
    "upper_arm.L": (-24, 0, 14), "forearm.L": (-58, 0, 0),
    "upper_arm.R": (-24, 0, -14), "forearm.R": (-58, 0, 0),
}

AUDIENCE_CLIPS = {
    "sit": dict(loop=True, keys=[
        (1, _SEATED),
        (52, _pose(_SEATED, spine=(10, 2, 0), head=(-4, 3, 0))),
        (104, _SEATED),
    ]),

    "clap": dict(loop=True, keys=[
        (1, _pose(_SEATED,
                  **{"upper_arm.L": (-64, 0, 40), "forearm.L": (-96, 0, -30),
                     "upper_arm.R": (-64, 0, -40), "forearm.R": (-96, 0, 30)})),
        (7, _pose(_SEATED,
                  **{"upper_arm.L": (-70, 0, 12), "forearm.L": (-104, 0, -6),
                     "upper_arm.R": (-70, 0, -12), "forearm.R": (-104, 0, 6)})),
        (14, _pose(_SEATED,
                   **{"upper_arm.L": (-64, 0, 40), "forearm.L": (-96, 0, -30),
                      "upper_arm.R": (-64, 0, -40), "forearm.R": (-96, 0, 30)})),
    ]),

    "cheer": dict(loop=True, keys=[
        (1, _pose(_SEATED, spine=(-6, 0, 0), head=(10, 0, 0),
                  **{"upper_arm.L": (-24, 0, 128), "forearm.L": (-40, 0, 0),
                     "upper_arm.R": (-24, 0, -128), "forearm.R": (-40, 0, 0)})),
        (18, _pose(_SEATED, spine=(-12, 0, 0), head=(14, 0, 0),
                   **{"upper_arm.L": (-10, 0, 142), "forearm.L": (-16, 0, 0),
                      "upper_arm.R": (-10, 0, -142), "forearm.R": (-16, 0, 0)})),
        (36, _pose(_SEATED, spine=(-6, 0, 0), head=(10, 0, 0),
                   **{"upper_arm.L": (-24, 0, 128), "forearm.L": (-40, 0, 0),
                      "upper_arm.R": (-24, 0, -128), "forearm.R": (-40, 0, 0)})),
    ]),
}
