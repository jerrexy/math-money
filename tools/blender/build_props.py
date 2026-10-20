"""World props: the shop stall + frog shopkeeper, plot fences / gate arch, lamps
and scenery (rocks, bushes). The world builder (tools/studio/build_world.luau)
places these from ServerStorage.WorldProps. Front is -Y, origin on the ground.
"""

import math

import mm_lib as mm

WOOD = (156, 108, 66)
WOOD_DARK = (112, 76, 46)
WOOD_LIGHT = (196, 150, 98)
RED = (226, 64, 72)
WHITE = (250, 248, 240)
BLACK = (30, 30, 36)
GREEN = (104, 196, 88)
GREEN_DARK = (70, 150, 66)
BELLY = (232, 236, 170)
GOLD = (255, 200, 60)


def shop_stall(x):
    """Market stall, 16 wide. The counter faces the front (-Y)."""
    coll = mm.prefab_collection("ShopStall", offset=(x, 140, 0))
    b = mm.Builder("Wood", coll, seed=80)
    for sx in (-7.6, 7.6):
        for sy in (-1.6, 3.6):
            b.box((0.8, 0.8, 11.5 if sy < 0 else 12.6), loc=(sx, sy, (11.5 if sy < 0 else 12.6) / 2), color=WOOD_DARK, bevel=0.08)
    # counter made of planks
    for k in range(6):
        b.box((15.2, 0.3, 0.55), loc=(0, -1.85, 0.35 + k * 0.58), color=WOOD if k % 2 else WOOD_LIGHT, bevel=0.04, jitter=0.01)
    b.box((16.2, 2.4, 0.35), loc=(0, -1.2, 3.75), color=WOOD_LIGHT, bevel=0.06)
    # back shelves
    for z in (2.0, 4.6, 7.2):
        b.box((14.8, 1.4, 0.25), loc=(0, 3.1, z), color=WOOD, bevel=0.04)
    b.box((15.2, 0.3, 9.0), loc=(0, 3.85, 4.5), color=WOOD_DARK, bevel=0.05)
    # crates out front
    for cx, cy, s in ((-9.6, -2.6, 1.6), (9.4, -2.9, 1.8), (10.3, -0.9, 1.4)):
        b.box((s, s, s), loc=(cx, cy, s / 2), rot=(0, 0, 8 if cx > 0 else -6), color=WOOD_LIGHT, bevel=0.06)
    # hanging sign board (the game puts the SHOP text on it)
    b.box((7.0, 0.3, 2.2), loc=(0, -2.7, 9.3), color=WOOD_LIGHT, bevel=0.08)
    for sx in (-2.6, 2.6):
        b.rod((sx, -2.7, 10.4), (sx, -2.5, 11.6), 0.06, color=BLACK, segs=5)
    b.build(material="Wood", smooth_angle=30, uv_tile=4, collision="Box", can_collide=True)

    b = mm.Builder("Awning", coll, seed=81)
    stripes = 8
    for i in range(stripes):
        x0 = -8.4 + i * (16.8 / stripes)
        col = RED if i % 2 == 0 else WHITE
        # a gently sagging striped canvas sloping down to the front
        pts = []
        for k in range(7):
            t = k / 6
            pts.append((x0 + 16.8 / stripes / 2, -3.0 + t * 7.2, 10.6 + t * 2.2 - math.sin(t * math.pi) * 0.35))
        for k in range(len(pts) - 1):
            p0, p1 = pts[k], pts[k + 1]
            b.beam(p0, p1, 16.8 / stripes, 0.12, color=col, extend=0.02)
    # scalloped front edge
    for i in range(16):
        b.sphere(0.55, loc=(-7.9 + i * 1.05, -3.05, 10.45), color=RED if i % 2 == 0 else WHITE, segs=8, rings=5,
                 scale=(1, 0.2, 0.8))
    b.build(material="Fabric", smooth_angle=40, uv_tile=3)

    b = mm.Builder("Goods", coll, seed=82)
    rng = b.rng
    jar_cols = [(255, 120, 150), (120, 200, 255), (255, 210, 80), (150, 230, 120), (200, 140, 255)]
    for row, z in enumerate((2.15, 4.75, 7.35)):
        for k in range(9):
            jx = -6.6 + k * 1.65
            col = jar_cols[(k + row) % len(jar_cols)]
            if (k + row) % 3 == 0:
                b.box((0.9, 0.2, 1.2), loc=(jx, 2.9, z + 0.6), rot=(0, 0, rng.uniform(-8, 8)), color=col)  # seed packets
            else:
                b.cyl(0.4, 0.9, loc=(jx, 3.0, z + 0.45), color=col, segs=12)
                b.cyl(0.42, 0.18, loc=(jx, 3.0, z + 0.98), color=(150, 110, 70), segs=12)
    for cx, cy, s in ((-9.6, -2.6, 1.6), (9.4, -2.9, 1.8), (10.3, -0.9, 1.4)):
        for _ in range(5):
            b.sphere(0.3, loc=(cx + rng.uniform(-s * 0.3, s * 0.3), cy + rng.uniform(-s * 0.3, s * 0.3), s + 0.15),
                     color=(RED, (255, 160, 40), (120, 200, 70))[rng.randrange(3)], segs=10, rings=6)
    b.build(material="SmoothPlastic", smooth_angle=45)
    mm.marker(coll, "Sign", loc=(0, -2.87, 9.3))
    return mm.export_prefab("ShopStall")


def frog(x):
    """Ribbit the shopkeeper: a dapper frog in a top hat and monocle."""
    coll = mm.prefab_collection("Frog", offset=(x, 140, 0))
    b = mm.Builder("Frog", coll, seed=83)
    b.lathe([(0, 0), (1.9, 0.1), (2.4, 1.2), (2.3, 2.6), (1.8, 3.8), (1.5, 4.3), (0, 4.5)], color=GREEN, segs=24,
            scale=(1.0, 0.9, 1.0))
    b.sphere(1.6, loc=(0, -0.75, 1.9), color=BELLY, segs=18, rings=10, scale=(1.0, 0.55, 1.15))
    # head
    b.sphere(2.0, loc=(0, -0.2, 5.0), color=GREEN, segs=22, rings=12, scale=(1.15, 0.95, 0.75))
    for ex in (-1.05, 1.05):
        b.sphere(0.85, loc=(ex, -0.3, 6.15), color=GREEN, segs=16, rings=10)
        b.sphere(0.62, loc=(ex, -0.75, 6.25), color=WHITE, segs=14, rings=8)
        b.sphere(0.3, loc=(ex, -1.27, 6.2), color=BLACK, segs=10, rings=6)
        b.sphere(0.09, loc=(ex - 0.12, -1.5, 6.36), color=WHITE, segs=6, rings=4)
    smile = []
    for k in range(13):
        a = math.radians(200 + 140 * k / 12)
        smile.append((1.35 * math.cos(a), -1.8 - 0.1 * math.sin(a * 2), 4.85 + 0.55 * math.sin(a)))
    b.tube(smile, 0.08, color=BLACK, sides=6)
    for ex in (-0.3, 0.3):
        b.sphere(0.08, loc=(ex, -1.95, 5.3), color=GREEN_DARK, segs=6, rings=4)
    # monocle + chain
    b.torus(0.62, 0.07, loc=(1.05, -1.35, 6.2), rot=(90, 0, 0), color=GOLD, segs=20, sides=6)
    b.tube([(1.6, -1.3, 5.9), (1.9, -1.2, 5.0), (1.6, -1.5, 4.2)], 0.03, color=GOLD, sides=4)
    # top hat
    b.lathe([(0, 6.15), (1.6, 6.15), (1.6, 6.32), (0.95, 6.35), (0.95, 8.3), (1.05, 8.4), (0, 8.42)], loc=(0, 0.35, 0),
            rot=(-8, 0, 0), color=BLACK, segs=24)
    b.torus(0.97, 0.12, loc=(0, 0.32, 6.65), rot=(-8, 0, 0), color=RED, segs=24, sides=6)
    # bowtie
    for side in (-1, 1):
        b.sphere(0.48, loc=(side * 0.45, -1.55, 3.55), rot=(0, side * 15, 0), color=RED, segs=10, rings=6, scale=(1.0, 0.45, 0.65))
    b.sphere(0.2, loc=(0, -1.72, 3.55), color=RED, segs=8, rings=5)
    # arms resting forwards (on the counter)
    for side in (-1, 1):
        b.tube(mm.smooth_path([(side * 2.0, -0.3, 3.0), (side * 2.4, -1.4, 2.6), (side * 1.6, -2.6, 2.8)], 3), 0.35,
               color=GREEN, sides=10)
        for f in (-1, 0, 1):
            b.sphere(0.24, loc=(side * 1.5 + f * 0.25, -2.95, 2.8), color=GREEN, segs=8, rings=5)
    b.build(material="SmoothPlastic", smooth_angle=45, collision="Box", can_collide=True)
    return mm.export_prefab("Frog")


def fence_section(x):
    """10-stud picket fence section running along Y (the game lays them end to end)."""
    coll = mm.prefab_collection("FenceSection", offset=(x, 170, 0))
    b = mm.Builder("Fence", coll, seed=84)
    # kept deliberately low-poly: hundreds of these line the plots
    for y in (-4.85, 4.85):
        b.box((0.55, 0.55, 3.9), loc=(0, y, 1.95), color=WOOD_DARK)
        b.cyl(0.32, 0.3, loc=(0, y, 4.0), r_top=0.05, color=WOOD_DARK, segs=4, rot=(0, 0, 45))
    for z in (1.1, 2.6):
        b.box((0.22, 10.0, 0.4), loc=(0.05, 0, z), color=WOOD)
    for k in range(9):
        y = -4.0 + k * 1.0
        h = 3.2 + (0.15 if k % 2 else 0.0)
        b.box((0.16, 0.6, h), loc=(-0.15, y, h / 2), color=WOOD_LIGHT)
        b.raw([(-0.08, -0.3, 0), (-0.08, 0.3, 0), (-0.08, 0.0, 0.4), (0.08, -0.3, 0), (0.08, 0.3, 0), (0.08, 0.0, 0.4)],
              [(0, 1, 2), (3, 5, 4), (0, 3, 4, 1), (1, 4, 5, 2), (2, 5, 3, 0)], color=WOOD_LIGHT, loc=(-0.15, y, h))
    b.build(material="Wood", smooth_angle=0, uv_tile=3, collision="Box", can_collide=True)
    return mm.export_prefab("FenceSection")


def gate_arch(x):
    coll = mm.prefab_collection("GateArch", offset=(x, 170, 0))
    b = mm.Builder("Arch", coll, seed=85)
    for sx in (-8.5, 8.5):
        b.box((1.7, 1.7, 13.0), loc=(sx, 0, 6.5), color=WOOD_DARK, bevel=0.15, jitter=0.02)
        b.box((2.4, 2.4, 0.8), loc=(sx, 0, 0.4), color=(140, 136, 130), bevel=0.15)
        b.cyl(0.5, 1.0, loc=(sx, 0, 13.4), r_top=0.2, color=WOOD, segs=8)
    b.box((20.0, 1.6, 1.3), loc=(0, 0, 13.0), color=WOOD, bevel=0.14)
    b.box((19.2, 1.0, 0.6), loc=(0, 0, 8.6), color=WOOD, bevel=0.1)
    # little roof
    b.raw([(-10.6, -1.6, 13.6), (10.6, -1.6, 13.6), (10.6, 1.6, 13.6), (-10.6, 1.6, 13.6), (-10.6, 0, 15.2), (10.6, 0, 15.2)],
          [(0, 1, 5, 4), (2, 3, 4, 5), (0, 4, 3), (1, 2, 5), (3, 2, 1, 0)], color=(176, 74, 62))
    b.build(material="Wood", smooth_angle=30, uv_tile=4, collision="Box", can_collide=True)
    return mm.export_prefab("GateArch")


def lamp(x):
    coll = mm.prefab_collection("Lamp", offset=(x, 170, 0))
    b = mm.Builder("Post", coll, seed=86)
    iron = (52, 54, 62)
    b.cyl(0.6, 0.5, loc=(0, 0, 0.25), r_top=0.45, color=iron, segs=10)
    b.cyl(0.18, 8.2, loc=(0, 0, 4.4), r_top=0.14, color=iron, segs=10)
    b.tube(mm.smooth_path([(0, 0, 8.4), (0, -0.2, 9.0), (0, -0.9, 9.2), (0, -1.4, 8.9)], 3), 0.1, color=iron, sides=6)
    b.lathe([(0.0, 8.0), (0.45, 8.05), (0.62, 8.35), (0.0, 8.95)], loc=(0, -1.4, 0), color=iron, segs=10)
    b.build(material="Metal", smooth_angle=45, collision="Box", can_collide=True)
    b = mm.Builder("Bulb", coll)
    b.sphere(0.42, loc=(0, -1.4, 7.75), color=(255, 226, 150), segs=12, rings=8)
    b.build(material="Neon", smooth_angle=60, cast_shadow=False)
    mm.marker(coll, "Light", loc=(0, -1.4, 7.6))
    return mm.export_prefab("Lamp")


def rocks(x):
    out = []
    for i, (r, sc) in enumerate(((2.4, (1.3, 1.0, 0.7)), (1.6, (1.0, 1.2, 0.9)), (3.4, (1.4, 1.1, 0.6)))):
        name = "Rock%d" % (i + 1)
        coll = mm.prefab_collection(name, offset=(x + i * 10, 190, 0))
        b = mm.Builder("Rock", coll, seed=90 + i)
        b.ico(r, loc=(0, 0, r * sc[2] * 0.55), color=(142, 138, 132), subdiv=2, scale=sc, jitter=r * 0.06)
        b.build(material="Slate", smooth_angle=30, uv_tile=4, collision="Hull", can_collide=True)
        out.append(mm.export_prefab(name))
    return out


def bush(x):
    coll = mm.prefab_collection("Bush", offset=(x, 190, 0))
    b = mm.Builder("Leaves", coll, seed=95)
    for bx, by, bz, r in ((0, 0, 1.4, 1.8), (1.4, 0.4, 1.1, 1.3), (-1.3, -0.3, 1.1, 1.35), (0.3, 1.1, 1.2, 1.2)):
        b.ico(r, loc=(bx, by, bz), color=(80, 160, 70), subdiv=2, jitter=0.1)
    b.build(material="Grass", smooth_angle=60, uv_tile=3)
    b = mm.Builder("Flowers", coll, seed=96)
    rng = b.rng
    for _ in range(9):
        a = rng.uniform(0, 2 * math.pi)
        b.sphere(0.2, loc=(math.cos(a) * 1.9, math.sin(a) * 1.9, rng.uniform(1.4, 2.6)),
                 color=((255, 240, 120), (255, 150, 200), (255, 255, 255))[rng.randrange(3)], segs=8, rings=5)
    b.build(material="SmoothPlastic", smooth_angle=60)
    return mm.export_prefab("Bush")


PROPS = ["ShopStall", "Frog", "FenceSection", "GateArch", "Lamp", "Rock1", "Rock2", "Rock3", "Bush"]


def build():
    return [shop_stall(0), frog(25), fence_section(0), gate_arch(15), lamp(40), *rocks(0), bush(35)]
