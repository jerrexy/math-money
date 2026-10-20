# Math Money 💰➗

A Roblox game where elementary-school kids practice their math facts by keeping
a plate of treasure out of a vat of bubbling acid.

Each of the 8 players claims a plot with four giant money machines:
**Addition → Subtraction → Multiplication → Division**, which pay more as the
math gets harder. Walk up to a machine's computer, press **E**, and a 30-second
round starts:

- The chain starts lowering the loot plate toward the acid.
- ✅ **Right answer**: the chain stops for a few seconds (answers stack the pause).
- ❌ **Wrong answer**: the engine grinds and smokes, the plate shakes, and jewels fall
  into the acid. The game shows the right answer and a hint, then asks that fact
  again a little later.
- 🔥 Three right in a row drops a bonus gem onto the plate.
- ⏱ If the timer runs out before the plate reaches the acid, you keep what's left.
  The loot flies to you and your money counter rolls up. If the plate hits the
  acid first, everything melts.

Spend the money at **Ribbit's Emporium** (the frog in the top hat). It sells
seeds that grow into flowers and forests in real time, garden decor (yes, a
golden toilet), costumes, and silly stuff: a rubber chicken, a confetti cannon,
speed sneakers, spring shoes and a pet rock. The **🎒 My Stuff** button lets you
put things on or take them off anywhere on the map. Money, levels, garden and
items are saved.

## Learning design

| Machine | Levels (8 each) | Plate at L1 → L8 |
|---|---|---|
| ➕ Addition | sums to 10 → sums to 20 → 2-digit (no carry → carry) → hundreds | $20 → $55 |
| ➖ Subtraction | within 10 → within 20 → 2-digit (no borrow → borrow) → hundreds | $35 → $96 |
| ✖️ Multiplication | tables in teaching order: ×1 ×2 ×10 → ×5 → ×3 → ×4 → ×6 → ×7 → ×8 ×9 → ×11 ×12 + mix | $55 → $151 |
| ➗ Division | the same tables as division facts | $80 → $220 |

- **Leveling is earned by accuracy.** Net right answers (right − wrong) at your
  highest level unlock the next one, so guessing doesn't help. Players can pick
  an easier "practice" level that pays less.
- About 30% of questions review earlier levels, and missed facts come back two
  questions later.
- The **📒 Report Card** shows level progress and accuracy per machine, plus a
  12×12 times-table grid that turns green as facts are mastered. It's handy for
  parents and teachers.
- **Pacing:** a round is about 40 seconds. A first-grader earns about $20 a round
  (a pack of daisy seeds). Shop prices run from $15 to $5,000, so the big goals
  take a few hours of real practice.

All tuning lives in [`src/shared/Config`](src/shared/Config): `Economy.luau`,
`Machines.luau`, `Catalog.luau` and `Sounds.luau`. Questions come from
[`src/shared/MathQuestions.luau`](src/shared/MathQuestions.luau).

## Project layout (Rojo)

```
default.project.json     Rojo project for `rojo serve` (code + prefabs + lighting)
build.project.json       same plus the world snapshot, for `rojo build` of a full place
rokit.toml               toolchain (rojo, stylua, selene)
src/
  server/                ServerScriptService.Server: bootstrap + Services/
    Services/            DataService, PlotService, MachineService, GardenService,
                         AvatarService, ShopService
  client/                StarterPlayerScripts.Client: bootstrap + Controllers/ + UI/
    Controllers/         HUD, round UI, machine renderer, shop, garden, report card, ...
    UI/Theme.luau        tiny UI kit (all UI is built in code)
  shared/                ReplicatedStorage.Shared: Config/, MathQuestions, Remotes, Util/
assets/
  blender/MathMoney.blend   every 3D model (source of truth)
  meshes/                   FBX export for Studio's 3D Importer + uploaded mesh ids
  models/server/            .rbxm prefabs -> ServerStorage.Prefabs (Apparatus, WorldProps)
  models/replicated/        .rbxm assets  -> ReplicatedStorage.Assets (loot, plants, costumes...)
  models/world/World.rbxm   snapshot of Workspace.World (used by build.project.json)
tools/
  blender/                  Python scripts that build every model (mm_lib.py = helpers + exporters)
  pipeline/                 Blender -> Studio asset pipeline (see tools/pipeline/README.md)
  studio/build_world.luau   builds the island, plaza, shop and the 8 plots
```

**Architecture.** The server is authoritative: it runs rounds, checks answers,
handles purchases and planting, and saves data. Clients only render. A machine
publishes its chain position as a few attributes on a shared clock
(`DropBase`, `DropStart`, `DropRate`, `PausedUntil`), so every player sees the
same smooth motion without streaming positions. Services and controllers are
plain ModuleScripts with `Init` / `Start` and no frameworks. Every remote is
listed in [`src/shared/Remotes.luau`](src/shared/Remotes.luau).

## Developing

1. Install the toolchain once with `rokit install`.
2. Start syncing with `rojo serve` (add `--port 34873` if another project already
   uses the default port).
3. In Studio, open the place and connect with the Rojo plugin.

The world (`Workspace.World`) lives in the place file, and a snapshot is kept at
`assets/models/world/World.rbxm`. To rebuild it, run
`tools/studio/build_world.luau` from the command bar; the header comment
explains how. Re-save the snapshot afterwards if you change it.

**A complete place from the repo.** `rojo build build.project.json -o MathMoney.rbxl`
produces the whole game, world included. Terrain can't be stored in a model
file, so the island is grown by `src/server/IslandTerrain.luau` the first time
the server starts.

**Which project file?**
- `rojo serve` uses `default.project.json`: code, prefabs and lighting, but not the
  world, so editing the world in Studio is safe while Rojo is connected.
- Only use `build.project.json` for `rojo build`.

**Saving data in Studio.** DataStores need a published place. Publish the game,
then turn on *Game Settings → Security → Enable Studio Access to API Services*.
Without that, the game still runs; progress just isn't saved in that Studio
session.

**3D models.** Run the scripts in `tools/blender` (Blender 4.1+) to rebuild every
model. Export with `mm_lib.export_fbx_bundle`, import the FBX once with
**Import 3D**, then run `tools/pipeline/assemble_all.luau` to turn the import
into prefabs. Details are in [`tools/pipeline/README.md`](tools/pipeline/README.md).

## Before publishing

- **Game Settings → Avatar:** R15 is recommended; costumes support R6 and R15.
- **Game Settings → Security:** turn *Allow HTTP Requests* **off**. It's only needed
  while running the asset pipeline.
- Add your own sound ids in `src/shared/Config/Sounds.luau` for the few
  moments that have none yet (`Correct`, `Wrong`, `Pop`, `Click`, ...).
