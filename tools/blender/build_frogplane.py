"""The Frog Plane event: Ribbit's flying frog plane, the frog safes it drops
(on parachutes) and the exclusive prizes found inside the safes.

Front is -Y everywhere. Origins:
  FrogPlane          middle of the fuselage (the game flies it nose first)
  FrogSafe           bottom center; markers Hinge (door), DialAxis, Top
  Parachute          where the lines meet (sits on the safe's Top marker)
  FrogPilotCap       HatAttachment, like the other hats
  ParachutePack      BodyBackAttachment (middle of the upper back)
  BabyFrog           bottom center (pet)
  GoldenFrogStatue   ground center (garden decor)
  LilyPond           ground center (garden decor)

Exported as its own FBX bundle (MathMoney_FrogPlane), so importing it doesn't
upload the rest of the game's meshes again:

    import build_frogplane; build_frogplane.build(); build_frogplane.export()
"""

import math

import mm_lib as mm

GREEN = (108, 200, 84)
GREEN_DARK = (62, 146, 60)
GREEN_LIGHT = (152, 224, 108)
CREAM = (246, 236, 200)
WHITE = (250, 248, 240)
BLACK = (30, 30, 36)
RED = (226, 64, 72)
YELLOW = (255, 212, 50)
GOLD = (255, 200, 60)
SILVER = (198, 204, 214)
STEEL = (120, 126, 140)
PINK = (255, 132, 150)
MOUTH = (128, 30, 50)
IRIS = (122, 74, 40)
GLASS = (150, 220, 255)
LEATHER = (156, 100, 58)
LEATHER_DARK = (112, 72, 44)
WATER = (64, 168, 208)
STONE = (150, 146, 140)

PREFABS = ["FrogPlane", "FrogSafe", "Parachute", "FrogPilotCap", "ParachutePack", "BabyFrog", "GoldenFrogStatue",
           "LilyPond"]


# --------------------------------------------------------------------------
# Shared bits
# --------------------------------------------------------------------------


def ribbit(b, s=1.0, base=(0.0, 0.0, 0.0), body=GREEN, belly=CREAM, white=WHITE, dark=BLACK, hat=BLACK, band=RED,
           bow=RED, segs=1.0):
    """A sitting Ribbit-style frog with a top hat and bow tie (s=1 is Ribbit's size,
    about 8.4 studs to the top of the hat). Pass one color everywhere for a statue."""
    bx, by, bz = base

    def p(x, y, z):
        return (bx + x * s, by + y * s, bz + z * s)

    def n(count):
        return max(6, int(count * segs))

    b.lathe([(0, 0), (1.9, 0.1), (2.4, 1.2), (2.3, 2.6), (1.8, 3.8), (1.5, 4.3), (0, 4.5)], loc=p(0, 0, 0), color=body,
            segs=n(24), scale=(s, 0.9 * s, s))
    b.sphere(1.6 * s, loc=p(0, -0.75, 1.9), color=belly, segs=n(18), rings=n(10), scale=(1.0, 0.55, 1.15))
    # back legs folded at the sides, front feet in front
    for side in (-1, 1):
        b.sphere(1.0 * s, loc=p(side * 2.0, 0.2, 0.75), color=body, segs=n(14), rings=n(8), scale=(0.75, 1.45, 0.72))
        b.sphere(0.6 * s, loc=p(side * 2.25, -1.55, 0.18), color=body, segs=n(12), rings=n(6), scale=(1.0, 1.5, 0.35))
        b.tube(mm.smooth_path([p(side * 1.9, -0.4, 3.0), p(side * 2.15, -1.3, 1.6), p(side * 1.5, -1.9, 0.45)], 3),
               0.33 * s, color=body, sides=n(10))
        for f in (-1, 0, 1):
            b.sphere(0.22 * s, loc=p(side * 1.45 + f * 0.24, -2.15, 0.25), color=body, segs=n(8), rings=n(5))
    # head + eyes
    b.sphere(2.0 * s, loc=p(0, -0.2, 5.0), color=body, segs=n(22), rings=n(12), scale=(1.15, 0.95, 0.75))
    for ex in (-1.05, 1.05):
        b.sphere(0.85 * s, loc=p(ex, -0.3, 6.15), color=body, segs=n(16), rings=n(10))
        b.sphere(0.62 * s, loc=p(ex, -0.75, 6.25), color=white, segs=n(14), rings=n(8))
        b.sphere(0.3 * s, loc=p(ex, -1.27, 6.2), color=dark, segs=n(10), rings=n(6))
        b.sphere(0.09 * s, loc=p(ex - 0.12, -1.5, 6.36), color=white, segs=6, rings=4)
    smile = []
    for k in range(13):
        a = math.radians(200 + 140 * k / 12)
        smile.append(p(1.35 * math.cos(a), -1.8 - 0.1 * math.sin(a * 2), 4.85 + 0.55 * math.sin(a)))
    b.tube(smile, 0.08 * s, color=dark, sides=6)
    # top hat + band, bow tie
    b.lathe([(0, 6.15), (1.6, 6.15), (1.6, 6.32), (0.95, 6.35), (0.95, 8.3), (1.05, 8.4), (0, 8.42)], loc=p(0, 0.35, 0),
            rot=(-8, 0, 0), color=hat, segs=n(24), scale=s)
    b.torus(0.97 * s, 0.12 * s, loc=p(0, 0.32 + 0.07, 6.65), rot=(-8, 0, 0), color=band, segs=n(24), sides=6)
    for side in (-1, 1):
        b.sphere(0.48 * s, loc=p(side * 0.45, -1.55, 3.55), rot=(0, side * 15, 0), color=bow, segs=n(10), rings=n(6),
                 scale=(1.0, 0.45, 0.65))
    b.sphere(0.2 * s, loc=p(0, -1.72, 3.55), color=bow, segs=8, rings=5)


def lily_pad(b, r, loc=(0, 0, 0), rot_z=0.0, color=GREEN_DARK, depth=0.08, rot=(0, 0, 0)):
    """A lily pad (a disc with a wedge cut out), lying in the XY plane unless rotated."""
    pts = [(0.0, 0.0)]
    for i in range(23):
        a = math.radians(rot_z + 18 + 324 * i / 22)
        pts.append((r * math.cos(a), r * math.sin(a)))
    b.extrude(pts, depth, loc=loc, rot=rot, color=color)


def flower(b, loc, r=0.3, petal=PINK, middle=YELLOW, petals=6):
    """Little lotus flower sitting on a pad (petals point up and out)."""
    x, y, z = loc
    for i in range(petals):
        a = 2 * math.pi * i / petals
        b.sphere(r, loc=(x + math.cos(a) * r * 0.9, y + math.sin(a) * r * 0.9, z + r * 0.5),
                 rot=(0, 0, math.degrees(a)), color=petal, segs=10, rings=6, scale=(1.0, 0.55, 0.45))
    b.sphere(r * 0.45, loc=(x, y, z + r * 0.75), color=middle, segs=8, rings=5)


def dome_shell(b, r, height, a0, a1, z0, color, thickness=0.14, rings=6, segs=6):
    """One closed, slightly thick gore of a dome (so it shows from inside too)."""
    verts, faces = [], []

    def ring_point(rr, hh, a, t):
        # t: 0 at the rim, 1 at the top
        ang = t * math.pi / 2
        return (rr * math.cos(ang) * math.cos(a), rr * math.cos(ang) * math.sin(a), z0 + hh * math.sin(ang))

    grid_out, grid_in = [], []
    for i in range(rings + 1):
        t = i / rings
        row_o, row_i = [], []
        for j in range(segs + 1):
            a = a0 + (a1 - a0) * j / segs
            verts.append(ring_point(r, height, a, t))
            row_o.append(len(verts) - 1)
            verts.append(ring_point(r - thickness, height - thickness, a, t))
            row_i.append(len(verts) - 1)
        grid_out.append(row_o)
        grid_in.append(row_i)
    for i in range(rings):
        for j in range(segs):
            o = (grid_out[i][j], grid_out[i][j + 1], grid_out[i + 1][j + 1], grid_out[i + 1][j])
            n_ = (grid_in[i][j], grid_in[i + 1][j], grid_in[i + 1][j + 1], grid_in[i][j + 1])
            faces += [list(o), list(n_)]
    # side walls along both gore edges and the rim
    for i in range(rings):
        for j in (0, segs):
            faces.append([grid_out[i][j], grid_out[i + 1][j], grid_in[i + 1][j], grid_in[i][j]])
    for j in range(segs):
        faces.append([grid_out[0][j], grid_in[0][j], grid_in[0][j + 1], grid_out[0][j + 1]])
    # the top ring collapses to one point: drop degenerate quads there
    clean = []
    for f in faces:
        pts = {tuple(round(c, 5) for c in verts[k]) for k in f}
        if len(pts) >= 3:
            clean.append(f)
    # merge duplicate points at the very top so the shell stays closed
    remap, uniq, uverts = {}, {}, []
    for k, v in enumerate(verts):
        key = tuple(round(c, 5) for c in v)
        if key not in uniq:
            uniq[key] = len(uverts)
            uverts.append(v)
        remap[k] = uniq[key]
    out_faces = []
    for f in clean:
        g = []
        for k in f:
            m = remap[k]
            if m not in g:
                g.append(m)
        if len(g) >= 3:
            out_faces.append(g)
    b.raw(uverts, out_faces, color=color)


# --------------------------------------------------------------------------
# The plane
# --------------------------------------------------------------------------


def _wing_poly(sign, root_x, tip_x, root_le, root_te, tip_le, tip_te):
    pts = [(sign * root_x, root_le), (sign * tip_x, tip_le), (sign * tip_x, tip_te), (sign * root_x, root_te)]
    return pts if sign > 0 else list(reversed(pts))


# the plane's head (a big green ellipsoid) and chin (a cream one under it)
HEAD = ((0.0, -11.5, 1.2), (6.2 * 1.12, 6.2 * 0.95, 6.2 * 0.88))
CHIN = ((0.0, -13.0, -1.7), (5.0 * 1.05, 5.0 * 0.92, 5.0 * 0.62))
DIHEDRAL = 5.0


def _front_y(x, z, ellipsoid):
    (cx, cy, cz), (rx, ry, rz) = ellipsoid
    k = 1 - ((x - cx) / rx) ** 2 - ((z - cz) / rz) ** 2
    return cy - ry * math.sqrt(k) if k > 0 else None


def face_y(x, z, out=0.0):
    """How far forward (-Y) the head/chin surface is at (x, z), pushed ``out``."""
    ys = [y for y in (_front_y(x, z, HEAD), _front_y(x, z, CHIN)) if y is not None]
    return min(ys) - out if ys else HEAD[0][1]


def face_patch(b, x0, x1, top, bottom, out, color, thickness=0.5, nu=18, nv=6):
    """A thin shell lying on the plane's face between x0..x1, from z=top(x) down to
    z=bottom(x) (like the open mouth painted onto the curve of the head)."""
    verts, faces = [], []
    front, back = [], []
    for i in range(nu + 1):
        px = x0 + (x1 - x0) * i / nu
        zt, zb = top(px), bottom(px)
        rf, rb = [], []
        for j in range(nv + 1):
            pz = zt + (zb - zt) * j / nv
            verts.append((px, face_y(px, pz, out), pz))
            rf.append(len(verts) - 1)
            verts.append((px, face_y(px, pz, out - thickness), pz))
            rb.append(len(verts) - 1)
        front.append(rf)
        back.append(rb)
    for i in range(nu):
        for j in range(nv):
            faces.append([front[i][j], front[i + 1][j], front[i + 1][j + 1], front[i][j + 1]])
            faces.append([back[i][j], back[i][j + 1], back[i + 1][j + 1], back[i + 1][j]])
    for i in range(nu):
        for j in (0, nv):
            faces.append([front[i][j], back[i][j], back[i + 1][j], front[i + 1][j]])
    for j in range(nv):
        for i in (0, nu):
            faces.append([front[i][j], front[i][j + 1], back[i][j + 1], back[i][j]])
    b.raw(verts, faces, color=color)


def wing_z(x_abs, top=0.0):
    """Height of the wing's mid plane (tilted up 5 degrees) at |x|, plus ``top``."""
    return 0.2 + x_abs * math.tan(math.radians(DIHEDRAL)) + top


def frog_plane(x):
    coll = mm.prefab_collection("FrogPlane", offset=(x, 260, 0))

    # fuselage: a chubby frog body, green on top with a cream belly
    b = mm.Builder("Fuselage", coll, seed=201)
    body = [(0.0, -16.5), (1.0, -16.2), (1.9, -14.5), (2.8, -11.5), (3.8, -7.5), (4.6, -3.5), (5.0, 0.0), (5.0, 3.0),
            (4.7, 6.0), (4.2, 8.5), (0.0, 9.0)]
    b.lathe(body, rot=(90, 0, 0), color=GREEN, segs=32, scale=(1.05, 0.95, 1.0))
    b.lathe(body, loc=(0, 0, -1.0), rot=(90, 0, 0), color=CREAM, segs=32, scale=(0.86, 0.86, 0.97))
    # cockpit bubble behind the head, with a silver rim
    b.sphere(1.9, loc=(0, -3.6, 4.55), color=GLASS, segs=20, rings=10, scale=(1.0, 1.45, 0.75))
    b.torus(1.9, 0.18, loc=(0, -3.6, 4.15), color=SILVER, segs=24, sides=6, scale=(1.0, 1.45, 1.0))
    # portholes along both sides
    for side in (-1, 1):
        for py in (1.5, 4.5, 7.5):
            r = 0.75 if py < 6 else 0.6
            b.cyl(r, 0.3, loc=(side * (4.85 - py * 0.05), py, 1.4), rot=(0, 90, 0), color=GLASS, segs=14)
            b.torus(r, 0.12, loc=(side * (4.95 - py * 0.05), py, 1.4), rot=(0, 90, 0), color=YELLOW, segs=16, sides=5)
    # cargo hatch under the belly (the safes drop out of here)
    b.box((3.4, 4.6, 0.3), loc=(0, 2.4, -5.05), color=STEEL, bevel=0.1)
    b.box((2.8, 4.0, 0.3), loc=(0, 2.4, -5.15), color=(60, 64, 74), bevel=0.06)
    b.build(material="SmoothPlastic", smooth_angle=55)
    mm.marker(coll, "Drop", loc=(0, 2.4, -5.8))

    # the frog head at the front
    b = mm.Builder("Head", coll, seed=202)
    b.sphere(6.2, loc=HEAD[0], color=GREEN, segs=30, rings=18, scale=(1.12, 0.95, 0.88))
    b.sphere(5.0, loc=CHIN[0], color=CREAM, segs=26, rings=14, scale=(1.05, 0.92, 0.62))  # chin
    # a big open grin with a pink tongue, drawn right on the curve of the face;
    # the upper lip curls up at the corners
    def lip_z(lx):
        return 0.75 + 0.9 * (lx / 4.6) ** 2

    def mouth_bottom(lx):
        return lip_z(lx) - 0.35 - 2.4 * math.sqrt(max(0.0, 1 - (lx / 4.4) ** 2))

    face_patch(b, -4.4, 4.4, lambda lx: lip_z(lx) - 0.1, mouth_bottom, 0.04, MOUTH)
    face_patch(b, -2.3, 2.3, lambda lx: mouth_bottom(lx) + 0.15 + 1.15 * math.sqrt(max(0.0, 1 - (lx / 2.3) ** 2)),
               lambda lx: mouth_bottom(lx) + 0.12, 0.1, PINK)
    lip = []
    for k in range(17):
        lx = -4.6 + 9.2 * k / 16
        lip.append((lx, face_y(lx, lip_z(lx), 0.08), lip_z(lx)))
    b.tube(mm.smooth_path(lip, 3), 0.2, color=GREEN_DARK, sides=8)
    for side in (-1, 1):
        b.sphere(0.32, loc=(side * 1.1, face_y(side * 1.1, 3.3, -0.1), 3.3), color=GREEN_DARK, segs=8, rings=5)  # nostrils
        b.sphere(0.85, loc=(side * 5.2, face_y(side * 5.2, 1.6, -0.25), 1.6), color=PINK, segs=12, rings=6,
                 scale=(0.6, 0.5, 0.7))  # rosy cheeks
        # big googly eyes on top
        b.sphere(2.5, loc=(side * 3.0, -12.6, 6.1), color=GREEN, segs=20, rings=12)
        b.sphere(2.15, loc=(side * 3.0, -13.75, 6.45), color=WHITE, segs=20, rings=12, scale=(1.0, 0.85, 1.0))
        b.sphere(1.3, loc=(side * 2.9, -15.45, 6.25), color=IRIS, segs=16, rings=10, scale=(1.0, 0.45, 1.0))
        b.sphere(0.78, loc=(side * 2.85, -16.0, 6.2), color=BLACK, segs=14, rings=8, scale=(1.0, 0.4, 1.0))
        b.sphere(0.32, loc=(side * 2.45 - 0.2, -16.35, 6.75), color=WHITE, segs=8, rings=5)
    # Ribbit's top hat, tipped back behind the eyes
    tilt = -12
    hat_y, hat_z = -8.6, 5.65

    def on_hat(h):  # a point h studs up the (tilted) hat's axis
        a = math.radians(tilt)
        return (0, hat_y - h * math.sin(a), hat_z + h * math.cos(a))

    b.lathe([(0, 0), (2.45, 0), (2.45, 0.3), (1.6, 0.36), (1.6, 3.9), (1.74, 4.05), (0, 4.1)], loc=(0, hat_y, hat_z),
            rot=(tilt, 0, 0), color=BLACK, segs=28)
    b.torus(1.63, 0.24, loc=on_hat(0.8), rot=(tilt, 0, 0), color=RED, segs=28, sides=8)
    # big red bow tie under the grin
    bow_z = -3.9
    for side in (-1, 1):
        # each loop is a squashed cone pointing at the knot
        b.cyl(1.45, 2.3, loc=(side * 1.35, face_y(side * 1.35, bow_z, -0.05), bow_z), r_top=0.4,
              rot=(side * 12, -side * 90, 0), color=RED, segs=16, scale=(1.0, 0.5, 1.0), bevel=0.12)
    b.sphere(0.75, loc=(0, face_y(0, bow_z, 0.3), bow_z), color=RED, segs=12, rings=8, scale=(0.9, 0.7, 1.0))
    b.build(material="SmoothPlastic", smooth_angle=60)

    # wings, tail and lily-pad emblems
    b = mm.Builder("Wings", coll, seed=203)
    for sign in (-1, 1):
        dih = -DIHEDRAL * sign
        b.extrude(_wing_poly(sign, 3.5, 24.5, -4.6, 3.6, -2.9, 2.0), 1.1, loc=(0, 0, 0.2), rot=(0, dih, 0),
                  color=CREAM, bevel=0.32)

        def le_y(xa):  # leading edge position along the span
            return -4.6 + (xa - 3.5) / 21.0 * 1.7

        # green stripe just behind the leading edge + red wingtip
        b.beam((sign * 5.0, le_y(5.0) + 0.75, wing_z(5.0, 0.56)), (sign * 23.2, le_y(23.2) + 0.75, wing_z(23.2, 0.56)),
               1.0, 0.12, color=GREEN)
        b.box((1.6, 5.0, 1.0), loc=(sign * 24.4, -0.45, wing_z(24.4)), rot=(0, dih, 0), color=RED, bevel=0.42)
        # lily pad emblem on top of each wing
        ex = sign * 17.0
        ez = wing_z(17.0, 0.6)
        lily_pad(b, 2.0, loc=(ex, -0.5, ez), rot_z=60 if sign > 0 else 120, color=GREEN, rot=(0, dih, 0))
        flower(b, (ex - sign * 0.3, -0.9, ez + 0.05), r=0.42, petal=WHITE, middle=YELLOW)
        # tail planes
        b.extrude(_wing_poly(sign, 1.2, 8.8, 11.8, 15.4, 13.4, 15.6), 0.7, loc=(0, 0, 1.4), color=CREAM, bevel=0.22)
        b.box((1.0, 2.6, 0.75), loc=(sign * 8.9, 14.5, 1.4), color=RED, bevel=0.3)
    # tall red tail fin with a lily pad badge on both sides
    fin = [(10.6, 1.0), (16.4, 1.0), (17.0, 9.6), (14.2, 9.8)]
    b.extrude(fin, 0.8, loc=(0, 0, 0), rot=(90, 0, 90), color=RED, bevel=0.28)
    for side in (-1, 1):
        b.cyl(1.55, 0.12, loc=(side * 0.46, 14.9, 6.0), rot=(0, 90, 0), color=WHITE, segs=24)
        lily_pad(b, 1.15, loc=(side * 0.55, 14.9, 6.0), rot_z=30, color=GREEN, rot=(0, 90, 0))
    b.build(material="SmoothPlastic", smooth_angle=35)

    # engines + landing gear
    b = mm.Builder("Engines", coll, seed=204)
    for sign in (-1, 1):
        ex, ez = sign * 10.5, -0.5
        b.lathe([(0, -3.6), (1.3, -3.4), (2.05, -1.8), (2.1, 1.4), (1.8, 3.0), (0, 3.4)], loc=(ex, -4.4, ez),
                rot=(90, 0, 0), color=GREEN, segs=24)
        b.torus(1.95, 0.36, loc=(ex, -7.6, ez), rot=(90, 0, 0), color=SILVER, segs=28, sides=8)
        b.cyl(1.7, 0.4, loc=(ex, -7.45, ez), rot=(90, 0, 0), color=(48, 52, 60), segs=24)
        for k in range(8):  # cooling fins inside the cowling
            a = math.radians(22.5 * k)
            b.beam((ex + math.cos(a) * 0.5, -7.5, ez + math.sin(a) * 0.5),
                   (ex + math.cos(a) * 1.6, -7.5, ez + math.sin(a) * 1.6), 0.18, 0.12, color=SILVER)
        # landing gear under the engine
        b.rod((ex, -3.2, ez - 1.6), (ex, -3.6, ez - 4.0), 0.22, color=SILVER, segs=8)
        b.cyl(1.05, 0.7, loc=(ex, -3.6, ez - 4.6), rot=(0, 90, 0), color=BLACK, segs=20, bevel=0.15)
        b.cyl(0.5, 0.8, loc=(ex, -3.6, ez - 4.6), rot=(0, 90, 0), color=SILVER, segs=14)
    b.build(material="SmoothPlastic", smooth_angle=50)

    # spinning propellers (their own parts so the game can spin them)
    for sign, name in ((1, "PropLeft"), (-1, "PropRight")):
        ex, ez = sign * 10.5, -0.5
        b = mm.Builder(name, coll, seed=205 + sign)
        b.lathe([(0, 0), (1.05, 0), (0.95, 0.75), (0.45, 1.5), (0, 1.75)], loc=(ex, -7.9, ez), rot=(90, 0, 0),
                color=RED, segs=20)
        for k in range(3):
            a = 90 + 120 * k
            ca, sa = math.cos(math.radians(a)), math.sin(math.radians(a))
            p0 = (ex + ca * 0.7, -8.25, ez + sa * 0.7)
            p1 = (ex + ca * 3.7, -8.25, ez + sa * 3.7)
            b.beam(p0, p1, 0.95, 0.16, color=YELLOW, roll=24, bevel=0.06)
        b.build(material="SmoothPlastic", smooth_angle=40, cast_shadow=False)
        mm.marker(coll, name + "Axis", loc=(ex, -8.25, ez))
    return mm.export_prefab("FrogPlane")


# --------------------------------------------------------------------------
# The safe + its parachute
# --------------------------------------------------------------------------


def frog_safe(x):
    coll = mm.prefab_collection("FrogSafe", offset=(x, 220, 0))
    w, d, h = 5.0, 5.0, 4.6
    b = mm.Builder("Body", coll, seed=211)
    b.box((w, d, h), loc=(0, 0, h / 2), color=GREEN, bevel=0.35, bevel_segments=3)
    # silver corner brackets + rivets
    for sx in (-1, 1):
        for sy in (-1, 1):
            for sz in (0, 1):
                cx, cy, cz = sx * (w / 2 - 0.42), sy * (d / 2 - 0.42), 0.42 if sz == 0 else h - 0.42
                b.box((1.05, 1.05, 1.05), loc=(cx, cy, cz), color=SILVER, bevel=0.22)
                b.sphere(0.13, loc=(cx + sx * 0.55, cy, cz), color=STEEL, segs=6, rings=4)
                b.sphere(0.13, loc=(cx, cy + sy * 0.55, cz), color=STEEL, segs=6, rings=4)
    # darker frame around the door
    b.box((4.3, 0.2, 4.1), loc=(0, -d / 2 - 0.02, h / 2), color=GREEN_DARK, bevel=0.08)
    # frog eyes peeking over the front edge
    for ex in (-1.25, 1.25):
        b.sphere(0.95, loc=(ex, -1.35, h + 0.25), color=GREEN, segs=16, rings=10)
        b.sphere(0.74, loc=(ex, -1.8, h + 0.42), color=WHITE, segs=14, rings=8)
        b.sphere(0.36, loc=(ex - 0.05, -2.42, h + 0.38), color=BLACK, segs=10, rings=6)
        b.sphere(0.11, loc=(ex - 0.2, -2.68, h + 0.6), color=WHITE, segs=6, rings=4)
    # little silver feet
    for sx in (-1, 1):
        for sy in (-1, 1):
            b.cyl(0.4, 0.25, loc=(sx * 1.8, sy * 1.8, 0.05), color=STEEL, segs=10)
    b.build(material="SmoothPlastic", smooth_angle=40, collision="Box", can_collide=True)

    # front door: frog smile + rosy cheeks + gold handle (swings open on the Hinge)
    b = mm.Builder("Door", coll, seed=212)
    dy = -d / 2 - 0.25
    b.box((3.9, 0.36, 3.8), loc=(0, dy, h / 2), color=GREEN_LIGHT, bevel=0.14)
    smile = []
    for k in range(13):
        a = math.radians(200 + 140 * k / 12)
        smile.append((1.25 * math.cos(a), dy - 0.2, 3.55 + 0.42 * math.sin(a)))
    b.tube(smile, 0.1, color=BLACK, sides=6)
    for cx in (-1.45, 1.45):
        b.sphere(0.34, loc=(cx, dy - 0.17, 3.35), color=PINK, segs=10, rings=6, scale=(1.0, 0.3, 0.75))
    b.cyl(0.18, 0.5, loc=(1.45, dy - 0.3, 1.75), rot=(90, 0, 0), color=GOLD, segs=10)
    b.box((0.26, 0.26, 1.2), loc=(1.45, dy - 0.55, 1.35), color=GOLD, bevel=0.08)
    b.build(material="SmoothPlastic", smooth_angle=40)
    mm.marker(coll, "Hinge", loc=(-1.95, dy, h / 2))

    # the combination dial (spins while you crack the safe)
    b = mm.Builder("Dial", coll, seed=213)
    cx, cz = -0.25, 1.75
    b.cyl(1.0, 0.24, loc=(cx, dy - 0.3, cz), rot=(90, 0, 0), color=SILVER, segs=28)
    b.torus(1.0, 0.09, loc=(cx, dy - 0.42, cz), rot=(90, 0, 0), color=STEEL, segs=28, sides=5)
    for k in range(12):
        a = math.radians(30 * k)
        b.box((0.08, 0.06, 0.24 if k % 3 == 0 else 0.14), loc=(cx + math.sin(a) * 0.78, dy - 0.44, cz + math.cos(a) * 0.78),
              rot=(0, math.degrees(a), 0), color=BLACK)
    b.cyl(0.42, 0.42, loc=(cx, dy - 0.55, cz), rot=(90, 0, 0), color=RED, segs=16, bevel=0.06)
    b.box((0.12, 0.1, 0.5), loc=(cx, dy - 0.78, cz + 0.2), color=WHITE)
    b.build(material="SmoothPlastic", smooth_angle=40, cast_shadow=False)
    mm.marker(coll, "DialAxis", loc=(cx, dy - 0.3, cz))
    mm.marker(coll, "Top", loc=(0, 0, h + 0.1))
    return mm.export_prefab("FrogSafe")


def parachute(x):
    coll = mm.prefab_collection("Parachute", offset=(x, 220, 0))
    b = mm.Builder("Canopy", coll, seed=221)
    gores = 8
    for i in range(gores):
        a0 = 2 * math.pi * i / gores
        a1 = 2 * math.pi * (i + 1) / gores
        dome_shell(b, 5.4, 3.4, a0, a1, 8.5, GREEN if i % 2 == 0 else WHITE)
    # scalloped rim
    for i in range(24):
        a = 2 * math.pi * (i + 0.5) / 24
        b.sphere(0.42, loc=(5.3 * math.cos(a), 5.3 * math.sin(a), 8.45), color=GREEN if (i // 3) % 2 == 0 else WHITE,
                 segs=8, rings=5, scale=(1, 1, 0.55))
    b.build(material="Fabric", smooth_angle=50, cast_shadow=False)
    b = mm.Builder("Lines", coll, seed=222)
    for i in range(gores):
        a = 2 * math.pi * i / gores
        b.rod((0, 0, 0.05), (5.2 * math.cos(a), 5.2 * math.sin(a), 8.5), 0.06, color=(236, 236, 230), segs=4)
    b.box((1.0, 1.0, 0.3), loc=(0, 0, 0.15), color=STEEL, bevel=0.08)
    b.build(material="SmoothPlastic", smooth_angle=30, cast_shadow=False)
    return mm.export_prefab("Parachute")


# --------------------------------------------------------------------------
# Exclusive prizes
# --------------------------------------------------------------------------


def frog_pilot_cap(x):
    coll = mm.prefab_collection("FrogPilotCap", offset=(x, 220, 0))
    b = mm.Builder("Cap", coll, seed=231)
    b.lathe([(0.66, -0.55), (0.69, -0.1), (0.63, 0.25), (0.43, 0.52), (0, 0.61)], color=LEATHER, segs=26)
    for side in (-1, 1):
        b.sphere(0.34, loc=(side * 0.66, 0.05, -0.72), color=LEATHER_DARK, segs=12, rings=8, scale=(0.35, 1.0, 1.35))
        b.tube([(side * 0.68, 0.1, -0.15), (side * 0.7, 0.05, -1.0)], 0.04, color=LEATHER_DARK, sides=5)
    # stitched seam over the top
    b.tube(mm.smooth_path([(0, -0.66, -0.05), (0, -0.45, 0.45), (0, 0.0, 0.62), (0, 0.45, 0.45), (0, 0.66, -0.05)], 3),
           0.035, color=LEATHER_DARK, sides=5)
    # pilot goggles pushed up on the forehead
    b.torus(0.7, 0.05, loc=(0, 0, 0.05), color=LEATHER_DARK, segs=28, sides=5, scale=(1.0, 1.0, 1.0))
    for gx in (-0.27, 0.27):
        b.torus(0.21, 0.065, loc=(gx, -0.66, 0.1), rot=(80, 0, 0), color=GOLD, segs=18, sides=6)
        b.cyl(0.18, 0.06, loc=(gx, -0.66, 0.1), rot=(80, 0, 0), color=GLASS, segs=16)
    b.box((0.16, 0.08, 0.06), loc=(0, -0.7, 0.12), color=GOLD)
    # froggy eyes on top
    for ex in (-0.26, 0.26):
        b.sphere(0.22, loc=(ex, -0.18, 0.6), color=GREEN, segs=12, rings=8)
        b.sphere(0.17, loc=(ex, -0.3, 0.66), color=WHITE, segs=10, rings=6)
        b.sphere(0.08, loc=(ex, -0.43, 0.65), color=BLACK, segs=8, rings=5)
    b.build(material="SmoothPlastic", smooth_angle=45)
    return mm.export_prefab("FrogPilotCap")


def parachute_pack(x):
    coll = mm.prefab_collection("ParachutePack", offset=(x, 220, 0))
    b = mm.Builder("Pack", coll, seed=241)
    b.box((1.35, 0.62, 1.55), loc=(0, 0.36, -0.05), color=GREEN, bevel=0.18, bevel_segments=3)
    b.box((1.38, 0.64, 0.26), loc=(0, 0.36, 0.22), color=WHITE, bevel=0.06)
    b.box((1.25, 0.5, 0.24), loc=(0, 0.42, 0.78), color=GREEN_DARK, bevel=0.1)
    for sx in (-0.42, 0.42):
        b.box((0.16, 0.08, 1.5), loc=(sx, 0.02, 0.0), color=LEATHER_DARK)
        b.box((0.2, 0.1, 0.12), loc=(sx, -0.02, -0.45), color=SILVER)
    b.torus(0.12, 0.05, loc=(0.42, -0.06, -0.2), rot=(90, 0, 0), color=RED, segs=12, sides=5)  # ripcord
    lily_pad(b, 0.42, loc=(0, 0.69, -0.25), rot_z=70, color=GREEN_DARK, rot=(-90, 0, 0))
    b.build(material="SmoothPlastic", smooth_angle=45)
    return mm.export_prefab("ParachutePack")


def baby_frog(x):
    coll = mm.prefab_collection("BabyFrog", offset=(x, 220, 0))
    b = mm.Builder("Frog", coll, seed=251)
    ribbit(b, s=0.36, segs=0.75)
    b.build(material="SmoothPlastic", smooth_angle=50)
    return mm.export_prefab("BabyFrog")


def golden_frog_statue(x):
    coll = mm.prefab_collection("GoldenFrogStatue", offset=(x, 220, 0))
    b = mm.Builder("Pedestal", coll, seed=261)
    b.box((2.8, 2.8, 0.35), loc=(0, 0, 0.18), color=STONE, bevel=0.08)
    b.box((2.3, 2.3, 1.0), loc=(0, 0, 0.85), color=(170, 166, 160), bevel=0.06)
    b.box((2.6, 2.6, 0.25), loc=(0, 0, 1.45), color=STONE, bevel=0.08)
    b.box((1.2, 0.08, 0.45), loc=(0, -1.17, 0.85), color=GOLD, bevel=0.03)  # name plaque
    b.build(material="Slate", smooth_angle=30, uv_tile=2, collision="Box")
    b = mm.Builder("Statue", coll, seed=262)
    ribbit(b, s=0.5, base=(0, 0.1, 1.55), body=GOLD, belly=GOLD, white=GOLD, dark=GOLD, hat=GOLD, band=GOLD,
           bow=GOLD, segs=0.85)
    b.build(material="Foil", smooth_angle=50, collision="Box")
    return mm.export_prefab("GoldenFrogStatue")


def lily_pond(x):
    coll = mm.prefab_collection("LilyPond", offset=(x, 220, 0))
    b = mm.Builder("Rim", coll, seed=271)
    rng = b.rng
    for i in range(15):
        a = 2 * math.pi * i / 15 + rng.uniform(-0.08, 0.08)
        r = 2.75 + rng.uniform(-0.1, 0.15)
        b.ico(0.42 + rng.uniform(-0.06, 0.1), loc=(r * math.cos(a), r * math.sin(a), 0.2), color=STONE, subdiv=1,
              scale=(1.2, 1.0, 0.7), jitter=0.05)
    b.build(material="Slate", smooth_angle=35, uv_tile=1.5, collision="Box")
    b = mm.Builder("Water", coll, seed=272)
    b.cyl(2.6, 0.22, loc=(0, 0, 0.11), color=WATER, segs=32)
    b.build(material="Glass", smooth_angle=30, transparency=0.15, reflectance=0.1)
    b = mm.Builder("Pads", coll, seed=273)
    for px, py, r, rot in ((-0.9, 0.6, 0.8, 30), (0.95, 0.3, 0.65, 200), (0.1, -1.1, 0.7, 120)):
        lily_pad(b, r, loc=(px, py, 0.26), rot_z=rot, color=GREEN if r > 0.7 else GREEN_DARK)
    flower(b, (-0.85, 0.55, 0.3), r=0.28)
    for cx, cy in ((1.9, 1.5), (2.2, 1.0)):  # cattails at the edge
        b.rod((cx, cy, 0.1), (cx + 0.1, cy, 1.9), 0.04, color=GREEN_DARK, segs=5)
        b.cyl(0.11, 0.5, loc=(cx + 0.1, cy, 1.75), color=(120, 76, 44), segs=8)
    b.build(material="SmoothPlastic", smooth_angle=45)
    return mm.export_prefab("LilyPond")


def build():
    return [frog_plane(0), frog_safe(60), parachute(75), frog_pilot_cap(90), parachute_pack(95), baby_frog(100),
            golden_frog_statue(108), lily_pond(118)]


def export():
    return mm.export_fbx_bundle("MathMoney_FrogPlane", PREFABS)
