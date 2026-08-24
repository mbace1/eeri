# Eeri — Godot port

**Status: skeleton.** The project boots, renders one placeholder screen, and
reads the real asset manifest. No run/jump/stomp/climb, no level, no
gameplay. Read `../EERI_GODOT_HANDOFF.md` before adding any of that — it is
the coordination surface, the port boundary, and a real trap found on the
very first import pass (§3, `KHR_mesh_quantization` — it blocks the
excavator and both flags).

**Engine:** Godot 4.7.2 stable (project file declares `4.3` features)

## Setup — one command

The canonical asset manifest and every asset it marks `"live"` live *above*
this folder (`../assets/`), and Godot can only load from `res://`, so they
are copied in:

```sh
npm install -g @gltf-transform/cli   # once — dev-only, never ships (see below)
node tools/sync-data.mjs             # ../assets -> data/, dequantizing models
node tools/export-levels.mjs         # js/rooms.js  -> data/levels/*.json
node tools/export-locale.mjs         # js/lang.js   -> locale/ui.csv
node tools/export-glyphs.mjs         # js/glyphs.js -> data/glyphs/*.svg
node tools/export-audio.mjs          # js/audio.js  -> data/audio/*.wav
```

All five have a `--check` mode that fails on drift instead of writing. Their
outputs (`data/`, `locale/`) are git-ignored on purpose: the sources of truth
are `../assets`, `../js/rooms.js` and `../js/lang.js`, and a second committed
copy is what drifts.

`data/` is git-ignored on purpose — a second committed copy of the manifest
and 13MB of art is how a lineage forks. Run the copy after every clone.

## Run

```sh
godot --path .                                          # play — a status screen only
godot --headless --path . --import                      # first-run import (run twice; a
                                                          #   cold .godot/ errors on pass one)
for t in boot kid robot ride dig run locale progress gizmos pieces shell audio; do
  godot --headless --path . res://tests/test_$t.tscn
done                                                     # 201 checks
```

`$GODOT` in the handoff doc and in `../CLAUDE.md` is the 4.7.2 console
binary.

## What's actually here

| File | What it proves |
|---|---|
| `project.godot` | boots, reflows (canvas_items + expand, sensor orientation) |
| `autoload/asset_registry.gd` | `data/manifest.json` parses; live/placeholder counted correctly across the whole tree, not just the top-level groups |
| `autoload/game_state.gd` | empty — nowhere for future run state to go yet |
| `scenes/main.tscn` / `.gd` | the above two rendered on screen as a status string |
| `tools/sync-data.mjs` | the manifest + live-asset copy, with a `--check` gate mode |
| `tests/test_boot.tscn` / `.gd` | 8 headless checks tying the above together |

**51 of 77 manifest entries are already `"live"`** — this was not expected
going in. The kid (`eeri_v5.glb`: Meshy-rigged, 14 animation clips), the
excavator, both shipped worlds' complete layer sets, UI art and textures all
have real files today. None of it is wired into a scene; `asset_registry.gd`
only proves the data is there and parses correctly.

## What is NOT here

Everything that makes this a game: a kid you can move, a level, a camera, a
ride, a HUD, translations, save state. See `EERI_GODOT_HANDOFF.md` §4 for
the port boundary and §6 for the scene structure the next pass should build
toward.

## Why the sync step needs gltf-transform

Every model in `../assets/3d/` requires `KHR_mesh_quantization`, which Godot
4.7.2 cannot import — untouched, **all seven fail**. `sync-data.mjs`
dequantizes them on the way into `data/`, verifies each one's node/clip/skin
contract survived, and refuses to write one that moved. `tests/test_boot.tscn`
then proves they really do load and really do still carry those contracts.

It costs nothing in the shipped game: Godot re-encodes meshes at import and
never carries the `.glb`. The tool is build-time only and never ships — a
restoration of something `art-src/tools/compress-models.mjs` already uses, not
a new dependency.

Full diagnosis: **`../GODOT_PORT_ANALYSIS.md` §1**. If you ever re-test the
import honestly, delete **both** `.godot/` and `data/` first — stale `.import`
sidecars once made this look like a four-file problem when it was a seven-file
one.

## Building for the web

```sh
node tools/sync-data.mjs                                  # models get dequantized here
"$GODOT" --headless --path . --import                     # twice on a cold .godot/
"$GODOT" --headless --path . --export-release "Web" ../build/web/index.html
```

`build/` is git-ignored. **Threads are off and that is not a preference** —
Godot's threaded web build needs SharedArrayBuffer, which needs COOP/COEP
response headers, which GitHub Pages cannot send. A threaded build is a black
screen on the hub.

**Measured payload, 2026-08-24:** 21.6 MB over the wire — 9.6 MB engine wasm
plus 11.9 MB for the entire game, all four worlds. For comparison the browser
build reaches level 1 in ~7.3 MB and streams the rest.

**Do not trust a size number here that predates the last import-settings
change.** The first export measured 45 MB purely because Godot's default
texture import is lossless and this game's art is already lossy WebP —
`importer_defaults/texture` in `project.godot` sets mode 1 (lossy) and is
worth 23.5 MB on its own.
