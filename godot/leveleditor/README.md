# The level editor

Godot's own built-in tools, arranged to author an Eeri level. No addon, no
custom dock, no EditorPlugin — see `EERI_GODOT_HANDOFF.md` §13 (the section
in the repo root recording why: an EditorPlugin was planned and then
explicitly rejected in favour of what Godot already ships).

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
   `Entities` node, position them in the 3D viewport or by typing exact
   numbers into the Inspector's Transform. Every marker is colour-coded and
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

15 checks: the built artifacts exist and match the legend, a tiny
hand-authored level round-trips through export and back into a real
`LevelData` with correct physics (belt direction, ladder climbability, the
bolt row/col flip), and an incomplete level is reported rather than silently
exported broken.
