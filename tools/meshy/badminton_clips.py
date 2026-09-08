"""The badminton animations, written against the Meshy rig.

A pose is a dictionary of bone name to three rotations in degrees, and the rotations
are about the *world* axes rather than the bone's own. That is deliberate. Meshy's
characters arrive through glTF, which has no concept of a bone tail, so Blender guesses
one — and every bone in this rig came in over a thousand units long pointing somewhere
arbitrary. Bone-local euler angles on a rig like that are unguessable. World axes are
not, because the character stands in a known orientation:

    +Z is up          -Y is the way they are facing        +X is their left

The character is generated in a T-pose, so every arm angle here is a departure from
straight out sideways, not from hanging at the side. That catches you out: an arm at
rest by the hip is a large rotation, not a small one. The two arms are mirror images,
so their signs are opposite:

    RightArm      +Y raises overhead,  -Y drops to the hip
                  +Z swings forward,   -Z swings back behind
    LeftArm       -Y raises overhead,  +Y drops to the hip
                  -Z swings forward,   +Z swings back behind
    RightForeArm  +Z bends the elbow,  LeftForeArm  -Z bends the elbow

Elbows bend about the arm's own rest frame, which is carried along by the shoulder, so
"bend the elbow" means the same thing whether the arm is overhead or by the hip.

Below the waist both sides share signs, because a hip and a knee only fold one way:

    UpLeg    -X swings the leg forward, +X back
    Leg      +X bends the knee
    Spine    +X leans the body forward

Frames are at 24 fps. `loop` marks the clips that repeat rather than play once; the
game reads that list too, so a clip only has to be described in one place.
"""

FPS = 24

## A pose entry under this key is not a bone but a shift of the whole body, in metres,
## along the world axes. Only the lunge and the celebration need it.
MOVE = "@move"

# Bones that exist on the Meshy rig, for the sanity check in the forge. A misspelled
# bone name is otherwise silent: the pose simply does not happen and the character
# plays the shot with one arm.
BONES = [
    "Hips", "LeftUpLeg", "LeftLeg", "LeftFoot", "LeftToeBase",
    "RightUpLeg", "RightLeg", "RightFoot", "RightToeBase",
    "Spine02", "Spine01", "Spine",
    "LeftShoulder", "LeftArm", "LeftForeArm", "LeftHand",
    "RightShoulder", "RightArm", "RightForeArm", "RightHand",
    "neck", "Head",
]

def lean(pose, degrees):
    """Leans the whole body forward from the ankles, keeping the feet on the floor.

    The obvious way to lean somebody forward is to bend their spine, and on this rig it
    barely works. Meshy's auto-rigging puts the torso almost entirely on the hip bone
    and the neck — the three spine bones between them carry 418 units of weight against
    the hips' 601 — so a forty-degree bend at the waist moves a sliver of shirt and
    leaves the player standing upright.

    Rotating the hips does move the whole body, but it takes the legs with it and lifts
    the feet off the floor. So the hips turn and both thighs turn back by the same
    amount, which cancels at the knee and leaves a body leaning over planted feet.
    """
    tilted = dict(pose)
    tilted["Hips"] = _add(tilted.get("Hips"), (degrees, 0, 0))
    for thigh in ("LeftUpLeg", "RightUpLeg"):
        tilted[thigh] = _add(tilted.get(thigh), (-degrees, 0, 0))
    return tilted


def _add(existing, extra):
    if existing is None:
        return extra
    return tuple(a + b for a, b in zip(existing, extra))


# The stance everything else is a departure from: knees soft, racket up in front,
# weight forward. A badminton player at rest is not standing still, they are waiting.
READY = lean({
    "Spine02": (6, 0, 0),
    "Spine": (4, 0, 0),
    "LeftUpLeg": (-12, 0, -4),
    "LeftLeg": (26, 0, 0),
    "RightUpLeg": (-12, 0, 4),
    "RightLeg": (26, 0, 0),
    "LeftArm": (0, 52, -30),
    "LeftForeArm": (0, 0, -62),
    "RightArm": (0, -48, 34),
    "RightForeArm": (0, 0, 72),
}, 12)


def _with(base, **changes):
    """A pose described as a departure from another one, which is how a shot is
    actually played — everything below the waist stays where it was."""
    pose = dict(base)
    pose.update(changes)
    return pose


CLIPS = {
    # --- the ones that repeat ---------------------------------------------------
    "idle": {
        "loop": True,
        "keys": [
            (0, _with(READY, LeftUpLeg=(-8, 0, -4), RightUpLeg=(-8, 0, 4),
                      LeftLeg=(16, 0, 0), RightLeg=(16, 0, 0), Spine02=(6, 0, 0),
                      LeftArm=(0, 70, -18), LeftForeArm=(0, 0, -40),
                      RightArm=(0, -66, 22), RightForeArm=(0, 0, 48))),
            (14, _with(READY, LeftUpLeg=(-12, 0, -4), RightUpLeg=(-12, 0, 4),
                       LeftLeg=(26, 0, 0), RightLeg=(26, 0, 0), Spine02=(9, 0, 0),
                       LeftArm=(0, 74, -16), LeftForeArm=(0, 0, -36),
                       RightArm=(0, -70, 20), RightForeArm=(0, 0, 44))),
            (28, _with(READY, LeftUpLeg=(-8, 0, -4), RightUpLeg=(-8, 0, 4),
                       LeftLeg=(16, 0, 0), RightLeg=(16, 0, 0), Spine02=(6, 0, 0),
                       LeftArm=(0, 70, -18), LeftForeArm=(0, 0, -40),
                       RightArm=(0, -66, 22), RightForeArm=(0, 0, 48))),
        ],
    },
    "ready": {
        "loop": True,
        "keys": [
            (0, READY),
            (10, _with(READY, Spine02=(14, 0, 0),
                       LeftLeg=(34, 0, 0), RightLeg=(34, 0, 0),
                       RightArm=(0, -42, 38), RightForeArm=(0, 0, 78))),
            (20, READY),
        ],
    },
    # Bent double with hands on the knees, between rallies in a long third game.
    "tired": {
        "loop": True,
        "keys": [
            (0, lean({
                "Spine02": (16, 0, 0), "Spine01": (8, 0, 0), "Spine": (-14, 0, 0),
                "neck": (-16, 0, 0),
                "LeftUpLeg": (-6, 0, -6), "LeftLeg": (22, 0, 0),
                "RightUpLeg": (-6, 0, 6), "RightLeg": (22, 0, 0),
                "LeftArm": (0, 58, -52), "LeftForeArm": (0, 0, -48),
                "RightArm": (0, -56, 52), "RightForeArm": (0, 0, 48),
            }, 46)),
            (18, lean({
                "Spine02": (18, 0, 0), "Spine01": (9, 0, 0), "Spine": (-16, 0, 0),
                "neck": (-18, 0, 0),
                "LeftUpLeg": (-6, 0, -6), "LeftLeg": (26, 0, 0),
                "RightUpLeg": (-6, 0, 6), "RightLeg": (26, 0, 0),
                "LeftArm": (0, 62, -50), "LeftForeArm": (0, 0, -44),
                "RightArm": (0, -60, 50), "RightForeArm": (0, 0, 44),
            }, 51)),
            (36, lean({
                "Spine02": (16, 0, 0), "Spine01": (8, 0, 0), "Spine": (-14, 0, 0),
                "neck": (-16, 0, 0),
                "LeftUpLeg": (-6, 0, -6), "LeftLeg": (22, 0, 0),
                "RightUpLeg": (-6, 0, 6), "RightLeg": (22, 0, 0),
                "LeftArm": (0, 58, -52), "LeftForeArm": (0, 0, -48),
                "RightArm": (0, -56, 52), "RightForeArm": (0, 0, 48),
            }, 46)),
        ],
    },
    # Both palms up at the umpire. The one time anybody looks at the chair.
    "argue": {
        "loop": True,
        "keys": [
            (0, lean(_with(READY, LeftArm=(0, 38, -48), LeftForeArm=(0, 0, -78),
                           RightArm=(0, -36, 50), RightForeArm=(0, 0, 78),
                           neck=(-10, 0, 0)), -16)),
            (16, lean(_with(READY, LeftArm=(0, 26, -58), LeftForeArm=(0, 0, -86),
                            RightArm=(0, -24, 60), RightForeArm=(0, 0, 86),
                            neck=(-16, 0, 0)), -22)),
            (32, lean(_with(READY, LeftArm=(0, 38, -48), LeftForeArm=(0, 0, -78),
                            RightArm=(0, -36, 50), RightForeArm=(0, 0, 78),
                            neck=(-10, 0, 0)), -16)),
        ],
    },

    # The line judges sit in their corner for the whole match, which is the one thing
    # they do that no player ever does. Same rig, same file, so they get the clip too.
    "sit": {
        "loop": True,
        "keys": [
            (0, {
                MOVE: (0.0, 0.0, -0.44),
                "Spine02": (6, 0, 0),
                "LeftUpLeg": (-84, 0, -7), "LeftLeg": (82, 0, 0), "LeftFoot": (-4, 0, 0),
                "RightUpLeg": (-84, 0, 7), "RightLeg": (82, 0, 0), "RightFoot": (-4, 0, 0),
                "LeftArm": (0, 74, -16), "LeftForeArm": (0, 0, -54),
                "RightArm": (0, -72, 18), "RightForeArm": (0, 0, 56),
            }),
            (30, {
                MOVE: (0.0, 0.0, -0.44),
                "Spine02": (9, 0, 0),
                "LeftUpLeg": (-84, 0, -7), "LeftLeg": (82, 0, 0), "LeftFoot": (-4, 0, 0),
                "RightUpLeg": (-84, 0, 7), "RightLeg": (82, 0, 0), "RightFoot": (-4, 0, 0),
                "LeftArm": (0, 76, -14), "LeftForeArm": (0, 0, -50),
                "RightArm": (0, -74, 16), "RightForeArm": (0, 0, 52),
            }),
            (60, {
                MOVE: (0.0, 0.0, -0.44),
                "Spine02": (6, 0, 0),
                "LeftUpLeg": (-84, 0, -7), "LeftLeg": (82, 0, 0), "LeftFoot": (-4, 0, 0),
                "RightUpLeg": (-84, 0, 7), "RightLeg": (82, 0, 0), "RightFoot": (-4, 0, 0),
                "LeftArm": (0, 74, -16), "LeftForeArm": (0, 0, -54),
                "RightArm": (0, -72, 18), "RightForeArm": (0, 0, 56),
            }),
        ],
    },

    # --- the shots, played once -------------------------------------------------
    # Wind up, contact overhead, follow through down across the body. The non-racket
    # arm points up at the shuttle, which is the thing that makes a badminton smash
    # look like badminton and not like a serve at tennis.
    "smash": {
        "loop": False,
        "keys": [
            (0, lean(_with(READY, RightArm=(0, 94, -32), RightForeArm=(0, 0, -78),
                           LeftArm=(0, -72, -14), LeftForeArm=(0, 0, -8),
                           Spine01=(-8, 0, 0)), -26)),
            (6, lean(_with(READY, RightArm=(0, 90, 24), RightForeArm=(0, 0, -6),
                           LeftArm=(0, -30, 24), LeftForeArm=(0, 0, -32)), 6)),
            (18, lean(_with(READY, RightArm=(0, -26, 72), RightForeArm=(0, 0, 46),
                            LeftArm=(0, 24, 34), LeftForeArm=(0, 0, -52)), 22)),
        ],
    },
    "forehand": {
        "loop": False,
        "keys": [
            (0, _with(READY, RightArm=(0, -22, -62), RightForeArm=(0, 0, 54),
                      Spine02=(8, 0, -12))),
            (6, _with(READY, RightArm=(0, 8, 32), RightForeArm=(0, 0, 14),
                      Spine02=(12, 0, 8))),
            (16, _with(READY, RightArm=(0, -14, 86), RightForeArm=(0, 0, 58),
                       Spine02=(14, 0, 14))),
        ],
    },
    "backhand": {
        "loop": False,
        "keys": [
            (0, _with(READY, RightArm=(0, -18, 82), RightForeArm=(0, 0, 88),
                      Spine02=(8, 0, 16))),
            (6, _with(READY, RightArm=(0, 12, 22), RightForeArm=(0, 0, 26),
                      Spine02=(10, 0, -4))),
            (16, _with(READY, RightArm=(0, 20, -42), RightForeArm=(0, 0, 10),
                       Spine02=(8, 0, -12))),
        ],
    },
    # Underarm and below the waist, because in badminton it has to be.
    "serve": {
        "loop": False,
        "keys": [
            (0, _with(READY, RightArm=(0, -72, -38), RightForeArm=(0, 0, 46),
                      LeftArm=(0, 28, -58), LeftForeArm=(0, 0, -18),
                      Spine02=(6, 0, 0))),
            (8, _with(READY, RightArm=(0, -64, 18), RightForeArm=(0, 0, 22),
                      LeftArm=(0, 34, -44), LeftForeArm=(0, 0, -24))),
            (20, _with(READY, RightArm=(0, -30, 62), RightForeArm=(0, 0, 52),
                       LeftArm=(0, 48, -24), LeftForeArm=(0, 0, -34))),
        ],
    },
    # A long step onto the front foot with the racket at full stretch. This is how a
    # player reaches a net shot, and it is the single most recognisable badminton shape.
    "lunge": {
        "loop": False,
        "keys": [
            (0, READY),
            # These numbers are measured rather than judged. A lunge only reads as one
            # if both feet are on the floor, and by eye it is impossible to tell a
            # planted front foot from one hanging four centimetres above the court. The
            # foot heights were swept against the rig until the front foot landed flat
            # and the back one trailed on its toe with the heel up, which is what the
            # shot actually looks like.
            (8, {
                MOVE: (0.0, -0.24, -0.20),
                "Hips": (18, 0, 0),
                "Spine02": (10, 0, 0), "Spine01": (6, 0, 0),
                "RightUpLeg": (-74, 0, 6), "RightLeg": (64, 0, 0),
                "RightFoot": (-18, 0, 0),
                "LeftUpLeg": (10, 0, -8), "LeftLeg": (30, 0, 0),
                "LeftFoot": (-40, 0, 0),
                "RightArm": (0, -22, 86), "RightForeArm": (0, 0, 12),
                "LeftArm": (0, 34, 62), "LeftForeArm": (0, 0, -26),
            }),
            (24, READY),
        ],
    },
    "celebrate": {
        "loop": False,
        "keys": [
            (0, READY),
            (8, lean(_with(READY, **{MOVE: (0.0, 0.0, 0.12)},
                           RightArm=(0, 104, 8), RightForeArm=(0, 0, -22),
                           LeftArm=(0, -104, -8), LeftForeArm=(0, 0, 22),
                           neck=(-14, 0, 0),
                           LeftLeg=(14, 0, 0), RightLeg=(14, 0, 0)), -26)),
            (20, lean(_with(READY, RightArm=(0, 88, 18), RightForeArm=(0, 0, -46),
                            LeftArm=(0, -88, -18), LeftForeArm=(0, 0, 46),
                            neck=(-8, 0, 0)), -20)),
            (34, READY),
        ],
    },
}

LOOPING = sorted(name for name, clip in CLIPS.items() if clip["loop"])
