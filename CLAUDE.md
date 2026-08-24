# Working rules — Eeri

Read this before every session. These rules outrank convenience, speed, and
your own judgment about what would be tidier. If a rule blocks you, stop and
ask — do not route around it.

A Mario 3 / Yoshi's Crafted World-shaped platformer for a six-year-old: Eeri
on a Tonka x Cat worksite he can run, jump, stomp and climb across, boarding
machines for short authored rides. Split out of the Suds-Jack monorepo on
2026-08-23 with its full history intact (`git-filter-repo`, same method used
for `mbace1/piritori-eden` on 2026-08-21).

**This repo carries two builds.** The browser build (`index.html`, `js/`,
`assets/`) is the finished game — **all twelve levels across four worlds**,
live and playable. `godot/` is a new port that currently has no gameplay in
it at all.

**Owner direction, 2026-08-24: Godot is the future, for this game and for
every game port in the catalogue.** The Godot build takes over the hub
cabinet once it reaches feature parity — not before, because parity is what
makes a real comparison possible.

Until then the browser build is **frozen, not dead**: it is the live game and
it is the comparison source every Godot gate is judged against
(`EERI_GODOT_HANDOFF.md` §10). Do not delete it, do not let its gates rot,
and do not start co-developing features in both — new work goes to Godot.

---

## 1. One part per prompt

Do the one thing asked. Not the thing asked plus the refactor you noticed,
not the adjacent file that looked wrong, not the "while I was in there."

If you spot something else worth doing, name it in your summary rather than
acting on it.

**Commit after each step.** Small, single-purpose commits with a message
that says what changed in plain language.

---

## 2. No new dependencies

Do not add Godot addons, plugins, GDExtensions, npm packages or CDN imports.
The engine, the JS test scripts and a handful of Node tools are the whole
toolchain and that is deliberate — the browser build has run this way for
37 versions without a build step, and the Godot port starts the same way.

If you believe a dependency is genuinely required, stop and ask before
writing any code.

**The one exception, taken 2026-08-24:** `@gltf-transform/cli`, installed
globally and used by `godot/tools/sync-data.mjs` to dequantize models Godot
cannot otherwise import. It is a *restoration* — `art-src/tools/compress-
models.mjs` already documents and shells out to the same tool — it runs only
at sync time, and it never ships with either build. Same shape as Piritori's
`fontTools`.

---

## 3. Lanes — who owns which files

Carried over from the browser build's own convention (it predates the split
and nothing about the split changes it):

| Lane | Owns |
|---|---|
| **Art** | `assets/**`, `art-src/**`, `js/craft.js`, `js/layers.js` paintings, `PAL` colour values, `ASSET_PLAN.md`, `ART_BRIEF.md` |
| **Design/Level** | `js/rooms.js`, `js/parts.js`, `js/level.js`, `js/kid.js`, `js/input.js`, `js/robots.js`, `js/flag.js`, `test/**`, `DESIGN.md` |
| **Engine (Godot)** | `godot/autoload/`, `godot/scenes/` logic, `godot/tools/`, `godot/tests/` |
| **Shared — coordinate first** | `js/main.js`, `js/assets.js`, `js/palette.js` (structure), `assets/manifest.json`, `index.html`, `godot/project.godot` |

`godot/scenes/` art (the diorama, materials) is Art's; the state machine
behind it is Engine's — same split the browser build draws between
`js/layers.js` (Art) and `js/main.js` (Shared).

If a task needs another lane, finish yours and name the handoff. Do not
reach across.

---

## 4. Canon, in authority order

1. Direct instruction in this session
2. `PHASING.md` — current phase, its exit gates, and the tool-reality table.
   **Newest owner direction; wins where it disagrees with anything below.**
3. `DESIGN.md` — what the game does, esp. §4 (level shape, locked counts) and
   §8 (the ordered plan)
4. `ART_BRIEF.md` — the look: Crafted World 80 / Tropical Freeze 20
5. `ART_PIPELINE.md` + `ART_TARGET.md` — the method and the quality bar.
   **Vendored copies** (see the note at the top of each) — the canonical
   originals are shared with Kindling and live in the old Suds-Jack monorepo;
   re-sync by hand if the method changes there.
6. `assets/README.md` + `assets/manifest.json` — the seam
7. `EERI_GODOT_HANDOFF.md` — Godot-specific coordination; creates no new
   canon of its own
8. `VERSIONS.md` — what shipped, and the traps

Newer owner direction beats older docs. If two canon docs disagree, say so
and ask — do not pick one silently.

---

## 5. Debug affordances are features

When adding a system, add the means to test it in the same step:

- URL params for state in the browser build (it already has `?skip` for the
  intro and `#eeri-W-L` level addressing — extend this pattern, don't
  replace it)
- A way to jump straight to a level/state in the Godot port once it has
  levels to jump to
- Never require a console, a keyboard, or a desktop browser to verify
  something works — this game is played on a phone or tablet by a
  six-year-old, and needs to be *testable* the same way

---

## 6. Never touch

- Git history — no rebase, no force push, no amend of pushed commits
- `main` directly for Eeri-only experiments — branch, per
  `EERI_GODOT_HANDOFF.md` §11's account of three separate accidental forks
  this exact project has already produced
- `.godot/` and `godot/data/` — both git-ignored and regenerated
  (`node godot/tools/sync-data.mjs`); never hand-edit or commit either

---

## 7. When stuck

Two failed attempts at the same problem means stop. Do not try a third
angle, do not add a dependency, do not rewrite the surrounding system.

Report: what you tried, what happened, what you think is actually wrong.
The `KHR_mesh_quantization` failure (`EERI_GODOT_HANDOFF.md` §3) is the
worked example: named and measured before it was fixed, which is why the fix
was three lines of tooling rather than a re-export that would have quietly
changed canon art.

---

## 8. The gates

**Browser build** (unchanged from the monorepo; still the comparison
source):

Paths moved up one level in the split — anything copied from the old
monorepo saying `eeri/test/...` means `test/...` here, run from the repo root:

```sh
node test/rooms.mjs                                 # the room prover
node test/fx-smoke.mjs                              # the FX spec, pool, inference
node test/dev-menu.mjs                              # the dev pack's contract
NODE_PATH=$(npm root -g) node test/smoke.cjs        # the game
NODE_PATH=$(npm root -g) node test/playthrough.cjs  # a bot finishes every level
```

**Godot port** (new):

```sh
cd godot
NODE_PATH=$(npm root -g) node tools/sync-data.mjs --check  # the data seam hasn't drifted
"$GODOT" --headless --path . --import                      # run twice on a cold .godot/
"$GODOT" --headless --path . res://tests/test_boot.tscn    # 18 checks
```

`NODE_PATH` is how `sync-data.mjs` finds the global `gltf-transform` without
shelling out. To re-test the glTF import honestly, delete **both** `.godot/`
and `data/` first — stale `.import` sidecars once hid three of seven failures.

`$GODOT` is the 4.7.2 console binary. Add `test_rooms`/`test_playthrough`
equivalents as gameplay lands (§6 of the handoff), and never remove a
browser-build gate while its Godot equivalent is unproven — a gate that
cannot fail is a finding, not a pass, and a build with no comparison at all
is worse.
