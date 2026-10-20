"""A community hall — a dewan serbaguna — for the bottom rungs of every indoor sport.

Luqman, 2026-10-20: the school and club rungs get "a plainer community or school hall
(bleachers, painted walls, high windows), and the arena is earned by climbing the ladder".
This is the hall every Malaysian town has: painted plaster walls over a gloss-painted dado,
a row of louvred windows high up both long walls, steel portal frames carrying a pitched
zinc roof on purlins, ceiling fans and fluorescent battens hanging under it, a stage with a
maroon curtain at one end, double doors with exit signs, and folding bleachers with wooden
planks down the two long sides.

One builder, four halls: each sport's JSON sizes it to its own court (`hall`), and paints
it (`colours`). The bleachers are `lib.bleacher`, the same frame the beach stands use.
"""

import math

import lib


def materials(plan):
    c = plan["hall"]["colours"]

    def rgb(k, a=1.0):
        v = c[k]
        return (v[0], v[1], v[2], a)
    return {
        "floor": lib.textured("floor", "hangar_concrete_floor", rgb("floor")),
        "plaster": lib.textured("plaster", "painted_plaster_wall", rgb("wall")),
        "dado": lib.plain("dado", rgb("dado"), 0.35),
        "trim": lib.plain("trim", rgb("trim"), 0.5),
        "zinc": lib.textured("zinc", "corrugated_iron_02", (0.80, 0.82, 0.84, 1), 0.6),
        "frame": lib.plain("frame", rgb("steel"), 0.5, 0.4),
        "plank": lib.textured("plank", "wood_planks", (0.95, 0.88, 0.78, 1)),
        "deck": lib.textured("deck", "wood_planks", (0.80, 0.72, 0.62, 1)),
        "nosing": lib.plain("nosing", (0.85, 0.70, 0.10, 1), 0.6),
        "louvre": lib.plain("louvre", (0.70, 0.74, 0.76, 1), 0.3, 0.2),
        "night": lib.plain("night", (0.02, 0.03, 0.06, 1), 0.2,
                           emission=((0.03, 0.05, 0.10, 1), 0.6)),
        "door": lib.plain("door", rgb("door"), 0.45),
        "curtain": lib.plain("curtain", (0.36, 0.05, 0.08, 1), 0.9),
        "valance": lib.plain("valance", (0.80, 0.62, 0.20, 1), 0.6, 0.3),
        "stage": lib.textured("stage", "wood_planks", (0.62, 0.44, 0.30, 1)),
        "tube": lib.plain("tube", (1, 1, 1, 1), 0.3, emission=((0.92, 0.96, 1.0, 1), 3.0)),
        "exit": lib.plain("exit", (0.05, 0.6, 0.2, 1), 0.3, emission=((0.10, 0.95, 0.35, 1), 2.5)),
        "fan": lib.plain("fan", (0.88, 0.88, 0.86, 1), 0.4),
        "board": lib.plain("board", (0.12, 0.22, 0.16, 1), 0.8),
        "clock": lib.plain("clock", (0.95, 0.95, 0.93, 1), 0.4),
    }


UV_METRES = {"floor": 4.0, "plaster": 3.0, "zinc": 1.6, "plank": 1.8, "deck": 1.8, "stage": 1.8}


def build(b, plan):
    h = plan["hall"]
    cx, cz = plan.cx, plan.cz
    wx, wz0, wz1 = h["half_x"], h["z_from"], h["z_to"]
    eave, apex = h["eave"], h["apex"]
    x0, x1 = cx - wx, cx + wx

    # The floor, under every court and both bleachers.
    b.quad("floor", (x0, -0.012, wz0), (x1, -0.012, wz0), (x1, -0.012, wz1), (x0, -0.012, wz1), (0, 1, 0))

    _walls(b, plan, h, x0, x1, wz0, wz1, eave)
    _roof(b, plan, h, x0, x1, wz0, wz1, eave, apex)
    _stage(b, plan, h, x0, x1, wz0)
    _fittings(b, plan, h, x0, x1, wz0, wz1, eave, apex)

    for tier in plan["tiers"]:
        for run in tier["runs"]:
            lib.bleacher(b, plan, tier, run, deck="deck", plank="plank", frame="frame",
                         rail_height=0.9)

    mid = (x0 + x1) * 0.5
    lib.lighting_rig_cables(b, plan, steel="frame",
                            roof_at=lambda x: apex - (apex - eave) * abs(x - mid) / wx)


def _walls(b, plan, h, x0, x1, z0, z1, eave):
    dado = h["dado"]
    win = h["windows"]
    # The long walls (x0, x1): dado, plaster, and a band of louvred windows every bay.
    for x, inward in ((x0, (1, 0, 0)), (x1, (-1, 0, 0))):
        b.quad("dado", (x, 0, z0), (x, 0, z1), (x, dado, z1), (x, dado, z0), inward)
        b.quad("trim", (x + inward[0] * 0.02, dado, z0), (x + inward[0] * 0.02, dado, z1),
               (x + inward[0] * 0.02, dado + 0.08, z1), (x + inward[0] * 0.02, dado + 0.08, z0), inward)
        bays = _bays(z0, z1, h["bay"])
        ys = (win["sill"], win["sill"] + win["height"])
        # Plaster round the windows: below, above, and the piers between them.
        b.quad("plaster", (x, dado, z0), (x, dado, z1), (x, ys[0], z1), (x, ys[0], z0), inward)
        b.quad("plaster", (x, ys[1], z0), (x, ys[1], z1), (x, eave, z1), (x, eave, z0), inward)
        edges = [z0]
        for za, zb in bays:
            mid = (za + zb) * 0.5
            edges += [mid - win["width"] * 0.5, mid + win["width"] * 0.5]
        edges.append(z1)
        for k in range(0, len(edges), 2):
            b.quad("plaster", (x, ys[0], edges[k]), (x, ys[0], edges[k + 1]),
                   (x, ys[1], edges[k + 1]), (x, ys[1], edges[k]), inward)
        for k in range(1, len(edges) - 1, 2):
            _window(b, x, inward, edges[k], edges[k + 1], ys[0], ys[1])
        # Two pairs of double doors in each long wall, under the windows.
        for dz in h["doors"]:
            _door(b, x, inward, plan.cz + dz)

    # The end walls. The stage end has its proscenium (see `_stage`); the other is plain,
    # with a clock and a notice board, and is where the event hangs its welcome banner.
    for z, inward in ((z1, (0, 0, -1)),):
        b.quad("dado", (x0, 0, z), (x1, 0, z), (x1, h["dado"], z), (x0, h["dado"], z), inward)
        b.quad("plaster", (x0, h["dado"], z), (x1, h["dado"], z), (x1, eave, z), (x0, eave, z), inward)
        b.quad("trim", (x0, h["dado"], z - 0.02), (x1, h["dado"], z - 0.02),
               (x1, h["dado"] + 0.08, z - 0.02), (x0, h["dado"] + 0.08, z - 0.02), inward)
        mid = (x0 + x1) * 0.5
        # The clock, high on the wall.
        b.box("clock", (mid + (x1 - x0) * 0.3, eave - 1.2, z - 0.05), (0.6, 0.6, 0.06))
        b.box("frame", (mid + (x1 - x0) * 0.3, eave - 1.2, z - 0.09), (0.04, 0.22, 0.02))
        # A green notice board beside the door.
        b.box("board", (mid - (x1 - x0) * 0.32, 1.7, z - 0.04), (2.4, 1.2, 0.04))
        b.box("trim", (mid - (x1 - x0) * 0.32, 1.7, z - 0.03), (2.5, 1.3, 0.03))


def _bays(z0, z1, bay):
    n = max(1, int(round((z1 - z0) / bay)))
    step = (z1 - z0) / n
    return [(z0 + step * i, z0 + step * (i + 1)) for i in range(n)]


def _window(b, x, inward, za, zb, y0, y1):
    """A louvred window: dark night glass, a frame, and glass louvres across it."""
    ix = inward[0]
    b.quad("night", (x - ix * 0.08, y0, za), (x - ix * 0.08, y0, zb), (x - ix * 0.08, y1, zb),
           (x - ix * 0.08, y1, za), inward)
    for z in (za, zb):
        b.box("trim", (x, (y0 + y1) * 0.5, z), (0.18, y1 - y0, 0.08))
    for y in (y0, y1):
        b.box("trim", (x, y, (za + zb) * 0.5), (0.18, 0.08, zb - za + 0.08))
    y = y0 + 0.12
    while y < y1 - 0.08:
        b.box("louvre", (x - ix * 0.02, y, (za + zb) * 0.5), (0.10, 0.012, zb - za - 0.06))
        y += 0.14
    # The burglar bars every Malaysian hall window has.
    z = za + 0.15
    while z < zb - 0.1:
        b.box("frame", (x + ix * 0.03, (y0 + y1) * 0.5, z), (0.02, y1 - y0, 0.02))
        z += 0.15


def _door(b, x, inward, z):
    ix = inward[0]
    b.box("door", (x + ix * 0.03, 1.15, z), (0.06, 2.3, 1.8))
    b.box("trim", (x + ix * 0.02, 1.2, z), (0.05, 2.45, 2.0))
    b.box("frame", (x + ix * 0.07, 1.1, z - 0.12), (0.03, 0.03, 0.25))
    b.box("frame", (x + ix * 0.07, 1.1, z + 0.12), (0.03, 0.03, 0.25))
    # The exit sign over it.
    b.box("exit", (x + ix * 0.06, 2.75, z), (0.04, 0.22, 0.6))


def _roof(b, plan, h, x0, x1, z0, z1, eave, apex):
    """Steel portal frames across the hall, purlins along it, and the zinc underneath."""
    mid = (x0 + x1) * 0.5
    t = 0.12
    # The underside of the zinc, both pitches.
    b.quad("zinc", (x0, eave + t, z0), (x0, eave + t, z1), (mid, apex + t, z1), (mid, apex + t, z0), (0.3, -1, 0))
    b.quad("zinc", (x1, eave + t, z0), (x1, eave + t, z1), (mid, apex + t, z1), (mid, apex + t, z0), (-0.3, -1, 0))
    # The gable ends, filled in above the walls.
    for z, f in ((z0, (0, 0, 1)), (z1, (0, 0, -1))):
        b.tri("plaster", (x0, eave, z), (x1, eave, z), (mid, apex, z), f)
    # Portal frames: a column at each wall and two rafters meeting at the ridge, with a
    # haunch at each knee.
    for za, zb in _bays(z0, z1, h["bay"]) + [(z1, z1)]:
        z = za
        for x, s in ((x0, 1), (x1, -1)):
            b.box("frame", (x + s * 0.18, eave * 0.5, z), (0.3, eave, 0.2))
            b.beam("frame", (x + s * 0.18, eave - 0.6, z), (x + s * 1.6, eave + 0.1, z), 0.2, 0.25)
        b.beam("frame", (x0 + 0.1, eave, z), (mid, apex - 0.05, z), 0.18, 0.45)
        b.beam("frame", (x1 - 0.1, eave, z), (mid, apex - 0.05, z), 0.18, 0.45)
    # Purlins along the hall.
    n = h["purlins"]
    for i in range(n + 1):
        f = i / n
        for xa, xb in ((x0, mid), (x1, mid)):
            x = xa + (xb - xa) * f
            y = eave + (apex - eave) * f - 0.05
            b.beam("frame", (x, y, z0), (x, y, z1), 0.08, 0.16)


def _stage(b, plan, h, x0, x1, z0):
    """The stage at the -z end: a raised wooden platform behind a proscenium wall with its
    opening, a maroon curtain drawn across, a gold valance, and steps up at both sides."""
    st = h["stage"]
    mid = (x0 + x1) * 0.5
    front = z0 + st["depth"]
    eave = h["eave"]
    w = st["opening"] * 0.5
    top = st["height"] + st["opening_height"]
    # The proscenium wall, in the plane of the stage front, with the opening cut out.
    for a, c in ((x0, mid - w), (mid + w, x1)):
        b.quad("dado", (a, 0, front), (c, 0, front), (c, h["dado"], front), (a, h["dado"], front), (0, 0, 1))
        b.quad("plaster", (a, h["dado"], front), (c, h["dado"], front), (c, eave, front), (a, eave, front), (0, 0, 1))
    b.quad("plaster", (mid - w, top, front), (mid + w, top, front), (mid + w, eave, front), (mid - w, eave, front), (0, 0, 1))
    # The stage itself, its front face and its floor.
    b.quad("dado", (mid - w, 0, front), (mid + w, 0, front), (mid + w, st["height"], front), (mid - w, st["height"], front), (0, 0, 1))
    b.quad("stage", (mid - w, st["height"], z0), (mid + w, st["height"], z0), (mid + w, st["height"], front), (mid - w, st["height"], front), (0, 1, 0))
    # The curtain, a little behind the opening, in folds.
    folds = 28
    for i in range(folds):
        xa = mid - w + 2 * w * i / folds
        xb = mid - w + 2 * w * (i + 1) / folds
        dz = 0.08 if i % 2 else 0.0
        b.quad("curtain", (xa, st["height"], front - 0.5 - dz), (xb, st["height"], front - 0.5 - (0.08 - dz)),
               (xb, top, front - 0.5 - (0.08 - dz)), (xa, top, front - 0.5 - dz), (0, 0, 1))
    b.box("valance", (mid, top - 0.3, front - 0.15), (2 * w, 0.6, 0.06))
    for x in (mid - w, mid + w):
        b.box("trim", (x, top * 0.5, front + 0.02), (0.25, top, 0.06))
    b.box("trim", (mid, top + 0.1, front + 0.02), (2 * w + 0.25, 0.2, 0.06))
    # Steps up to the stage at both sides of the opening.
    steps = 4
    for side in (-1, 1):
        x = mid + side * (w + 1.0)
        for k in range(steps):
            y = st["height"] * (k + 1) / steps
            b.box("stage", (x, y * 0.5, front + 0.3 * (steps - k) - 0.15), (1.2, y, 0.3))
    # The back wall of the hall, behind the stage, seen through the opening.
    b.quad("plaster", (x0, 0, z0), (x1, 0, z0), (x1, eave, z0), (x0, eave, z0), (0, 0, 1))


def _fittings(b, plan, h, x0, x1, z0, z1, eave, apex):
    """Ceiling fans and fluorescent battens hung from the purlins, in rows down the hall."""
    mid = (x0 + x1) * 0.5
    span = x1 - x0

    def roof_y(x):
        return apex - (apex - eave) * abs(x - mid) / (span * 0.5)
    for x_frac in h["fan_rows"]:
        x = mid + x_frac * span * 0.5
        for za, zb in _bays(z0, z1, h["bay"]):
            z = (za + zb) * 0.5
            top = roof_y(x)
            hub = h["fan_height"]
            b.tube("frame", (x, hub, z), (x, top, z), 0.02, 4)
            b.box("fan", (x, hub - 0.05, z), (0.28, 0.12, 0.28))
            for k in range(3):
                a = k * math.tau / 3
                b.box("fan", (x + math.cos(a) * 0.62, hub - 0.08, z + math.sin(a) * 0.62),
                      (0.14, 0.012, 1.0), a + math.pi * 0.5)
    for x_frac in h["light_rows"]:
        x = mid + x_frac * span * 0.5
        for za, zb in _bays(z0, z1, h["bay"]):
            for dz in (-0.25, 0.25):
                z = za + (zb - za) * (0.5 + dz)
                y = h["light_height"]
                b.box("frame", (x, y + 0.05, z), (0.14, 0.06, 1.3))
                b.box("tube", (x, y, z), (0.05, 0.05, 1.22))
                b.tube("frame", (x, y + 0.08, z - 0.5), (x, roof_y(x), z - 0.5), 0.006, 3)
                b.tube("frame", (x, y + 0.08, z + 0.5), (x, roof_y(x), z + 0.5), 0.006, 3)
