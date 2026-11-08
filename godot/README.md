# Eeri — Godot port

**Status: playable twelve-level port with a native level editor.** Browser
JS/assets remain upstream; the tablet build follows their content. Read
`../SESSION_HANDOFF.md` for current implementation, validation and deployment
status. Use `leveleditor/README.md` for the open/edit/save/play workflow.

**Validated engine:** Godot 4.6.3 (project file declares `4.3` features).
The release engine/templates still need to be pinned together before export.

## Generate runtime data

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
node tools/export-scenery.mjs        # js/scenery.js + artprops.js -> data/scenery.json
node tools/export-palette.mjs        # js/palette.js + ground.js   -> data/palette.json
```

All seven have a `--check` mode that fails on drift instead of writing. Their
outputs (`data/`, `locale/`) are git-ignored on purpose: the sources of truth
are `../assets`, `../js/rooms.js` and `../js/lang.js`, and a second committed
copy is what drifts.

`data/` is git-ignored on purpose — a second committed copy of the manifest
and 13MB of art is how a lineage forks. Run the copy after every clone.

## Run

```sh
godot --path .                                          # play the game
godot --headless --path . --import                      # first-run import (run twice; a
                                                          #   cold .godot/ errors on pass one)
node tools/verify.mjs                                    # seven drift checks + all test scenes
```

The verifier discovers every `tests/test_*.tscn` scene and saves its engine,
source commit, dirty-file status and results in `../build/verification.json`.
Set `GODOT` to the executable path when it is not on PATH. The current branch
was validated with Godot **4.6.3**; older handoff references to 4.7.2 are not
proof of compatibility with that engine. Export templates must match the
engine used for the actual release.

## Current runtime and editor

The port plays all twelve campaign levels, with the kid, rides and jobs,
robots, collectibles, checkpoints, progression, clock-out, localized shell,
audio and landscape controller layout. It consumes generated browser data.
The Layers editor opens campaign rooms as durable scene drafts and supports
save/check/play, checkpoint preview, art search, native undo/redo and reviewed
world-art application back to canonical JS. See [the authoring workflow](leveleditor/README.md).

Campaign gameplay is still authored in `../js/rooms.js`. A gameplay draft can
be played and saved but does not replace that source. New mechanics belong in
the browser first. Physical M2 iPad/DualSense and phone acceptance remain
separate from the headless gates.

## Why the sync step needs gltf-transform

Every model in `../assets/3d/` requires `KHR_mesh_quantization`, which the original port could not import — untouched, **all seven fail**. `sync-data.mjs`
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
