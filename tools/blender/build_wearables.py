"""Costumes (worn as Accessories) and fun-stuff items.

Costume origins are the avatar attachment point they hang from:
  Hat   -> HatAttachment (top center of the head; hats sit ~0.25 lower so they hug it)
  Face  -> FaceFrontAttachment (front of the face at eye level)
  Waist -> WaistCenterAttachment
Sized for a default ~1.2 stud head. Tools are modelled with their grip at the
origin and pointing along -Y (forwards). Front is -Y everywhere.
"""

import math

import mm_lib as mm

WHITE = (250, 250, 248)
BLACK = (30, 30, 36)
RED = (230, 56, 66)
ORANGE = (255, 130, 30)
YELLOW = (255, 212, 50)
GOLD = (255, 200, 60)
PURPLE = (130, 70, 200)
GREEN = (90, 190, 90)
BLUE = (70, 140, 240)
PINK = (255, 120, 180)
CREAM = (246, 232, 200)
SKIN_BEAK = (255, 150, 40)


def _done(b, name, material="SmoothPlastic", smooth=45):
    b.build(material=material, smooth_angle=smooth)
    return mm.export_prefab(name)


def traffic_cone(x):
    coll = mm.prefab_collection("TrafficCone", offset=(x, 100, 0))
    b = mm.Builder("Cone", coll)
    b.box((1.5, 1.5, 0.12), loc=(0, 0, -0.18), color=ORANGE, bevel=0.04)
    bands = [(-0.12, 0.62, 0.22, ORANGE), (0.22, 0.52, 0.55, WHITE), (0.55, 0.42, 0.85, ORANGE), (0.85, 0.33, 1.1, WHITE),
             (1.1, 0.26, 1.55, ORANGE)]
    for z0, r0, z1, col in bands:
        r1 = 0.62 - (z1 + 0.12) * 0.32
        b.cyl(r0, z1 - z0, loc=(0, 0, (z0 + z1) / 2), r_top=max(r1, 0.08), color=col, segs=20)
    return _done(b, "TrafficCone")


def party_hat(x):
    coll = mm.prefab_collection("PartyHat", offset=(x, 100, 0))
    b = mm.Builder("Hat", coll)
    h, r = 1.35, 0.58
    for i in range(5):
        z0, z1 = h * i / 5, h * (i + 1) / 5
        r0, r1 = r * (1 - z0 / h) + 0.03, r * (1 - z1 / h) + 0.03
        b.cyl(r0, z1 - z0, loc=(0, 0, z0 + (z1 - z0) / 2 - 0.25), r_top=r1, color=PURPLE if i % 2 == 0 else YELLOW, segs=18)
    b.sphere(0.2, loc=(0, 0, h - 0.18), color=PINK, segs=10, rings=6, jitter=0.02)
    for i in range(10):
        a = math.radians(36 * i)
        b.sphere(0.07, loc=(0.5 * math.cos(a), 0.5 * math.sin(a), -0.08), color=(80, 220, 255), segs=6, rings=4)
    return _done(b, "PartyHat")


def nerd_glasses(x):
    coll = mm.prefab_collection("NerdGlasses", offset=(x, 100, 0))
    b = mm.Builder("Glasses", coll)
    for ex in (-0.3, 0.3):
        b.torus(0.22, 0.05, loc=(ex, -0.08, 0.05), rot=(90, 0, 0), color=BLACK, segs=20, sides=6)
    b.tube([(-0.09, -0.08, 0.1), (0, -0.1, 0.13), (0.09, -0.08, 0.1)], 0.035, color=BLACK, sides=5)
    for ex in (-0.52, 0.52):
        b.tube([(ex, -0.08, 0.05), (ex * 1.08, 0.2, 0.05), (ex * 1.08, 0.62, 0.0), (ex * 1.02, 0.72, -0.12)], 0.035,
               color=BLACK, sides=5)
    b.box((0.08, 0.04, 0.04), loc=(0.22, -0.1, 0.18), color=WHITE)  # tape on the bridge, nerd style
    return _done(b, "NerdGlasses")


def chef_hat(x):
    coll = mm.prefab_collection("ChefHat", offset=(x, 100, 0))
    b = mm.Builder("Hat", coll, seed=60)
    b.cyl(0.62, 0.5, loc=(0, 0, 0.0), color=WHITE, segs=22)
    for i in range(6):
        a = math.radians(60 * i)
        b.sphere(0.42, loc=(0.42 * math.cos(a), 0.42 * math.sin(a), 0.72), color=WHITE, segs=12, rings=8, jitter=0.02)
    b.sphere(0.5, loc=(0, 0, 0.95), color=WHITE, segs=12, rings=8, jitter=0.02)
    return _done(b, "ChefHat", smooth=60)


def pirate_hat(x):
    coll = mm.prefab_collection("PirateHat", offset=(x, 100, 0))
    b = mm.Builder("Hat", coll)
    b.lathe([(0.62, -0.18), (0.62, 0.15), (0.55, 0.45), (0.3, 0.62), (0, 0.65)], color=BLACK, segs=20)
    # bicorne flaps: half discs standing up front and back
    half = [(math.cos(math.radians(a)) * 1.1, math.sin(math.radians(a)) * 0.62) for a in range(0, 181, 15)]
    for y, tilt in ((-0.5, 12), (0.5, -12)):
        b.extrude(half, 0.1, loc=(0, y, 0.0), rot=(90 + tilt, 0, 0), color=BLACK)
        b.tube([(math.cos(math.radians(a)) * 1.1, y - 0.06 * (1 if y < 0 else -1), math.sin(math.radians(a)) * 0.62 * 0.98)
                for a in range(0, 181, 15)], 0.04, color=GOLD, sides=5)
    b.cyl(0.18, 0.04, loc=(0, -0.58, 0.36), rot=(78, 0, 0), color=WHITE, segs=14)
    for ex in (-0.06, 0.06):
        b.sphere(0.035, loc=(ex, -0.61, 0.38), color=BLACK, segs=6, rings=4)
    return _done(b, "PirateHat")


def duck_floaty(x):
    coll = mm.prefab_collection("DuckFloaty", offset=(x, 100, 0))
    b = mm.Builder("Floaty", coll)
    b.torus(1.55, 0.5, color=YELLOW, segs=32, sides=12)
    b.sphere(0.55, loc=(0, -1.95, 0.55), color=YELLOW, segs=14, rings=8)
    b.sphere(0.3, loc=(0, -2.45, 0.45), color=SKIN_BEAK, segs=10, rings=6, scale=(1, 1.1, 0.45))
    for ex in (-0.22, 0.22):
        b.sphere(0.09, loc=(ex, -2.3, 0.75), color=BLACK, segs=6, rings=4)
    b.sphere(0.35, loc=(0, 1.9, 0.3), rot=(30, 0, 0), color=YELLOW, segs=10, rings=6, scale=(0.6, 0.6, 1.1))
    return _done(b, "DuckFloaty", smooth=60)


def viking_helmet(x):
    coll = mm.prefab_collection("VikingHelmet", offset=(x, 100, 0))
    b = mm.Builder("Helmet", coll)
    steel = (170, 176, 186)
    b.lathe([(0.66, -0.35), (0.68, 0.0), (0.6, 0.35), (0.38, 0.62), (0, 0.72)], color=steel, segs=24)
    b.torus(0.67, 0.07, loc=(0, 0, -0.3), color=GOLD, segs=24, sides=6)
    b.box((0.12, 0.08, 0.5), loc=(0, -0.68, -0.48), color=steel)
    for side in (-1, 1):
        pts = [(side * 0.6, 0, 0.05), (side * 0.95, 0, 0.15), (side * 1.15, 0, 0.5), (side * 1.12, 0, 0.95)]
        b.tube(mm.smooth_path(pts, 4), 0.16, color=CREAM, sides=10, radii=[0.17 - k * 0.0105 for k in range(13)])
    for i in range(8):
        a = math.radians(45 * i)
        b.sphere(0.05, loc=(0.7 * math.cos(a), 0.7 * math.sin(a), -0.3), color=GOLD, segs=6, rings=4)
    return _done(b, "VikingHelmet")


def dino_hood(x):
    coll = mm.prefab_collection("DinoHood", offset=(x, 100, 0))
    b = mm.Builder("Hood", coll)
    green = (96, 196, 96)
    b.lathe([(0.72, -0.9), (0.76, -0.2), (0.7, 0.25), (0.45, 0.6), (0, 0.7)], color=green, segs=22, scale=(1, 1.05, 1))
    b.sphere(0.55, loc=(0, -0.85, 0.2), color=green, segs=14, rings=8, scale=(0.95, 1.1, 0.6))  # snout over the face
    for i in range(7):
        tx = -0.4 + i * 0.133
        b.cyl(0.06, 0.16, loc=(tx, -1.18 + abs(tx) * 0.35, -0.05), rot=(180, 0, 0), r_top=0.0, color=WHITE, segs=5)
    for ex in (-0.3, 0.3):
        b.sphere(0.16, loc=(ex, -0.72, 0.52), color=WHITE, segs=8, rings=5)
        b.sphere(0.08, loc=(ex, -0.84, 0.55), color=BLACK, segs=6, rings=4)
    for i in range(5):
        y = -0.3 + i * 0.32
        z = 0.72 - (y * y) * 0.4
        b.cyl(0.14, 0.32, loc=(0, y, z + 0.1), r_top=0.0, color=ORANGE, segs=6)
    return _done(b, "DinoHood")


def wizard_hat(x):
    coll = mm.prefab_collection("WizardHat", offset=(x, 100, 0))
    b = mm.Builder("Hat", coll)
    b.lathe([(0.6, -0.2), (1.25, -0.18), (1.25, -0.12), (0.6, -0.08)], color=PURPLE, segs=28, closed=True)
    cone = [(0, 0, -0.15), (0, 0.05, 0.5), (0, 0.15, 1.1), (0, 0.45, 1.6), (0, 0.85, 1.8)]
    pts = mm.smooth_path(cone, 4)
    n = len(pts)
    b.tube(pts, 0.6, color=PURPLE, sides=16, radii=[0.62 * (1 - k / n) + 0.03 for k in range(n)])
    b.torus(0.6, 0.06, loc=(0, 0, -0.05), color=GOLD, segs=24, sides=6)
    star = mm.star_poly(0.16, 0.07)
    for (sx, sy, sz, ry) in ((0.35, -0.42, 0.3, 0), (-0.3, -0.3, 0.7, -20), (0.1, -0.2, 1.05, 10)):
        b.extrude(star, 0.05, loc=(sx, sy, sz), rot=(90, ry, 0), color=YELLOW)
    return _done(b, "WizardHat")


def royal_crown(x):
    coll = mm.prefab_collection("RoyalCrown", offset=(x, 100, 0))
    b = mm.Builder("Crown", coll)
    b.lathe([(0.0, -0.1), (0.55, -0.1), (0.5, 0.35), (0, 0.42)], color=(150, 40, 70), segs=20)  # velvet cap
    b.lathe([(0.6, -0.2), (0.68, -0.2), (0.68, 0.18), (0.6, 0.18)], color=GOLD, segs=28, closed=True)
    for i in range(8):
        a = 2 * math.pi * i / 8
        c, s = math.cos(a), math.sin(a)
        b.cyl(0.13, 0.42, loc=(0.64 * c, 0.64 * s, 0.38), r_top=0.03, color=GOLD, segs=6)
        b.sphere(0.07, loc=(0.64 * c, 0.64 * s, 0.62), color=GOLD, segs=6, rings=4)
        b.sphere(0.075, loc=(0.7 * c, 0.7 * s, 0.0), color=RED if i % 2 == 0 else BLUE, segs=8, rings=5)
    b.sphere(0.1, loc=(0, 0, 0.5), color=GOLD, segs=8, rings=5)
    b.box((0.06, 0.06, 0.26), loc=(0, 0, 0.66), color=GOLD)
    b.box((0.2, 0.06, 0.06), loc=(0, 0, 0.7), color=GOLD)
    b.build(material="Metal", smooth_angle=40, reflectance=0.05)
    return mm.export_prefab("RoyalCrown")


COSTUMES = ["TrafficCone", "PartyHat", "NerdGlasses", "ChefHat", "PirateHat", "DuckFloaty", "VikingHelmet", "DinoHood",
            "WizardHat", "RoyalCrown"]


# ---------------------------------------------------------------- fun stuff


def rubber_chicken(x):
    coll = mm.prefab_collection("RubberChicken", offset=(x, 115, 0))
    b = mm.Builder("Chicken", coll)
    # held by the feet, body flopping forwards
    body = mm.smooth_path([(0, 0, 0.0), (0, -0.5, 0.15), (0, -1.3, 0.2), (0, -2.0, 0.05), (0, -2.5, -0.25)], 4)
    n = len(body)
    b.tube(body, 0.3, color=YELLOW, sides=12, radii=[0.12 + 0.3 * math.sin(math.pi * min(1, (k + 2) / n)) for k in range(n)])
    head = body[-1]
    b.sphere(0.28, loc=(head[0], head[1] - 0.15, head[2] - 0.05), color=YELLOW, segs=12, rings=8)
    for k in range(3):
        b.sphere(0.1, loc=(0, head[1] - 0.15 + (k - 1) * 0.1, head[2] + 0.22), color=RED, segs=8, rings=5)
    b.cyl(0.11, 0.28, loc=(0, head[1] - 0.48, head[2] - 0.08), rot=(90, 0, 0), r_top=0.0, color=ORANGE, segs=8)
    b.sphere(0.07, loc=(0, head[1] - 0.32, head[2] - 0.25), color=RED, segs=6, rings=4, scale=(1, 0.6, 1.6))  # wattle
    for ex in (-0.13, 0.13):  # X_X eyes
        for ang in (45, -45):
            b.box((0.12, 0.02, 0.025), loc=(ex * 1.4, head[1] - 0.4, head[2] + 0.05), rot=(0, ang, 0), color=BLACK)
    for ex in (-0.12, 0.12):
        b.tube([(ex, 0.0, 0.0), (ex, 0.15, -0.1), (ex, 0.3, -0.12)], 0.035, color=ORANGE, sides=5)
    b.build(material="SmoothPlastic", smooth_angle=50)
    return mm.export_prefab("RubberChicken")


def confetti_cannon(x):
    coll = mm.prefab_collection("ConfettiCannon", offset=(x, 115, 0))
    b = mm.Builder("Cannon", coll)
    barrel = [(0.28, 0.0), (0.3, 0.4), (0.3, 1.2), (0.42, 1.6), (0.36, 1.65)]
    b.lathe(barrel, loc=(0, -0.1, 0.25), rot=(90, 0, 0), color=PINK, segs=18, cap_top=True)
    for k, col in enumerate((YELLOW, BLUE, GREEN)):
        b.torus(0.31, 0.04, loc=(0, -0.5 - k * 0.32, 0.25), rot=(90, 0, 0), color=col, segs=18, sides=5)
    b.box((0.18, 0.3, 0.5), loc=(0, 0.05, -0.05), rot=(15, 0, 0), color=PURPLE, bevel=0.05)  # grip
    for i in range(8):
        a = math.radians(45 * i)
        b.box((0.08, 0.02, 0.12), loc=(0.2 * math.cos(a), -1.8 - (i % 3) * 0.12, 0.25 + 0.2 * math.sin(a)),
              rot=(i * 20, i * 33, 0), color=(YELLOW, BLUE, GREEN, RED)[i % 4])
    b.build(material="SmoothPlastic", smooth_angle=45)
    return mm.export_prefab("ConfettiCannon")


def _sneaker(b, sx, upper, z=0.0):
    b.box((0.75, 1.5, 0.22), loc=(sx, 0, z + 0.11), color=WHITE, bevel=0.08)
    b.sphere(0.42, loc=(sx, 0.25, z + 0.45), color=upper, segs=12, rings=8, scale=(0.9, 1.4, 0.75))
    b.sphere(0.36, loc=(sx, -0.42, z + 0.32), color=upper, segs=12, rings=8, scale=(1.0, 1.1, 0.55))
    for k in range(3):
        b.box((0.4, 0.05, 0.05), loc=(sx, -0.25 + k * 0.17, z + 0.62 + k * 0.03), color=WHITE)
    b.box((0.06, 0.6, 0.12), loc=(sx + 0.38, 0.0, z + 0.4), rot=(0, 0, 0), color=YELLOW)


def speed_sneakers(x):
    coll = mm.prefab_collection("SpeedSneakers", offset=(x, 115, 0))
    b = mm.Builder("Shoes", coll)
    for sx in (-0.5, 0.5):
        _sneaker(b, sx, RED)
    b.build(material="SmoothPlastic", smooth_angle=45)
    return mm.export_prefab("SpeedSneakers")


def spring_shoes(x):
    coll = mm.prefab_collection("SpringShoes", offset=(x, 115, 0))
    b = mm.Builder("Shoes", coll)
    for sx in (-0.5, 0.5):
        pts = []
        for k in range(49):
            a = 2 * math.pi * k / 12
            pts.append((sx + 0.28 * math.cos(a), 0.28 * math.sin(a), 0.05 + k * 0.02))
        b.tube(pts, 0.05, color=(170, 176, 190), sides=6)
        _sneaker(b, sx, BLUE, z=1.0)
    b.build(material="SmoothPlastic", smooth_angle=45)
    return mm.export_prefab("SpringShoes")


def pet_rock(x):
    coll = mm.prefab_collection("PetRock", offset=(x, 115, 0))
    b = mm.Builder("Rock", coll, seed=70)
    b.ico(0.8, loc=(0, 0, 0.65), color=(140, 136, 130), subdiv=2, scale=(1.1, 0.95, 0.8), jitter=0.07)
    b.build(material="Slate", smooth_angle=35, uv_tile=1.5)
    b = mm.Builder("Eyes", coll, seed=71)
    for ex in (-0.28, 0.28):
        b.sphere(0.24, loc=(ex, -0.66, 0.85), color=WHITE, segs=12, rings=8, scale=(1, 0.6, 1))
        b.sphere(0.11, loc=(ex + 0.05, -0.8, 0.8), color=BLACK, segs=8, rings=6, scale=(1, 0.6, 1))
    b.tube([(-0.2, -0.78, 0.45), (0, -0.83, 0.38), (0.2, -0.78, 0.45)], 0.035, color=BLACK, sides=5)  # smile
    b.box((0.36, 0.1, 0.14), loc=(0, 0.0, 1.22), rot=(0, 0, 20), color=PINK, bevel=0.03)  # tiny bow
    b.build(material="SmoothPlastic", smooth_angle=50)
    return mm.export_prefab("PetRock")


FUN = ["RubberChicken", "ConfettiCannon", "SpeedSneakers", "SpringShoes", "PetRock"]


def build():
    out = []
    for i, fn in enumerate([traffic_cone, party_hat, nerd_glasses, chef_hat, pirate_hat, duck_floaty, viking_helmet,
                            dino_hood, wizard_hat, royal_crown]):
        out.append(fn(i * 5))
    for i, fn in enumerate([rubber_chicken, confetti_cannon, speed_sneakers, spring_shoes, pet_rock]):
        out.append(fn(i * 5))
    return out
