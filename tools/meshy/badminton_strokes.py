"""Badminton's full stroke and footwork set, one clip per situation on court.

Added 2026-10-15 after Luqman asked for an animation for every movement an athlete makes.
`dev/looks/_movelog` played 24 matches and found the athletes had three strokes for every
situation: 120 of 122 shuttles were taken on the racket side because the body spun to put
them there, a backhand played with the shuttle on the right, nobody lunged although 59% of
contacts were more than 1.3 m away, and a smash was defended with the same forehand as a
lift. These are the clips that replace that, chosen in `Player._badminton_stroke` by where
the shuttle is against the body, how high, how far, and what the shot is going to be.

Technique, from coaching references checked the same day:
  - round the head: weight onto the non-racket side, racket behind the head, free arm up
    and out (activesgcircle.gov.sg, badminton-insight.com);
  - smash defence: a short push with no follow-through, backhand for a smash at the body
    (blog.badmintonbay.com, badmintonbible.com);
  - backhand clear: chassé back with the non-racket leg leading, pivot so the back is to
    the net, contact behind the body (badminton-insight.com);
  - every lunge, forehand or backhand corner, is made on the racket leg.

Same conventions as badminton_clips.py: world-axis degrees, +Z up, -Y the way they face,
+X their left. A turn on the hips carries everything above and below it, so arm angles in a
turned pose read in the body's own frame. `CONTACT` is the frame each stroke meets the
shuttle on; Player.CONTACT_AT copies it, divided by 24.
"""

from badminton_clips import MOVE, READY, STAND, lean, _with, _moved

# --- base poses ----------------------------------------------------------------------

# Between points: standing up, racket held loosely in front at the waist. The old idle was
# the in-rally crouch with the back tipped forward, so every athlete hunched over between
# every point (Luqman: "when the athlete is standing idle, they lean forward").
IDLE = {
    "LeftUpLeg": (-3, 0, -3), "LeftLeg": (5, 0, 0),
    "RightUpLeg": (-3, 0, 3), "RightLeg": (5, 0, 0),
    "Spine02": (1, 0, 0),
    "LeftArm": (0, 74, -10), "LeftForeArm": (0, 0, -24),
    "RightArm": (0, -60, 26), "RightForeArm": (0, 0, 46),
}

# Waiting for a smash: lower and wider than READY, racket in front of the chest.
DEFEND = lean(_moved({
    "Spine02": (8, 0, 0),
    "LeftUpLeg": (-16, 0, -11), "LeftLeg": (44, 0, 0),
    "RightUpLeg": (-16, 0, 11), "RightLeg": (44, 0, 0),
    "LeftArm": (0, 46, -38), "LeftForeArm": (0, 0, -64),
    "RightArm": (0, -26, 46), "RightForeArm": (0, 0, 62),
}, (0.0, 0.0, -0.025)), 12)

# Sideways on under a high shuttle: racket shoulder back, racket cocked behind the head,
# free arm pointing up at the shuttle. Every overhead starts from here.
COCKED = {
    "Hips": (0, 0, -34),
    "Spine02": (-6, 0, 0),
    "LeftUpLeg": (-6, 0, -6), "LeftLeg": (14, 0, 0),
    "RightUpLeg": (8, 0, 8), "RightLeg": (18, 0, 0),
    "LeftArm": (0, -78, -18), "LeftForeArm": (0, 0, -10),
    # Elbow up at shoulder height and the hand dropped behind the head — the forearm folds
    # about Y, not Z, once the upper arm is raised (checked side-on: Z only folded it forward).
    "RightArm": (0, 30, -10), "RightForeArm": (0, 110, 0),
}

# Round the head: the same, leaning over onto the non-racket side.
COCKED_RTH = _with(COCKED, Hips=(0, 12, -20), Spine02=(-4, 8, 0),
                   LeftArm=(0, -40, -30), LeftForeArm=(0, 0, -30),
                   RightArm=(0, 84, -34), RightForeArm=(0, 0, 126))

# Back to the net for a backhand overhead: turned most of the way round, racket elbow up
# and leading, racket hanging behind.
COCKED_BH = {
    "Hips": (0, 0, 100),
    "Spine02": (4, 0, 0),
    "LeftUpLeg": (6, 0, -6), "LeftLeg": (18, 0, 0),
    "RightUpLeg": (-14, 0, 6), "RightLeg": (24, 0, 0),
    "LeftArm": (0, 70, 10), "LeftForeArm": (0, 0, -30),
    "RightArm": (0, 26, 88), "RightForeArm": (0, 0, 104),
}

# The racket-leg lunge to the front, forehand corner: the shape the old `lunge` measured
# for a planted front foot, turned a little towards the right-hand corner.
LUNGE_FH = {
    MOVE: (-0.10, -0.24, -0.18),
    "Hips": (18, 0, -18),
    "Spine02": (10, 0, 0), "Spine01": (6, 0, 0),
    "RightUpLeg": (-74, 0, 6), "RightLeg": (64, 0, 0), "RightFoot": (-18, 0, 0),
    "LeftUpLeg": (10, 0, -8), "LeftLeg": (30, 0, 0), "LeftFoot": (-40, 0, 0),
    "RightArm": (0, -18, 80), "RightForeArm": (0, 0, 14),
    "LeftArm": (0, 30, -60), "LeftForeArm": (0, 0, -20),
}

# The same lunge into the backhand corner: still the racket leg in front, the body turned
# towards the left and the racket reaching across it.
LUNGE_BH = {
    MOVE: (0.14, -0.22, -0.18),
    "Hips": (18, 0, 34),
    "Spine02": (10, 0, 0), "Spine01": (6, 0, 0),
    "RightUpLeg": (-74, 0, 6), "RightLeg": (64, 0, 0), "RightFoot": (-18, 0, 0),
    "LeftUpLeg": (10, 0, -8), "LeftLeg": (30, 0, 0), "LeftFoot": (-40, 0, 0),
    "RightArm": (0, -10, 118), "RightForeArm": (0, 0, 40),
    "LeftArm": (0, 40, -14), "LeftForeArm": (0, 0, -40),
}

# Out sideways to the racket side for a wide smash: the right leg steps out, the body
# drops over it, the racket low and out to the right.
WIDE_FH = {
    MOVE: (-0.28, 0.0, -0.05),
    "Hips": (8, -10, -10),
    "Spine02": (8, 0, 0),
    "RightUpLeg": (-34, 0, 32), "RightLeg": (66, 0, 0), "RightFoot": (-10, 0, 0),
    "LeftUpLeg": (-4, 0, -14), "LeftLeg": (12, 0, 0),
    "RightArm": (0, -30, 6), "RightForeArm": (0, 0, 24),
    "LeftArm": (0, 40, -40), "LeftForeArm": (0, 0, -50),
}

# And to the backhand side: the left leg out, racket across the body to the left.
WIDE_BH = {
    MOVE: (0.28, 0.0, -0.05),
    "Hips": (8, 10, 24),
    "Spine02": (8, 0, 0),
    "LeftUpLeg": (-34, 0, -32), "LeftLeg": (66, 0, 0), "LeftFoot": (-10, 0, 0),
    "RightUpLeg": (-4, 0, 14), "RightLeg": (12, 0, 0),
    "RightArm": (0, -24, 120), "RightForeArm": (0, 0, 36),
    "LeftArm": (0, 50, -10), "LeftForeArm": (0, 0, -46),
}


def _stroke(keys):
    return {"loop": False, "keys": keys}


def _cycle(keys):
    return {"loop": True, "keys": keys}


CLIPS = {
    # --- standing and moving ----------------------------------------------------------
    "idle": _cycle([
        (0, IDLE),
        (30, _with(IDLE, Spine02=(3, 0, 0), neck=(2, 0, 0),
                   RightArm=(0, -62, 24), RightForeArm=(0, 0, 44))),
        (60, IDLE),
    ]),

    # The hop as the opponent strikes: up onto the toes, land wide, ready to go either way.
    "bd_split": _stroke([
        (0, READY),
        (3, _moved(_with(READY, LeftUpLeg=(-6, 0, -2), RightUpLeg=(-6, 0, 2),
                         LeftLeg=(10, 0, 0), RightLeg=(10, 0, 0),
                         LeftFoot=(24, 0, 0), RightFoot=(24, 0, 0)), (0.0, 0.0, 0.07))),
        (6, _moved(_with(READY, LeftUpLeg=(-14, 0, -12), RightUpLeg=(-14, 0, 12),
                         LeftLeg=(42, 0, 0), RightLeg=(42, 0, 0)), (0.0, 0.0, -0.02))),
        (11, READY),
    ]),

    # The chassé, now one each way: the leading foot opens first and the trailing foot
    # snaps in after it, and the body leans into the way it is going. Played as one clip
    # for both directions, the feet opened symmetrically and the athlete looked as though
    # they were doing star jumps along the line.
    "shuffle_left": _cycle([
        (0, _moved(_with(READY, LeftUpLeg=(-8, 0, -4), RightUpLeg=(-8, 0, 4),
                         Hips=(0, 4, 0)), (0.0, 0.0, 0.0))),
        (4, _moved(_with(READY, LeftUpLeg=(-8, 0, -22), LeftLeg=(30, 0, 0),
                         RightUpLeg=(-8, 0, 8), RightLeg=(34, 0, 0),
                         Hips=(0, 8, 0)), (0.04, 0.0, 0.0))),
        (8, _moved(_with(READY, LeftUpLeg=(-8, 0, -10), RightUpLeg=(-8, 0, -6),
                         RightLeg=(20, 0, 0), Hips=(0, 6, 0)), (0.02, 0.0, 0.02))),
        (12, _moved(_with(READY, LeftUpLeg=(-8, 0, -4), RightUpLeg=(-8, 0, 4),
                          Hips=(0, 4, 0)), (0.0, 0.0, 0.0))),
    ]),
    "shuffle_right": _cycle([
        (0, _moved(_with(READY, LeftUpLeg=(-8, 0, -4), RightUpLeg=(-8, 0, 4),
                         Hips=(0, -4, 0)), (0.0, 0.0, 0.0))),
        (4, _moved(_with(READY, RightUpLeg=(-8, 0, 22), RightLeg=(30, 0, 0),
                         LeftUpLeg=(-8, 0, -8), LeftLeg=(34, 0, 0),
                         Hips=(0, -8, 0)), (-0.04, 0.0, 0.0))),
        (8, _moved(_with(READY, RightUpLeg=(-8, 0, 10), LeftUpLeg=(-8, 0, 6),
                         LeftLeg=(20, 0, 0), Hips=(0, -6, 0)), (-0.02, 0.0, 0.02))),
        (12, _moved(_with(READY, LeftUpLeg=(-8, 0, -4), RightUpLeg=(-8, 0, 4),
                          Hips=(0, -4, 0)), (0.0, 0.0, 0.0))),
    ]),

    # A long way back to the rear court: turned side-on with the racket shoulder back and the
    # racket already coming up, chasséing back rather than backpedalling square.
    "bd_retreat": _cycle([
        (0, _with(COCKED, LeftUpLeg=(-20, 0, -6), LeftLeg=(30, 0, 0),
                  RightUpLeg=(18, 0, 8), RightLeg=(20, 0, 0), RightFoot=(-20, 0, 0),
                  RightArm=(0, 40, -30), RightForeArm=(0, 0, 100))),
        (5, _moved(_with(COCKED, LeftUpLeg=(-4, 0, -6), LeftLeg=(20, 0, 0),
                         RightUpLeg=(2, 0, 8), RightLeg=(24, 0, 0),
                         RightArm=(0, 46, -34), RightForeArm=(0, 0, 104)), (0.0, 0.0, 0.04))),
        (10, _with(COCKED, LeftUpLeg=(-20, 0, -6), LeftLeg=(30, 0, 0),
                   RightUpLeg=(18, 0, 8), RightLeg=(20, 0, 0), RightFoot=(-20, 0, 0),
                   RightArm=(0, 40, -30), RightForeArm=(0, 0, 100))),
    ]),

    # Pushing back out of a lunge to the middle, played when a lunging stroke finishes.
    "bd_recover": _stroke([
        (0, _with(LUNGE_FH, RightArm=(0, -30, 60), RightForeArm=(0, 0, 40))),
        (6, _moved(_with(READY, RightUpLeg=(-40, 0, 6), RightLeg=(40, 0, 0)),
                   (0.0, -0.10, -0.01))),
        (14, READY),
    ]),

    # Head down, racket hanging, walking back after losing a point.
    "walk_sad": _cycle([
        (0, _with(STAND, neck=(22, 0, 0), Spine02=(8, 0, 0),
                  LeftUpLeg=(-20, 0, -2), LeftLeg=(10, 0, 0),
                  RightUpLeg=(12, 0, 2), RightLeg=(16, 0, 0),
                  LeftArm=(0, 80, 6), RightArm=(0, -80, -8), RightForeArm=(0, 0, 10))),
        (14, _with(STAND, neck=(24, 0, 0), Spine02=(9, 0, 0),
                   LeftUpLeg=(12, 0, -2), LeftLeg=(16, 0, 0),
                   RightUpLeg=(-20, 0, 2), RightLeg=(10, 0, 0),
                   LeftArm=(0, 80, -8), RightArm=(0, -80, 6), RightForeArm=(0, 0, 12))),
        (28, _with(STAND, neck=(22, 0, 0), Spine02=(8, 0, 0),
                   LeftUpLeg=(-20, 0, -2), LeftLeg=(10, 0, 0),
                   RightUpLeg=(12, 0, 2), RightLeg=(16, 0, 0),
                   LeftArm=(0, 80, 6), RightArm=(0, -80, -8), RightForeArm=(0, 0, 10))),
    ]),

    # --- rear court, overhead -----------------------------------------------------------
    # Turning side-on under the shuttle, racket cocked, waiting to strike: the wind-up that is
    # stretched to end where a smash begins. Replaces Meshy's own crouch, which turned the
    # whole body a quarter turn to the left and led into a smash that finished side-on to the
    # net (Luqman, 2026-10-15: "sometimes when the player smash, they facing the wrong way").
    "bd_smash_prep": _stroke([
        (0, READY),
        (10, COCKED),
    ]),
    # The standing smash: side-on and cocked, then the hips come round so the chest faces the
    # net at contact, the racket arm reaching up and forward, and the follow-through goes
    # down across the body as the racket leg steps through. Contact on 7.
    "bd_smash": _stroke([
        (0, COCKED),
        (4, _with(COCKED, Hips=(0, 0, -22), RightArm=(0, 36, -18), RightForeArm=(0, 124, 0))),
        (7, {
            "Hips": (8, 0, 6), "Spine02": (16, 0, 0),
            "LeftUpLeg": (-8, 0, -6), "LeftLeg": (20, 0, 0),
            "RightUpLeg": (-16, 0, 6), "RightLeg": (28, 0, 0),
            "LeftArm": (0, 30, -30), "LeftForeArm": (0, 0, -40),
            "RightArm": (0, 90, 44), "RightForeArm": (0, 0, 4),
        }),
        (13, {
            "Hips": (12, 0, 24), "Spine02": (18, 0, 0),
            "LeftUpLeg": (10, 0, -6), "LeftLeg": (24, 0, 0),
            "RightUpLeg": (-30, 0, 6), "RightLeg": (34, 0, 0),
            "LeftArm": (0, 50, -10), "LeftForeArm": (0, 0, -40),
            "RightArm": (0, -40, 80), "RightForeArm": (0, 0, 40),
        }),
        (20, READY),
    ]),
    # Contact on 9, at the top of the jump.
    "bd_jump_smash": _stroke([
        (0, _moved(_with(COCKED, LeftUpLeg=(-30, 0, -8), LeftLeg=(56, 0, 0),
                         RightUpLeg=(-20, 0, 8), RightLeg=(56, 0, 0)), (0.0, 0.0, -0.05))),
        (6, _moved(_with(COCKED, LeftUpLeg=(-40, 0, -6), LeftLeg=(70, 0, 0),
                         RightUpLeg=(-10, 0, 6), RightLeg=(60, 0, 0),
                         RightArm=(0, 36, -18), RightForeArm=(0, 124, 0)), (0.0, 0.0, 0.34))),
        (9, _moved({
            "Hips": (6, 0, 6), "Spine02": (14, 0, 0),
            "LeftUpLeg": (-30, 0, -6), "LeftLeg": (50, 0, 0),
            "RightUpLeg": (10, 0, 6), "RightLeg": (40, 0, 0),
            "LeftArm": (0, 20, -40), "LeftForeArm": (0, 0, -40),
            "RightArm": (0, 98, 34), "RightForeArm": (0, 0, 4),
        }, (0.0, -0.06, 0.38))),
        (13, _moved({
            "Hips": (10, 0, 22), "Spine02": (18, 0, 0),
            "LeftUpLeg": (18, 0, -6), "LeftLeg": (30, 0, 0),
            "RightUpLeg": (-30, 0, 6), "RightLeg": (40, 0, 0),
            "LeftArm": (0, 50, -10), "LeftForeArm": (0, 0, -40),
            "RightArm": (0, -40, 74), "RightForeArm": (0, 0, 34),
        }, (0.0, -0.12, 0.16))),
        (18, _moved(_with(READY, LeftLeg=(52, 0, 0), RightLeg=(52, 0, 0)), (0.0, -0.14, -0.04))),
        (26, READY),
    ]),

    # Round the head: a smash from over the left shoulder. Contact on 6.
    "bd_rth_smash": _stroke([
        (0, COCKED_RTH),
        (6, _with(COCKED_RTH, Hips=(8, 8, 8), Spine02=(12, 8, 0),
                  RightArm=(0, 86, 68), RightForeArm=(0, 0, 8),
                  LeftArm=(0, 46, -20), LeftForeArm=(0, 0, -40))),
        (14, _with(READY, Hips=(12, 8, 24), RightArm=(0, -36, 82), RightForeArm=(0, 0, 44))),
        (22, READY),
    ]),

    # The forehand clear: tall and upright at contact, racket straight up, hit high and long.
    "bd_clear": _stroke([
        (0, COCKED),
        (6, _with(COCKED, Hips=(4, 0, -8), Spine02=(4, 0, 0),
                  RightArm=(0, 70, 44), RightForeArm=(0, 0, 8),
                  LeftArm=(0, 30, -30), LeftForeArm=(0, 0, -40))),
        (15, _with(READY, Hips=(12, 0, 14), RightArm=(0, -16, 70), RightForeArm=(0, 0, 52))),
        (22, READY),
    ]),
    "bd_rth_clear": _stroke([
        (0, COCKED_RTH),
        (6, _with(COCKED_RTH, Hips=(4, 8, 4), Spine02=(4, 8, 0),
                  RightArm=(0, 88, 64), RightForeArm=(0, 0, 8),
                  LeftArm=(0, 46, -20), LeftForeArm=(0, 0, -40))),
        (15, _with(READY, Hips=(12, 8, 18), RightArm=(0, -20, 76), RightForeArm=(0, 0, 50))),
        (22, READY),
    ]),

    # Backhand overhead from the left rear corner, back to the net. The forearm whips the
    # racket up and over from behind; contact on 7.
    "bd_bh_clear": _stroke([
        (0, COCKED_BH),
        (4, _with(COCKED_BH, RightArm=(0, 46, 92), RightForeArm=(0, 0, 96))),
        (7, _with(COCKED_BH, RightArm=(0, 76, -34), RightForeArm=(0, 0, 6))),
        (14, _with(COCKED_BH, Hips=(0, 0, 80), RightArm=(0, 60, -10), RightForeArm=(0, 0, 20))),
        (24, READY),
    ]),

    # The drop: the clear's shape with the arm slowing through contact and the racket face
    # coming down, so the shuttle falls short. Contact on 6.
    "bd_drop": _stroke([
        (0, COCKED),
        (6, _with(COCKED, Hips=(4, 0, -8), Spine02=(6, 0, 0),
                  RightArm=(0, 70, 44), RightForeArm=(0, 0, 16),
                  LeftArm=(0, 30, -30), LeftForeArm=(0, 0, -40))),
        (12, _with(READY, Hips=(12, 0, 8), RightArm=(0, 30, 72), RightForeArm=(0, 0, 40))),
        (20, READY),
    ]),
    "bd_bh_drop": _stroke([
        (0, COCKED_BH),
        (4, _with(COCKED_BH, RightArm=(0, 44, 92), RightForeArm=(0, 0, 90))),
        (7, _with(COCKED_BH, RightArm=(0, 76, 14), RightForeArm=(0, 0, 24))),
        (13, _with(COCKED_BH, Hips=(0, 0, 84), RightArm=(0, 56, 0), RightForeArm=(0, 0, 30))),
        (22, READY),
    ]),

    # --- defence and the middle of the court ---------------------------------------------
    # Smash to the racket side, at the hip: a short block, no follow-through. Contact on 5.
    "bd_block_fh": _stroke([
        (0, DEFEND),
        (5, _with(DEFEND, Hips=(12, 0, -16), RightArm=(0, -40, 10), RightForeArm=(0, 0, 36),
                  RightUpLeg=(-20, 0, 18))),
        (14, DEFEND),
    ]),
    # Smash wide to the racket side: out onto the right leg and lifted back deep.
    "bd_lift_fh_wide": _stroke([
        (0, DEFEND),
        (6, _with(WIDE_FH, RightArm=(0, -40, -20), RightForeArm=(0, 0, 30))),
        (9, _with(WIDE_FH, RightArm=(0, -24, 40), RightForeArm=(0, 0, 20))),
        (16, _with(WIDE_FH, RightArm=(0, 10, 70), RightForeArm=(0, 0, 50))),
        (26, DEFEND),
    ]),
    # Smash to the backhand side, at the hip: the racket across the front, a push.
    "bd_block_bh": _stroke([
        (0, DEFEND),
        (5, _with(DEFEND, Hips=(12, 0, 20), RightArm=(0, -30, 96), RightForeArm=(0, 0, 30),
                  LeftUpLeg=(-20, 0, -18))),
        (14, DEFEND),
    ]),
    "bd_lift_bh_wide": _stroke([
        (0, DEFEND),
        (6, _with(WIDE_BH, RightArm=(0, -30, 128), RightForeArm=(0, 0, 70))),
        (9, _with(WIDE_BH, RightArm=(0, -10, 110), RightForeArm=(0, 0, 20))),
        (16, _with(WIDE_BH, RightArm=(0, 20, 70), RightForeArm=(0, 0, 10))),
        (26, DEFEND),
    ]),
    # Smash at the chest: elbow up and out, backhand face in front of the body.
    "bd_body": _stroke([
        (0, DEFEND),
        (5, _with(DEFEND, Spine02=(-4, 0, 0), RightArm=(0, -10, 80), RightForeArm=(0, 0, 70),
                  LeftArm=(0, 60, -20))),
        (12, DEFEND),
    ]),
    # Out of reach: a full stretch to the racket side that ends on the floor. Contact on 8.
    "bd_dive": _stroke([
        (0, DEFEND),
        (5, _with(WIDE_FH, RightArm=(0, -10, 10), RightForeArm=(0, 0, 10))),
        (8, _moved(_with(WIDE_FH, Hips=(10, -40, -10), RightUpLeg=(-20, 0, 40),
                         LeftUpLeg=(0, 0, 10), RightArm=(0, 0, 14), RightForeArm=(0, 0, 4)),
                   (-0.48, 0.0, -0.22))),
        (16, _moved(_with(WIDE_FH, Hips=(10, -70, -10), RightUpLeg=(-10, 0, 30),
                          LeftUpLeg=(0, 0, 20), LeftLeg=(30, 0, 0),
                          RightArm=(0, 10, 20), RightForeArm=(0, 0, 10)),
                    (-0.62, 0.0, -0.39))),
        (30, _moved(_with(WIDE_FH, Hips=(10, -60, -10), LeftUpLeg=(0, 0, 10)),
                    (-0.56, 0.0, -0.40))),
        (44, DEFEND),
    ]),
    # A flat drive at shoulder height, either side. Contact on 5.
    "bd_drive_fh": _stroke([
        (0, _with(READY, Hips=(12, 0, -24), RightArm=(0, 4, -40), RightForeArm=(0, 0, 90))),
        (5, _with(READY, Hips=(12, 0, 0), RightArm=(0, 8, 30), RightForeArm=(0, 0, 12))),
        (12, _with(READY, Hips=(12, 0, 14), RightArm=(0, -4, 74), RightForeArm=(0, 0, 40))),
        (18, READY),
    ]),
    "bd_drive_bh": _stroke([
        (0, _with(READY, Hips=(12, 0, 30), RightArm=(0, 0, 118), RightForeArm=(0, 0, 100))),
        (5, _with(READY, Hips=(12, 0, 18), RightArm=(0, 10, 92), RightForeArm=(0, 0, 14))),
        (12, _with(READY, Hips=(12, 0, 0), RightArm=(0, 16, 40), RightForeArm=(0, 0, 10))),
        (18, READY),
    ]),

    # --- the front of the court --------------------------------------------------------
    # Lunge in and touch it over: racket in front, face open, almost no swing. Contact on 9.
    "bd_net_fh": _stroke([
        (0, READY),
        (6, _with(LUNGE_FH, RightArm=(0, -10, 74), RightForeArm=(0, 0, 20))),
        (9, _with(LUNGE_FH, RightArm=(0, -6, 82), RightForeArm=(0, 0, 10))),
        (15, LUNGE_FH),
    ]),
    "bd_net_bh": _stroke([
        (0, READY),
        (6, _with(LUNGE_BH, RightArm=(0, -10, 112), RightForeArm=(0, 0, 36))),
        (9, _with(LUNGE_BH, RightArm=(0, -6, 106), RightForeArm=(0, 0, 24))),
        (15, LUNGE_BH),
    ]),
    # Lunge in and lift it to the back: racket low, a wrist flick up. Contact on 9.
    "bd_lift_fh": _stroke([
        (0, READY),
        (6, _with(LUNGE_FH, RightArm=(0, -40, 50), RightForeArm=(0, 0, 50))),
        (9, _with(LUNGE_FH, RightArm=(0, -18, 84), RightForeArm=(0, 0, 20))),
        (15, _with(LUNGE_FH, RightArm=(0, 14, 88), RightForeArm=(0, 0, 10))),
    ]),
    "bd_lift_bh": _stroke([
        (0, READY),
        (6, _with(LUNGE_BH, RightArm=(0, -40, 126), RightForeArm=(0, 0, 70))),
        (9, _with(LUNGE_BH, RightArm=(0, -14, 104), RightForeArm=(0, 0, 22))),
        (15, _with(LUNGE_BH, RightArm=(0, 14, 96), RightForeArm=(0, 0, 10))),
    ]),
    # Above the tape: a short tap down, racket up in front. Contact on 5.
    "bd_kill": _stroke([
        (0, _with(READY, RightArm=(0, 40, 50), RightForeArm=(0, 0, 70))),
        (5, _moved(_with(READY, RightArm=(0, 36, 74), RightForeArm=(0, 0, 10),
                         Spine02=(12, 0, 0)), (0.0, -0.10, 0.0))),
        (12, READY),
    ]),

    # --- serving and receiving -----------------------------------------------------------
    # The doubles serve: backhand, racket in front of the waist, shuttle held by its
    # feathers in front of the racket, pushed just over the tape. Contact on 10.
    "bd_serve_low": _stroke([
        (0, _with(STAND, RightUpLeg=(-14, 0, 4), RightLeg=(14, 0, 0),
                  LeftUpLeg=(8, 0, -4), LeftLeg=(10, 0, 0),
                  RightArm=(0, -40, 92), RightForeArm=(0, 0, 100),
                  LeftArm=(0, -36, -60), LeftForeArm=(0, 0, -50))),
        (6, _with(STAND, RightUpLeg=(-14, 0, 4), RightLeg=(14, 0, 0),
                  LeftUpLeg=(8, 0, -4), LeftLeg=(10, 0, 0),
                  RightArm=(0, -44, 100), RightForeArm=(0, 0, 112),
                  LeftArm=(0, -30, -64), LeftForeArm=(0, 0, -50))),
        (10, _with(STAND, RightUpLeg=(-14, 0, 4), RightLeg=(14, 0, 0),
                   LeftUpLeg=(8, 0, -4), LeftLeg=(10, 0, 0),
                   RightArm=(0, -50, 84), RightForeArm=(0, 0, 60),
                   LeftArm=(0, 40, -50), LeftForeArm=(0, 0, -50))),
        (20, READY),
    ]),
    # The singles serve: forehand, a long underarm swing that sends it high to the back.
    "bd_serve_high": _stroke([
        (0, _with(STAND, Hips=(0, 0, -20), LeftUpLeg=(-14, 0, -4), LeftLeg=(10, 0, 0),
                  RightUpLeg=(10, 0, 4), RightLeg=(8, 0, 0),
                  RightArm=(0, -10, -60), RightForeArm=(0, 0, 60),
                  LeftArm=(0, -10, -50), LeftForeArm=(0, 0, -30))),
        (6, _with(STAND, Hips=(0, 0, -16), LeftUpLeg=(-14, 0, -4), LeftLeg=(10, 0, 0),
                  RightUpLeg=(10, 0, 4), RightLeg=(8, 0, 0),
                  RightArm=(0, -40, -30), RightForeArm=(0, 0, 40),
                  LeftArm=(0, 20, -46), LeftForeArm=(0, 0, -30))),
        (10, _with(STAND, Hips=(0, 0, 0), LeftUpLeg=(-14, 0, -4), LeftLeg=(14, 0, 0),
                   RightUpLeg=(6, 0, 4), RightLeg=(10, 0, 0),
                   RightArm=(0, -50, 40), RightForeArm=(0, 0, 16),
                   LeftArm=(0, 40, -30), LeftForeArm=(0, 0, -40))),
        (18, _with(STAND, Hips=(0, 0, 16), RightArm=(0, 50, 70), RightForeArm=(0, 0, 70),
                   LeftArm=(0, 60, -20), LeftForeArm=(0, 0, -30))),
        (26, READY),
    ]),
    # Waiting to receive: front foot forward, weight on it, racket up high.
    "bd_receive": _cycle([
        (0, lean({
            "LeftUpLeg": (-26, 0, -4), "LeftLeg": (30, 0, 0),
            "RightUpLeg": (12, 0, 6), "RightLeg": (20, 0, 0), "RightFoot": (-16, 0, 0),
            "Spine02": (8, 0, 0),
            "LeftArm": (0, 20, -50), "LeftForeArm": (0, 0, -60),
            "RightArm": (0, 40, 30), "RightForeArm": (0, 0, 90),
        }, 10)),
        (20, lean({
            "LeftUpLeg": (-26, 0, -4), "LeftLeg": (34, 0, 0),
            "RightUpLeg": (12, 0, 6), "RightLeg": (22, 0, 0), "RightFoot": (-16, 0, 0),
            "Spine02": (9, 0, 0),
            "LeftArm": (0, 22, -50), "LeftForeArm": (0, 0, -62),
            "RightArm": (0, 42, 30), "RightForeArm": (0, 0, 92),
        }, 11)),
        (40, lean({
            "LeftUpLeg": (-26, 0, -4), "LeftLeg": (30, 0, 0),
            "RightUpLeg": (12, 0, 6), "RightLeg": (20, 0, 0), "RightFoot": (-16, 0, 0),
            "Spine02": (8, 0, 0),
            "LeftArm": (0, 20, -50), "LeftForeArm": (0, 0, -60),
            "RightArm": (0, 40, 30), "RightForeArm": (0, 0, 90),
        }, 10)),
    ]),
}

## The frame each stroke meets the shuttle on. Player.CONTACT_AT holds the same numbers.
CONTACT = {
    "bd_smash": 7, "bd_jump_smash": 9, "bd_rth_smash": 6, "bd_clear": 6, "bd_rth_clear": 6,
    "bd_bh_clear": 7, "bd_drop": 6, "bd_bh_drop": 7,
    "bd_block_fh": 5, "bd_lift_fh_wide": 9, "bd_block_bh": 5, "bd_lift_bh_wide": 9,
    "bd_body": 5, "bd_dive": 8, "bd_drive_fh": 5, "bd_drive_bh": 5,
    "bd_net_fh": 9, "bd_net_bh": 9, "bd_lift_fh": 9, "bd_lift_bh": 9, "bd_kill": 5,
    "bd_serve_low": 10, "bd_serve_high": 10,
}

LOOPING = sorted(name for name, clip in CLIPS.items() if clip["loop"])
