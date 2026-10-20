"""Loot that sits on the apparatus plate: coins, gems, gold bars, money bags...

Each item is its own prefab (one Model per item) centred on the origin so the
client can pile clones onto a plate. Gems are exported "tint" so the game can
recolour them (ruby, sapphire, emerald, amethyst, topaz).
"""

import math

import mm_lib as mm

GOLD = (255, 196, 46)
GOLD_DARK = (214, 150, 30)
WHITE = (246, 246, 250)
SACK = (196, 160, 104)
SACK_DARK = (150, 116, 70)
ROPE = (120, 84, 50)
RED = (220, 40, 60)
BLUE = (60, 110, 230)


def _brilliant(b, r, h_crown, h_pavilion, table_frac=0.55, segs=8, loc=(0, 0, 0), color=WHITE, scale=(1, 1, 1)):
    b.lathe([(0, -h_pavilion), (r, 0.0), (r * 0.82, h_crown * 0.55), (r * table_frac, h_crown), (0, h_crown)],
            loc=loc, color=color, segs=segs, scale=scale)


def coin(x):
    coll = mm.prefab_collection("Coin", offset=(x, -40, 0))
    b = mm.Builder("Coin", coll)
    b.lathe([(0, -0.1), (0.72, -0.1), (0.78, -0.04), (0.78, 0.04), (0.72, 0.1), (0.6, 0.1), (0.56, 0.06), (0, 0.06)],
            color=GOLD, segs=28)
    b.lathe([(0, 0.06), (0.32, 0.06), (0.28, 0.12), (0, 0.12)], color=GOLD, segs=20)
    b.build(material="Metal", smooth_angle=35, reflectance=0.05)
    return mm.export_prefab("Coin")


def gold_bar(x):
    coll = mm.prefab_collection("GoldBar", offset=(x, -40, 0))
    b = mm.Builder("GoldBar", coll)
    # trapezoid ingot: wide bottom, narrower top
    bw, bd, tw, td, h = 1.7, 0.85, 1.35, 0.55, 0.55
    verts = [(-bw / 2, -bd / 2, 0), (bw / 2, -bd / 2, 0), (bw / 2, bd / 2, 0), (-bw / 2, bd / 2, 0),
             (-tw / 2, -td / 2, h), (tw / 2, -td / 2, h), (tw / 2, td / 2, h), (-tw / 2, td / 2, h)]
    faces = [(0, 3, 2, 1), (4, 5, 6, 7), (0, 1, 5, 4), (1, 2, 6, 5), (2, 3, 7, 6), (3, 0, 4, 7)]
    b.raw(verts, faces, color=(255, 200, 70), loc=(0, 0, -h / 2))
    b.build(material="Foil", smooth_angle=20)
    return mm.export_prefab("GoldBar")


def gems(x):
    out = []
    coll = mm.prefab_collection("GemRound", offset=(x, -40, 0))
    b = mm.Builder("GemRound", coll)
    _brilliant(b, 0.62, 0.38, 0.62, loc=(0, 0, 0.12))
    b.build(material="Glass", tint=True, smooth_angle=0, reflectance=0.15)
    out.append(mm.export_prefab("GemRound"))

    coll = mm.prefab_collection("GemSquare", offset=(x + 3, -40, 0))
    b = mm.Builder("GemSquare", coll)
    b.lathe([(0, -0.45), (0.72, -0.05), (0.72, 0.1), (0.5, 0.3), (0, 0.3)], color=WHITE, segs=4, rot=(0, 0, 45),
            scale=(1.25, 0.85, 1))
    b.build(material="Glass", tint=True, smooth_angle=0, reflectance=0.15)
    out.append(mm.export_prefab("GemSquare"))

    coll = mm.prefab_collection("GemHeart", offset=(x + 6, -40, 0))
    b = mm.Builder("GemHeart", coll)
    heart = []
    for i in range(32):
        t = 2 * math.pi * i / 32
        hx = 16 * math.sin(t) ** 3
        hy = 13 * math.cos(t) - 5 * math.cos(2 * t) - 2 * math.cos(3 * t) - math.cos(4 * t)
        heart.append((hx * 0.042, hy * 0.042))
    heart.reverse()
    b.extrude(heart, 0.42, rot=(90, 0, 0), color=WHITE, bevel=0.06)
    b.build(material="Glass", tint=True, smooth_angle=0, reflectance=0.15)
    out.append(mm.export_prefab("GemHeart"))

    coll = mm.prefab_collection("Diamond", offset=(x + 9, -40, 0))
    b = mm.Builder("Diamond", coll)
    _brilliant(b, 0.95, 0.5, 0.95, table_frac=0.5, segs=10)
    b.build(material="Glass", tint=True, smooth_angle=0, reflectance=0.25)
    out.append(mm.export_prefab("Diamond"))
    return out


def pearl(x):
    coll = mm.prefab_collection("Pearl", offset=(x, -40, 0))
    b = mm.Builder("Pearl", coll)
    b.sphere(0.42, color=(250, 244, 236), segs=16, rings=10)
    b.build(material="SmoothPlastic", smooth_angle=80, reflectance=0.25)
    return mm.export_prefab("Pearl")


def crown(x):
    coll = mm.prefab_collection("MiniCrown", offset=(x, -40, 0))
    b = mm.Builder("MiniCrown", coll)
    b.lathe([(0.62, 0.0), (0.7, 0.0), (0.7, 0.45), (0.62, 0.45)], color=GOLD, segs=24, closed=True)
    for i in range(6):
        a = 2 * math.pi * i / 6
        c, s = math.cos(a), math.sin(a)
        b.cyl(0.18, 0.55, loc=(0.66 * c, 0.66 * s, 0.7), r_top=0.02, color=GOLD, segs=6)
        b.sphere(0.09, loc=(0.66 * c, 0.66 * s, 1.0), color=GOLD, segs=8, rings=5)
        b.sphere(0.1, loc=(0.71 * c, 0.71 * s, 0.22), color=RED if i % 2 == 0 else BLUE, segs=8, rings=5)
    b.build(material="Metal", smooth_angle=40, reflectance=0.05)
    return mm.export_prefab("MiniCrown")


def money_bag(x):
    coll = mm.prefab_collection("MoneyBag", offset=(x, -40, 0))
    b = mm.Builder("MoneyBag", coll, seed=6)
    b.lathe([(0, 0.0), (0.55, 0.03), (0.85, 0.3), (0.9, 0.62), (0.72, 0.98), (0.3, 1.2), (0.22, 1.3), (0, 1.3)],
            color=SACK, segs=18, jitter=0.02)
    b.torus(0.24, 0.07, loc=(0, 0, 1.3), color=ROPE, segs=12, sides=6)
    b.lathe([(0.2, 1.3), (0.38, 1.52), (0.3, 1.62), (0, 1.6)], color=SACK, segs=12, jitter=0.02)
    # a big "$" stitched on the front: an S made of two arcs plus a vertical bar,
    # each point pushed out onto the sack's curved surface
    profile = [(0.03, 0.55), (0.3, 0.85), (0.62, 0.9), (0.98, 0.72)]

    def surface_y(x, z):
        for (z0, r0), (z1, r1) in zip(profile, profile[1:]):
            if z0 <= z <= z1:
                r = r0 + (r1 - r0) * (z - z0) / (z1 - z0)
                return -math.sqrt(max(r * r - x * x, 0.01)) - 0.02
        return -0.75

    s_pts = []
    for k in range(10):  # upper bowl: right-top, over the top, down to the middle
        a = math.radians(30 + 240 * k / 9)
        s_pts.append((0.14 * math.cos(a), 0.77 + 0.13 * math.sin(a)))
    for k in range(1, 10):  # lower bowl: middle, round the right, to bottom-left
        a = math.radians(90 - 240 * k / 9)
        s_pts.append((0.14 * math.cos(a), 0.51 + 0.13 * math.sin(a)))
    b.tube([(x, surface_y(x, z), z) for x, z in s_pts], 0.045, color=SACK_DARK, sides=6)
    bar = [(0.0, z) for z in (0.3, 0.5, 0.7, 0.96)]
    b.tube([(x, surface_y(x, z) - 0.01, z) for x, z in bar], 0.035, color=SACK_DARK, sides=6)
    b.build(material="Fabric", smooth_angle=60, uv_tile=1.5)
    return mm.export_prefab("MoneyBag")


def build():
    return [coin(0), gold_bar(3), *gems(6), pearl(18), crown(21), money_bag(24)]
