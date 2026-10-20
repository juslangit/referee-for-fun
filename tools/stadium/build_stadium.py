"""Builds the tennis stadium in Blender and exports it for the game.

Run inside the shared Blender, through the MCP (never a headless Blender of its own):

    exec(open("<repo>/tools/stadium/build_stadium.py").read())

or from the MCP tool, with REPO set first. It works in a scene of its own, "TennisStadium",
so whatever else is open in that Blender is left alone, and writes
`assets/stadium/tennis_stadium.glb`.

Luqman, 2026-10-20, after the outdoor courts got a photographed sky: "the hdri is good but
the problem now is the court stadium ... create a proper stadium arena". He chose one
generic modern stadium for every rung, modelled here rather than downloaded.

Every number comes from `assets/stadium/tennis_bowl.json`, which the game reads too
(`scripts/bowl.gd`) to put the seats and the crowd on these steps. Change the bowl there,
re-run this, and both follow.

The bowl is a rounded rectangle. Every row of seats runs round the inside face of the
podium wall offset outwards by some distance `d`, which makes all the rows parallel at
the corners as well as down the sides: a point at offset `d` is `base + d * normal`,
where `base` is the matching point on the podium face. Everything below is built from
that one function.
"""

import json
import math
import os

import bmesh
import bpy

REPO = globals().get("REPO") or os.path.expanduser("~/Desktop/projects/game/referee-for-fun")
BOWL = json.load(open(os.path.join(REPO, "assets/stadium/tennis_bowl.json")))
TEXTURES = os.path.join(REPO, "tools/stadium/textures")
OUT = os.path.join(REPO, "assets/stadium/tennis_stadium.glb")
SCENE = "TennisStadium"

HX, HZ = BOWL["inner_half"]
R = BOWL["corner_radius"]
ARC = 10  # segments per corner


def V(x, y, z):
    """Godot coordinates (y up, court along z) to Blender's (z up). The glTF exporter turns
    them back, so the file arrives in Godot exactly as written here."""
    return (x, -z, y)


# --- the path every row follows ---------------------------------------------------------

def frame():
    """The podium face as (base point, outward normal) pairs, once round. Corners are
    sampled; the straights between them are the gaps between consecutive corners."""
    pts = []
    corners = [((HX - R), (HZ - R), 0.0), (-(HX - R), (HZ - R), 90.0),
               (-(HX - R), -(HZ - R), 180.0), ((HX - R), -(HZ - R), 270.0)]
    for cx, cz, a0 in corners:
        for i in range(ARC + 1):
            a = math.radians(a0 + 90.0 * i / ARC)
            n = (math.cos(a), math.sin(a))
            pts.append(((cx + R * n[0], cz + R * n[1]), n))
    return pts


FRAME = frame()


def at(i, d, y):
    (bx, bz), (nx, nz) = FRAME[i % len(FRAME)]
    return (bx + d * nx, y, bz + d * nz)


def perimeter_points(d, spacing):
    """Evenly spaced (point, normal, arc position) round the row at offset d."""
    loop = [(at(i, d, 0.0), FRAME[i][1]) for i in range(len(FRAME))]
    out = []
    carry = 0.0
    s = 0.0
    for i in range(len(loop)):
        (p0, n0), (p1, n1) = loop[i], loop[(i + 1) % len(loop)]
        seg = math.dist((p0[0], p0[2]), (p1[0], p1[2]))
        t = carry
        while t < seg:
            f = t / seg if seg > 0 else 0.0
            p = (p0[0] + (p1[0] - p0[0]) * f, 0.0, p0[2] + (p1[2] - p0[2]) * f)
            n = (n0[0] + (n1[0] - n0[0]) * f, n0[1] + (n1[1] - n0[1]) * f)
            ln = math.hypot(*n)
            out.append((p, (n[0] / ln, n[1] / ln), s + t))
            t += spacing
        carry = t - seg
        s += seg
    return out


def aisle_spots():
    """(base point, normal) at the middle of each aisle, on the podium face."""
    spots = []
    for side in (1.0, -1.0):
        for z in BOWL["aisles"]["side_z"]:
            spots.append(((side * HX, z), (side, 0.0)))
        for x in BOWL["aisles"]["end_x"]:
            spots.append(((x, side * HZ), (0.0, side)))
    for sx in (1.0, -1.0):
        for sz in (1.0, -1.0):
            for deg in BOWL["aisles"]["corner_deg"]:
                a = math.radians(deg)
                n = (sx * math.cos(a), sz * math.sin(a))
                spots.append((((HX - R) * sx + R * n[0], (HZ - R) * sz + R * n[1]), n))
    return spots


# --- mesh building ----------------------------------------------------------------------

class Builder:
    """One mesh per material, so the stadium is a handful of draw calls."""

    def __init__(self):
        self.parts = {}

    def bm(self, material):
        if material not in self.parts:
            self.parts[material] = bmesh.new()
        return self.parts[material]

    def quad(self, material, a, b, c, d, facing):
        """A quad from Godot points, wound so its normal points along `facing`."""
        bm = self.bm(material)
        vs = [bm.verts.new(V(*p)) for p in (a, b, c, d)]
        f = bm.faces.new(vs)
        f.normal_update()
        want = V(*facing)
        if f.normal.dot(want) < 0.0:
            f.normal_flip()

    def band(self, material, d0, y0, d1, y1, facing):
        """A strip all the way round, from (d0, y0) to (d1, y1) in the offset-height plane.
        `facing` is "up", "down", "in" (towards the court) or "out"."""
        n = len(FRAME)
        for i in range(n):
            j = (i + 1) % n
            a, b = at(i, d0, y0), at(j, d0, y0)
            c, d = at(j, d1, y1), at(i, d1, y1)
            nx, nz = FRAME[i][1]
            f = {"up": (0, 1, 0), "down": (0, -1, 0),
                 "in": (-nx, 0, -nz), "out": (nx, 0, nz)}[facing]
            self.quad(material, a, b, c, d, f)

    def box(self, material, centre, size, yaw=0.0):
        """An upright box in Godot space, `yaw` about y. Size is (across, up, along)."""
        cx, cy, cz = centre
        hx, hy, hz = size[0] / 2, size[1] / 2, size[2] / 2
        c, s = math.cos(yaw), math.sin(yaw)

        def P(x, y, z):
            return (cx + x * c + z * s, cy + y, cz - x * s + z * c)

        corners = {k: P(*k) for k in [(sx * hx, sy * hy, sz * hz)
                                       for sx in (-1, 1) for sy in (-1, 1) for sz in (-1, 1)]}
        faces = [
            ((1, 0, 0), [(hx, -hy, -hz), (hx, hy, -hz), (hx, hy, hz), (hx, -hy, hz)]),
            ((-1, 0, 0), [(-hx, -hy, -hz), (-hx, -hy, hz), (-hx, hy, hz), (-hx, hy, -hz)]),
            ((0, 1, 0), [(-hx, hy, -hz), (-hx, hy, hz), (hx, hy, hz), (hx, hy, -hz)]),
            ((0, -1, 0), [(-hx, -hy, -hz), (hx, -hy, -hz), (hx, -hy, hz), (-hx, -hy, hz)]),
            ((0, 0, 1), [(-hx, -hy, hz), (hx, -hy, hz), (hx, hy, hz), (-hx, hy, hz)]),
            ((0, 0, -1), [(-hx, -hy, -hz), (-hx, hy, -hz), (hx, hy, -hz), (hx, -hy, -hz)]),
        ]
        for (nx, ny, nz), quad in faces:
            facing = (nx * c + nz * s, ny, -nx * s + nz * c)
            self.quad(material, *[corners[q] for q in quad], facing)

    def beam(self, material, p0, p1, width, height):
        """A box from p0 to p1 (Godot points), width across and height up."""
        dx, dy, dz = p1[0] - p0[0], p1[1] - p0[1], p1[2] - p0[2]
        length = math.sqrt(dx * dx + dy * dy + dz * dz)
        mid = ((p0[0] + p1[0]) / 2, (p0[1] + p1[1]) / 2, (p0[2] + p1[2]) / 2)
        bm = self.bm(material)
        tmp = bmesh.new()
        bmesh.ops.create_cube(tmp, size=1.0)
        for v in tmp.verts:
            v.co.x *= width
            v.co.y *= length
            v.co.z *= height
        # Point the cube's +y (Blender) along the beam.
        from mathutils import Vector
        d = Vector(V(dx, dy, dz)).normalized()
        rot = Vector((0, 1, 0)).rotation_difference(d).to_matrix().to_4x4()
        bmesh.ops.transform(tmp, matrix=rot, verts=tmp.verts)
        bmesh.ops.translate(tmp, vec=Vector(V(*mid)), verts=tmp.verts)
        me = bpy.data.meshes.new("tmp")
        tmp.to_mesh(me)
        tmp.free()
        bm.from_mesh(me)
        bpy.data.meshes.remove(me)

    def finish(self, collection, uv_metres):
        objects = []
        for material, bm in self.parts.items():
            me = bpy.data.meshes.new(material)
            bm.to_mesh(me)
            bm.free()
            _uv_by_box(me, uv_metres.get(material, 2.0))
            me.materials.append(MATERIALS[material])
            ob = bpy.data.objects.new(material.capitalize(), me)
            collection.objects.link(ob)
            objects.append(ob)
        return objects


def _uv_by_box(me, metres):
    """World-scale UVs by box projection: each face takes the two axes it is flattest
    across. One texture repeat per `metres`, so concrete is concrete-sized everywhere."""
    me.uv_layers.new(name="UVMap")
    uv = me.uv_layers.active.data
    for poly in me.polygons:
        n = poly.normal
        ax = max(range(3), key=lambda k: abs(n[k]))
        for li in poly.loop_indices:
            co = me.vertices[me.loops[li].vertex_index].co
            if ax == 0:
                u, v = co.y, co.z
            elif ax == 1:
                u, v = co.x, co.z
            else:
                u, v = co.x, co.y
            uv[li].uv = (u / metres, v / metres)


# --- materials --------------------------------------------------------------------------

def _textured(name, tex, tint=(1, 1, 1, 1), metallic=0.0):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    bsdf = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
    bsdf.inputs["Metallic"].default_value = metallic
    def img(kind, colour):
        node = nt.nodes.new("ShaderNodeTexImage")
        node.image = bpy.data.images.load(os.path.join(TEXTURES, f"{tex}_{kind}_1k.jpg"),
                                          check_existing=True)
        if not colour:
            node.image.colorspace_settings.name = "Non-Color"
        return node
    diff = img("diff", True)
    if tint != (1, 1, 1, 1):
        mix = nt.nodes.new("ShaderNodeMix")
        mix.data_type = "RGBA"
        mix.blend_type = "MULTIPLY"
        mix.inputs["Factor"].default_value = 1.0
        mix.inputs["B"].default_value = tint
        nt.links.new(diff.outputs["Color"], mix.inputs["A"])
        nt.links.new(mix.outputs["Result"], bsdf.inputs["Base Color"])
    else:
        nt.links.new(diff.outputs["Color"], bsdf.inputs["Base Color"])
    rough = img("rough", False)
    nt.links.new(rough.outputs["Color"], bsdf.inputs["Roughness"])
    nor = img("nor_gl", False)
    nmap = nt.nodes.new("ShaderNodeNormalMap")
    nt.links.new(nor.outputs["Color"], nmap.inputs["Color"])
    nt.links.new(nmap.outputs["Normal"], bsdf.inputs["Normal"])
    return m


def _plain(name, colour, rough=0.5, metallic=0.0, emission=None, alpha=1.0):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    bsdf = next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    bsdf.inputs["Base Color"].default_value = colour
    bsdf.inputs["Roughness"].default_value = rough
    bsdf.inputs["Metallic"].default_value = metallic
    if emission:
        bsdf.inputs["Emission Color"].default_value = emission[0]
        bsdf.inputs["Emission Strength"].default_value = emission[1]
    if alpha < 1.0:
        bsdf.inputs["Alpha"].default_value = alpha
        m.surface_render_method = "BLENDED"
    return m


def make_materials():
    return {
        "steps": _textured("steps", "steps_concrete", (0.86, 0.87, 0.89, 1)),
        "walls": _textured("walls", "wall_panels", (0.95, 0.95, 0.97, 1)),
        "plaza": _textured("plaza", "plaza_pavers"),
        "roof": _textured("roof", "roof_sheet", (0.92, 0.94, 0.96, 1), 0.5),
        # Painted over by the game with the court's own surround colour at each rung.
        "apron": _plain("apron", (0.14, 0.30, 0.36, 1), 0.8),
        "steel": _plain("steel", (0.78, 0.80, 0.83, 1), 0.35, 0.9),
        "dark": _plain("dark", (0.06, 0.07, 0.09, 1), 0.6),
        "glass": _plain("glass", (0.75, 0.85, 0.90, 1), 0.05, 0.0, alpha=0.22),
        "ribbon": _plain("ribbon", (0.02, 0.05, 0.14, 1), 0.3,
                         emission=((0.05, 0.20, 0.70, 1), 1.2)),
        "lamp": _plain("lamp", (1, 1, 1, 1), 0.2, emission=((1.0, 0.97, 0.90, 1), 6.0)),
        "screen": _plain("screen", (0.01, 0.02, 0.05, 1), 0.2,
                         emission=((0.04, 0.10, 0.30, 1), 1.5)),
        "nosing": _plain("nosing", (0.85, 0.70, 0.10, 1), 0.6),
    }


UV_METRES = {"steps": 2.0, "walls": 4.0, "plaza": 3.6, "roof": 2.0}


# --- the stadium ------------------------------------------------------------------------

def build(b):
    pod = BOWL["podium"]
    # The court-side wall: a solid face with an LED ribbon on it, and glass above.
    b.band("walls", 0.0, 0.0, 0.0, pod["solid_height"], "in")
    b.band("walls", 0.0, pod["solid_height"], pod["thickness"], pod["solid_height"], "up")
    b.band("ribbon", -0.02, 0.35, -0.02, 1.45, "in")
    b.band("glass", 0.08, pod["solid_height"], 0.08, pod["glass_top"], "in")
    b.band("steel", 0.06, pod["glass_top"] - 0.02, 0.10, pod["glass_top"] + 0.04, "up")

    # The floor between the court's own surround and the podium, under everything.
    b.quad("apron", (-HX, -0.005, -HZ), (HX, -0.005, -HZ), (HX, -0.005, HZ), (-HX, -0.005, HZ),
           (0, 1, 0))

    for tier in BOWL["tiers"]:
        _tier(b, tier)

    cc = BOWL["concourse"]
    b.band("steps", cc["from_offset"], cc["height"], cc["to_offset"], cc["height"], "up")

    uf = BOWL["upper_front"]
    b.band("walls", uf["offset"], cc["height"], uf["offset"], uf["solid_top"], "in")
    b.band("walls", uf["offset"], uf["solid_top"], uf["offset"] + 0.2, uf["solid_top"], "up")
    b.band("ribbon", uf["offset"] - 0.02, uf["solid_top"] - 1.25, uf["offset"] - 0.02,
           uf["solid_top"] - 0.25, "in")
    b.band("glass", uf["offset"] + 0.08, uf["solid_top"], uf["offset"] + 0.08, uf["glass_top"], "in")
    b.band("steel", uf["offset"] + 0.06, uf["glass_top"] - 0.02, uf["offset"] + 0.10,
           uf["glass_top"] + 0.04, "up")
    # Glass along the back of the concourse too, where it looks down the lower tier.
    lower = BOWL["tiers"][0]
    b.band("glass", cc["from_offset"] + 0.05, cc["height"], cc["from_offset"] + 0.05,
           cc["height"] + 1.0, "in")

    bw = BOWL["back_wall"]
    b.band("walls", bw["offset"], _tier_top(BOWL["tiers"][1]), bw["offset"], bw["top"], "in")
    b.band("walls", bw["offset"] + bw["thickness"], 0.0, bw["offset"] + bw["thickness"],
           bw["top"], "out")
    b.band("walls", bw["offset"], bw["top"], bw["offset"] + bw["thickness"], bw["top"], "up")
    _fins(b, bw)
    _roof(b)
    _aisles(b)
    _screens(b)

    ph = BOWL["plaza_half"]
    b.quad("plaza", (-ph[0], -0.02, -ph[1]), (ph[0], -0.02, -ph[1]),
           (ph[0], -0.02, ph[1]), (-ph[0], -0.02, ph[1]), (0, 1, 0))


def _tier_top(tier):
    return tier["base"] + tier["rise"] * tier["rows"]


def _tier(b, tier):
    """Rows of treads and risers. Tread r is at base + rise * (r + 1), from
    first_offset + depth * r to the next row — the same numbers `Bowl` seats people on."""
    prev = tier["base"]
    for r in range(tier["rows"]):
        d0 = tier["first_offset"] + tier["depth"] * r
        d1 = d0 + tier["depth"]
        h = tier["base"] + tier["rise"] * (r + 1)
        b.band("steps", d0, prev, d0, h, "in")
        b.band("steps", d0, h, d1, h, "up")
        prev = h
    # The back of the last row, down to whatever is behind it.
    last = tier["first_offset"] + tier["depth"] * tier["rows"]
    b.band("steps", last, prev, last, prev - 0.01, "in")


def _aisles(b):
    """Two steps a row up every aisle, a yellow nosing on each, and a handrail."""
    w = BOWL["aisles"]["width"]
    for (bx, bz), (nx, nz) in aisle_spots():
        yaw = math.atan2(nx, nz)
        for tier in BOWL["tiers"]:
            for r in range(tier["rows"]):
                d0 = tier["first_offset"] + tier["depth"] * r
                h = tier["base"] + tier["rise"] * (r + 1)
                # The half step, on the back half of this row's tread.
                mid = d0 + tier["depth"] * 0.75
                y = h + tier["rise"] * 0.25
                c = (bx + nx * mid, y, bz + nz * mid)
                b.box("steps", c, (w, tier["rise"] * 0.5, tier["depth"] * 0.5), yaw)
                for edge, top in ((d0 + 0.02, h), (d0 + tier["depth"] * 0.5 + 0.02, h + tier["rise"] * 0.5)):
                    b.box("nosing", (bx + nx * edge, top + 0.004, bz + nz * edge),
                          (w * 0.96, 0.01, 0.04), yaw)
            # A rail up the middle of the aisle, on posts every few rows.
            first = tier["first_offset"] + tier["depth"] * 0.5
            last = tier["first_offset"] + tier["depth"] * (tier["rows"] - 0.5)
            y0 = tier["base"] + tier["rise"] + 0.9
            y1 = _tier_top(tier) + 0.9
            b.beam("steel", (bx + nx * first, y0, bz + nz * first),
                   (bx + nx * last, y1, bz + nz * last), 0.05, 0.05)
            for r in range(0, tier["rows"], 3):
                d = tier["first_offset"] + tier["depth"] * (r + 0.5)
                h = tier["base"] + tier["rise"] * (r + 1)
                b.box("steel", (bx + nx * d, h + 0.45, bz + nz * d), (0.05, 0.9, 0.05), yaw)


def _fins(b, bw):
    """Vertical concrete fins down the outside of the back wall."""
    for p, n, s in perimeter_points(bw["offset"] + bw["thickness"], 3.6):
        d = 0.6
        c = (p[0] + n[0] * d, bw["top"] * 0.5 + 0.2, p[2] + n[1] * d)
        b.box("walls", c, (0.35, bw["top"] + 0.4, 1.2), math.atan2(n[0], n[1]))


def _roof(b):
    rf = BOWL["roof"]
    i_d, o_d = rf["inner_offset"], rf["outer_offset"]
    i_h, o_h = rf["inner_height"], rf["outer_height"]
    t = rf["thickness"]
    b.band("roof", i_d, i_h + t, o_d, o_h + t, "up")
    b.band("roof", i_d, i_h, o_d, o_h, "down")
    b.band("steel", i_d, i_h, i_d, i_h + t, "in")
    b.band("steel", o_d, o_h, o_d, o_h + t, "out")
    # Ribs under the roof, deep at the back wall and thin at the tip, and a column under each.
    bw = BOWL["back_wall"]
    for p, n, s in perimeter_points(bw["offset"] + 0.2, rf["rib_spacing"]):
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
    for p, n, s in perimeter_points(i_d + 0.5, 4.2):
        c = (p[0], i_h - 0.35, p[2])
        b.box("lamp", c, (1.1, 0.25, 0.5), math.atan2(n[0], n[1]))
        b.box("dark", (c[0], c[1] + 0.2, c[2]), (1.2, 0.2, 0.6), math.atan2(n[0], n[1]))


def _screens(b):
    """Video screens hung under the roof in two corners, square to the corner."""
    for sc in BOWL["screens"]:
        sx, sz = sc["corner"]
        n = (sx * math.sqrt(0.5), sz * math.sqrt(0.5))
        base = ((HX - R) * sx + R * n[0], (HZ - R) * sz + R * n[1])
        d = sc["offset"]
        w, h = sc["size"]
        c = (base[0] + n[0] * d, sc["bottom"] + h * 0.5, base[1] + n[1] * d)
        yaw = math.atan2(n[0], n[1])
        b.box("dark", c, (w + 0.4, h + 0.4, 0.5), yaw)
        face = (c[0] - n[0] * 0.27, c[1], c[2] - n[1] * 0.27)
        b.box("screen", face, (w, h, 0.02), yaw)
        # Hung from the roof on two rods.
        for side in (-1, 1):
            off = side * w * 0.35
            rx, rz = c[0] + n[1] * off, c[2] - n[0] * off
            top = BOWL["roof"]["inner_height"] - 0.2
            b.beam("steel", (rx, sc["bottom"] + h + 0.2, rz), (rx, top + 0.6, rz), 0.08, 0.08)


# --- run --------------------------------------------------------------------------------

def run():
    global MATERIALS
    scene = bpy.data.scenes.get(SCENE) or bpy.data.scenes.new(SCENE)
    for ob in list(scene.collection.all_objects):
        if ob.type == "MESH":
            bpy.data.objects.remove(ob, do_unlink=True)
    for coll in list(scene.collection.children):
        bpy.data.collections.remove(coll)
    # Last run's meshes and materials, so this run's get their own names back rather
    # than "steps.001" — the game finds the apron by name.
    for me in list(bpy.data.meshes):
        if me.users == 0:
            bpy.data.meshes.remove(me)
    for m in list(bpy.data.materials):
        if m.users == 0:
            bpy.data.materials.remove(m)
    MATERIALS = make_materials()
    coll = bpy.data.collections.new("Stadium")
    scene.collection.children.link(coll)
    b = Builder()
    build(b)
    objects = b.finish(coll, UV_METRES)
    for ob in objects:
        # Every surface is meant to be seen from one side; the glass is the exception.
        for m in ob.data.materials:
            m.use_backface_culling = m.name != "glass"
    window = bpy.context.window
    if window is not None:
        window.scene = scene
    bpy.ops.export_scene.gltf(filepath=OUT, export_format="GLB", use_active_scene=True,
                              export_apply=True, export_yup=True)
    tris = sum(sum(len(p.vertices) - 2 for p in ob.data.polygons) for ob in objects)
    print(f"stadium: {len(objects)} meshes, {tris} triangles -> {OUT}")


run()
