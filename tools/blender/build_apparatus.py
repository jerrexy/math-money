"""The money-dropping apparatus: acid vat, wooden derrick, pulleys, engine, console.

Layout (Blender units == studs, Z up, front/player side is -Y):
  * vat centered on the origin, rim at z=6, acid surface at z~4.85
  * derrick A-frames at x=+-8.6, top crossbeam at z=34.6, boom running back (+Y)
  * chain: plate hook -> front of pulley A -> over to pulley B -> down to the drum
  * engine behind the vat (y~12), computer console in front (y~-11.5)
The machine is ~41 studs tall to the top of its sign.
"""

import math

import mm_lib as mm

WOOD = (156, 108, 66)
WOOD_DARK = (112, 76, 46)
IRON = (68, 72, 80)
IRON_LIGHT = (110, 116, 126)
BRASS = (204, 160, 70)
COPPER = (192, 112, 72)
VAT = (70, 94, 82)
ACID = (128, 236, 56)
CREAM = (238, 228, 204)
BEZEL = (58, 58, 64)
KEY = (96, 96, 104)
RUBBER = (38, 38, 42)
WHITE = (246, 246, 246)
RED = (226, 52, 52)
BLACK = (24, 24, 28)

PULLEY_A = (0.0, 1.6, 31.5)
PULLEY_B = (0.0, 10.4, 31.5)
PULLEY_R = 1.6
ENGINE_LIFT = 2.6  # engine sits on a stone plinth so its face peeks over the vat
LIFT = (0.0, 0.0, ENGINE_LIFT)
DRUM_LOCAL = (0.0, 13.0, 8.0)
DRUM = (0.0, 13.0, 8.0 + ENGINE_LIFT)
PLATE_TOP_Z = 22.0
HOOK_Z = PLATE_TOP_Z + 6.4
ACID_Z = 4.85


def vat(coll):
    b = mm.Builder("Vat", coll, seed=3)
    b.lathe(
        [(0, 0.5), (6.5, 0.5), (6.9, 0.8), (7.1, 3.0), (7.0, 5.0), (7.5, 5.3), (7.6, 5.9), (7.2, 6.2),
         (6.6, 6.0), (6.4, 5.4), (6.3, 1.4), (0, 1.4)],
        color=VAT, segs=40,
    )
    for z, r in ((1.6, 7.03), (4.3, 7.09)):
        b.torus(r, 0.2, loc=(0, 0, z), color=BRASS, segs=40, sides=8)
        for i in range(14):
            a = 2 * math.pi * (i + 0.5) / 14
            c, s = math.cos(a), math.sin(a)
            b.rod((c * (r - 0.05), s * (r - 0.05), z), (c * (r + 0.28), s * (r + 0.28), z), 0.13, color=BRASS, segs=6)
    for i in range(4):
        a = math.radians(45 + 90 * i)
        b.box((1.6, 1.6, 0.7), loc=(6.0 * math.cos(a), 6.0 * math.sin(a), 0.35), rot=(0, 0, 45 + 90 * i), color=IRON, bevel=0.12)
    b.build(material="Metal", smooth_angle=40, uv_tile=6, collision="PreciseConvexDecomposition", can_collide=True)

    # bubbling acid surface with lumps of goo
    b = mm.Builder("Acid", coll, seed=7)
    b.cyl(6.3, 0.3, loc=(0, 0, ACID_Z - 0.15), color=ACID, segs=40)
    rng = b.rng
    for _ in range(9):
        a = rng.uniform(0, 2 * math.pi)
        d = rng.uniform(0.5, 4.8)
        r = rng.uniform(0.35, 0.75)
        b.sphere(r, loc=(d * math.cos(a), d * math.sin(a), ACID_Z - r * 0.45), color=ACID, segs=12, rings=7, scale=(1, 1, 0.7))
    b.build(material="Neon", smooth_angle=60, transparency=0.12, cast_shadow=False)

    # goo dripping down the outside of the vat (quirky)
    b = mm.Builder("AcidDrips", coll, seed=11)
    for i, a_deg in enumerate((20, 95, 160, 250, 310)):
        a = math.radians(a_deg)
        c, s = math.cos(a), math.sin(a)
        length = 1.6 + (i % 3) * 0.9
        top = 6.1
        pts = [(c * (7.35 - 0.05 * k), s * (7.35 - 0.05 * k), top - length * k / 4) for k in range(5)]
        b.tube(pts, 0.28, color=ACID, sides=8, radii=[0.34, 0.3, 0.24, 0.2, 0.17])
        end = pts[-1]
        b.sphere(0.34, loc=(end[0] + c * 0.05, end[1] + s * 0.05, end[2] - 0.15), color=ACID, segs=10, rings=6, scale=(1, 1, 1.25))
        b.lathe([(0, 6.0), (0.75, 6.05), (0.55, 6.35), (0, 6.4)], loc=(c * 7.3, s * 7.3, 0), color=ACID, segs=10)
    b.build(material="Neon", smooth_angle=60, transparency=0.12, cast_shadow=False)


def derrick(coll):
    b = mm.Builder("FrameWood", coll, seed=5)
    w = 1.3
    for x in (-8.6, 8.6):
        apex = (x, 1.6, 34.1)
        b.beam((x, -4.4, 0.0), apex, w, color=WOOD, bevel=0.12, extend=0.2)
        b.beam((x, 7.6, 0.0), apex, w, color=WOOD, bevel=0.12, extend=0.2)
        for z in (11.0, 22.0):
            t = z / 34.1
            y0 = -4.4 + (1.6 + 4.4) * t
            y1 = 7.6 - (7.6 - 1.6) * t
            b.beam((x, y0 - 0.6, z), (x, y1 + 0.6, z), 1.0, color=WOOD_DARK, bevel=0.1)
        # diagonal brace between the crossbars
        b.beam((x, -2.46, 11.0), (x, 3.72, 22.0), 0.8, color=WOOD_DARK, bevel=0.08)
    b.beam((-9.8, 1.6, 34.6), (9.8, 1.6, 34.6), 1.5, color=WOOD, bevel=0.14)
    b.beam((0, 0.8, 34.6), (0, 17.4, 34.6), 1.4, color=WOOD, bevel=0.14)
    # rear support (A-frame across X behind the engine)
    for x in (-4.2, 4.2):
        b.beam((x, 16.6, 0.0), (0, 16.6, 34.0), 1.2, color=WOOD, bevel=0.12, extend=0.2)
    b.beam((-3.2, 16.6, 8.0), (3.2, 16.6, 8.0), 0.9, color=WOOD_DARK, bevel=0.08)
    b.beam((-1.6, 16.6, 21.0), (1.6, 16.6, 21.0), 0.9, color=WOOD_DARK, bevel=0.08)
    # sign posts
    for x in (-1.6, 1.6):
        b.beam((x, 1.6, 35.2), (x, 1.6, 36.6), 0.5, color=WOOD_DARK)
    b.build(material="Wood", smooth_angle=30, uv_tile=7, collision="PreciseConvexDecomposition", can_collide=True)

    b = mm.Builder("FrameMetal", coll, seed=9)
    # joint plates at the apexes and on the boom end
    for x in (-8.6, 8.6):
        side = 1 if x > 0 else -1
        b.box((0.25, 2.8, 2.8), loc=(x + side * 0.78, 1.6, 33.6), color=IRON, bevel=0.06)
        for dy, dz in ((-0.9, -0.9), (0.9, -0.9), (-0.9, 0.9), (0.9, 0.9)):
            b.cyl(0.16, 0.25, loc=(x + side * 0.95, 1.6 + dy, 33.6 + dz), rot=(0, 90, 0), color=BRASS, segs=8)
        for y in (-4.4, 7.6):
            b.box((2.2, 2.2, 0.3), loc=(x, y, 0.15), color=IRON, bevel=0.05)
    for x in (-4.2, 4.2):
        b.box((2.2, 2.2, 0.3), loc=(x, 16.6, 0.15), color=IRON, bevel=0.05)
    b.box((2.6, 0.25, 2.6), loc=(0, 17.4, 34.0), color=IRON, bevel=0.06)
    # pulley brackets + axles
    for (px, py, pz) in (PULLEY_A, PULLEY_B):
        for sx in (-0.75, 0.75):
            b.box((0.24, 1.5, 3.6), loc=(px + sx, py, pz + 1.3), color=IRON, bevel=0.05)
        b.rod((px - 1.0, py, pz), (px + 1.0, py, pz), 0.24, color=BRASS, segs=10)
        for sx in (-1.0, 1.0):
            b.cyl(0.36, 0.2, loc=(px + sx, py, pz), rot=(0, 90, 0), color=BRASS, segs=8)
    b.build(material="Metal", smooth_angle=35, uv_tile=3)

    # pulley wheels (identical meshes -> uploaded once)
    for name, center in (("PulleyA", PULLEY_A), ("PulleyB", PULLEY_B)):
        b = mm.Builder(name, coll)
        b.lathe([(1.2, -0.38), (PULLEY_R + 0.2, -0.38), (PULLEY_R - 0.05, -0.1), (PULLEY_R - 0.05, 0.1),
                 (PULLEY_R + 0.2, 0.38), (1.2, 0.38)], loc=center, rot=(0, 90, 0), color=IRON_LIGHT, segs=28, closed=True)
        b.cyl(0.45, 0.9, loc=center, rot=(0, 90, 0), color=BRASS, segs=12)
        for i in range(6):
            a = 60 * i
            ca, sa = math.cos(math.radians(a)), math.sin(math.radians(a))
            p0 = (center[0], center[1] + 0.35 * ca, center[2] + 0.35 * sa)
            p1 = (center[0], center[1] + 1.25 * ca, center[2] + 1.25 * sa)
            b.beam(p0, p1, 0.22, 0.3, color=IRON_LIGHT)
        b.build(material="Metal", smooth_angle=40, uv_tile=2)


def sign(coll):
    center = (0.0, 1.6, 38.6)
    b = mm.Builder("SignBoard", coll, seed=2)
    b.cyl(3.0, 0.5, loc=center, rot=(90, 0, 0), color=WOOD, segs=32)
    b.build(material="Wood", smooth_angle=40, uv_tile=4)
    b = mm.Builder("SignRim", coll)
    b.torus(3.0, 0.22, loc=center, rot=(90, 0, 0), color=BRASS, segs=36, sides=8)
    for a in range(0, 360, 45):
        ca, sa = math.cos(math.radians(a)), math.sin(math.radians(a))
        b.sphere(0.16, loc=(center[0] + 2.62 * ca, center[1] - 0.27, center[2] + 2.62 * sa), color=BRASS, segs=8, rings=5)
    b.build(material="Metal", smooth_angle=40)

    depth = 1.2  # pokes out of both faces of the board
    bar = mm.rounded_rect(3.6, 0.95, 0.4)
    shapes = {
        "SymbolPlus": [(bar, 0), (bar, 90)],
        "SymbolMinus": [(bar, 0)],
        "SymbolTimes": [(bar, 45), (bar, -45)],
        "SymbolDivide": [(mm.rounded_rect(3.6, 0.8, 0.35), 0)],
    }
    for name, parts in shapes.items():
        b = mm.Builder(name, coll)
        for poly, angle in parts:
            b.extrude(poly, depth, loc=center, rot=(90, angle, 0), color=WHITE)
        if name == "SymbolDivide":
            for dz in (-1.15, 1.15):
                b.cyl(0.55, depth, loc=(center[0], center[1], center[2] + dz), rot=(90, 0, 0), color=WHITE, segs=20)
        b.build(material="SmoothPlastic", tint=True, smooth_angle=50, group="Symbols")


def plate(coll):
    z = PLATE_TOP_Z
    b = mm.Builder("Platter", coll)
    b.lathe([(0, z - 0.9), (1.2, z - 0.9), (3.8, z - 0.35), (4.6, z - 0.1), (4.85, z + 0.35), (4.65, z + 0.5),
             (4.4, z + 0.18), (0, z)], color=WHITE, segs=40)
    b.build(material="Metal", tint=True, smooth_angle=50, uv_tile=3, group="Plate")

    b = mm.Builder("PlateHanger", coll)
    top = z + 5.0
    for i in range(4):
        a = math.radians(45 + 90 * i)
        c, s = math.cos(a), math.sin(a)
        b.rod((4.25 * c, 4.25 * s, z + 0.3), (0.5 * c, 0.5 * s, top), 0.1, color=IRON, segs=6)
        b.sphere(0.22, loc=(4.25 * c, 4.25 * s, z + 0.32), color=BRASS, segs=8, rings=5)
    b.torus(0.55, 0.16, loc=(0, 0, top), color=IRON, segs=16, sides=8)
    b.torus(0.42, 0.15, loc=(0, 0, top + 0.85), rot=(90, 0, 0), color=IRON, segs=14, sides=8, stretch=0.35)
    b.build(material="Metal", smooth_angle=50, group="Plate")


def engine(coll):
    ey = 12.1  # engine center (y)
    front = ey - 2.5  # front face (-Y side) of the body
    b = mm.Builder("EnginePlinth", coll, seed=12)
    b.box((8.6, 6.4, ENGINE_LIFT), loc=(0, ey, ENGINE_LIFT / 2), color=(150, 146, 140), bevel=0.35, bevel_segments=2, jitter=0.06)
    b.box((7.8, 5.6, 0.3), loc=(0, ey, ENGINE_LIFT + 0.05), color=(120, 116, 112), bevel=0.1)
    b.build(material="Cobblestone", smooth_angle=30, uv_tile=5, collision="Box", can_collide=True)

    b = mm.Builder("EngineBody", coll, offset=LIFT)
    b.box((7.0, 5.0, 5.4), loc=(0, ey, 3.6), color=WHITE, bevel=0.45, bevel_segments=3)
    b.box((5.6, 4.0, 0.7), loc=(0, ey, 6.55), color=WHITE, bevel=0.25)
    b.build(material="Metal", tint=True, smooth_angle=35, uv_tile=4, collision="Box", can_collide=True)

    b = mm.Builder("EngineTrim", coll, seed=4, offset=LIFT)
    # gauge "eyes" rims
    for x in (-1.6, 1.6):
        b.cyl(1.1, 0.45, loc=(x, front - 0.12, 4.85), rot=(90, 0, 0), color=BRASS, segs=24)
    # grille "mouth"
    b.extrude(mm.rounded_rect(3.6, 1.7, 0.6), 0.3, loc=(0, front - 0.08, 2.35), rot=(90, 0, 0), color=IRON)
    for dz in (-0.45, 0.0, 0.45):
        b.box((3.0, 0.2, 0.18), loc=(0, front - 0.26, 2.35 + dz), color=IRON_LIGHT)
    # feet
    for x in (-2.9, 2.9):
        for y in (ey - 1.8, ey + 1.8):
            b.box((1.3, 1.3, 0.9), loc=(x, y, 0.45), color=IRON, bevel=0.12)
    # drum brackets + axle
    for x in (-2.55, 2.55):
        b.box((0.4, 1.6, 2.6), loc=(x, DRUM_LOCAL[1], 7.3), color=IRON, bevel=0.08)
    b.rod((-2.9, DRUM_LOCAL[1], DRUM_LOCAL[2]), (2.9, DRUM_LOCAL[1], DRUM_LOCAL[2]), 0.2, color=BRASS, segs=8)
    # copper pipes
    b.tube(mm.smooth_path([(-3.5, ey + 1.2, 2.0), (-4.3, ey + 1.0, 3.5), (-4.0, ey - 0.6, 5.6), (-2.2, ey - 1.0, 6.9)], 3),
           0.25, color=COPPER, sides=8)
    b.tube(mm.smooth_path([(3.5, ey - 1.6, 1.3), (4.1, ey - 1.9, 2.4), (4.0, ey - 2.2, 5.6), (3.0, ey - 1.8, 6.95)], 3),
           0.22, color=COPPER, sides=8)
    # valve wheel on the left side
    b.torus(0.75, 0.11, loc=(-3.75, ey + 0.6, 3.4), rot=(0, 90, 0), color=RED, segs=16, sides=6)
    for a in (0, 60, 120):
        ca, sa = math.cos(math.radians(a)), math.sin(math.radians(a))
        b.beam((-3.75, ey + 0.6 - 0.75 * ca, 3.4 - 0.75 * sa), (-3.75, ey + 0.6 + 0.75 * ca, 3.4 + 0.75 * sa), 0.1, color=RED)
    b.rod((-3.5, ey + 0.6, 3.4), (-3.85, ey + 0.6, 3.4), 0.18, color=IRON, segs=8)
    # gear axles
    b.rod((3.45, ey, 3.8), (4.15, ey, 3.8), 0.3, color=IRON, segs=10)
    b.rod((3.45, ey + 1.9, 5.9), (4.15, ey + 1.9, 5.9), 0.2, color=IRON, segs=8)
    # rivets around the body
    for x in (-3.1, 3.1):
        for z in (1.4, 5.9):
            b.sphere(0.17, loc=(x, front - 0.02, z), color=BRASS, segs=8, rings=5)
    b.build(material="Metal", smooth_angle=40, uv_tile=3, collision="Box")

    b = mm.Builder("GaugeFaces", coll, offset=LIFT)
    for x in (-1.6, 1.6):
        b.cyl(0.88, 0.1, loc=(x, front - 0.38, 4.85), rot=(90, 0, 0), color=WHITE, segs=24)
        for a in range(-60, 241, 30):
            ca, sa = math.cos(math.radians(a)), math.sin(math.radians(a))
            b.box((0.06, 0.04, 0.2), loc=(x + 0.68 * ca, front - 0.44, 4.85 + 0.68 * sa), rot=(0, -a + 90, 0), color=BLACK)
    b.build(material="SmoothPlastic", smooth_angle=30)

    for name, x in (("NeedleL", -1.6), ("NeedleR", 1.6)):
        b = mm.Builder(name, coll, offset=LIFT)
        b.box((0.12, 0.05, 0.7), loc=(x, front - 0.47, 4.85 + 0.3), color=RED)
        b.cyl(0.14, 0.08, loc=(x, front - 0.48, 4.85), rot=(90, 0, 0), color=BLACK, segs=10)
        b.build(material="SmoothPlastic", smooth_angle=30)

    b = mm.Builder("Drum", coll, offset=LIFT)
    b.cyl(1.0, 4.2, loc=DRUM_LOCAL, rot=(0, 90, 0), color=IRON_LIGHT, segs=20)
    for sx in (-2.1, 2.1):
        b.cyl(1.55, 0.2, loc=(sx, DRUM_LOCAL[1], DRUM_LOCAL[2]), rot=(0, 90, 0), color=BRASS, segs=20)
    for k in range(5):
        b.torus(1.05, 0.09, loc=(-1.6 + 0.8 * k, DRUM_LOCAL[1], DRUM_LOCAL[2]), rot=(0, 90, 0), color=IRON, segs=20, sides=6)
    b.build(material="Metal", smooth_angle=40)

    b = mm.Builder("Gear", coll, offset=LIFT)
    b.extrude(mm.gear_poly(1.7, 2.15, 14), 0.4, loc=(3.75, ey, 3.8), rot=(0, 90, 0), color=BRASS)
    b.cyl(0.6, 0.6, loc=(3.75, ey, 3.8), rot=(0, 90, 0), color=BRASS, segs=12)
    b.build(material="Metal", smooth_angle=30)

    b = mm.Builder("GearSmall", coll, offset=LIFT)
    b.extrude(mm.gear_poly(0.75, 1.05, 8), 0.4, loc=(3.75, ey + 1.9, 5.9), rot=(0, 90, 0), color=COPPER)
    b.build(material="Metal", smooth_angle=30)

    b = mm.Builder("EngineStack", coll, offset=LIFT)
    sx, sy = 2.2, ey + 1.2
    b.lathe([(0.6, 6.8), (0.55, 10.4), (0.95, 11.3), (1.05, 11.6), (0.85, 11.7), (0.5, 11.2)], loc=(sx, sy, 0),
            color=IRON, segs=16, cap_bottom=True, cap_top=True)
    b.torus(0.62, 0.1, loc=(sx, sy, 8.6), color=BRASS, segs=16, sides=6)
    b.build(material="Metal", smooth_angle=40)


def console(coll):
    cy = -11.5
    b = mm.Builder("ConsoleDesk", coll, seed=8)
    b.box((6.6, 3.8, 0.4), loc=(0, cy, 3.3), color=WOOD, bevel=0.1)
    b.box((5.8, 3.3, 3.1), loc=(0, cy + 0.15, 1.55), color=WOOD_DARK, bevel=0.15)
    b.box((2.4, 0.1, 0.3), loc=(0, cy - 1.52, 2.3), color=BRASS)
    b.build(material="Wood", smooth_angle=30, uv_tile=4, collision="Box", can_collide=True)

    # a big chunky retro computer so kids can read its screen from a distance
    b = mm.Builder("ConsoleMonitor", coll)
    mz = 6.0
    my = cy + 0.5
    b.box((5.6, 2.2, 4.4), loc=(0, my, mz), color=CREAM, bevel=0.35, bevel_segments=3)
    b.box((4.0, 1.8, 3.2), loc=(0, my + 1.7, mz - 0.1), color=CREAM, bevel=0.35)
    b.box((4.9, 0.12, 3.8), loc=(0, my - 1.12, mz), color=BEZEL, bevel=0.08)
    b.box((1.6, 1.0, 0.3), loc=(0, my + 0.2, 3.65), color=CREAM)
    for k in range(4):
        b.box((0.08, 1.4, 0.18), loc=(2.81, my + 0.3, mz - 1.0 + k * 0.45), color=BEZEL)
    # keyboard + keys
    b.box((4.2, 1.15, 0.25), loc=(0, cy - 1.3, 3.62), rot=(-8, 0, 0), color=CREAM, bevel=0.06)
    for row in range(3):
        for col in range(9):
            b.box((0.34, 0.26, 0.12), loc=(-1.68 + col * 0.42, cy - 1.62 + row * 0.31, 3.77 + row * 0.043), rot=(-8, 0, 0), color=KEY)
    # big red button
    b.cyl(0.46, 0.25, loc=(2.75, cy - 1.15, 3.62), color=BEZEL, segs=16)
    b.lathe([(0.38, 3.72), (0.4, 3.92), (0.22, 4.06), (0, 4.08)], loc=(2.75, cy - 1.15, 0), color=RED, segs=16)
    # silly antenna
    b.rod((1.2, my + 0.4, mz + 2.15), (2.0, my + 0.7, mz + 4.2), 0.06, color=BEZEL, segs=6)
    b.sphere(0.24, loc=(2.0, my + 0.7, mz + 4.26), color=RED, segs=10, rings=6)
    b.build(material="SmoothPlastic", smooth_angle=35, collision="Box", can_collide=True)

    b = mm.Builder("ConsoleCable", coll)
    path = mm.smooth_path([(1.4, cy + 1.9, 0.6), (3.2, cy + 2.4, 0.25), (8.6, -6.0, 0.25), (9.9, 0.0, 0.25),
                           (8.8, 6.2, 0.25), (5.6, 9.8, 0.3), (4.8, 10.6, 1.6), (4.6, 10.9, 3.0), (3.6, 11.2, 3.8)], 5)
    b.tube(path, 0.24, color=RUBBER, sides=8)
    b.build(material="SmoothPlastic", smooth_angle=60)

    # quirky warning sign stuck in the ground beside the vat
    b = mm.Builder("AcidSign", coll, seed=21)
    sx, sy = -8.0, -8.6
    b.beam((sx, sy, 0.0), (sx + 0.15, sy, 5.2), 0.35, color=WOOD_DARK, jitter=0.02)
    b.box((3.6, 0.25, 1.9), loc=(sx + 0.15, sy - 0.25, 4.6), rot=(0, -6, 0), color=(232, 196, 64), bevel=0.06, jitter=0.03)
    b.build(material="Wood", smooth_angle=30, uv_tile=3)


def build():
    coll = mm.prefab_collection("Apparatus", offset=(0, 0, 0))
    vat(coll)
    derrick(coll)
    sign(coll)
    plate(coll)
    engine(coll)
    console(coll)
    mm.marker(coll, "PulleyA", loc=PULLEY_A)
    mm.marker(coll, "PulleyB", loc=PULLEY_B)
    mm.marker(coll, "Drum", loc=DRUM)
    mm.marker(coll, "ChainTop", loc=(0, 0, PULLEY_A[2]))
    mm.marker(coll, "ChainDrum", loc=(0, DRUM[1] - 1.0, DRUM[2]))
    mm.marker(coll, "PlateTop", loc=(0, 0, PLATE_TOP_Z))
    mm.marker(coll, "Hook", loc=(0, 0, HOOK_Z))
    mm.marker(coll, "AcidTop", loc=(0, 0, ACID_Z))
    mm.marker(coll, "Screen", loc=(0, -11.5 + 0.5 - 1.2, 6.0))
    mm.marker(coll, "AcidSignFace", loc=(-8.0 + 0.15, -8.6 - 0.39, 4.6), rot=(0, -6, 0))
    mm.marker(coll, "Smoke", loc=(2.2, 13.3, 11.9 + ENGINE_LIFT))
    mm.marker(coll, "GaugeL", loc=(-1.6, 12.1 - 2.5 - 0.47, 4.85 + ENGINE_LIFT))
    mm.marker(coll, "GaugeR", loc=(1.6, 12.1 - 2.5 - 0.47, 4.85 + ENGINE_LIFT))
    mm.marker(coll, "Gear", loc=(3.75, 12.1, 3.8 + ENGINE_LIFT))
    mm.marker(coll, "GearSmall", loc=(3.75, 12.1 + 1.9, 5.9 + ENGINE_LIFT))
    mm.marker(coll, "Prompt", loc=(0, -13.8, 4.0))
    mm.marker(coll, "PlayerStand", loc=(0, -15.5, 0))
    mm.marker(coll, "CameraEye", loc=(-11.0, -33.0, 17.0))
    mm.marker(coll, "CameraFocus", loc=(0, 2.0, 13.5))
    return mm.export_prefab("Apparatus")


def build_chain_link():
    coll = mm.prefab_collection("ChainLink", offset=(30, 0, 0))
    b = mm.Builder("Link", coll)
    # stadium link lying along Z (its pitch direction), 2.26 long
    b.torus(0.5, 0.18, rot=(90, 0, 0), color=(82, 86, 96), segs=16, sides=8, stretch=0.9)
    b.build(material="Metal", smooth_angle=60, cast_shadow=True)
    return mm.export_prefab("ChainLink")
