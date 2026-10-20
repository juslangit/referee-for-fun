"""Sepak takraw's arena, from the state games up: modelled on Stadium Titiwangsa in Kuala
Lumpur, named the Home of Sepak Takraw in 2026.

An older, smaller indoor stadium than the others — about two thousand seats. Concrete
stands with blue seats down both long sides behind an LED-ribboned wall; above them the
walls of a hall built for the tropics, with a band of pierced ventilation blocks; a barrel
roof on steel arch trusses; and at one end the songket mural the 2026 upgrade gave it.
The ends of the floor are left clear for the event's backdrop and screen.
"""

import math

import lib


def materials():
    return {
        "steps": lib.textured("steps", "steps_concrete", (0.66, 0.67, 0.70, 1)),
        "walls": lib.textured("walls", "painted_plaster_wall", (0.20, 0.36, 0.66, 1)),
        "upper": lib.textured("upper", "painted_plaster_wall", (0.88, 0.90, 0.92, 1)),
        "floor": lib.textured("floor", "hangar_concrete_floor", (0.55, 0.57, 0.60, 1)),
        "zinc": lib.textured("zinc", "corrugated_iron_02", (0.78, 0.80, 0.82, 1), 0.6),
        "steel": lib.plain("steel", (0.85, 0.86, 0.88, 1), 0.4, 0.5),
        "ribbon": lib.plain("ribbon", (0.02, 0.04, 0.12, 1), 0.3, emission=((0.04, 0.16, 0.62, 1), 0.8)),
        "wrap_mural": lib.picture("wrap_mural", lib.TEXTURES + "/songket_mural.png", emission=0.25),
        "wrap_roster": lib.picture("wrap_roster", lib.TEXTURES + "/roster_blocks.png"),
        "nosing": lib.plain("nosing", (0.85, 0.70, 0.10, 1), 0.6),
        "lamp": lib.plain("lamp", (1, 1, 1, 1), 0.2, emission=((1.0, 0.97, 0.90, 1), 6.0)),
        "exit": lib.plain("exit", (0.05, 0.6, 0.2, 1), 0.3, emission=((0.10, 0.95, 0.35, 1), 2.5)),
        "door": lib.plain("door", (0.10, 0.16, 0.30, 1), 0.5),
    }


UV_METRES = {"steps": 2.0, "walls": 3.0, "upper": 3.0, "floor": 5.0, "zinc": 1.6,
             "wrap_mural": 4.0, "wrap_roster": 2.0}


def build(b, plan):
    hall = plan["hall"]
    wx, wz = hall["half_x"], hall["half_z"]
    eave, crown = hall["eave"], hall["crown"]
    b.quad("floor", (-wx, -0.012, -wz), (wx, -0.012, -wz), (wx, -0.012, wz), (-wx, -0.012, wz), (0, 1, 0))

    tier = plan["tiers"][0]
    for run in tier["runs"]:
        _stand(b, plan, tier, run)

    top = lib.tier_top(tier)
    back = tier["first_offset"] + tier["depth"] * tier["rows"]
    # The long walls: from the back of the stands up to the eaves, the roster band near the
    # top. The stands' backs meet them.
    for x, f in ((-wx, (1, 0, 0)), (wx, (-1, 0, 0))):
        b.quad("upper", (x, 0, -wz), (x, 0, wz), (x, hall["roster"][0], wz), (x, hall["roster"][0], -wz), f)
        b.quad("wrap_roster", (x, hall["roster"][0], -wz), (x, hall["roster"][0], wz),
               (x, hall["roster"][1], wz), (x, hall["roster"][1], -wz), f)
        b.quad("upper", (x, hall["roster"][1], -wz), (x, hall["roster"][1], wz), (x, eave, wz), (x, eave, -wz), f)
    # The end walls: blue to the height of the stands, plaster above, the mural across the
    # +z end, and the arch of the roof closed off over each.
    for z, f in ((wz, (0, 0, -1)), (-wz, (0, 0, 1))):
        b.quad("walls", (-wx, 0, z), (wx, 0, z), (wx, top, z), (-wx, top, z), f)
        if z > 0:
            m0, m1 = hall["mural"]
            b.quad("upper", (-wx, top, z), (wx, top, z), (wx, m0, z), (-wx, m0, z), f)
            b.quad("wrap_mural", (-wx, m0, z + f[2] * 0.01), (wx, m0, z + f[2] * 0.01),
                   (wx, m1, z + f[2] * 0.01), (-wx, m1, z + f[2] * 0.01), f)
            b.quad("upper", (-wx, m1, z), (wx, m1, z), (wx, eave, z), (-wx, eave, z), f)
        else:
            b.quad("upper", (-wx, top, z), (wx, top, z), (wx, eave, z), (-wx, eave, z), f)
        # The arch over the wall, as a fan.
        prev = None
        for i in range(17):
            x = -wx + 2 * wx * i / 16
            y = _arch(x, wx, eave, crown)
            if prev:
                b.quad("upper", (prev[0], eave, z), (x, eave, z), (x, y, z), (prev[0], prev[1], z), f)
            prev = (x, y)
        # Doors in the end walls, at the corners clear of the stands.
        for sx in (-1, 1):
            dx = sx * (plan.hx + 0.3 + back * 0.5)
            b.box("door", (dx, 1.15, z + f[2] * 0.05), (1.8, 2.3, 0.08))
            b.box("exit", (dx, 2.6, z + f[2] * 0.06), (0.6, 0.22, 0.04))
    _roof(b, plan, hall, wx, wz, eave, crown)
    lib.lighting_rig_cables(b, plan, steel="steel",
                            roof_at=lambda x: _arch(x, wx, eave, crown) - 1.0)


def _arch(x, wx, eave, crown):
    """The barrel roof's curve: a circular arc from the eaves up to the crown."""
    f = x / wx
    return eave + (crown - eave) * (1.0 - f * f)


def _stand(b, plan, tier, run):
    lib.run_tier(b, tier, run, material="steps", end_material="walls")
    rows, depth, rise, base, first = (tier["rows"], tier["depth"], tier["rise"], tier["base"],
                                      tier["first_offset"])
    # The wall in front of the stand, its LED ribbon, and the rail along the top of it.
    b.run_band("walls", run, 0.0, 0.0, 0.0, base + rise, "in")
    b.run_band("walls", run, 0.0, base + rise, first, base + rise, "up")
    b.run_band("ribbon", run, -0.02, 0.15, -0.02, base + rise - 0.1, "in")
    b.tube("steel", plan.run_point(run, run["from"], 0.1, base + rise + 0.9),
           plan.run_point(run, run["to"], 0.1, base + rise + 0.9), 0.025)
    nx, nz = plan.run_normal(run)
    yaw = math.atan2(nx, nz)
    w = plan["aisles"]["width"]
    for g in tier.get("gaps", []):
        for r in range(rows):
            d0 = first + depth * r
            y = base + rise * (r + 1)
            b.box("steps", plan.run_point(run, g, d0 + depth * 0.75, y + rise * 0.25),
                  (w, rise * 0.5, depth * 0.5), yaw)
            for edge, top in ((d0 + 0.02, y), (d0 + depth * 0.5 + 0.02, y + rise * 0.5)):
                b.box("nosing", plan.run_point(run, g, edge, top + 0.004), (w * 0.96, 0.01, 0.04), yaw)
        p0 = plan.run_point(run, g, first + depth * 0.5, base + rise + 0.9)
        p1 = plan.run_point(run, g, first + depth * (rows - 0.5), base + rise * rows + 0.9)
        b.tube("steel", p0, p1, 0.025)


def _roof(b, plan, hall, wx, wz, eave, crown):
    """Zinc on purlins, carried by steel arch trusses across the hall, with lamps hung
    between them."""
    n = 16
    xs = [-wx + 2 * wx * i / n for i in range(n + 1)]
    for i in range(n):
        xa, xb = xs[i], xs[i + 1]
        ya, yb = _arch(xa, wx, eave, crown) + 0.15, _arch(xb, wx, eave, crown) + 0.15
        b.quad("zinc", (xa, ya, -wz), (xb, yb, -wz), (xb, yb, wz), (xa, ya, wz), (0, -1, 0))
    z = -wz + hall["bay"]
    while z < wz - 0.5:
        for i in range(n):
            xa, xb = xs[i], xs[i + 1]
            ya, yb = _arch(xa, wx, eave, crown), _arch(xb, wx, eave, crown)
            b.beam("steel", (xa, ya, z), (xb, yb, z), 0.16, 0.16)
            b.beam("steel", (xa, ya - 1.0, z), (xb, yb - 1.0, z), 0.12, 0.12)
            b.beam("steel", (xa, ya - 1.0, z), (xb, yb, z), 0.06, 0.06)
            b.beam("steel", (xa, ya - 1.0, z), (xa, ya, z), 0.06, 0.06)
        for x in hall["lamp_x"]:
            y = _arch(x, wx, eave, crown) - 1.0
            b.tube("steel", (x, y - 1.2, z), (x, y, z), 0.015, 4)
            b.box("lamp", (x, y - 1.35, z), (0.45, 0.06, 0.45))
        z += hall["bay"]
    for x in xs[1:-1:2]:
        y = _arch(x, wx, eave, crown) + 0.05
        b.beam("steel", (x, y, -wz), (x, y, wz), 0.08, 0.14)
