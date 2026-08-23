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
node tools/sync-data.mjs          # copy ../assets -> data/ (manifest + live files)
node tools/sync-data.mjs --check  # gate: fail if data/ has drifted
```

`data/` is git-ignored on purpose — a second committed copy of the manifest
and 13MB of art is how a lineage forks. Run the copy after every clone.

## Run

```sh
godot --path .                                          # play — a status screen only
godot --headless --path . --import                      # first-run import (run twice; a
                                                          #   cold .godot/ errors on pass one)
godot --headless --path . res://tests/test_boot.tscn     # 8 checks
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

## The trap that will eat the first real session

`excavator_v1.glb`, `flag_v1.glb`, `flag_big_v1.glb` and `token_bolt_v1.glb`
fail Godot's built-in glTF import with a `KHR_mesh_quantization` error.
Everything else — including the skinned/rigged kid model and every 2D
layer — imports clean. Full detail and three fix options in
`../EERI_GODOT_HANDOFF.md` §3. Do not re-export these at lower fidelity to
route around it without going through the normal `assets/` seam (bump `v`,
keep the node/clip contract, re-check the browser build's own smoke gate).
