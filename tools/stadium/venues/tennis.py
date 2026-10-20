"""The tennis stadium: an open-air bowl round the court at every rung.

Luqman, 2026-10-20, after the outdoor courts got a photographed sky: "the hdri is good but
the problem now is the court stadium ... create a proper stadium arena". He chose one
generic modern stadium for every rung, modelled here rather than downloaded.

A podium wall with an LED ribbon and glass on it, a 14-row lower tier, a concourse, an
8-row upper tier behind a glass front, a back wall with fins down its outside, a
cantilevered roof on steel ribs with floodlights along its tip, two corner screens and a
paved plaza for the stadium to stand on.
"""

import math

import lib


def materials():
    return {
        "steps": lib.textured("steps", "steps_concrete", (0.86, 0.87, 0.89, 1)),
        "walls": lib.textured("walls", "wall_panels", (0.95, 0.95, 0.97, 1)),
        "plaza": lib.textured("plaza", "plaza_pavers"),
        "roof": lib.textured("roof", "roof_sheet", (0.92, 0.94, 0.96, 1), 0.5),
        # Painted over by the game with the court's own surround colour at each rung.
        "apron": lib.plain("apron", (0.14, 0.30, 0.36, 1), 0.8),
        "steel": lib.plain("steel", (0.78, 0.80, 0.83, 1), 0.35, 0.9),
        "dark": lib.plain("dark", (0.06, 0.07, 0.09, 1), 0.6),
        "glass": lib.plain("glass", (0.75, 0.85, 0.90, 1), 0.05, 0.0, alpha=0.22),
        "ribbon": lib.plain("ribbon", (0.02, 0.05, 0.14, 1), 0.3,
                            emission=((0.05, 0.20, 0.70, 1), 1.2)),
        "lamp": lib.plain("lamp", (1, 1, 1, 1), 0.2, emission=((1.0, 0.97, 0.90, 1), 6.0)),
        "screen": lib.plain("screen", (0.01, 0.02, 0.05, 1), 0.2,
                            emission=((0.04, 0.10, 0.30, 1), 1.5)),
        "nosing": lib.plain("nosing", (0.85, 0.70, 0.10, 1), 0.6),
    }


UV_METRES = {"steps": 2.0, "walls": 4.0, "plaza": 3.6, "roof": 2.0}


def build(b, plan):
    hx, hz = plan.hx, plan.hz
    pod = plan["podium"]
    # The court-side wall: a solid face with an LED ribbon on it, and glass above.
    b.band("walls", 0.0, 0.0, 0.0, pod["solid_height"], "in")
    b.band("walls", 0.0, pod["solid_height"], pod["thickness"], pod["solid_height"], "up")
    b.band("ribbon", -0.02, 0.35, -0.02, 1.45, "in")
    b.band("glass", 0.08, pod["solid_height"], 0.08, pod["glass_top"], "in")
    b.band("steel", 0.06, pod["glass_top"] - 0.02, 0.10, pod["glass_top"] + 0.04, "up")

    # The floor between the court's own surround and the podium, under everything.
    b.quad("apron", (-hx, -0.005, -hz), (hx, -0.005, -hz), (hx, -0.005, hz), (-hx, -0.005, hz),
           (0, 1, 0))

    for tier in plan["tiers"]:
        lib.perimeter_tier(b, tier)

    cc = plan["concourse"]
    b.band("steps", cc["from_offset"], cc["height"], cc["to_offset"], cc["height"], "up")

    uf = plan["upper_front"]
    b.band("walls", uf["offset"], cc["height"], uf["offset"], uf["solid_top"], "in")
    b.band("walls", uf["offset"], uf["solid_top"], uf["offset"] + 0.2, uf["solid_top"], "up")
    b.band("ribbon", uf["offset"] - 0.02, uf["solid_top"] - 1.25, uf["offset"] - 0.02,
           uf["solid_top"] - 0.25, "in")
    b.band("glass", uf["offset"] + 0.08, uf["solid_top"], uf["offset"] + 0.08, uf["glass_top"], "in")
    b.band("steel", uf["offset"] + 0.06, uf["glass_top"] - 0.02, uf["offset"] + 0.10,
           uf["glass_top"] + 0.04, "up")
    # Glass along the back of the concourse too, where it looks down the lower tier.
    b.band("glass", cc["from_offset"] + 0.05, cc["height"], cc["from_offset"] + 0.05,
           cc["height"] + 1.0, "in")

    bw = plan["back_wall"]
    b.band("walls", bw["offset"], lib.tier_top(plan["tiers"][1]), bw["offset"], bw["top"], "in")
    b.band("walls", bw["offset"] + bw["thickness"], 0.0, bw["offset"] + bw["thickness"],
           bw["top"], "out")
    b.band("walls", bw["offset"], bw["top"], bw["offset"] + bw["thickness"], bw["top"], "up")
    _fins(b, plan, bw)
    _roof(b, plan)
    lib.aisles(b, plan)
    lib.screens(b, plan, hang_to=plan["roof"]["inner_height"] + 0.4)

    ph = plan["plaza_half"]
    b.quad("plaza", (-ph[0], -0.02, -ph[1]), (ph[0], -0.02, -ph[1]),
           (ph[0], -0.02, ph[1]), (-ph[0], -0.02, ph[1]), (0, 1, 0))


def _fins(b, plan, bw):
    """Vertical concrete fins down the outside of the back wall."""
    for p, n, s in plan.perimeter_points(bw["offset"] + bw["thickness"], 3.6):
        d = 0.6
        c = (p[0] + n[0] * d, bw["top"] * 0.5 + 0.2, p[2] + n[1] * d)
        b.box("walls", c, (0.35, bw["top"] + 0.4, 1.2), math.atan2(n[0], n[1]))


def _roof(b, plan):
    rf = plan["roof"]
    i_d, o_d = rf["inner_offset"], rf["outer_offset"]
    i_h, o_h = rf["inner_height"], rf["outer_height"]
    t = rf["thickness"]
    b.band("roof", i_d, i_h + t, o_d, o_h + t, "up")
    b.band("roof", i_d, i_h, o_d, o_h, "down")
    b.band("steel", i_d, i_h, i_d, i_h + t, "in")
    b.band("steel", o_d, o_h, o_d, o_h + t, "out")
    # Ribs under the roof, deep at the back wall and thin at the tip, and a column under each.
    bw = plan["back_wall"]
    for p, n, s in plan.perimeter_points(bw["offset"] + 0.2, rf["rib_spacing"]):
        base = (p[0] - n[0] * (bw["offset"] + 0.2), p[2] - n[1] * (bw["offset"] + 0.2))

        def P(d, y):
            return (base[0] + n[0] * d, y, base[1] + n[1] * d)
        steps = 6
        for k in range(steps):
            f0, f1 = k / steps, (k + 1) / steps
            d0 = o_d - 0.6 + (i_d - o_d + 0.6) * f0
            d1 = o_d - 0.6 + (i_d - o_d + 0.6) * f1
            y0 = o_h + (i_h - o_h) * f0
            y1 = o_h + (i_h - o_h) * f1
            depth0 = 2.2 - 1.9 * f0
            b.beam("steel", P(d0, y0 - depth0 * 0.5), P(d1, y1 - (2.2 - 1.9 * f1) * 0.5),
                   0.25, depth0)
        b.box("steel", P(bw["offset"] + 0.6, bw["top"] * 0.5), (0.45, bw["top"], 0.45),
              math.atan2(n[0], n[1]))
    # Floodlights in a line along the tip of the roof, angled at the court.
    for p, n, s in plan.perimeter_points(i_d + 0.5, 4.2):
        c = (p[0], i_h - 0.35, p[2])
        b.box("lamp", c, (1.1, 0.25, 0.5), math.atan2(n[0], n[1]))
        b.box("dark", (c[0], c[1] + 0.2, c[2]), (1.2, 0.2, 0.6), math.atan2(n[0], n[1]))
