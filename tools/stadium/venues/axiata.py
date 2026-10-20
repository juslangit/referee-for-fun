"""Badminton's arena, from the state open up: modelled on the Axiata Arena at Bukit Jalil,
where the Malaysia Open is played.

From the reference photograph (Commons, "Axiata Arena 2017 Sea Games"): a rectangular bowl
with rounded corners, two tiers of blue seats, a ring of glass-fronted suites between the
tiers, LED boards along the front of each tier, a dark floor big enough for several courts,
and over all of it a deep black steel roof grid with catwalks and lamps, and a four-sided
screen hung over the middle of the floor.

The bowl is centred between our court and the one behind the umpire (Venue.SECOND_COURT_X),
as the community hall is, and the near tier starts where the near stand always has, so the
crowd the umpire looks at all match is as close as it was.
"""

import math

import lib


def materials():
    return {
        "steps": lib.textured("steps", "steps_concrete", (0.42, 0.43, 0.47, 1)),
        "walls": lib.textured("walls", "wall_panels", (0.30, 0.32, 0.37, 1)),
        "apron": lib.textured("apron", "hangar_concrete_floor", (0.30, 0.31, 0.33, 1)),
        "steel": lib.plain("steel", (0.05, 0.05, 0.06, 1), 0.5, 0.6),
        "grating": lib.plain("grating", (0.10, 0.10, 0.11, 1), 0.7, 0.4),
        "ceiling": lib.plain("ceiling", (0.02, 0.02, 0.03, 1), 0.9),
        "glass": lib.plain("glass", (0.55, 0.65, 0.75, 1), 0.05, 0.0, alpha=0.25),
        "suite": lib.plain("suite", (0.10, 0.08, 0.06, 1), 0.6, emission=((1.0, 0.78, 0.50, 1), 0.28)),
        "ribbon": lib.plain("ribbon", (0.02, 0.04, 0.12, 1), 0.3, emission=((0.04, 0.16, 0.62, 1), 0.7)),
        "lamp": lib.plain("lamp", (1, 1, 1, 1), 0.2, emission=((1.0, 0.97, 0.90, 1), 8.0)),
        "screen": lib.plain("screen", (0.01, 0.02, 0.05, 1), 0.2, emission=((0.04, 0.10, 0.30, 1), 1.5)),
        "dark": lib.plain("dark", (0.03, 0.03, 0.04, 1), 0.6),
        "nosing": lib.plain("nosing", (0.85, 0.70, 0.10, 1), 0.6),
        "exit": lib.plain("exit", (0.05, 0.6, 0.2, 1), 0.3, emission=((0.10, 0.95, 0.35, 1), 2.5)),
        "wrap": lib.picture("wrap", lib.TEXTURES + "/wrap_badminton.png", emission=1.2),
    }


UV_METRES = {"steps": 2.0, "walls": 4.0, "apron": 5.0, "wrap": 16.0}


def build(b, plan):
    pod = plan["podium"]
    lib.floor_quad(b, plan, "apron", y=-0.012)
    lib.podium(b, plan, pod["solid_height"], ribbon="ribbon")

    lower, upper = plan["tiers"]
    lib.perimeter_tier(b, lower)
    lib.perimeter_tier(b, upper)
    lib.aisles(b, plan)

    # The suites between the tiers: a concourse floor, a glass front with warm rooms behind
    # it, and a solid fascia over them carrying a sponsor ribbon.
    st = plan["suites"]
    b.band("steps", st["from_offset"], st["floor"], st["to_offset"], st["floor"], "up")
    b.band("walls", st["from_offset"], lib.tier_top(lower), st["from_offset"], st["floor"] + 1.0, "in")
    b.band("glass", st["front"], st["floor"] + 1.0, st["front"], st["top"] - 0.5, "in")
    b.band("suite", st["to_offset"], st["floor"], st["to_offset"], st["top"], "in")
    b.band("suite", st["front"], st["top"], st["to_offset"], st["top"], "down")
    lib.tier_fascia(b, plan, st["front"] - 0.1, st["top"] - 0.5, upper["base"] + 1.1, "walls",
                    ribbon="wrap", ribbon_band=(st["top"] - 0.35, upper["base"] + 0.95))
    # Exit signs over every aisle, on the suite fronts.
    for (bx, bz), (nx, nz) in plan.aisle_spots():
        d = st["front"] - 0.14
        b.box("exit", (bx + nx * d, st["floor"] + 2.4, bz + nz * d), (0.6, 0.22, 0.04), math.atan2(nx, nz))

    # The back of the upper tier, up to the roof.
    bw = plan["back_wall"]
    b.band("walls", bw["offset"], lib.tier_top(upper), bw["offset"], bw["top"], "in")

    # The roof: a black ceiling, the space frame under it, catwalks with their lamps, and the
    # screen cube over the middle of the floor.
    rf = plan["roof"]
    ext = bw["offset"] + 0.4
    x0, x1 = plan.cx - plan.hx - ext, plan.cx + plan.hx + ext
    z0, z1 = plan.cz - plan.hz - ext, plan.cz + plan.hz + ext
    b.quad("ceiling", (x0, rf["top"], z0), (x1, rf["top"], z0), (x1, rf["top"], z1), (x0, rf["top"], z1),
           (0, -1, 0))
    lib.space_frame(b, x0 + 1, x1 - 1, z0 + 1, z1 - 1, rf["bottom"], rf["top"] - 0.3, rf["bay"])
    for d in rf["catwalks"]:
        y = rf["bottom"] - 0.9
        b.band("grating", d, y, d + 1.0, y, "down")
        b.band("grating", d, y + 0.02, d + 1.0, y + 0.02, "up")
        b.band("steel", d - 0.02, y, d - 0.02, y + 1.0, "in")
        for p, n, s in plan.perimeter_points(d + 0.5, 3.0):
            b.box("lamp", (p[0], y - 0.2, p[2]), (0.5, 0.18, 0.5), math.atan2(n[0], n[1]))
            b.box("dark", (p[0], y - 0.05, p[2]), (0.6, 0.15, 0.6), math.atan2(n[0], n[1]))
        for p, n, s in plan.perimeter_points(d + 0.5, 9.0):
            b.tube("steel", (p[0], y + 1.0, p[2]), (p[0], rf["bottom"], p[2]), 0.03, 4)
    lib.screens(b, plan, hang_to=rf["bottom"])
    lib.lighting_rig_cables(b, plan, roof_at=lambda x: rf["bottom"])
