# Working rules — Eeri

Read this before every session. These rules outrank convenience, speed, and
your own judgment about what would be tidier. If a rule blocks you, stop and
ask — do not route around it.

A Mario 3 / Yoshi's Crafted World-shaped platformer for a six-year-old: Eeri
on a Tonka x Cat worksite he can run, jump, stomp and climb across, boarding
machines for short authored rides. Split out of the Suds-Jack monorepo on
2026-08-23 with its full history intact (`git-filter-repo`, same method used
for `mbace1/piritori-eden` on 2026-08-21).

**This repo carries two builds, and as of 2026-08-27 BOTH ARE LIVE WORK —
but in an ORDER: the browser build leads and Godot follows it.**
The browser build (`index.html`, `js/`, `assets/`) is the finished game — all
twelve levels across four worlds — and is the **phone build, played portrait
with the drawn touch pad**. `godot/` is the port, and is the **tablet build,
played landscape on an M2 iPad with a DualSense**.

**This supersedes the 2026-08-24 direction** that the browser build was
"frozen, not dead… do not start co-developing features in both". That rule
existed to stop two lineages drifting, which this repo has already suffered
three times. It is replaced rather than ignored, because the situation that
justified it changed: **the Godot build cannot render on the owner's phone**
(Pixel 10, PowerVR D-Series — `EERI_GODOT_HANDOFF.md` §14 records the
thirty-nine builds that established this, and it is almost certainly an
engine/driver bug, see godotengine/godot#121005). A frozen browser build is
not a yardstick when it is the only thing that runs on a phone.

Godot is still the future. It is now the future of the TABLET first, and of
everything once the renderer question is settled.

### The order of work: JS FIRST, GODOT FOLLOWS

**Owner direction, 2026-08-27.** The browser build is the **upstream**. New
gameplay, new levels, new mechanics are developed there first and the version
number keeps climbing past v15.37. The Godot build then **follows** it, and
its own work is the part the browser build cannot do: **landscape framing and
controller feel**.

So neither build is frozen, but they are not equal partners either:

- **js/ leads.** It is where a feature is designed, played and proved.
- **godot/ follows.** It ports what landed, then finesses for tablet —
  landscape composition, DualSense handling, 3D presentation.
- A feature does NOT get designed twice. If it is new, it goes to js/ first,
  even when the Godot build is the one being looked at that week.

This is what keeps the two from becoming two games. The old fear was drift
between co-developed features; the answer is not to freeze one build but to
give them an ORDER.

### The rule that carries it, and it is what keeps the lineages safe

**CONTENT IS AUTHORED ONCE AND FLOWS. CODE IS NOT SHARED.**

Every content pipeline already runs one way, JS → Godot, generated rather
than copied — so a level, a string or a painting cannot drift by
construction:

| authored in | reaches Godot via |
|---|---|
| `js/rooms.js` (the twelve rooms) | `godot/tools/export-levels.mjs` |
| `js/lang.js` (fi / en / ja) | `godot/tools/export-locale.mjs` |
| `js/glyphs.js` | `godot/tools/export-glyphs.mjs` |
| `js/audio.js` | `godot/tools/export-audio.mjs` |
| `assets/**` | `godot/tools/sync-data.mjs` |

So:

- **Level design, art, translations and audio** — author in the JS/assets
  source. Both builds get it. Never hand-edit `godot/data/`; it is generated
  and git-ignored.
- **Browser build** — bug fixes and PORTRAIT/touch polish. It is the shipping
  game and the one a six-year-old actually plays today.
- **Godot build** — the port, 3D, and LANDSCAPE/controller work.
- **THE HARD LINE: never implement the same gameplay feature twice.** If
  something new is needed in both, it goes into the shared JS source so the
  Godot side inherits it. Two implementations of one verb is exactly the
  drift the old rule was protecting against, and it is the only thing here
  that can still cause it.

What this costs, stated plainly: two sets of gates stay green (5 browser, 14
Godot), and the browser build is no longer a frozen reference for parity
comparisons. Both are acceptable; a second divergent implementation of the
same mechanic is not.

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
