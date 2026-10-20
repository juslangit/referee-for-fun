"""Indoor volleyball's arena, from the national league up: an exhibition hall fitted out
for the Games, modelled on MITEC in Kuala Lumpur, where the 2017 SEA Games volleyball was
played.

An exhibition hall is not a stadium. It is a vast bright shed — a polished floor, walls of
grey metal cladding over a band of concrete panels, roller shutters big enough to drive a
lorry through, long-span steel trusses carrying a metal deck, and a grid of high-bay lamps —
with the competition built inside it for a fortnight: telescopic stands of blue seats down
both sides of the court, and black pipe-and-drape closing off the ends.
"""

import math

import lib


def materials():
    return {
        "floor": lib.textured("floor", "hangar_concrete_floor", (0.72, 0.73, 0.75, 1)),
        "panels": lib.textured("panels", "wall_panels", (0.80, 0.80, 0.82, 1)),
        "cladding": lib.textured("cladding", "cladding", (0.85, 0.87, 0.90, 1), 0.3),
        "deck": lib.textured("deck", "box_profile_metal_sheet", (0.75, 0.77, 0.80, 1), 0.5),
        "shutter": lib.textured("shutter", "box_profile_metal_sheet", (0.55, 0.58, 0.62, 1), 0.4),
        "truss": lib.plain("truss", (0.82, 0.84, 0.86, 1), 0.4, 0.6),
        "stand": lib.plain("stand", (0.16, 0.17, 0.19, 1), 0.6, 0.2),
        "riser": lib.plain("riser", (0.04, 0.04, 0.05, 1), 0.8),
        "drape": lib.plain("drape", (0.02, 0.02, 0.025, 1), 0.95),
        "steel": lib.plain("steel", (0.60, 0.62, 0.65, 1), 0.35, 0.8),
        "lamp": lib.plain("lamp", (1, 1, 1, 1), 0.2, emission=((1.0, 0.98, 0.94, 1), 7.0)),
        "housing": lib.plain("housing", (0.30, 0.31, 0.33, 1), 0.5, 0.5),
        "nosing": lib.plain("nosing", (0.85, 0.70, 0.10, 1), 0.6),
        "ribbon": lib.plain("ribbon", (0.02, 0.04, 0.12, 1), 0.3, emission=((0.04, 0.16, 0.62, 1), 0.7)),
        "exit": lib.plain("exit", (0.05, 0.6, 0.2, 1), 0.3, emission=((0.10, 0.95, 0.35, 1), 2.5)),
        "wrap": lib.picture("wrap", lib.TEXTURES + "/wrap_volleyball.png"),
    }


UV_METRES = {"floor": 6.0, "panels": 4.0, "cladding": 3.0, "deck": 2.0, "shutter": 1.5,
             "wrap": 18.0}


def build(b, plan):
    hall = plan["hall"]
    x0, x1 = -hall["half_x"], hall["half_x"]
    z0, z1 = -hall["half_z"], hall["half_z"]
    H = hall["height"]

    b.quad("floor", (x0, -0.012, z0), (x1, -0.012, z0), (x1, -0.012, z1), (x0, -0.012, z1), (0, 1, 0))
    _shed(b, hall, x0, x1, z0, z1, H)
    for tier in plan["tiers"]:
        for run in tier["runs"]:
            _telescopic(b, plan, tier, run)
    _drapes(b, plan, hall)
    lib.lighting_rig_cables(b, plan, steel="steel", roof_at=lambda x: hall["truss_bottom"])


def _shed(b, hall, x0, x1, z0, z1, H):
    band = hall["panel_band"]
    for (a, c, facing, along_x) in (((x0, z0), (x0, z1), (1, 0, 0), False), ((x1, z1), (x1, z0), (-1, 0, 0), False),
                                     ((x1, z0), (x0, z0), (0, 0, 1), True), ((x0, z1), (x1, z1), (0, 0, -1), True)):
        b.quad("panels", (a[0], 0, a[1]), (c[0], 0, c[1]), (c[0], band, c[1]), (a[0], band, a[1]), facing)
        b.quad("cladding", (a[0], band, a[1]), (c[0], band, c[1]), (c[0], H, c[1]), (a[0], H, a[1]), facing)
        # Roller shutters in every wall, and an exit door with its sign beside each.
        length = math.dist(a, c)
        for f in hall["shutters"]:
            p = (a[0] + (c[0] - a[0]) * f, a[1] + (c[1] - a[1]) * f)
            off = (facing[0] * 0.12, facing[2] * 0.12)
            yaw = math.atan2(facing[0], facing[2])
            b.box("shutter", (p[0] + off[0], 3.2, p[1] + off[1]), (6.0, 6.4, 0.2), yaw)
            b.box("housing", (p[0] + off[0] * 2, 6.7, p[1] + off[1] * 2), (6.4, 0.7, 0.5), yaw)
            q = (a[0] + (c[0] - a[0]) * (f + 4.5 / length), a[1] + (c[1] - a[1]) * (f + 4.5 / length))
            b.box("housing", (q[0] + off[0], 1.1, q[1] + off[1]), (1.8, 2.2, 0.12), yaw)
            b.box("exit", (q[0] + off[0] * 1.4, 2.55, q[1] + off[1] * 1.4), (0.6, 0.22, 0.05), yaw)
    # The metal deck, and the long-span trusses across the hall carrying it.
    b.quad("deck", (x0, H, z0), (x1, H, z0), (x1, H, z1), (x0, H, z1), (0, -1, 0))
    top, bottom = H - 0.3, hall["truss_bottom"]
    z = z0 + hall["truss_bay"]
    while z < z1 - 1.0:
        b.beam("truss", (x0, top, z), (x1, top, z), 0.3, 0.3)
        b.beam("truss", (x0 + 3.0, bottom, z), (x1 - 3.0, bottom, z), 0.3, 0.3)
        n = int((x1 - x0 - 6.0) / 3.0)
        for i in range(n + 1):
            x = x0 + 3.0 + i * (x1 - x0 - 6.0) / n
            b.beam("truss", (x, bottom, z), (x, top, z), 0.12, 0.12)
            if i < n:
                xn = x0 + 3.0 + (i + 1) * (x1 - x0 - 6.0) / n
                if (i < n / 2):
                    b.beam("truss", (x, bottom, z), (xn, top, z), 0.1, 0.1)
                else:
                    b.beam("truss", (x, top, z), (xn, bottom, z), 0.1, 0.1)
        b.beam("truss", (x0, top, z), (x0 + 3.0, bottom, z), 0.3, 0.3)
        b.beam("truss", (x1, top, z), (x1 - 3.0, bottom, z), 0.3, 0.3)
        # High-bay lamps hung under the bottom chord.
        for x in hall["lamp_x"]:
            b.tube("steel", (x, bottom - 1.4, z), (x, bottom, z), 0.02, 4)
            b.box("housing", (x, bottom - 1.6, z), (0.55, 0.4, 0.55))
            b.box("lamp", (x, bottom - 1.82, z), (0.5, 0.04, 0.5))
        z += hall["truss_bay"]
    # Purlins along the hall between the trusses.
    x = x0 + 4.0
    while x < x1:
        b.beam("truss", (x, top + 0.15, z0), (x, top + 0.15, z1), 0.12, 0.2)
        x += 4.0


def _telescopic(b, plan, tier, run):
    """A bank of telescopic seating: stepped decks on a closed black frame, ends panelled
    in black, a skirt with an LED ribbon along the front, and gangway steps with nosings."""
    lib.run_tier(b, tier, run, material="stand", end_material="riser")
    rows, depth, rise, base, first = (tier["rows"], tier["depth"], tier["rise"], tier["base"],
                                      tier["first_offset"])
    b.run_band("riser", run, first - 0.01, 0.0, first - 0.01, base + rise, "in")
    b.run_band("ribbon", run, first - 0.03, 0.12, first - 0.03, base + rise - 0.08, "in")
    nx, nz = plan.run_normal(run)
    yaw = math.atan2(nx, nz)
    gap_w = plan["aisles"]["width"]
    for g in tier.get("gaps", []):
        for r in range(rows):
            d0 = first + depth * r
            y = base + rise * (r + 1)
            b.box("stand", plan.run_point(run, g, d0 + depth * 0.75, y + rise * 0.25),
                  (gap_w, rise * 0.5, depth * 0.5), yaw)
            for edge, top in ((d0 + 0.02, y), (d0 + depth * 0.5 + 0.02, y + rise * 0.5)):
                b.box("nosing", plan.run_point(run, g, edge, top + 0.004), (gap_w * 0.96, 0.01, 0.04), yaw)
        b.box("stand", plan.run_point(run, g, first - 0.25, (base + rise) * 0.5), (gap_w, base + rise, 0.5), yaw)
        # Handrails up both sides of the gangway.
        for side in (-0.5, 0.5):
            a = g + side * gap_w
            p0 = plan.run_point(run, a, first + depth * 0.5, base + rise + 0.9)
            p1 = plan.run_point(run, a, first + depth * (rows - 0.5), base + rise * rows + 0.9)
            b.tube("steel", p0, p1, 0.025)
    # The rail along the back, and the sponsor wrap round the back of the frame.
    top = base + rise * rows
    back = first + depth * rows
    b.run_band("riser", run, back - 0.02, top, back - 0.02, top + 1.1, "in")
    b.run_band("wrap", run, back + 0.02, 0.6, back + 0.02, 2.4, "out")


def _drapes(b, plan, hall):
    """Pipe-and-drape across both ends of the competition floor, between the stands."""
    for z, facing in ((-hall["drape_z"], (0, 0, 1)), (hall["drape_z"], (0, 0, -1))):
        w = hall["drape_half"]
        h = hall["drape_height"]
        folds = 40
        for i in range(folds):
            xa = -w + 2 * w * i / folds
            xb = -w + 2 * w * (i + 1) / folds
            da = 0.06 if i % 2 else 0.0
            db = 0.06 - da
            b.quad("drape", (xa, 0, z - facing[2] * da), (xb, 0, z - facing[2] * db),
                   (xb, h, z - facing[2] * db), (xa, h, z - facing[2] * da), facing)
        b.tube("steel", (-w, h, z), (w, h, z), 0.03)
        x = -w
        while x <= w + 0.01:
            b.tube("steel", (x, 0, z), (x, h, z), 0.025)
            x += 3.0
