"""The beach volleyball animations, written against the same Meshy rig.

Everything in `badminton_clips` about the rig applies here unchanged — world-axis
rotations in degrees, because glTF carries no bone tails and Blender's guesses for this
rig are meaningless; a T-pose to depart from, so an arm at rest is a large rotation and
not a small one; and `lean()` rather than a spine bend, because Meshy weights the torso
almost entirely to the hips.

    +Z is up          -Y is the way they are facing        +X is their left

    RightArm      +Y raises overhead,  -Y drops to the hip
                  +Z swings forward,   -Z swings back behind
    LeftArm       -Y raises overhead,  +Y drops to the hip
    RightForeArm  +Z bends the elbow,  LeftForeArm  -Z bends the elbow
    UpLeg         -X swings the leg forward, +X back
    Leg           +X bends the knee

Real numbers off the badminton clips, because the first version of this file had the
Y sign inverted on every raised arm and produced six poses of a man standing with his
hands by his hips. Copy these rather than guessing:

    arm straight overhead     RightArm (0,  94, -32)   LeftArm (0, -72, -14)
    arm hanging at the hip    RightArm (0, -72, -38)   LeftArm (0,  28, -58)
    arm horizontal, forward   Z near +/-80, Y near +/-30

A volleyball player's arms are up far more of the time than a badminton player's, so
almost everything here is nearer the first line than the second.

What is different is the shape of the sport. A badminton player is side-on with one arm
doing everything; a volleyball player is square to the net and **symmetrical** — both
arms together to dig, both hands overhead to set, both arms up to block. Only the spike
is one-armed, and it is the only one that looks like a badminton smash at all.

Every clip here is prefixed `vb_` so that both sports can live in one exported character
without arguing over the word "serve".
"""

from badminton_clips import MOVE, lean

FPS = 24


def _with(base, **changes):
    pose = dict(base)
    pose.update(changes)
    return pose


def _moved(pose, up):
    """Lifts the whole body off the sand, for the two clips that leave the ground.

    MOVE cannot go through _with as a keyword: that would key a *bone* called "MOVE"
    rather than the body shift, and a misspelled bone is silent — the jump simply would
    not happen and the spike would be played with both feet planted.
    """
    lifted = dict(pose)
    lifted[MOVE] = (0.0, 0.0, up)
    return lifted


# The stance a beach player waits in: low, square to the net, hands up and open in
# front of the chest, weight on the balls of the feet. Much lower than the badminton
# ready pose, because the ball can be dug off the sand and a player who is standing up
# straight is already too late.
READY = lean({
    "Spine02": (10, 0, 0),
    "Spine01": (4, 0, 0),
    "LeftUpLeg": (-24, 0, -8),
    "LeftLeg": (46, 0, 0),
    "RightUpLeg": (-24, 0, 8),
    "RightLeg": (46, 0, 0),
    "LeftArm": (0, 22, -74),
    "LeftForeArm": (0, 0, -66),
    "RightArm": (0, -22, 74),
    "RightForeArm": (0, 0, 66),
    "neck": (-8, 0, 0),
}, 18)


# Arms straight and locked together in front, which is the whole shape of a dig. Both
# elbows go nearly straight — a bent arm is the commonest fault in the sport and it
# reads instantly as wrong to anybody who has played.
_PLATFORM = {
    "LeftArm": (0, 4, -92),
    "LeftForeArm": (0, 0, -4),
    "RightArm": (0, -4, 92),
    "RightForeArm": (0, 0, 4),
}


# Both hands above and in front of the forehead, elbows out, fingers spread. The
# giveaway of a good set is that the hands are high and early rather than at the face.
_HANDS_UP = {
    "LeftArm": (0, -18, -66),
    "LeftForeArm": (0, 0, -104),
    "RightArm": (0, 18, 66),
    "RightForeArm": (0, 0, 104),
}


CLIPS = {
    # --- waiting -----------------------------------------------------------------
    "vb_ready": {
        "loop": True,
        "keys": [
            (0, READY),
            (12, _with(READY, LeftLeg=(52, 0, 0), RightLeg=(52, 0, 0),
                       Spine02=(13, 0, 0), neck=(-10, 0, 0))),
            (24, READY),
        ],
    },

    # --- the first touch ---------------------------------------------------------
    #
    # Down to the ball, arms out in front and locked, and a shrug of the shoulders
    # rather than a swing: a dig is passed, not hit. The knees do the work.
    "vb_dig": {
        "loop": False,
        "keys": [
            (0, _with(READY, **_PLATFORM)),
            (5, lean(_with(READY, LeftUpLeg=(-44, 0, -10), RightUpLeg=(-44, 0, 10),
                           LeftLeg=(76, 0, 0), RightLeg=(76, 0, 0),
                           Spine02=(10, 0, 0),
                           **_PLATFORM), 14)),
            (9, lean(_with(READY, LeftUpLeg=(-30, 0, -10), RightUpLeg=(-30, 0, 10),
                           LeftLeg=(52, 0, 0), RightLeg=(52, 0, 0),
                           Spine02=(6, 0, 0),
                           LeftArm=(0, 24, -78), LeftForeArm=(0, 0, -10),
                           RightArm=(0, -24, 78), RightForeArm=(0, 0, 10)), 12)),
            (18, READY),
        ],
    },

    # --- the second --------------------------------------------------------------
    #
    # Hands up early, a small dip of the knees, and the ball goes out of the fingers as
    # the legs extend. The arms finish straighter than they started, which is the only
    # part of a set anybody can actually see.
    "vb_set": {
        "loop": False,
        "keys": [
            (0, _with(READY, **_HANDS_UP)),
            (5, lean(_with(READY, LeftLeg=(58, 0, 0), RightLeg=(58, 0, 0),
                           **_HANDS_UP), 8)),
            (10, _with(READY, LeftUpLeg=(-6, 0, -6), RightUpLeg=(-6, 0, 6),
                       LeftLeg=(10, 0, 0), RightLeg=(10, 0, 0),
                       Spine02=(-6, 0, 0), neck=(-14, 0, 0),
                       LeftArm=(0, -44, -52), LeftForeArm=(0, 0, -64),
                       RightArm=(0, 44, 52), RightForeArm=(0, 0, 64))),
            (20, READY),
        ],
    },

    # --- the third ---------------------------------------------------------------
    #
    # The only one-armed action in the sport, and the only one that leaves the ground.
    # Both arms swing back and up on the approach, the hitting arm goes over the top,
    # and the whole body pikes forward through the contact.
    "vb_spike": {
        "loop": False,
        "keys": [
            (0, lean(_with(READY,
                           LeftUpLeg=(-34, 0, -8), RightUpLeg=(-34, 0, 8),
                           LeftLeg=(64, 0, 0), RightLeg=(64, 0, 0),
                           LeftArm=(0, 30, 58), LeftForeArm=(0, 0, -20),
                           RightArm=(0, -30, -58), RightForeArm=(0, 0, 20)), 22)),
            (5, _moved(_with(READY,
                      LeftUpLeg=(-4, 0, -6), RightUpLeg=(-4, 0, 6),
                      LeftLeg=(8, 0, 0), RightLeg=(8, 0, 0),
                      Spine02=(-14, 0, 0), neck=(-6, 0, 0),
                      LeftArm=(0, -64, -18), LeftForeArm=(0, 0, -24),
                      RightArm=(0, 88, -34), RightForeArm=(0, 0, -70)), 0.42)),
            (9, _moved(_with(READY,
                      LeftUpLeg=(-2, 0, -6), RightUpLeg=(-2, 0, 6),
                      LeftLeg=(6, 0, 0), RightLeg=(6, 0, 0),
                      Spine02=(18, 0, 0), neck=(4, 0, 0),
                      LeftArm=(0, 8, -34), LeftForeArm=(0, 0, -34),
                      RightArm=(0, 92, 22), RightForeArm=(0, 0, -4)), 0.50)),
            (14, lean(_with(READY,
                            LeftUpLeg=(-30, 0, -8), RightUpLeg=(-30, 0, 8),
                            LeftLeg=(58, 0, 0), RightLeg=(58, 0, 0),
                            Spine02=(22, 0, 0),
                            LeftArm=(0, 34, -52), LeftForeArm=(0, 0, -56),
                            RightArm=(0, -34, 66), RightForeArm=(0, 0, 60)), 24)),
            (24, READY),
        ],
    },

    # --- at the net --------------------------------------------------------------
    #
    # Both arms straight up and pressed over the tape, shoulders by the ears, hands
    # turned in. This is the pose the whole TOUCH call is about: if the ball clips
    # anything here it is the blocker's point lost and not the attacker's.
    "vb_block": {
        "loop": False,
        "keys": [
            (0, _with(READY, LeftArm=(0, -34, -34), LeftForeArm=(0, 0, -44),
                      RightArm=(0, 34, 34), RightForeArm=(0, 0, 44))),
            (5, _moved(_with(READY,
                      LeftUpLeg=(-2, 0, -5), RightUpLeg=(-2, 0, 5),
                      LeftLeg=(6, 0, 0), RightLeg=(6, 0, 0),
                      Spine02=(-6, 0, 0), neck=(-12, 0, 0),
                      LeftArm=(0, -88, -10), LeftForeArm=(0, 0, -6),
                      RightArm=(0, 88, 10), RightForeArm=(0, 0, 6)), 0.36)),
            (12, _moved(_with(READY,
                       LeftUpLeg=(-2, 0, -5), RightUpLeg=(-2, 0, 5),
                       LeftLeg=(6, 0, 0), RightLeg=(6, 0, 0),
                       Spine02=(-6, 0, 0), neck=(-12, 0, 0),
                       LeftArm=(0, -88, -10), LeftForeArm=(0, 0, -6),
                       RightArm=(0, 88, 10), RightForeArm=(0, 0, 6)), 0.36)),
            (22, READY),
        ],
    },

    # --- starting it off ---------------------------------------------------------
    #
    # A standing float serve: ball held up in the off hand, a short step, and a flat
    # punch through it with a still wrist. No jump, because a jump serve needs the ball
    # tossed several metres and this rig has nothing to toss.
    "vb_serve": {
        "loop": False,
        "keys": [
            (0, lean(_with(READY,
                           LeftUpLeg=(-14, 0, -6), RightUpLeg=(-14, 0, 6),
                           LeftLeg=(28, 0, 0), RightLeg=(28, 0, 0),
                           LeftArm=(0, -6, -74), LeftForeArm=(0, 0, -34),
                           RightArm=(0, 34, -54), RightForeArm=(0, 0, -46)), 10)),
            (7, _with(READY,
                      LeftUpLeg=(-10, 0, -6), RightUpLeg=(-10, 0, 6),
                      LeftLeg=(20, 0, 0), RightLeg=(20, 0, 0),
                      Spine02=(-10, 0, 0), neck=(-10, 0, 0),
                      LeftArm=(0, 6, -70), LeftForeArm=(0, 0, -40),
                      RightArm=(0, 86, 14), RightForeArm=(0, 0, -8))),
            (12, _with(READY,
                       LeftUpLeg=(-16, 0, -6), RightUpLeg=(-16, 0, 6),
                       LeftLeg=(30, 0, 0), RightLeg=(30, 0, 0),
                       Spine02=(10, 0, 0),
                       LeftArm=(0, 26, -58), LeftForeArm=(0, 0, -44),
                       RightArm=(0, 6, 62), RightForeArm=(0, 0, 34))),
            (22, READY),
        ],
    },
}
