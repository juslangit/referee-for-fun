"""Tennis, table tennis, volleyball and sepak takraw: one clip per situation, like badminton.

Added 2026-10-15 after Luqman asked for every movement in every sport ("move on with other
sports, do all sports"), following badminton_strokes.py. `dev/looks/_movelog` found:
  - tennis played almost every groundstroke as a forehand, had no volley or slice, and
    smashed with Meshy's badminton smash;
  - table tennis had no backhand at all, served with the tennis serve and smashed with the
    badminton one, and 39 contacts were struck with no stroke playing;
  - volleyball and takraw received everything standing square, so a ball a step to the side
    was met with the arms or the foot half a metre away from it.

Same conventions as badminton_clips.py: world-axis degrees, +Z up, -Y the way they face, +X
their left; a turn on the hips carries everything above and below it. `CONTACT` is each
clip's frame of contact; Player.CONTACT_AT copies it in seconds.

Volleyball and takraw variants keep the frame of contact of the touch they stand in for, so
the timing those sports already have for the touch lands on the variant just as well.
"""

from badminton_clips import MOVE, READY, STAND, lean, _with
from badminton_strokes import COCKED, WIDE_FH, WIDE_BH
import volleyball_clips as vb
import takraw_clips as st


def _at(pose, x=0.0, y=0.0, z=0.0):
    """A pose with the whole body shifted, in metres along the world axes."""
    moved = dict(pose)
    moved[MOVE] = (x, y, z)
    return moved


def _stroke(keys):
    return {"loop": False, "keys": keys}


def _cycle(keys):
    return {"loop": True, "keys": keys}


def _left_thigh(lift, turn_out, swing=0.0):
    """The left-leg mirror of takraw's right-thigh helper: Y and Z change sign."""
    x, y, z = st._right_thigh(lift, turn_out, swing)
    return (x, -y, -z)


# --- tennis ---------------------------------------------------------------------------

# Square to the net, knees bent, racket held in front with both hands.
TN_READY = lean({
    "Spine02": (6, 0, 0),
    "LeftUpLeg": (-14, 0, -8), "LeftLeg": (30, 0, 0),
    "RightUpLeg": (-14, 0, 8), "RightLeg": (30, 0, 0),
    "LeftArm": (0, 40, -50), "LeftForeArm": (0, 0, -60),
    "RightArm": (0, -40, 50), "RightForeArm": (0, 0, 64),
}, 12)

# --- table tennis ---------------------------------------------------------------------

# Close to the table, low, bat in front of the body at table height, free hand out.
TT_READY = lean(_at({
    "Spine02": (14, 0, 0),
    "LeftUpLeg": (-20, 0, -10), "LeftLeg": (42, 0, 0),
    "RightUpLeg": (-20, 0, 10), "RightLeg": (42, 0, 0),
    "LeftArm": (0, 40, -40), "LeftForeArm": (0, 0, -60),
    "RightArm": (0, -36, 46), "RightForeArm": (0, 0, 70),
}, z=-0.05), 14)


CLIPS = {
    # ===================================================================== tennis =====
    # Forehand groundstroke: unit turn to the right with the racket back, then swung low to
    # high through contact in front of the right hip, finishing over the left shoulder.
    "tn_forehand": _stroke([
        (0, _with(TN_READY, Hips=(12, 0, -44), RightArm=(0, -14, -70), RightForeArm=(0, 0, 40),
                  LeftArm=(0, 10, -80), LeftForeArm=(0, 0, -20))),
        (6, _with(TN_READY, Hips=(12, 0, -6), RightArm=(0, -26, 26), RightForeArm=(0, 0, 14),
                  LeftArm=(0, 30, -40), LeftForeArm=(0, 0, -50))),
        (14, _with(TN_READY, Hips=(12, 0, 40), RightArm=(0, 40, 104), RightForeArm=(0, 0, 96),
                   LeftArm=(0, 50, -10), LeftForeArm=(0, 0, -60))),
        (22, TN_READY),
    ]),
    # Two-handed backhand: turned to the left with both hands back, through in front of the
    # left hip, finishing high over the right shoulder.
    "tn_backhand": _stroke([
        (0, _with(TN_READY, Hips=(12, 0, 56), RightArm=(0, -24, 124), RightForeArm=(0, 0, 50),
                  LeftArm=(0, 30, 30), LeftForeArm=(0, 0, -70))),
        (6, _with(TN_READY, Hips=(12, 0, 12), RightArm=(0, -26, 92), RightForeArm=(0, 0, 20),
                  LeftArm=(0, 20, -70), LeftForeArm=(0, 0, -40))),
        (14, _with(TN_READY, Hips=(12, 0, -34), RightArm=(0, 30, 40), RightForeArm=(0, 0, 90),
                   LeftArm=(0, -40, -100), LeftForeArm=(0, 0, -90))),
        (22, TN_READY),
    ]),
    # Slices for a low ball: deeper knees, racket high to low under it.
    "tn_slice_fh": _stroke([
        (0, _at(_with(TN_READY, Hips=(12, 0, -36), RightArm=(0, 10, -50), RightForeArm=(0, 0, 70),
                      LeftLeg=(52, 0, 0), RightLeg=(52, 0, 0)), z=-0.04)),
        (6, _at(_with(TN_READY, Hips=(12, 0, -8), RightArm=(0, -40, 30), RightForeArm=(0, 0, 20),
                      LeftLeg=(52, 0, 0), RightLeg=(52, 0, 0)), z=-0.04)),
        (14, _with(TN_READY, Hips=(12, 0, 16), RightArm=(0, -30, 80), RightForeArm=(0, 0, 30))),
        (22, TN_READY),
    ]),
    "tn_slice_bh": _stroke([
        (0, _at(_with(TN_READY, Hips=(12, 0, 54), RightArm=(0, 10, 120), RightForeArm=(0, 0, 100),
                      LeftLeg=(52, 0, 0), RightLeg=(52, 0, 0)), z=-0.04)),
        (6, _at(_with(TN_READY, Hips=(12, 0, 18), RightArm=(0, -36, 96), RightForeArm=(0, 0, 16),
                      LeftLeg=(52, 0, 0), RightLeg=(52, 0, 0)), z=-0.04)),
        (14, _with(TN_READY, Hips=(12, 0, -10), RightArm=(0, -20, 40), RightForeArm=(0, 0, 10),
                   LeftArm=(0, 40, 30))),
        (22, TN_READY),
    ]),
    # Running for a wide ball: out onto the outside leg, open stance, swung on the stretch.
    "tn_run_fh": _stroke([
        (0, TN_READY),
        (4, _with(WIDE_FH, RightArm=(0, -10, -60), RightForeArm=(0, 0, 40))),
        (8, _with(WIDE_FH, RightArm=(0, -24, 30), RightForeArm=(0, 0, 14))),
        (16, _with(WIDE_FH, Hips=(8, -10, 20), RightArm=(0, 30, 96), RightForeArm=(0, 0, 90))),
        (26, TN_READY),
    ]),
    "tn_run_bh": _stroke([
        (0, TN_READY),
        (4, _with(WIDE_BH, RightArm=(0, -20, 126), RightForeArm=(0, 0, 60),
                  LeftArm=(0, 30, 30), LeftForeArm=(0, 0, -70))),
        (8, _with(WIDE_BH, RightArm=(0, -24, 96), RightForeArm=(0, 0, 20),
                  LeftArm=(0, 20, -60), LeftForeArm=(0, 0, -40))),
        (16, _with(WIDE_BH, Hips=(8, 10, -10), RightArm=(0, 30, 40), RightForeArm=(0, 0, 80),
                   LeftArm=(0, -40, -90), LeftForeArm=(0, 0, -80))),
        (26, TN_READY),
    ]),
    # Volleys at the net: racket head up, a short punch with a step in, no backswing.
    "tn_volley_fh": _stroke([
        (0, _with(TN_READY, Hips=(12, 0, -20), RightArm=(0, 10, -10), RightForeArm=(0, 0, 80))),
        (5, _at(_with(TN_READY, Hips=(12, 0, -10), RightArm=(0, 4, 40), RightForeArm=(0, 0, 40),
                      LeftUpLeg=(-30, 0, -8), LeftLeg=(40, 0, 0)), y=-0.10)),
        (12, TN_READY),
    ]),
    "tn_volley_bh": _stroke([
        (0, _with(TN_READY, Hips=(12, 0, 26), RightArm=(0, 10, 110), RightForeArm=(0, 0, 90))),
        (5, _at(_with(TN_READY, Hips=(12, 0, 14), RightArm=(0, 4, 88), RightForeArm=(0, 0, 20),
                      RightUpLeg=(-30, 0, 8), RightLeg=(40, 0, 0)), y=-0.10)),
        (12, TN_READY),
    ]),
    # Return of serve: a compact block, half a backswing, taken early.
    "tn_return_fh": _stroke([
        (0, _with(TN_READY, Hips=(12, 0, -24), RightArm=(0, -10, -30), RightForeArm=(0, 0, 50))),
        (5, _with(TN_READY, Hips=(12, 0, -4), RightArm=(0, -20, 30), RightForeArm=(0, 0, 18))),
        (12, _with(TN_READY, Hips=(12, 0, 16), RightArm=(0, 0, 70), RightForeArm=(0, 0, 50))),
        (18, TN_READY),
    ]),
    "tn_return_bh": _stroke([
        (0, _with(TN_READY, Hips=(12, 0, 34), RightArm=(0, -20, 116), RightForeArm=(0, 0, 50),
                  LeftArm=(0, 30, 20), LeftForeArm=(0, 0, -70))),
        (5, _with(TN_READY, Hips=(12, 0, 12), RightArm=(0, -22, 90), RightForeArm=(0, 0, 18),
                  LeftArm=(0, 20, -60), LeftForeArm=(0, 0, -40))),
        (12, _with(TN_READY, Hips=(12, 0, -10), RightArm=(0, 10, 50), RightForeArm=(0, 0, 50))),
        (18, TN_READY),
    ]),

    # =============================================================== table tennis =====
    # The serve: side-on at the end of the table, ball on the flat free palm, a toss and a
    # short brushing stroke low over the table. Contact on 10 (paced to the toss).
    "tt_serve": _stroke([
        (0, _with(TT_READY, Hips=(14, 0, -40), LeftArm=(0, 10, -80), LeftForeArm=(0, 0, -40),
                  RightArm=(0, -30, -40), RightForeArm=(0, 0, 70))),
        (5, _with(TT_READY, Hips=(14, 0, -44), LeftArm=(0, -20, -70), LeftForeArm=(0, 0, -50),
                  RightArm=(0, -24, -60), RightForeArm=(0, 0, 90))),
        (10, _with(TT_READY, Hips=(14, 0, -20), LeftArm=(0, 30, -40), LeftForeArm=(0, 0, -60),
                   RightArm=(0, -34, 30), RightForeArm=(0, 0, 50))),
        (18, TT_READY),
    ]),
    # Forehand drive: from beside the right hip, forearm and waist up and across to the
    # forehead. Contact on 5.
    "tt_fh_drive": _stroke([
        (0, _with(TT_READY, Hips=(14, 0, -30), RightArm=(0, -40, -20), RightForeArm=(0, 0, 50))),
        (5, _with(TT_READY, Hips=(14, 0, -4), RightArm=(0, -24, 40), RightForeArm=(0, 0, 60))),
        (11, _with(TT_READY, Hips=(14, 0, 20), RightArm=(0, 10, 80), RightForeArm=(0, 0, 110))),
        (17, TT_READY),
    ]),
    # Backhand drive: bat in front of the belly, elbow forward, flicked out and up.
    "tt_bh_drive": _stroke([
        (0, _with(TT_READY, Hips=(14, 0, 10), RightArm=(0, -30, 90), RightForeArm=(0, 0, 120))),
        (5, _with(TT_READY, Hips=(14, 0, 4), RightArm=(0, -16, 76), RightForeArm=(0, 0, 60))),
        (11, _with(TT_READY, Hips=(14, 0, -6), RightArm=(0, 4, 60), RightForeArm=(0, 0, 30))),
        (17, TT_READY),
    ]),
    # Pushes for a short ball: leaning in over the table, bat open, pushed forward low.
    "tt_fh_push": _stroke([
        (0, _with(TT_READY, Spine02=(22, 0, 0), RightArm=(0, -34, 40), RightForeArm=(0, 0, 80))),
        (6, _at(_with(TT_READY, Spine02=(24, 0, 0), RightUpLeg=(-40, 0, 10), RightLeg=(50, 0, 0),
                      RightArm=(0, -30, 64), RightForeArm=(0, 0, 30)), y=-0.14)),
        (14, TT_READY),
    ]),
    "tt_bh_push": _stroke([
        (0, _with(TT_READY, Spine02=(22, 0, 0), RightArm=(0, -30, 96), RightForeArm=(0, 0, 110))),
        (6, _at(_with(TT_READY, Spine02=(24, 0, 0), RightUpLeg=(-40, 0, 10), RightLeg=(50, 0, 0),
                      RightArm=(0, -26, 84), RightForeArm=(0, 0, 50)), y=-0.14)),
        (14, TT_READY),
    ]),
    # Block close to the table: bat held still in front, a small forward give. Contact on 4.
    "tt_block": _stroke([
        (0, _with(TT_READY, RightArm=(0, -20, 70), RightForeArm=(0, 0, 70))),
        (4, _with(TT_READY, RightArm=(0, -18, 78), RightForeArm=(0, 0, 50))),
        (10, TT_READY),
    ]),
    # Smash at a high ball: bigger forehand, upright, bat from shoulder height down through.
    "tt_smash": _stroke([
        (0, _with(TT_READY, Hips=(10, 0, -40), Spine02=(4, 0, 0),
                  RightArm=(0, 30, -40), RightForeArm=(0, 0, 80))),
        (6, _with(TT_READY, Hips=(14, 0, -2), Spine02=(16, 0, 0),
                  RightArm=(0, 10, 40), RightForeArm=(0, 0, 20))),
        (13, _with(TT_READY, Hips=(16, 0, 30), Spine02=(20, 0, 0),
                   RightArm=(0, -30, 90), RightForeArm=(0, 0, 60))),
        (20, TT_READY),
    ]),
    # Back from the table: a big upward lob, from the knee to above the head.
    "tt_lob": _stroke([
        (0, _at(_with(TT_READY, Hips=(10, 0, -30), RightArm=(0, -60, -10), RightForeArm=(0, 0, 30),
                      LeftLeg=(56, 0, 0), RightLeg=(56, 0, 0)), z=-0.06)),
        (7, _with(TT_READY, Hips=(10, 0, -6), RightArm=(0, -30, 40), RightForeArm=(0, 0, 10))),
        (16, _with(STAND, Hips=(0, 0, 20), RightArm=(0, 60, 70), RightForeArm=(0, 0, 40))),
        (24, TT_READY),
    ]),

    # ================================================================= volleyball =====
    # A pass a step to the side: the platform angled across, the body dropping over the
    # outside leg. Contact on 9, like vb_dig.
    "vb_pass_left": _stroke([
        (0, _with(vb.READY, **vb._PLATFORM)),
        (5, _at(_with(vb.READY, LeftUpLeg=(-30, 0, -28), LeftLeg=(70, 0, 0),
                      RightUpLeg=(-10, 0, 10), RightLeg=(30, 0, 0), Hips=(14, 12, 0),
                      LeftArm=(0, 10, -70), LeftForeArm=(0, 0, -4),
                      RightArm=(0, 4, 112), RightForeArm=(0, 0, 4)), x=0.22, z=-0.06)),
        (9, _at(_with(vb.READY, LeftUpLeg=(-26, 0, -26), LeftLeg=(60, 0, 0),
                      RightUpLeg=(-10, 0, 10), RightLeg=(26, 0, 0), Hips=(14, 10, 0),
                      LeftArm=(0, 18, -64), LeftForeArm=(0, 0, -4),
                      RightArm=(0, 10, 106), RightForeArm=(0, 0, 4)), x=0.22, z=-0.04)),
        (18, vb.READY),
    ]),
    "vb_pass_right": _stroke([
        (0, _with(vb.READY, **vb._PLATFORM)),
        (5, _at(_with(vb.READY, RightUpLeg=(-30, 0, 28), RightLeg=(70, 0, 0),
                      LeftUpLeg=(-10, 0, -10), LeftLeg=(30, 0, 0), Hips=(14, -12, 0),
                      RightArm=(0, -10, 70), RightForeArm=(0, 0, 4),
                      LeftArm=(0, -4, -112), LeftForeArm=(0, 0, -4)), x=-0.22, z=-0.06)),
        (9, _at(_with(vb.READY, RightUpLeg=(-26, 0, 26), RightLeg=(60, 0, 0),
                      LeftUpLeg=(-10, 0, -10), LeftLeg=(26, 0, 0), Hips=(14, -10, 0),
                      RightArm=(0, -18, 64), RightForeArm=(0, 0, 4),
                      LeftArm=(0, -10, -106), LeftForeArm=(0, 0, -4)), x=-0.22, z=-0.04)),
        (18, vb.READY),
    ]),
    # A ball out of reach indoors: a forward sprawl, arms out flat, sliding onto the chest.
    "vb_dive": _stroke([
        (0, vb.READY),
        (5, _at(_with(vb.READY, Hips=(40, 0, 0), RightUpLeg=(-60, 0, 8), RightLeg=(70, 0, 0),
                      LeftUpLeg=(10, 0, -8), LeftLeg=(20, 0, 0), **vb._PLATFORM), y=-0.3, z=-0.12)),
        (9, _at(_with(vb.READY, Hips=(70, 0, 0), RightUpLeg=(-30, 0, 8), RightLeg=(30, 0, 0),
                      LeftUpLeg=(20, 0, -8), LeftLeg=(10, 0, 0),
                      LeftArm=(0, -20, -80), RightArm=(0, 20, 80)), y=-0.55, z=-0.27)),
        (18, _at(_with(vb.READY, Hips=(80, 0, 0), RightUpLeg=(-80, 0, 8), RightLeg=(10, 0, 0),
                       LeftUpLeg=(-80, 0, -8), LeftLeg=(10, 0, 0),
                       LeftArm=(0, -40, -70), RightArm=(0, 40, 70)), y=-0.75, z=-0.06)),
        (34, vb.READY),
    ]),
    # On the beach: a full-length dive to the side into the sand, landing on the hip.
    "vb_dive_sand": _stroke([
        (0, vb.READY),
        (5, _at(_with(vb.READY, Hips=(10, -30, 0), RightUpLeg=(-40, 0, 30), RightLeg=(60, 0, 0),
                      **vb._PLATFORM), x=-0.3, z=-0.15)),
        (9, _at(_with(vb.READY, Hips=(10, -60, 0), RightUpLeg=(-10, 0, 30), RightLeg=(20, 0, 0),
                      LeftUpLeg=(0, 0, -10), LeftLeg=(10, 0, 0),
                      RightArm=(0, 10, 70), LeftArm=(0, -10, -110)), x=-0.6, z=-0.36)),
        (18, _at(_with(vb.READY, Hips=(10, -80, 0), RightUpLeg=(-10, 0, 20), RightLeg=(20, 0, 0),
                       LeftUpLeg=(-10, 0, -10), LeftLeg=(30, 0, 0),
                       RightArm=(0, 30, 60), LeftArm=(0, -30, -100)), x=-0.75, z=-0.6)),
        (36, vb.READY),
    ]),
    # A high reception taken overhead with the fingers instead of the forearms. Contact on 9.
    "vb_overhead_pass": _stroke([
        (0, _with(vb.READY, **vb._HANDS_UP)),
        (5, _with(vb.READY, LeftLeg=(56, 0, 0), RightLeg=(56, 0, 0), **vb._HANDS_UP)),
        (9, _with(vb.STANDING, Spine02=(-4, 0, 0), neck=(-14, 0, 0),
                  LeftArm=(0, -50, -44), LeftForeArm=(0, 0, -60),
                  RightArm=(0, 50, 44), RightForeArm=(0, 0, 60))),
        (18, vb.READY),
    ]),
    # The back set: the same hands, but the back arches and the arms push up and back over
    # the head. Contact on 10, like vb_set.
    "vb_back_set": _stroke([
        (0, _with(vb.READY, **vb._HANDS_UP)),
        (5, lean(_with(vb.READY, LeftLeg=(58, 0, 0), RightLeg=(58, 0, 0), **vb._HANDS_UP), 6)),
        (10, _with(vb.STANDING, Spine02=(-18, 0, 0), Spine01=(-8, 0, 0), neck=(-24, 0, 0),
                   LeftArm=(0, -70, -20), LeftForeArm=(0, 0, -40),
                   RightArm=(0, 70, 20), RightForeArm=(0, 0, 40))),
        (20, vb.READY),
    ]),
    # The tip: the spike's jump and arm, but the hand stops short and pushes the ball over
    # with the fingers. Contact on 9, like vb_spike.
    "vb_tip": _stroke([
        (0, vb.CLIPS["vb_spike"]["keys"][0][1]),
        (5, vb.CLIPS["vb_spike"]["keys"][1][1]),
        (9, _with(vb.CLIPS["vb_spike"]["keys"][2][1], Spine02=(4, 0, 0),
                  RightArm=(0, 96, 6), RightForeArm=(0, 0, -30))),
        (14, vb.CLIPS["vb_spike"]["keys"][3][1]),
        (24, vb.READY),
    ]),
    # The attacker's approach, the last three steps in: long low strides with both arms
    # swinging back. Plays as the footwork when somebody is running in to spike.
    "vb_approach": _cycle([
        (0, lean(_with(vb.READY, LeftUpLeg=(-40, 0, -6), LeftLeg=(40, 0, 0),
                       RightUpLeg=(20, 0, 6), RightLeg=(40, 0, 0), RightFoot=(-20, 0, 0),
                       LeftArm=(0, 40, 40), RightArm=(0, -40, -40)), 22)),
        (6, lean(_with(vb.READY, RightUpLeg=(-40, 0, 6), RightLeg=(40, 0, 0),
                       LeftUpLeg=(20, 0, -6), LeftLeg=(40, 0, 0), LeftFoot=(-20, 0, 0),
                       LeftArm=(0, 30, 60), RightArm=(0, -30, -60)), 24)),
        (12, lean(_with(vb.READY, LeftUpLeg=(-40, 0, -6), LeftLeg=(40, 0, 0),
                        RightUpLeg=(20, 0, 6), RightLeg=(40, 0, 0), RightFoot=(-20, 0, 0),
                        LeftArm=(0, 40, 40), RightArm=(0, -40, -40)), 22)),
    ]),
    # The jump serve: a run-up, a high toss, a spike in the air from behind the line.
    # Contact on 15, the same frame as vb_serve, so the toss the game already throws for
    # the standing serve lands on it.
    "vb_jump_serve": _stroke([
        (0, vb.STANDING),
        (5, lean(_with(vb.READY, LeftUpLeg=(-40, 0, -6), LeftLeg=(40, 0, 0),
                       RightUpLeg=(20, 0, 6), RightLeg=(40, 0, 0),
                       LeftArm=(0, -60, -20), RightArm=(0, -40, -40)), 18)),
        (10, lean(_with(vb.READY, LeftUpLeg=(-34, 0, -8), RightUpLeg=(-34, 0, 8),
                        LeftLeg=(64, 0, 0), RightLeg=(64, 0, 0),
                        LeftArm=(0, 30, 58), RightArm=(0, -30, -58)), 22)),
        (13, vb.CLIPS["vb_spike"]["keys"][1][1]),
        (15, vb.CLIPS["vb_spike"]["keys"][2][1]),
        (20, vb.CLIPS["vb_spike"]["keys"][3][1]),
        (30, vb.READY),
    ]),

    # ================================================================ sepak takraw ====
    # Inside of the left foot, for a ball to the left. Contact on 9, like st_receive.
    "st_receive_left": _stroke([
        (0, st.STANCE),
        (5, _at(lean(_with(st._ARMS_OUT,
                           RightUpLeg=(-10, 0, 4), RightLeg=(22, 0, 0),
                           LeftUpLeg=_left_thigh(48, 80, 34), LeftLeg=(92, 0, 0),
                           LeftFoot=(-10, 0, 0)), 6), z=0.03)),
        (9, lean(_with(st._ARMS_OUT,
                       RightUpLeg=(-8, 0, 4), RightLeg=(16, 0, 0),
                       LeftUpLeg=_left_thigh(38, 70, 30), LeftLeg=(84, 0, 0),
                       LeftFoot=(-10, 0, 0)), 4)),
        (15, st.STANCE),
    ]),
    # Off the thigh, for a ball arriving at the waist: the right thigh lifted straight
    # forward to horizontal under it. Contact on 9.
    "st_thigh": _stroke([
        (0, st.STANCE),
        (5, lean(_with(st._ARMS_OUT, LeftUpLeg=(-6, 0, -4), LeftLeg=(14, 0, 0),
                       RightUpLeg=(-70, 0, 4), RightLeg=(80, 0, 0)), 0)),
        (9, lean(_with(st._ARMS_OUT, LeftUpLeg=(-6, 0, -4), LeftLeg=(14, 0, 0),
                       RightUpLeg=(-88, 0, 4), RightLeg=(90, 0, 0)), -4)),
        (16, st.STANCE),
    ]),
    # Off the chest, for a ball arriving high: chest out, arms back, a small give.
    "st_chest": _stroke([
        (0, st.STANCE),
        (5, lean(_with(st._ARMS_WIDE, Spine02=(-14, 0, 0), Spine01=(-6, 0, 0), neck=(10, 0, 0),
                       LeftArm=(0, 30, 30), RightArm=(0, -30, -30),
                       LeftLeg=(26, 0, 0), RightLeg=(26, 0, 0)), -10)),
        (9, lean(_with(st._ARMS_WIDE, Spine02=(-6, 0, 0), neck=(14, 0, 0),
                       LeftArm=(0, 30, 40), RightArm=(0, -30, -40),
                       LeftLeg=(34, 0, 0), RightLeg=(34, 0, 0)), -6)),
        (16, st.STANCE),
    ]),
    # The knee set: a ball too low for the inside of the foot at waist height, popped up off
    # the knee to the striker. Contact on 10, like st_set.
    "st_knee_set": _stroke([
        (0, st.STANCE),
        (6, lean(_with(st._ARMS_OUT, LeftUpLeg=(-6, 0, -4), LeftLeg=(14, 0, 0),
                       RightUpLeg=(-50, 0, 4), RightLeg=(70, 0, 0)), 0)),
        (10, lean(_with(st._ARMS_OUT, LeftUpLeg=(-4, 0, -4), LeftLeg=(10, 0, 0),
                        RightUpLeg=(-74, 0, 4), RightLeg=(100, 0, 0), neck=(-10, 0, 0)), -6)),
        (20, st.STANCE),
    ]),
    # The sunback: the scissor spike with the body square to the net rather than rolled, the
    # kicking leg coming straight up and over in front. Contact on 14, like st_spike.
    "st_sunback": _stroke([
        (0, _at(lean(_with(st._ARMS_OUT, LeftUpLeg=(-30, 0, -4), LeftLeg=(56, 0, 0),
                           RightUpLeg=(18, 0, 4), RightLeg=(40, 0, 0)), 14), z=-0.10)),
        (4, _at(_with(st._ARMS_WIDE, LeftUpLeg=(-4, 0, -4), LeftLeg=(6, 0, 0), LeftFoot=(40, 0, 0),
                      RightUpLeg=(-50, 0, 4), RightLeg=(70, 0, 0), Hips=(-10, 0, 0)), z=0.12)),
        (10, _at(_with(st._ARMS_WIDE, Hips=(-34, 0, 0),
                       LeftUpLeg=(-70, 0, -4), LeftLeg=(40, 0, 0),
                       RightUpLeg=(-40, 0, 4), RightLeg=(50, 0, 0), neck=(-14, 0, 0)), z=0.70)),
        (14, _at(_with(st._ARMS_WIDE, Hips=(-36, 0, 0),
                       LeftUpLeg=(10, 0, -4), LeftLeg=(30, 0, 0),
                       RightUpLeg=(-118, 0, 4), RightLeg=(6, 0, 0), neck=(-20, 0, 0)), z=0.82)),
        (20, _at(_with(st._ARMS_WIDE, Hips=(-10, 0, 0),
                       LeftUpLeg=(-30, 0, -4), LeftLeg=(60, 0, 0),
                       RightUpLeg=(-30, 0, 4), RightLeg=(60, 0, 0)), z=0.0)),
        (30, st.STANCE),
    ]),
}

## Each clip's frame of contact. Player.CONTACT_AT holds the same numbers, in seconds.
CONTACT = {
    "tn_forehand": 6, "tn_backhand": 6, "tn_slice_fh": 6, "tn_slice_bh": 6,
    "tn_run_fh": 8, "tn_run_bh": 8, "tn_volley_fh": 5, "tn_volley_bh": 5,
    "tn_return_fh": 5, "tn_return_bh": 5,
    "tt_serve": 10, "tt_fh_drive": 5, "tt_bh_drive": 5, "tt_fh_push": 6, "tt_bh_push": 6,
    "tt_block": 4, "tt_smash": 6, "tt_lob": 7,
    "vb_pass_left": 9, "vb_pass_right": 9, "vb_dive": 9, "vb_dive_sand": 9,
    "vb_overhead_pass": 9, "vb_back_set": 10, "vb_tip": 9, "vb_jump_serve": 15,
    "st_receive_left": 9, "st_thigh": 9, "st_chest": 9, "st_knee_set": 10, "st_sunback": 14,
}

LOOPING = sorted(name for name, clip in CLIPS.items() if clip["loop"])
