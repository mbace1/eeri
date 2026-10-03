# The level editor

Godot's built-in GridMap and marker prefabs, plus one dock. The **Layers**
dock is an EditorPlugin (`addons/eeri_leveleditor`; the slider UI and the
layer table live in this folder). `EERI_GODOT_HANDOFF.md` §13 records why
the original editor shipped with no plugin — this dock is the first piece
added on top of that, not a second editor.

The slider picks a depth layer. Names and z come from `data/scenery.json`
`layerZ` (what `SceneryData` already loads: SKY, SKYLINE, FAR, MID, NEAR,
PLAY, FORE). If that file is absent, the same lanes fall back to
`Diorama.RECTS` plus PLAY at z = 0. Dropping a marker prefab from
`markers/` into the open level scene sets that marker's `position.z` to
the selected layer and snaps x/y to the half-tile grid. Dragging a marker that is already placed snaps x/y onto that same grid
and leaves its layer (its z) where the drop put it. The background
pieces that already have a texture file ride that same path. Spruce, oak
and birch were already there (`EeriTreeSpruce`, `EeriTreeOak`,
`EeriTreeBirch`). The other keyed cutouts that are backgrounds and whose
files are real images are too: dock bay, site office, cargo stack, work
lamp, cable reel and lit barrier (`markers/eeri_dock_bay.tscn`,
`eeri_office.tscn`, `eeri_cargo.tscn`, `eeri_worklamp.tscn`,
`eeri_cable_reel.tscn`, `eeri_barrier_lamps.tscn`). Each cutout is the
texture `SceneryData.mount_art` already mounts. No new art, no MN prop
pack, and nothing was renamed. Log tunnel and stump clearing are keyed,
but the files on disk are not WebP, so they are not prefabs. Buried finds
(`fRoot` and the other `f*` rows) are not trees or backgrounds, and props
with no art file are still data.
Terrain painting is still the `Terrain` GridMap — the exporter reads
cell x/y only, so the slider is not a second paint plane.

## Authoring a new level, start to finish

1. **Duplicate the template.** In the FileSystem dock, right-click
   `leveleditor/level_template.tscn` > Duplicate. Rename it something like
   `eeri-5-1.tscn` and move it wherever you keep work-in-progress levels.
2. **Open it, select the scene root**, and in the Inspector's bottom
   "Metadata" section set `eeri_slug` to the level's slug (e.g. `eeri-5-1`)
   and `eeri_name` to its display name (e.g. `WORLD 5 — WHATEVER`). The
   exporter reads these two directly; without a slug starting `eeri-` it
   will refuse to write anything.
3. **Paint terrain.** Select the `Terrain` GridMap node. The bottom panel
   shows the palette from `tiles.meshlib` — one item per tile character.
   Left-click paints, right-click erases, exactly like any Godot GridMap.
   A green line hovers at y=4, the fixed GROUND row every existing level
   sits its floor on — paint at or below it.
4. **Drop entities.** Drag prefabs from `leveleditor/markers/` into the
   `Entities` node. The Layers slider (top of this file) is the layer that
   drop lands on. Moving it afterwards in the viewport, or typing a new
   x/y, snaps onto the same half-tile grid and does not change its layer.
   Every marker is colour-coded and
   carries a floating label so it reads at a glance. One `EeriKidSpawn`, one
   `EeriExit` (or let `EeriFlag` stand in for it), and one `EeriFlag` are
   required — everything else is as needed.
5. **Export.** Open `leveleditor/export_level.gd` in the Script editor and
   press Run (the play-circle icon top-right of the script editor, or
   File > Run). It writes `data/levels/<slug>.json` and prints either
   `Wrote ...` or a list of problems (missing spawn/exit/flag, a machine
   with no matching spawn marker, etc.) — fix those and run again.
6. **Play it.** `data/` is git-ignored and regenerated, same as always — the
   new level's JSON sits right next to the eleven generated ones and
   `LevelData.load_slug()` cannot tell the difference. Wire it into whatever
   selects levels (currently `scenes/shell.gd`'s level list) same as any
   other slug.

## What is derived vs. authored

Paint the tile, and its metadata is *derived* automatically at export time —
there is no second place to describe a belt's direction or a bank's row
count, because the exact same character the physics reads is what the
exporter reads too:

| Painted tile(s) | Auto-derived into |
|---|---|
| `B` (contiguous rect) | `bank` |
| `K` (contiguous rect) | `wall` |
| `H` (contiguous run, one column) | one `ladders` entry per column |
| `C` (contiguous run, one row) | `belts` entry, `dir: 1` |
| `c` (contiguous run, one row) | `belts` entry, `dir: -1` |
| `T` (contiguous run, one row) | `tarps` entry |
| `~` (contiguous run, one row) | `water` entry, `deep: false` |

Girder, bolts-in-a-line, deep water and pipes still need explicit markers
(`EeriGirderStack`/`Gap`/`Seat`, `EeriBoltRun`, `EeriWaterRegion` with `deep`
checked, `EeriPipeMouth` pairs) — those either have no tile at all (a pit
lives in *empty* GridMap cells) or carry data a single character can't
(a hoist's period, a pipe's other end).

## Regenerating the built artifacts

Only needed after changing the legend, adding a marker type, or changing the
level canvas size — not part of normal level authoring:

```sh
godot --headless --path . --script res://leveleditor/build_meshlib.gd
godot --headless --path . --script res://leveleditor/build_marker_scenes.gd
godot --headless --path . --script res://leveleditor/build_level_template.gd
```

`build_marker_scenes.gd` regenerates **every** marker `.tscn` from its
script, so hand-edits to a marker prefab's node tree do not survive —
change the script (`markers/*.gd`), not the generated scene.

## Testing

```sh
godot --headless --path . res://tests/test_leveleditor.tscn
```

51 checks: the built artifacts exist and match the legend, the layer
slider's names match `scenery.json` / the diorama, a placed marker snaps
onto the selected layer, dragging that marker afterwards snaps x/y
without leaving the layer, opening a level does not move a marker that
was already placed, the existing spruce, oak and birch cutouts and the
other keyed tree and background cutouts snap onto the slider's layer and
stay there when dragged, a tiny hand-authored level round-trips
through export and back into a real `LevelData` with correct physics (belt
direction, ladder climbability, the bolt row/col flip), and an incomplete
level is reported rather than silently exported broken.
