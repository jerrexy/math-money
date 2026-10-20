"""Shared helpers for Math Money's Blender model scripts.

Conventions
-----------
* 1 Blender unit == 1 Roblox stud.
* Model in Blender as usual (Z up). The *front* of every prefab faces Blender -Y.
  The exporter maps Blender (x, y, z) -> Roblox (-x, z, y), so the front ends up
  facing Roblox -Z (a CFrame's LookVector) and nothing is mirrored.
* Each prefab lives in its own Blender collection. Every mesh object in it becomes
  one Roblox MeshPart. Object names are "<Prefab>|<Part>"; empties named
  "<Prefab>|@<Marker>" become marker CFrames in the prefab manifest.
* Object custom properties drive the Roblox side (see Builder.build):
    rbx_material   Enum.Material name
    tint           True: export no vertex colors, Roblox Color = the base color
                   (lets one mesh be recolored per machine theme)
    smooth_angle   auto-smooth angle in degrees (0 = flat shaded)
    uv_tile        studs per texture tile for the box-projected UVs
    collision      Enum.CollisionFidelity name
    can_collide    bool
    group          name of a sub-Model to put the part in (e.g. "Plate")
"""

import hashlib
import json
import math
import os
import random

import bmesh
import bpy
from mathutils import Euler, Matrix, Vector

REPO = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
BUILD = os.path.join(REPO, "build")

# --------------------------------------------------------------------------
# Scene helpers
# --------------------------------------------------------------------------


def _remove_collection_contents(coll):
    for child in list(coll.children):
        _remove_collection_contents(child)
        bpy.data.collections.remove(child)
    for ob in list(coll.objects):
        data = ob.data
        bpy.data.objects.remove(ob, do_unlink=True)
        if data is not None and getattr(data, "users", 1) == 0:
            if isinstance(data, bpy.types.Mesh):
                bpy.data.meshes.remove(data)


def prefab_collection(name, offset=(0.0, 0.0, 0.0)):
    """(Re)create the collection for a prefab. ``offset`` only moves it in the
    Blender viewport so prefabs don't overlap; the exporter removes it again."""
    root = bpy.data.collections.get("MathMoney")
    if root is None:
        root = bpy.data.collections.new("MathMoney")
        bpy.context.scene.collection.children.link(root)
    coll = bpy.data.collections.get(name)
    if coll is None:
        coll = bpy.data.collections.new(name)
        root.children.link(coll)
    _remove_collection_contents(coll)
    coll["prefab_offset"] = list(offset)
    return coll


def purge_orphans():
    for _ in range(3):
        bpy.ops.outliner.orphans_purge(do_local_ids=True, do_linked_ids=True, do_recursive=True)


# --------------------------------------------------------------------------
# Colors / materials
# --------------------------------------------------------------------------


def _srgb_to_linear(c):
    c = c / 255.0
    return c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4


def color_material(rgb):
    rgb = tuple(int(round(c)) for c in rgb)
    name = "rgb_%02x%02x%02x" % rgb
    mat = bpy.data.materials.get(name)
    if mat is None:
        mat = bpy.data.materials.new(name)
        lin = [_srgb_to_linear(c) for c in rgb]
        mat.diffuse_color = (lin[0], lin[1], lin[2], 1.0)
        mat["rgb"] = list(rgb)
        tree = getattr(mat, "node_tree", None)
        if tree is None:
            try:
                mat.use_nodes = True
                tree = mat.node_tree
            except Exception:
                tree = None
        if tree is not None:
            bsdf = tree.nodes.get("Principled BSDF")
            if bsdf is not None:
                bsdf.inputs["Base Color"].default_value = (lin[0], lin[1], lin[2], 1.0)
                bsdf.inputs["Roughness"].default_value = 0.6
    return mat


# --------------------------------------------------------------------------
# Mesh builder
# --------------------------------------------------------------------------


def _matrix(loc=(0, 0, 0), rot=(0, 0, 0), scale=(1, 1, 1)):
    if isinstance(scale, (int, float)):
        scale = (scale, scale, scale)
    r = Euler(tuple(math.radians(a) for a in rot), "XYZ").to_matrix().to_4x4()
    s = Matrix.Diagonal((scale[0], scale[1], scale[2], 1.0))
    return Matrix.Translation(Vector(loc)) @ r @ s


class Builder:
    """Accumulates primitives (each with its own color) into one mesh object.

    Every primitive takes ``loc`` (studs), ``rot`` (degrees, XYZ Euler) and
    ``color`` (sRGB 0-255). ``jitter`` nudges vertices randomly for an organic,
    hand-made look.
    """

    def __init__(self, name, collection, seed=1, offset=(0.0, 0.0, 0.0)):
        self.name = name
        self.collection = collection
        self.bm = bmesh.new()
        self.colors = []
        self.rng = random.Random(seed)
        self.offset = Matrix.Translation(Vector(offset))

    # ---- internals ----
    def _slot(self, rgb):
        rgb = tuple(int(round(c)) for c in rgb)
        if rgb not in self.colors:
            self.colors.append(rgb)
        return self.colors.index(rgb)

    def _merge(self, tmp, color, matrix, jitter=0.0, bevel=0.0, bevel_segments=2):
        if bevel > 0:
            bmesh.ops.bevel(
                tmp,
                geom=list(tmp.verts) + list(tmp.edges),
                offset=bevel,
                offset_type="OFFSET",
                segments=bevel_segments,
                profile=0.5,
                affect="EDGES",
                clamp_overlap=True,
            )
        bmesh.ops.transform(tmp, matrix=self.offset @ matrix, verts=tmp.verts)
        if jitter > 0:
            for v in tmp.verts:
                v.co += Vector(
                    (
                        self.rng.uniform(-jitter, jitter),
                        self.rng.uniform(-jitter, jitter),
                        self.rng.uniform(-jitter, jitter),
                    )
                )
        idx = self._slot(color)
        for f in tmp.faces:
            f.material_index = idx
        me = bpy.data.meshes.new("_mm_tmp")
        tmp.to_mesh(me)
        tmp.free()
        self.bm.from_mesh(me)
        bpy.data.meshes.remove(me)
        return self

    # ---- primitives ----
    def box(self, size, loc=(0, 0, 0), rot=(0, 0, 0), color=(200, 200, 200), bevel=0.0, bevel_segments=2, jitter=0.0):
        tmp = bmesh.new()
        bmesh.ops.create_cube(tmp, size=1.0)
        bmesh.ops.scale(tmp, vec=Vector(size), verts=tmp.verts)
        return self._merge(tmp, color, _matrix(loc, rot), jitter, bevel, bevel_segments)

    def cyl(self, r, depth, loc=(0, 0, 0), rot=(0, 0, 0), color=(200, 200, 200), segs=24, r_top=None, caps=True,
            bevel=0.0, jitter=0.0, scale=(1, 1, 1)):
        """Cylinder / cone / frustum along local Z, centered on ``loc``."""
        tmp = bmesh.new()
        bmesh.ops.create_cone(
            tmp, cap_ends=caps, cap_tris=False, segments=segs, radius1=r,
            radius2=r if r_top is None else r_top, depth=depth,
        )
        return self._merge(tmp, color, _matrix(loc, rot, scale), jitter, bevel)

    def sphere(self, r, loc=(0, 0, 0), rot=(0, 0, 0), color=(200, 200, 200), segs=16, rings=10, scale=(1, 1, 1), jitter=0.0):
        tmp = bmesh.new()
        bmesh.ops.create_uvsphere(tmp, u_segments=segs, v_segments=rings, radius=r)
        return self._merge(tmp, color, _matrix(loc, rot, scale), jitter)

    def ico(self, r, loc=(0, 0, 0), rot=(0, 0, 0), color=(200, 200, 200), subdiv=2, scale=(1, 1, 1), jitter=0.0):
        tmp = bmesh.new()
        bmesh.ops.create_icosphere(tmp, subdivisions=subdiv, radius=r)
        return self._merge(tmp, color, _matrix(loc, rot, scale), jitter)

    def torus(self, major, minor, loc=(0, 0, 0), rot=(0, 0, 0), color=(200, 200, 200), segs=24, sides=10,
              scale=(1, 1, 1), stretch=0.0, arc=360.0):
        """Torus in the local XY plane. ``stretch`` makes a stadium/chain-link shape
        by pulling the two halves apart along local Y. ``arc`` < 360 makes an open arc."""
        tmp = bmesh.new()
        full = arc >= 359.99
        path = []  # (angle, y offset) of each cross-section ring
        if stretch > 0 and full:
            half = max(2, segs // 2)
            path += [(math.pi * i / half, stretch / 2) for i in range(half + 1)]
            path += [(math.pi + math.pi * i / half, -stretch / 2) for i in range(half + 1)]
        else:
            count = segs if full else segs + 1
            path = [(math.radians(arc) * i / segs, 0.0) for i in range(count)]
        rings = []
        for a, off in path:
            ca, sa = math.cos(a), math.sin(a)
            ring = []
            for j in range(sides):
                b = 2 * math.pi * j / sides
                rr = major + minor * math.cos(b)
                ring.append(tmp.verts.new((rr * ca, rr * sa + off, minor * math.sin(b))))
            rings.append(ring)
        n_ring = len(rings)
        for i in range(n_ring if full else n_ring - 1):
            r0, r1 = rings[i], rings[(i + 1) % n_ring]
            for j in range(sides):
                tmp.faces.new((r0[j], r1[j], r1[(j + 1) % sides], r0[(j + 1) % sides]))
        if not full:
            tmp.faces.new(list(reversed(rings[0])))
            tmp.faces.new(rings[-1])
        bmesh.ops.recalc_face_normals(tmp, faces=tmp.faces)
        return self._merge(tmp, color, _matrix(loc, rot, scale))

    def lathe(self, profile, loc=(0, 0, 0), rot=(0, 0, 0), color=(200, 200, 200), segs=32, scale=(1, 1, 1),
              jitter=0.0, cap_bottom=True, cap_top=True, closed=False):
        """Revolve ``profile`` [(radius, z), ...] (bottom to top) around local Z.
        ``closed`` joins the last profile point back to the first (ring/torus-like
        cross-sections such as a grooved pulley rim) instead of capping the ends."""
        if closed:
            cap_bottom = cap_top = False
        tmp = bmesh.new()
        rings = []
        for r, z in profile:
            if r <= 1e-5:
                rings.append([tmp.verts.new((0.0, 0.0, z))])
                continue
            ring = []
            for i in range(segs):
                a = 2 * math.pi * i / segs
                ring.append(tmp.verts.new((r * math.cos(a), r * math.sin(a), z)))
            rings.append(ring)
        pairs = [(k, k + 1) for k in range(len(rings) - 1)]
        if closed:
            pairs.append((len(rings) - 1, 0))
        for ka, kb in pairs:
            a, b = rings[ka], rings[kb]
            if len(a) == 1 and len(b) == 1:
                continue
            if len(a) == 1:
                for i in range(segs):
                    tmp.faces.new((a[0], b[i], b[(i + 1) % segs]))
            elif len(b) == 1:
                for i in range(segs):
                    tmp.faces.new((a[i], b[0], a[(i + 1) % segs]))
            else:
                for i in range(segs):
                    tmp.faces.new((a[i], a[(i + 1) % segs], b[(i + 1) % segs], b[i]))
        if cap_bottom and len(rings[0]) > 1:
            tmp.faces.new(list(reversed(rings[0])))
        if cap_top and len(rings[-1]) > 1:
            tmp.faces.new(rings[-1])
        bmesh.ops.recalc_face_normals(tmp, faces=tmp.faces)
        return self._merge(tmp, color, _matrix(loc, rot, scale), jitter)

    def extrude(self, poly, depth, loc=(0, 0, 0), rot=(0, 0, 0), color=(200, 200, 200), bevel=0.0, scale=(1, 1, 1)):
        """Extrude a 2D polygon [(x, y), ...] (counter-clockwise) along local Z, centered."""
        tmp = bmesh.new()
        bottom = [tmp.verts.new((x, y, -depth / 2)) for x, y in poly]
        top = [tmp.verts.new((x, y, depth / 2)) for x, y in poly]
        tmp.faces.new(list(reversed(bottom)))
        tmp.faces.new(top)
        n = len(poly)
        for i in range(n):
            j = (i + 1) % n
            tmp.faces.new((bottom[i], bottom[j], top[j], top[i]))
        bmesh.ops.recalc_face_normals(tmp, faces=tmp.faces)
        # concave polygons: triangulate caps so they render correctly
        bmesh.ops.triangulate(tmp, faces=[f for f in tmp.faces if len(f.verts) > 4])
        return self._merge(tmp, color, _matrix(loc, rot, scale), 0.0, bevel)

    def tube(self, points, radius, color=(200, 200, 200), sides=10, caps=True, radii=None):
        """Sweep a circle along a polyline (list of 3D points)."""
        tmp = bmesh.new()
        pts = [Vector(p) for p in points]
        rings = []
        prev_n = None
        for i, p in enumerate(pts):
            if i == 0:
                t = (pts[1] - pts[0]).normalized()
            elif i == len(pts) - 1:
                t = (pts[-1] - pts[-2]).normalized()
            else:
                t = ((pts[i + 1] - pts[i]).normalized() + (pts[i] - pts[i - 1]).normalized()).normalized()
            if prev_n is None:
                helper = Vector((0, 0, 1)) if abs(t.z) < 0.9 else Vector((1, 0, 0))
                n = t.cross(helper).normalized()
            else:
                n = (prev_n - t * prev_n.dot(t)).normalized()
            prev_n = n
            b = t.cross(n).normalized()
            r = radius if radii is None else radii[i]
            ring = []
            for j in range(sides):
                a = 2 * math.pi * j / sides
                ring.append(tmp.verts.new(p + (n * math.cos(a) + b * math.sin(a)) * r))
            rings.append(ring)
        for k in range(len(rings) - 1):
            a, c = rings[k], rings[k + 1]
            for j in range(sides):
                tmp.faces.new((a[j], a[(j + 1) % sides], c[(j + 1) % sides], c[j]))
        if caps:
            tmp.faces.new(list(reversed(rings[0])))
            tmp.faces.new(rings[-1])
        bmesh.ops.recalc_face_normals(tmp, faces=tmp.faces)
        return self._merge(tmp, color, Matrix.Identity(4))

    def beam(self, p0, p1, width, height=None, color=(200, 200, 200), bevel=0.0, extend=0.0, roll=0.0, jitter=0.0):
        """Box running from p0 to p1 (optionally extended past both ends)."""
        p0, p1 = Vector(p0), Vector(p1)
        d = p1 - p0
        length = d.length + 2 * extend
        tmp = bmesh.new()
        bmesh.ops.create_cube(tmp, size=1.0)
        bmesh.ops.scale(tmp, vec=Vector((width, height or width, length)), verts=tmp.verts)
        if bevel > 0:
            bmesh.ops.bevel(tmp, geom=list(tmp.verts) + list(tmp.edges), offset=bevel, offset_type="OFFSET",
                            segments=2, profile=0.5, affect="EDGES", clamp_overlap=True)
        rot = Vector((0, 0, 1)).rotation_difference(d.normalized()).to_matrix().to_4x4()
        rollm = Matrix.Rotation(math.radians(roll), 4, "Z")
        m = Matrix.Translation((p0 + p1) / 2) @ rot @ rollm
        return self._merge(tmp, color, m, jitter)

    def rod(self, p0, p1, r, color=(200, 200, 200), segs=10, r_end=None):
        """Cylinder running from p0 to p1."""
        p0, p1 = Vector(p0), Vector(p1)
        d = p1 - p0
        tmp = bmesh.new()
        bmesh.ops.create_cone(tmp, cap_ends=True, cap_tris=False, segments=segs, radius1=r,
                              radius2=r if r_end is None else r_end, depth=d.length)
        rot = Vector((0, 0, 1)).rotation_difference(d.normalized()).to_matrix().to_4x4()
        return self._merge(tmp, color, Matrix.Translation((p0 + p1) / 2) @ rot)

    def raw(self, verts, faces, color=(200, 200, 200), loc=(0, 0, 0), rot=(0, 0, 0), scale=(1, 1, 1), jitter=0.0):
        tmp = bmesh.new()
        vs = [tmp.verts.new(v) for v in verts]
        for f in faces:
            tmp.faces.new([vs[i] for i in f])
        bmesh.ops.recalc_face_normals(tmp, faces=tmp.faces)
        return self._merge(tmp, color, _matrix(loc, rot, scale), jitter)

    # ---- output ----
    def build(self, material="SmoothPlastic", tint=False, smooth_angle=35.0, uv_tile=4.0, collision="Box",
              can_collide=False, group=None, cast_shadow=True, transparency=0.0, reflectance=0.0, extra=None):
        prefab = self.collection.name
        name = "%s|%s" % (prefab, self.name)
        me = bpy.data.meshes.new(name)
        self.bm.normal_update()
        self.bm.to_mesh(me)
        self.bm.free()
        for rgb in self.colors:
            me.materials.append(color_material(rgb))
        ob = bpy.data.objects.new(name, me)
        self.collection.objects.link(ob)
        off = self.collection.get("prefab_offset", [0, 0, 0])
        ob.location = Vector(off)
        ob["rbx_material"] = material
        ob["tint"] = bool(tint)
        ob["smooth_angle"] = float(smooth_angle)
        ob["uv_tile"] = float(uv_tile)
        ob["collision"] = collision
        ob["can_collide"] = bool(can_collide)
        ob["cast_shadow"] = bool(cast_shadow)
        ob["transparency"] = float(transparency)
        ob["reflectance"] = float(reflectance)
        if group:
            ob["group"] = group
        for k, v in (extra or {}).items():
            ob[k] = v
        return ob


def marker(collection, name, loc=(0, 0, 0), rot=(0, 0, 0)):
    """Empty that exports as a named CFrame (e.g. where the chain attaches)."""
    full = "%s|@%s" % (collection.name, name)
    ob = bpy.data.objects.new(full, None)
    ob.empty_display_type = "ARROWS"
    ob.empty_display_size = 1.5
    off = Vector(collection.get("prefab_offset", [0, 0, 0]))
    ob.location = Vector(loc) + off
    ob.rotation_euler = Euler(tuple(math.radians(a) for a in rot), "XYZ")
    collection.objects.link(ob)
    return ob


# --------------------------------------------------------------------------
# Shape helpers
# --------------------------------------------------------------------------


def circle_poly(r, n=24, start=0.0):
    return [(r * math.cos(start + 2 * math.pi * i / n), r * math.sin(start + 2 * math.pi * i / n)) for i in range(n)]


def star_poly(r_out, r_in, points=5, start=90.0):
    pts = []
    for i in range(points * 2):
        r = r_out if i % 2 == 0 else r_in
        a = math.radians(start) + math.pi * i / points
        pts.append((r * math.cos(a), r * math.sin(a)))
    return pts


def smooth_path(points, samples=6):
    """Catmull-Rom resample of a polyline so tubes bend smoothly."""
    pts = [Vector(p) for p in points]
    if len(pts) < 3:
        return [tuple(p) for p in pts]
    out = []
    ext = [pts[0] * 2 - pts[1]] + pts + [pts[-1] * 2 - pts[-2]]
    for i in range(1, len(ext) - 2):
        p0, p1, p2, p3 = ext[i - 1], ext[i], ext[i + 1], ext[i + 2]
        for s in range(samples):
            t = s / samples
            t2, t3 = t * t, t * t * t
            out.append(tuple(0.5 * ((2 * p1) + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t2 + (-p0 + 3 * p1 - 3 * p2 + p3) * t3)))
    out.append(tuple(pts[-1]))
    return out


def gear_poly(r_root, r_tip, teeth, tooth_frac=0.45):
    pts = []
    step = 2 * math.pi / teeth
    for i in range(teeth):
        a0 = i * step
        half = step * tooth_frac / 2
        pts += [
            (r_root * math.cos(a0 - step / 2 + 0.02), r_root * math.sin(a0 - step / 2 + 0.02)),
            (r_tip * math.cos(a0 - half), r_tip * math.sin(a0 - half)),
            (r_tip * math.cos(a0 + half), r_tip * math.sin(a0 + half)),
            (r_root * math.cos(a0 + step / 2 - 0.02), r_root * math.sin(a0 + step / 2 - 0.02)),
        ]
    return pts


def rounded_rect(w, h, r, n=4):
    pts = []
    corners = [(w / 2 - r, h / 2 - r, 0), (-w / 2 + r, h / 2 - r, 90), (-w / 2 + r, -h / 2 + r, 180), (w / 2 - r, -h / 2 + r, 270)]
    for cx, cy, a0 in corners:
        for i in range(n + 1):
            a = math.radians(a0 + 90 * i / n)
            pts.append((cx + r * math.cos(a), cy + r * math.sin(a)))
    return pts


# --------------------------------------------------------------------------
# Exporter
# --------------------------------------------------------------------------

_M = Matrix(((-1, 0, 0), (0, 0, 1), (0, 1, 0)))  # Blender -> Roblox basis change


def _rbx(v):
    return (-v[0], v[2], v[1])


def _box_uv(p, n, tile):
    ax, ay, az = abs(n[0]), abs(n[1]), abs(n[2])
    if ax >= ay and ax >= az:
        u, v = p[2], p[1]
    elif ay >= ax and ay >= az:
        u, v = p[0], p[2]
    else:
        u, v = p[0], p[1]
    return (u / tile, -v / tile)


def _export_mesh(ob, depsgraph, offset, out_dir, prefab):
    ob_eval = ob.evaluated_get(depsgraph)
    me = bpy.data.meshes.new_from_object(ob_eval, preserve_all_data_layers=False, depsgraph=depsgraph)
    me.transform(Matrix.Translation(-offset) @ ob.matrix_world)
    angle = float(ob.get("smooth_angle", 35.0))
    if angle > 0:
        me.shade_smooth()
        me.set_sharp_from_angle(angle=math.radians(angle))
    else:
        me.shade_flat()
    me.calc_loop_triangles()
    corner_normals = me.corner_normals
    tint = bool(ob.get("tint", False))
    tile = float(ob.get("uv_tile", 4.0))
    mat_rgb = []
    for m in me.materials:
        mat_rgb.append(tuple(m["rgb"]) if (m is not None and "rgb" in m) else (255, 255, 255))
    if not mat_rgb:
        mat_rgb = [(255, 255, 255)]

    pos, nrm, uvs, cols, tris = [], [], [], [], []
    index = {}
    for lt in me.loop_triangles:
        fn = _rbx(lt.normal)
        rgb = mat_rgb[min(lt.material_index, len(mat_rgb) - 1)]
        tri = []
        for vi, li in zip(lt.vertices, lt.loops):
            p = _rbx(me.vertices[vi].co)
            n = _rbx(corner_normals[li].vector)
            uv = _box_uv(p, fn, tile)
            key = (
                vi,
                round(n[0], 3), round(n[1], 3), round(n[2], 3),
                round(uv[0], 4), round(uv[1], 4),
                None if tint else rgb,
            )
            idx = index.get(key)
            if idx is None:
                idx = len(pos)
                index[key] = idx
                pos.append(p)
                nrm.append(n)
                uvs.append(uv)
                cols.append(rgb)
            tri.append(idx)
        tris.append(tri)
    bpy.data.meshes.remove(me)

    if not pos:
        return None
    mins = [min(p[i] for p in pos) for i in range(3)]
    maxs = [max(p[i] for p in pos) for i in range(3)]
    center = [(mins[i] + maxs[i]) / 2 for i in range(3)]
    size = [maxs[i] - mins[i] for i in range(3)]

    part_name = ob.name.split("|", 1)[1]
    mesh = {
        "name": part_name,
        "pos": [round(c - center[i % 3], 4) for p in pos for i, c in enumerate(p)],
        "nrm": [round(c, 4) for n in nrm for c in n],
        "uv": [round(c, 4) for uv in uvs for c in uv],
        "tri": [i for t in tris for i in t],
    }
    if not tint and len(set(cols)) > 1:
        mesh["col"] = [c for rgb in cols for c in rgb]
    blob = json.dumps(mesh, separators=(",", ":"))
    digest = hashlib.sha1(blob.encode("utf-8")).hexdigest()[:16]
    rel = "build/meshes/%s/%s.json" % (prefab, part_name)
    os.makedirs(os.path.join(out_dir, "meshes", prefab), exist_ok=True)
    with open(os.path.join(REPO, rel), "w", encoding="utf-8") as f:
        f.write(blob)

    single = mat_rgb[0] if len(set(cols)) <= 1 else (255, 255, 255)
    return {
        "name": part_name,
        "mesh": rel,
        "hash": digest,
        "tris": len(tris),
        "material": ob.get("rbx_material", "SmoothPlastic"),
        "color": list(mat_rgb[0]) if tint else list(single),
        "center": [round(c, 4) for c in center],
        "size": [round(s, 4) for s in size],
        "collision": ob.get("collision", "Box"),
        "canCollide": bool(ob.get("can_collide", False)),
        "castShadow": bool(ob.get("cast_shadow", True)),
        "transparency": float(ob.get("transparency", 0.0)),
        "reflectance": float(ob.get("reflectance", 0.0)),
        "group": ob.get("group", ""),
        "attributes": {k[5:]: ob[k] for k in ob.keys() if k.startswith("attr_")},
    }


def export_fbx_bundle(bundle, prefabs):
    """Write assets/meshes/<bundle>.fbx for Studio's 3D Importer (File > Import 3D).

    Every mesh object becomes a node named "<Prefab>__<Part>" with its transform
    baked in, colors baked to vertex colors (tint parts stay white) and box UVs.
    The geometry is pre-rotated 180 degrees about Z so Blender's default FBX axis
    conversion lands it in the same Roblox frame the JSON exporter uses; the
    Studio side (tools/pipeline/assemble_import.luau) then rebuilds each prefab
    from build/prefabs/<Prefab>.json using the imported MeshParts.
    """
    depsgraph = bpy.context.evaluated_depsgraph_get()
    tmp = bpy.data.collections.get("_fbx_export")
    if tmp is None:
        tmp = bpy.data.collections.new("_fbx_export")
        bpy.context.scene.collection.children.link(tmp)
    _remove_collection_contents(tmp)
    flip = Matrix.Rotation(math.pi, 4, "Z")
    names = []
    for prefab in prefabs:
        coll = bpy.data.collections[prefab]
        offset = Vector(coll.get("prefab_offset", [0, 0, 0]))
        for ob in sorted(coll.all_objects, key=lambda o: o.name):
            if ob.type != "MESH":
                continue
            part = ob.name.split("|", 1)[1]
            me = bpy.data.meshes.new_from_object(ob.evaluated_get(depsgraph), preserve_all_data_layers=False,
                                                 depsgraph=depsgraph)
            me.transform(flip @ Matrix.Translation(-offset) @ ob.matrix_world)
            angle = float(ob.get("smooth_angle", 35.0))
            if angle > 0:
                me.shade_smooth()
                me.set_sharp_from_angle(angle=math.radians(angle))
            else:
                me.shade_flat()
            rgb = [tuple(m["rgb"]) if (m is not None and "rgb" in m) else (255, 255, 255) for m in me.materials]
            rgb = rgb or [(255, 255, 255)]
            tint = bool(ob.get("tint", False))
            if not tint and len(set(rgb)) > 1:
                attr = me.color_attributes.new(name="Col", type="BYTE_COLOR", domain="CORNER")
                for poly in me.polygons:
                    c = rgb[min(poly.material_index, len(rgb) - 1)]
                    srgb = (c[0] / 255.0, c[1] / 255.0, c[2] / 255.0, 1.0)
                    for li in poly.loop_indices:
                        attr.data[li].color_srgb = srgb
            tile = float(ob.get("uv_tile", 4.0))
            uv_layer = me.uv_layers.new(name="UVMap")
            for poly in me.polygons:
                n = poly.normal
                nr = (n.x, n.z, -n.y)
                for li in poly.loop_indices:
                    co = me.vertices[me.loops[li].vertex_index].co
                    uv_layer.data[li].uv = _box_uv((co.x, co.z, -co.y), nr, tile)
            me.materials.clear()
            name = "%s__%s" % (prefab, part)
            me.name = name
            node = bpy.data.objects.new(name, me)
            tmp.objects.link(node)
            names.append(name)

    for ob in bpy.context.view_layer.objects:
        ob.select_set(False)
    for ob in tmp.objects:
        ob.select_set(True)
    out = os.path.join(REPO, "assets", "meshes", bundle + ".fbx")
    os.makedirs(os.path.dirname(out), exist_ok=True)
    bpy.ops.export_scene.fbx(
        filepath=out, use_selection=True, object_types={"MESH"}, use_mesh_modifiers=False,
        mesh_smooth_type="OFF", colors_type="SRGB", add_leaf_bones=False, bake_anim=False,
        axis_forward="-Z", axis_up="Y", apply_unit_scale=True, apply_scale_options="FBX_SCALE_UNITS",
        use_custom_props=False, path_mode="AUTO",
    )
    _remove_collection_contents(tmp)
    bpy.data.collections.remove(tmp)
    with open(os.path.join(BUILD, "fbx_" + bundle + ".json"), "w", encoding="utf-8") as f:
        json.dump({"bundle": bundle, "prefabs": list(prefabs), "nodes": names}, f, indent=1)
    return {"fbx": out, "nodes": len(names), "bytes": os.path.getsize(out)}


def export_prefab(name):
    """Write build/prefabs/<name>.json + build/meshes/<name>/*.json."""
    coll = bpy.data.collections[name]
    offset = Vector(coll.get("prefab_offset", [0, 0, 0]))
    depsgraph = bpy.context.evaluated_depsgraph_get()
    parts, markers = [], {}
    for ob in sorted(coll.all_objects, key=lambda o: o.name):
        if ob.type == "MESH":
            info = _export_mesh(ob, depsgraph, offset, BUILD, name)
            if info:
                parts.append(info)
        elif ob.type == "EMPTY" and "|@" in ob.name:
            mw = Matrix.Translation(-offset) @ ob.matrix_world
            p = _rbx(mw.translation)
            r = _M @ mw.to_3x3().normalized() @ _M.transposed()
            markers[ob.name.split("|@", 1)[1]] = [round(c, 4) for c in p] + [round(r[i][j], 5) for i in range(3) for j in range(3)]
    manifest = {"name": name, "parts": parts, "markers": markers}
    os.makedirs(os.path.join(BUILD, "prefabs"), exist_ok=True)
    with open(os.path.join(BUILD, "prefabs", name + ".json"), "w", encoding="utf-8") as f:
        json.dump(manifest, f, indent=1)
    return {"prefab": name, "parts": len(parts), "tris": sum(p["tris"] for p in parts), "markers": len(markers)}
