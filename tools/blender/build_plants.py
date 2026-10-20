"""Garden plants (grown from seeds) and garden decor.

Every prefab is modelled full-grown with its origin at ground level in the
middle; GardenService scales it up from a sprout as it grows. Front is -Y.
Small plants are cheerful SmoothPlastic with vertex colours; trees use Wood
trunks and leafy "Grass"-material canopies so they read as natural.
"""

import math

import mm_lib as mm

LEAF = (96, 178, 72)
LEAF_DARK = (64, 138, 56)
STEM = (90, 164, 66)
TRUNK = (124, 88, 58)
TRUNK_DARK = (92, 64, 42)
WHITE = (250, 250, 244)
YELLOW = (255, 212, 60)
ORANGE = (250, 150, 40)
PINK = (255, 150, 196)
RED = (230, 58, 70)
BLACK = (30, 30, 34)
CREAM = (246, 232, 200)
BROWN = (120, 76, 44)


def _flower_head(b, centre, petal_color, petals=8, r=0.42, petal_len=0.55, face=(0, 0, 0)):
    cx, cy, cz = centre
    b.sphere(r * 0.62, loc=centre, rot=face, color=YELLOW, segs=12, rings=6, scale=(1, 1, 0.55))
    for i in range(petals):
        a = 360.0 * i / petals
        rad = math.radians(a)
        px = cx + math.cos(rad) * (r * 0.55 + petal_len * 0.5)
        py = cy + math.sin(rad) * (r * 0.55 + petal_len * 0.5)
        b.sphere(petal_len * 0.5, loc=(px, py, cz), rot=(0, 0, a), color=petal_color, segs=8, rings=5,
                 scale=(1.0, 0.42, 0.22))


def daisy(x):
    coll = mm.prefab_collection("Daisy", offset=(x, 60, 0))
    b = mm.Builder("Flowers", coll, seed=31)
    heads = [(-0.5, 0.1, 2.3), (0.55, -0.2, 2.9), (0.05, 0.6, 2.0)]
    for hx, hy, hz in heads:
        b.tube(mm.smooth_path([(hx * 0.3, hy * 0.3, 0), (hx * 0.8, hy * 0.8, hz * 0.5), (hx, hy, hz - 0.1)], 3), 0.07,
               color=STEM, sides=6)
        _flower_head(b, (hx, hy, hz), WHITE, petals=10, r=0.36, petal_len=0.5)
    for i in range(5):
        a = math.radians(72 * i + 10)
        b.sphere(0.45, loc=(math.cos(a) * 0.45, math.sin(a) * 0.45, 0.18), rot=(0, 0, 72 * i + 10), color=LEAF,
                 segs=8, rings=5, scale=(1.4, 0.55, 0.25))
    b.build(material="SmoothPlastic", smooth_angle=50)
    return mm.export_prefab("Daisy")


def tulip(x):
    coll = mm.prefab_collection("Tulip", offset=(x, 60, 0))
    b = mm.Builder("Flowers", coll, seed=32)
    tulips = [(-0.5, 0.0, 2.6, RED), (0.45, -0.25, 3.1, PINK), (0.1, 0.55, 2.3, YELLOW)]
    for tx, ty, tz, col in tulips:
        b.tube([(tx * 0.4, ty * 0.4, 0), (tx * 0.8, ty * 0.8, tz * 0.5), (tx, ty, tz - 0.3)], 0.07, color=STEM, sides=6)
        b.lathe([(0, tz - 0.42), (0.22, tz - 0.38), (0.34, tz - 0.12), (0.36, tz + 0.15), (0.28, tz + 0.34),
                 (0.2, tz + 0.3), (0.12, tz + 0.12), (0, tz + 0.1)], loc=(tx, ty, 0), color=col, segs=10)
        for side in (-1, 1):
            b.sphere(0.6, loc=(tx + side * 0.18, ty, 0.75), rot=(0, side * 12, 90), color=LEAF, segs=8, rings=5,
                     scale=(0.3, 0.12, 1.4))
    b.build(material="SmoothPlastic", smooth_angle=45)
    return mm.export_prefab("Tulip")


def sunflower(x):
    coll = mm.prefab_collection("Sunflower", offset=(x, 60, 0))
    b = mm.Builder("Flower", coll, seed=33)
    top = 7.4
    b.tube(mm.smooth_path([(0, 0, 0), (0.15, 0.1, 2.5), (-0.1, 0.0, 5.0), (0, 0.15, top - 0.4)], 4), 0.18,
           color=STEM, sides=8)
    for side, z in ((-1, 2.6), (1, 4.2)):
        b.sphere(0.9, loc=(side * 0.8, 0, z), rot=(0, side * -25, 0), color=LEAF, segs=10, rings=6, scale=(1.3, 0.25, 0.7))
    # the face looks forwards (-Y) and a little up
    centre = (0.0, -0.25, top)
    tilt = math.radians(20)
    n = (0.0, -math.cos(tilt), math.sin(tilt))  # face normal
    up = (0.0, math.sin(tilt), math.cos(tilt))  # "up" across the face

    def on_face(u, v, h):
        return (centre[0] + u, centre[1] + v * up[1] + h * n[1], centre[2] + v * up[2] + h * n[2])

    b.cyl(1.05, 0.35, loc=centre, rot=(70, 0, 0), color=BROWN, segs=24)
    for i in range(18):
        a = math.radians(20 * i)
        p0 = on_face(0.95 * math.cos(a), 0.95 * math.sin(a), 0.0)
        p1 = on_face(2.05 * math.cos(a), 2.05 * math.sin(a), -0.12)
        b.rod(p0, p1, 0.32, color=YELLOW, segs=6, r_end=0.05)
    for ex in (-0.35, 0.35):
        b.sphere(0.14, loc=on_face(ex, 0.3, 0.2), color=BLACK, segs=8, rings=5)
    smile = [on_face(0.45 * math.cos(math.radians(a)), 0.45 * math.sin(math.radians(a)) + 0.05, 0.2)
             for a in range(200, 341, 20)]
    b.tube(smile, 0.06, color=BLACK, sides=5)
    b.build(material="SmoothPlastic", smooth_angle=45)
    return mm.export_prefab("Sunflower")


def mushroom(x):
    coll = mm.prefab_collection("Mushroom", offset=(x, 60, 0))
    b = mm.Builder("Toadstools", coll, seed=34)
    rng = b.rng
    for (mx, my, h, r) in ((0.0, 0.0, 3.2, 2.1), (1.9, -0.9, 1.7, 1.15), (-1.6, 0.8, 1.2, 0.8)):
        b.lathe([(0, 0), (r * 0.36, 0), (r * 0.3, h * 0.5), (r * 0.26, h), (0, h)], loc=(mx, my, 0), color=CREAM, segs=14)
        b.lathe([(r * 0.28, h - 0.15), (r * 1.0, h + 0.05), (r * 0.95, h + r * 0.35), (r * 0.65, h + r * 0.7),
                 (0, h + r * 0.82)], loc=(mx, my, 0), color=RED, segs=20, cap_bottom=True)
        for _ in range(int(5 + r * 3)):
            a = rng.uniform(0, 2 * math.pi)
            t = rng.uniform(0.25, 0.85)
            rr = r * (1.0 - t * 0.55)
            zz = h + 0.05 + r * 0.8 * math.sin(t * math.pi / 2) * 0.95
            b.sphere(r * 0.13, loc=(mx + rr * math.cos(a), my + rr * math.sin(a), zz), color=WHITE, segs=8, rings=4,
                     scale=(1, 1, 0.45))
    b.build(material="SmoothPlastic", smooth_angle=45)
    return mm.export_prefab("Mushroom")


def berry_bush(x):
    coll = mm.prefab_collection("BerryBush", offset=(x, 60, 0))
    b = mm.Builder("Leaves", coll, seed=35)
    blobs = [(0, 0, 1.5, 1.6), (1.2, 0.3, 1.2, 1.2), (-1.1, -0.2, 1.3, 1.25), (0.2, 1.0, 1.3, 1.15), (0.0, -0.9, 1.6, 1.1),
             (0.3, 0.1, 2.5, 1.0)]
    for bx, by, bz, r in blobs:
        b.ico(r, loc=(bx, by, bz), color=LEAF_DARK, subdiv=2, jitter=0.08)
    b.build(material="Grass", smooth_angle=60, uv_tile=3)
    b = mm.Builder("Berries", coll, seed=36)
    rng = b.rng
    for bx, by, bz, r in blobs:
        for _ in range(5):
            th = rng.uniform(0, 2 * math.pi)
            ph = rng.uniform(-0.2, 1.2)
            p = (bx + math.cos(th) * math.cos(ph) * r, by + math.sin(th) * math.cos(ph) * r, bz + math.sin(ph) * r)
            b.sphere(0.17, loc=p, color=(214, 40, 70) if rng.random() < 0.6 else (90, 80, 220), segs=8, rings=5)
    b.build(material="SmoothPlastic", smooth_angle=60)
    return mm.export_prefab("BerryBush")


def cactus(x):
    coll = mm.prefab_collection("Cactus", offset=(x, 60, 0))
    b = mm.Builder("Cactus", coll, seed=37)
    green = (72, 160, 88)
    b.lathe([(0, 0), (0.75, 0), (0.8, 2.0), (0.78, 5.2), (0.6, 5.9), (0.3, 6.2), (0, 6.25)], color=green, segs=12)
    for side, z0, h in ((1, 2.2, 2.0), (-1, 3.0, 1.6)):
        pts = [(0, 0, z0), (side * 1.3, 0, z0), (side * 1.6, 0, z0 + 0.4), (side * 1.6, 0, z0 + h)]
        b.tube(mm.smooth_path(pts, 4), 0.42, color=green, sides=10)
        b.sphere(0.42, loc=(side * 1.6, 0, z0 + h), color=green, segs=10, rings=6)
    # flower crown
    for i in range(6):
        a = math.radians(60 * i)
        b.sphere(0.32, loc=(0.32 * math.cos(a), 0.32 * math.sin(a), 6.32), rot=(0, 0, 60 * i), color=(255, 110, 170),
                 segs=8, rings=5, scale=(1.3, 0.7, 0.45))
    b.sphere(0.22, loc=(0, 0, 6.4), color=YELLOW, segs=8, rings=5)
    b.build(material="SmoothPlastic", smooth_angle=50)
    return mm.export_prefab("Cactus")


def pine_tree(x):
    coll = mm.prefab_collection("PineTree", offset=(x, 60, 0))
    b = mm.Builder("Trunk", coll, seed=38)
    b.cyl(0.7, 5.0, loc=(0, 0, 2.5), r_top=0.45, color=TRUNK, segs=10, jitter=0.03)
    b.build(material="Wood", smooth_angle=50, uv_tile=3, collision="Box")
    b = mm.Builder("Needles", coll, seed=39)
    tiers = [(3.0, 4.6, 5.5), (6.2, 3.8, 4.8), (9.0, 3.0, 4.2), (11.6, 2.2, 3.6), (13.8, 1.4, 3.0)]
    for z, r, h in tiers:
        b.cyl(r, h, loc=(0, 0, z + h / 2), r_top=0.05, color=(52, 120, 64), segs=12, jitter=0.12)
    b.build(material="Grass", smooth_angle=40, uv_tile=4)
    return mm.export_prefab("PineTree")


def _canopy(b, centre, radius, color, n, spread, rng, subdiv=2, jitter=0.18):
    cx, cy, cz = centre
    b.ico(radius, loc=centre, color=color, subdiv=subdiv, jitter=jitter)
    for i in range(n):
        a = 2 * math.pi * i / n + rng.uniform(-0.3, 0.3)
        r = radius * rng.uniform(0.62, 0.85)
        d = radius * spread
        b.ico(r, loc=(cx + math.cos(a) * d, cy + math.sin(a) * d, cz + rng.uniform(-0.6, 0.9) * radius * 0.35),
              color=color, subdiv=subdiv, jitter=jitter)


def _trunk(b, height, base_r, branches, rng, color):
    b.cyl(base_r, height, loc=(0, 0, height / 2), r_top=base_r * 0.65, color=color, segs=10, jitter=0.04)
    for a_deg, z, length in branches:
        a = math.radians(a_deg)
        p0 = (0, 0, z)
        p1 = (math.cos(a) * length * 0.6, math.sin(a) * length * 0.6, z + length * 0.55)
        p2 = (math.cos(a) * length, math.sin(a) * length, z + length * 0.9)
        b.tube([p0, p1, p2], base_r * 0.35, color=color, sides=7, radii=[base_r * 0.42, base_r * 0.3, base_r * 0.16])
    # roots
    for i in range(4):
        a = math.radians(45 + 90 * i)
        b.tube([(0, 0, 0.9), (math.cos(a) * base_r * 1.5, math.sin(a) * base_r * 1.5, 0.05)], base_r * 0.3,
               color=color, sides=6, radii=[base_r * 0.35, base_r * 0.12])


def oak_tree(x):
    coll = mm.prefab_collection("OakTree", offset=(x, 60, 0))
    b = mm.Builder("Trunk", coll, seed=40)
    _trunk(b, 9.0, 1.2, [(20, 6.5, 4.5), (150, 7.0, 4.0), (260, 7.5, 3.6)], b.rng, TRUNK)
    b.build(material="Wood", smooth_angle=50, uv_tile=3, collision="Box")
    b = mm.Builder("Leaves", coll, seed=41)
    _canopy(b, (0, 0, 13.0), 5.2, (86, 166, 64), 7, 0.95, b.rng)
    b.build(material="Grass", smooth_angle=60, uv_tile=5)
    return mm.export_prefab("OakTree")


def cherry_tree(x):
    coll = mm.prefab_collection("CherryTree", offset=(x, 60, 0))
    b = mm.Builder("Trunk", coll, seed=42)
    _trunk(b, 7.5, 0.95, [(0, 5.0, 4.2), (120, 5.5, 4.0), (230, 6.0, 3.8)], b.rng, (84, 58, 48))
    b.build(material="Wood", smooth_angle=50, uv_tile=3, collision="Box")
    b = mm.Builder("Blossoms", coll, seed=43)
    rng = b.rng
    cx, cz = 0, 11.0
    for i in range(9):
        a = 2 * math.pi * i / 9
        d = 3.6 if i % 2 == 0 else 2.2
        col = (255, 178, 206) if i % 3 else (255, 214, 228)
        b.ico(rng.uniform(2.3, 3.1), loc=(math.cos(a) * d, math.sin(a) * d, cz + rng.uniform(-1.0, 1.4)), color=col,
              subdiv=2, jitter=0.2)
    b.ico(3.2, loc=(0, 0, cz + 1.6), color=(255, 190, 214), subdiv=2, jitter=0.2)
    b.build(material="SmoothPlastic", smooth_angle=60)
    return mm.export_prefab("CherryTree")


def rainbow_tree(x):
    coll = mm.prefab_collection("RainbowTree", offset=(x, 60, 0))
    b = mm.Builder("Trunk", coll, seed=44)
    _trunk(b, 9.0, 1.1, [(40, 6.5, 4.4), (170, 7.0, 4.2), (290, 7.2, 4.0)], b.rng, (236, 228, 214))
    b.build(material="Wood", smooth_angle=50, uv_tile=3, collision="Box")
    b = mm.Builder("Leaves", coll, seed=45)
    rainbow = [(255, 84, 84), (255, 160, 60), (255, 224, 70), (110, 214, 90), (80, 170, 255), (170, 110, 255)]
    rng = b.rng
    for i, col in enumerate(rainbow):
        a = 2 * math.pi * i / len(rainbow)
        b.ico(rng.uniform(2.6, 3.2), loc=(math.cos(a) * 3.6, math.sin(a) * 3.6, 12.2 + rng.uniform(-0.8, 0.8)),
              color=col, subdiv=2, jitter=0.15)
    b.ico(3.4, loc=(0, 0, 14.4), color=(255, 255, 255), subdiv=2, jitter=0.15)
    b.build(material="SmoothPlastic", smooth_angle=60)
    b = mm.Builder("Sparkles", coll, seed=46)
    for _ in range(14):
        a = rng.uniform(0, 2 * math.pi)
        d = rng.uniform(2.0, 6.5)
        b.ico(0.22, loc=(math.cos(a) * d, math.sin(a) * d, rng.uniform(9.5, 17.0)), color=(255, 250, 200), subdiv=1)
    b.build(material="Neon", smooth_angle=0, cast_shadow=False)
    return mm.export_prefab("RainbowTree")


# ---------------------------------------------------------------- decor


def rubber_duck(x):
    coll = mm.prefab_collection("RubberDuck", offset=(x, 75, 0))
    b = mm.Builder("Duck", coll, seed=50)
    yellow = (255, 214, 50)
    b.sphere(1.6, loc=(0, 0.2, 1.4), color=yellow, segs=20, rings=12, scale=(1.0, 1.25, 0.82))
    b.sphere(0.7, loc=(0, 1.75, 1.95), rot=(30, 0, 0), color=yellow, segs=12, rings=6, scale=(0.6, 0.6, 1.0))  # tail
    b.sphere(1.0, loc=(0, -1.1, 3.0), color=yellow, segs=18, rings=10)
    b.sphere(0.55, loc=(0, -2.05, 2.85), color=ORANGE, segs=12, rings=6, scale=(1.0, 1.0, 0.45))
    for ex in (-0.4, 0.4):
        b.sphere(0.2, loc=(ex, -1.8, 3.35), color=BLACK, segs=8, rings=5)
        b.sphere(0.07, loc=(ex - 0.05, -1.97, 3.42), color=WHITE, segs=6, rings=4)
    for side in (-1, 1):
        b.sphere(0.7, loc=(side * 1.45, 0.3, 1.6), rot=(0, side * 20, 0), color=yellow, segs=10, rings=6, scale=(0.3, 1.0, 0.6))
    b.build(material="SmoothPlastic", smooth_angle=50, collision="Box")
    return mm.export_prefab("RubberDuck")


def flamingo(x):
    coll = mm.prefab_collection("Flamingo", offset=(x, 75, 0))
    b = mm.Builder("Flamingo", coll, seed=51)
    pink = (255, 120, 170)
    leg = (232, 110, 140)
    b.sphere(1.0, loc=(0, 0.3, 3.2), rot=(-12, 0, 0), color=pink, segs=16, rings=10, scale=(0.75, 1.3, 0.75))
    b.tube(mm.smooth_path([(0, -0.6, 3.6), (0, -0.9, 4.4), (0, -0.4, 5.0), (0, -0.7, 5.6), (0, -1.1, 6.0)], 4), 0.18,
           color=pink, sides=8)
    b.sphere(0.36, loc=(0, -1.15, 6.15), color=pink, segs=12, rings=8)
    b.cyl(0.14, 0.7, loc=(0, -1.55, 6.0), rot=(70, 0, 0), r_top=0.05, color=(250, 240, 230), segs=8)
    b.cyl(0.06, 0.25, loc=(0, -1.85, 5.88), rot=(70, 0, 0), r_top=0.02, color=BLACK, segs=6)
    for ex in (-0.22, 0.22):
        b.sphere(0.07, loc=(ex, -1.35, 6.25), color=BLACK, segs=6, rings=4)
    b.tube([(0.15, 0.3, 2.4), (0.15, 0.3, 1.2), (0.15, 0.3, 0.05)], 0.07, color=leg, sides=6)
    b.tube([(-0.15, 0.3, 2.4), (-0.15, 0.4, 1.6), (-0.15, 0.95, 1.9)], 0.07, color=leg, sides=6)  # tucked leg
    b.sphere(0.25, loc=(0.15, 0.1, 0.05), color=leg, segs=8, rings=5, scale=(1, 1.6, 0.3))
    b.build(material="SmoothPlastic", smooth_angle=50, collision="Box")
    return mm.export_prefab("Flamingo")


def gnome(x):
    coll = mm.prefab_collection("Gnome", offset=(x, 75, 0))
    b = mm.Builder("Gnome", coll, seed=52)
    skin = (255, 206, 176)
    blue = (60, 110, 210)
    for side in (-1, 1):
        b.sphere(0.32, loc=(side * 0.3, -0.12, 0.2), color=BROWN, segs=10, rings=6, scale=(1, 1.4, 0.65))
    b.lathe([(0, 0.3), (0.62, 0.32), (0.66, 0.9), (0.55, 1.45), (0.3, 1.65), (0, 1.66)], color=blue, segs=16)
    b.torus(0.6, 0.08, loc=(0, 0, 0.92), color=BLACK, segs=16, sides=6)
    b.box((0.26, 0.08, 0.22), loc=(0, -0.66, 0.92), color=YELLOW)
    b.sphere(0.45, loc=(0, 0, 2.0), color=skin, segs=14, rings=8)
    b.lathe([(0, 1.3), (0.5, 1.55), (0.52, 1.85), (0.32, 2.0), (0, 2.02)], loc=(0, -0.2, 0), color=WHITE, segs=14,
            scale=(1, 0.75, 1))
    b.sphere(0.17, loc=(0, -0.48, 2.02), color=(255, 170, 160), segs=10, rings=6)
    for ex in (-0.16, 0.16):
        b.sphere(0.06, loc=(ex, -0.4, 2.2), color=BLACK, segs=6, rings=4)
    hat = []
    for k in range(8):
        t = k / 7
        hat.append((0.0, 0.25 * t * t, 2.3 + 1.6 * t))
    b.tube(hat, 0.5, color=RED, sides=12, radii=[0.52 * (1 - k / 8) + 0.04 for k in range(8)])
    for side in (-1, 1):
        b.tube([(side * 0.55, 0, 1.35), (side * 0.75, -0.25, 1.0), (side * 0.6, -0.45, 0.85)], 0.14, color=blue, sides=6)
        b.sphere(0.15, loc=(side * 0.6, -0.5, 0.82), color=skin, segs=8, rings=5)
    b.build(material="SmoothPlastic", smooth_angle=45, collision="Box")
    return mm.export_prefab("Gnome")


def golden_toilet(x):
    coll = mm.prefab_collection("GoldenToilet", offset=(x, 75, 0))
    b = mm.Builder("Toilet", coll, seed=53)
    gold = (255, 205, 70)
    b.lathe([(0, 0), (0.55, 0), (0.6, 0.4), (0.5, 0.9), (0.85, 1.4), (1.05, 1.8), (0.95, 1.9), (0.7, 1.75), (0.0, 1.5)],
            loc=(0, -0.3, 0), color=gold, segs=24, scale=(0.85, 1.15, 1))
    b.torus(0.78, 0.12, loc=(0, -0.3, 1.95), color=gold, segs=24, sides=8, scale=(0.85, 1.15, 1))
    b.box((1.9, 0.8, 1.6), loc=(0, 1.0, 2.5), color=gold, bevel=0.15, bevel_segments=2)
    b.box((2.0, 0.9, 0.2), loc=(0, 1.0, 3.35), color=gold, bevel=0.06)
    b.box((1.7, 0.12, 1.9), loc=(0, 0.62, 2.95), rot=(-12, 0, 0), color=gold, bevel=0.05)  # lid up
    b.rod((0.75, 0.55, 3.0), (0.4, 0.4, 3.0), 0.06, color=gold, segs=6)
    b.sphere(0.12, loc=(0.4, 0.4, 3.0), color=gold, segs=8, rings=5)
    b.build(material="Foil", smooth_angle=45, collision="Box")
    return mm.export_prefab("GoldenToilet")


PLANTS = ["Daisy", "Tulip", "Sunflower", "Mushroom", "BerryBush", "Cactus", "PineTree", "OakTree", "CherryTree", "RainbowTree"]
DECOR = ["RubberDuck", "Flamingo", "Gnome", "GoldenToilet"]


def build():
    out = []
    builders = [daisy, tulip, sunflower, mushroom, berry_bush, cactus, pine_tree, oak_tree, cherry_tree, rainbow_tree]
    for i, fn in enumerate(builders):
        out.append(fn(i * 16))
    for i, fn in enumerate([rubber_duck, flamingo, gnome, golden_toilet]):
        out.append(fn(i * 8))
    return out
