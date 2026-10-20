"""Table tennis's arena, from the national ranking event up: modelled on Malawati Stadium in
Shah Alam, where the 2016 World Team Championships were played.

A round indoor stadium under a dome. A circular bowl — a lower tier, a concourse ring, an
upper tier behind a balcony front — in the salmon the 2016 championships dressed the hall
in, with the sponsors along the balcony; a ribbed dome closing over the top with a ring at
its crown; and a screen cube hung from the crown over the table.

The bowl is a rounded rectangle whose corner radius is half its width, which is a circle,
so `Bowl` seats it with the same code as every other venue.
"""

import math

import lib


def materials():
    return {
        "steps": lib.textured("steps", "steps_concrete", (0.58, 0.55, 0.55, 1)),
        "walls": lib.textured("walls", "painted_plaster_wall", (0.78, 0.46, 0.42, 1)),
        "floor": lib.textured("floor", "hangar_concrete_floor", (0.35, 0.33, 0.36, 1)),
        "dome": lib.textured("dome", "box_profile_metal_sheet", (0.62, 0.62, 0.66, 1), 0.3),
        "steel": lib.plain("steel", (0.80, 0.80, 0.82, 1), 0.4, 0.6),
        "glass": lib.plain("glass", (0.55, 0.65, 0.75, 1), 0.05, 0.0, alpha=0.25),
        "ribbon": lib.plain("ribbon", (0.06, 0.02, 0.05, 1), 0.3, emission=((0.70, 0.10, 0.40, 1), 0.7)),
        "wrap": lib.picture("wrap", lib.TEXTURES + "/wrap_table_tennis.png", emission=0.4),
        "lamp": lib.plain("lamp", (1, 1, 1, 1), 0.2, emission=((1.0, 0.97, 0.90, 1), 7.0)),
        "dark": lib.plain("dark", (0.03, 0.03, 0.04, 1), 0.6),
        "screen": lib.plain("screen", (0.01, 0.02, 0.05, 1), 0.2, emission=((0.14, 0.03, 0.12, 1), 1.5)),
        "nosing": lib.plain("nosing", (0.85, 0.70, 0.10, 1), 0.6),
        "exit": lib.plain("exit", (0.05, 0.6, 0.2, 1), 0.3, emission=((0.10, 0.95, 0.35, 1), 2.5)),
    }


UV_METRES = {"steps": 2.0, "walls": 3.0, "floor": 5.0, "dome": 2.0, "wrap": 16.0}


def build(b, plan):
    lib.floor_quad(b, plan, "floor", y=-0.012)
    pod = plan["podium"]
    lib.podium(b, plan, pod["solid_height"], ribbon="ribbon")
    lower, upper = plan["tiers"]
    lib.perimeter_tier(b, lower)
    lib.perimeter_tier(b, upper)
    lib.aisles(b, plan)

    cc = plan["concourse"]
    b.band("steps", cc["from_offset"], cc["height"], cc["to_offset"], cc["height"], "up")
    b.band("glass", cc["from_offset"] + 0.05, cc["height"], cc["from_offset"] + 0.05, cc["height"] + 1.0, "in")
    lib.tier_fascia(b, plan, cc["to_offset"], cc["height"], upper["base"] + 1.0, "walls",
                    ribbon="wrap", ribbon_band=(cc["height"] + 0.15, upper["base"] + 0.9))
    for (bx, bz), (nx, nz) in plan.aisle_spots():
        d = cc["to_offset"] - 0.04
        b.box("exit", (bx + nx * d, cc["height"] + 2.2, bz + nz * d), (0.6, 0.22, 0.04), math.atan2(nx, nz))

    bw = plan["back_wall"]
    b.band("walls", bw["offset"], lib.tier_top(upper), bw["offset"], bw["spring"], "in")
    _dome(b, plan, bw["offset"], bw["spring"], plan["dome"])
    lib.screens(b, plan, hang_to=plan["dome"]["crown"] - 0.5)
    lib.lighting_rig_cables(b, plan, steel="steel", roof_at=lambda x: plan["dome"]["catwalk"])


def _dome(b, plan, edge, spring, dome):
    """The dome: panels between radial ribs, from the top of the back wall to a ring at the
    crown, a catwalk ring of lamps under it, and the ribs themselves standing proud."""
    R = plan.hx + edge  # radius of the bowl's back wall
    crown, ring = dome["crown"], dome["oculus"]
    ribs = dome["ribs"]
    steps = 10

    def P(a, f):
        # f from 0 at the wall to 1 at the oculus; a circular profile.
        r = R + (ring - R) * f
        y = spring + (crown - spring) * math.sin(f * math.pi * 0.5)
        return (plan.cx + r * math.cos(a), y, plan.cz + r * math.sin(a))
    for i in range(ribs):
        a0 = math.tau * i / ribs
        a1 = math.tau * (i + 1) / ribs
        for k in range(steps):
            f0, f1 = k / steps, (k + 1) / steps
            b.quad("dome", P(a0, f0), P(a1, f0), P(a1, f1), P(a0, f1), (0, -1, 0))
        for k in range(steps):
            p, q = P(a0, k / steps), P(a0, (k + 1) / steps)
            b.beam("steel", (p[0], p[1] - 0.5, p[2]), (q[0], q[1] - 0.5, q[2]), 0.35, 0.8)
    # The crown ring, and a disc of dark over the oculus.
    for i in range(ribs):
        p, q = P(math.tau * i / ribs, 1.0), P(math.tau * (i + 1) / ribs, 1.0)
        b.beam("steel", (p[0], p[1] - 0.6, p[2]), (q[0], q[1] - 0.6, q[2]), 0.5, 1.2)
        b.tri("dark", (plan.cx, crown + 0.2, plan.cz), q, p, (0, -1, 0))
    # Rings round the dome at two heights.
    for f in (0.35, 0.7):
        for i in range(ribs):
            p, q = P(math.tau * i / ribs, f), P(math.tau * (i + 1) / ribs, f)
            b.beam("steel", (p[0], p[1] - 0.4, p[2]), (q[0], q[1] - 0.4, q[2]), 0.2, 0.3)
    # A catwalk ring of lamps, hung from the dome.
    cr = dome["catwalk_radius"]
    y = dome["catwalk"]
    n = 36
    for i in range(n):
        a0, a1 = math.tau * i / n, math.tau * (i + 1) / n
        p = (plan.cx + cr * math.cos(a0), y, plan.cz + cr * math.sin(a0))
        q = (plan.cx + cr * math.cos(a1), y, plan.cz + cr * math.sin(a1))
        b.beam("dark", p, q, 1.0, 0.12)
        b.box("lamp", (p[0], y - 0.2, p[2]), (0.45, 0.16, 0.45), a0)
        if i % 3 == 0:
            b.tube("steel", p, (p[0], spring + (crown - spring) * 0.9, p[2]), 0.03, 4)
