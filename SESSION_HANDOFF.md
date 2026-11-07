# Eeri — shipping plan and current handoff

**Audited 2026-11-07. Goal: make the editor useful for production, polish the
existing twelve-level game, and ship reproducible browser and tablet builds.**

This is a planning and evidence update. The older September handoff is preserved
below as history. Its version numbers, missing-feature lists and test counts
must not be used as current status.

## Recommendation

Finish one reliable editing loop and one polished, playable world, then apply
that standard across the existing campaign. Start by recovering work that is
already deployed but missing from source. Keep browser portrait/touch and Godot
landscape/DualSense as the two supported experiences, as `CLAUDE.md` directs.

Preserve the established content flow for this release: JS/assets lead and
Godot consumes generated data. Do not bundle the unresolved `spec/eeri.json`
architecture migration, new worlds, new dependencies, or a new visual direction
into the polish work. The reference remains Crafted World 80 / Tropical Freeze
20, with Mario platforming grammar and a friendly construction-site cast.

## Repository and deployment map

| Surface | Observed state | Role in the plan |
|---|---|---|
| [`mbace1/eeri` main](https://github.com/mbace1/eeri/tree/e7384ca98e0835469b277c224d78f4fec0e52c8a) | HEAD `e7384ca`, October 12; browser log v15.69; JS game, assets, Godot runtime and editor | Development source; put recovered work here first |
| [`Suds-Jack/main/eeri`](https://github.com/mbace1/Suds-Jack/tree/4bf686942e1ab06e436a92a33f4cb7c343a1628c/eeri) | Older game copy, plus later Hub integration; not identical to standalone source | Historical/integration copy; stop treating it as another development lane |
| [`Suds-Jack/gh-pages/eeri`](https://github.com/mbace1/Suds-Jack/tree/933c8e63faed89c8bae3d616be2ec630b7122578/eeri) | Deployed browser v15.70; `hub/versions.json` agrees | Current public browser release, ahead of source in specific files |
| [`Suds-Jack/gh-pages/eeri-godot`](https://github.com/mbace1/Suds-Jack/tree/933c8e63faed89c8bae3d616be2ec630b7122578/eeri-godot) | Exported HTML/JS/PCK/WASM, no Godot source or source-SHA manifest | Published tablet/Web build; provenance needs to become explicit |
| `eeri-godot-tiny`, `eeri-godot-pirtest` on `gh-pages` | Diagnostic exports | Keep separate from the campaign route |
| `Kindling` and Suds root art documents | Shared art-method context; no separate Eeri implementation found | Reference only; no unrelated game work |

Discovery covered the connected account's repositories and Eeri-related paths,
branches, open PRs and deployed trees. No separate Eeri editor repository was
found. Browser and Godot editors both live in `mbace1/eeri`.

The public browser URL `https://mbace1.github.io/Suds-Jack/eeri/` returned 200.
The actual Hub -> Eeri link -> Start -> grounded level-1 flow was verified in
Chromium with touch emulation, no page errors and the live Toko hooks present.
`https://mbace1.github.io/eeri/` returned 404. Keep the working Hub route for
this release; enabling separate Pages hosting is unnecessary to ship polish.
The Hub catalogue's frozen-v15.49 comment and note are stale: the deployed log
and version record say v15.70.

## What is actually done

- Twelve compiled levels, four worlds, the pump/drain job, sheet/flattener,
  tipping plank, girder placement, ladders, pipes, progression and clock-out
  systems exist. Do not rebuild features from the September missing-work list.
- Godot has GridMap terrain, prefab entities, a seven-layer rail, half-tile
  snapping and numerous approved art cutouts. Local editor suite: **99/99**.
- Local Godot suite: **15 scenes, 383 passed, 0 failed**. This includes the
  twelve-level simulation suite. These are automated runtime/model checks,
  not evidence that a child can finish the real input flow.
- Cheap browser checks passed: rooms **246**, FX **31**, dev contract **36**;
  World 3/4 structural check passed. The report tool prints **11 SHIP, 1 THIN**
  (`2-2`, short estimate), which is a diagnostic, not a release verdict.
- Browser title -> Start -> movement was exercised locally through UI input,
  with no page errors in the visual audit. Portrait shots cover all four
  world openings. Godot rendered shots cover Worlds 1, 3 and 4 at 1180x820.

The audit machine has **Godot 4.6.3**, while project documentation names 4.7.2.
Godot shots use the compatibility renderer, matching the Web renderer setting.
Final release evidence must use the explicitly chosen shipping engine version
and actual devices. Audio fell back to a dummy device during screenshots;
sound quality and controller feel were not evaluated.

## Findings that determine the order

**Source and release have split again.** After normalizing line endings and
module version tokens, the deployed browser copy has substantive changes absent
from standalone main in `js/main.js`, `index.html` and `dev/inspector.js`:
Toko pause/recap hooks, `table: true`, valid CSS comments, responsive editor
layout fixes, and the sheet/flood/plank/pump entries in its reference palette.
The live v15.70 log also claims Godot editor support for the sheet, flattener,
pump and flooded trench: **110 editor / 394 total checks**. Checked-in main
still has 99 editor / 383 total checks, four machine kinds and no `F` palette
tile. That Godot source was not found in the connected branches or deployed
tree. Recover its actual commit/worktree if available before recreating it;
otherwise implement the missing slice and prove it anew. A deployed changelog
claim alone does not establish that source or a reproducible export exists.

**Editor placement is ahead of persistence.** A clean temporary Godot scene
probe placed a spruce on FAR, exported successfully with no validation problems,
and found **no `treeSpruce` in the output**. `LevelExporter` serializes gameplay
markers but not art rows/layers. The same probe removed spawn and flag: export
reported three problems **and still overwrote the JSON file**. Validation must
protect the last valid export, not merely warn after writing it.

**The authoring loop is unfinished.** Godot export is an EditorScript Run
operation into ignored `data/levels`; playtesting a new slug needs manual
wiring. There is no campaign-level import/edit/save workflow. The current
exporter also omits sheet/flood/planks and finish/gate authoring, and hardcodes
machine track/verbs. These gaps matter more than adding more prop prefabs.

**The browser editor is an inspector and partial placer.** Source reproduces
Times New Roman and a static wrapper because `//` comments invalidate its
first CSS rule; the live site already fixes that. Terrain, machines and many
gizmos are reference entries. Whole-world export concatenates original scenery
rows and initially placed rows rather than reconstructing moved/deleted state.
Moving a live entity updates its model coordinates; undoing that move only
restores its mesh. It should remain a useful phone inspection/FX tool while the
Godot editor becomes the primary production editor.

**Visual completion differs substantially between engines.** Godot's ordinary
and golden pickups still use colored box MultiMeshes (`play.gd`), despite real
pickup assets existing. World 4 still builds a large procedural loading-dock
wall in `scripts/dressing34.gd` behind/alongside the newer cutouts. Its night
grass is bright and its earth palette differs from the browser. Browser World
3 showed horizontal artifacts through a tree cutout; the source image is clean,
so isolate overlap/depth/alpha handling before regenerating art. These are
runtime integration and presentation problems, not a shortage of concepts.

**Browser release checks are not currently demonstrated green.** The initial
smoke run reported a level-1 progression failure, followed by checks inspecting
the wrong room, plus a flatten-pass failure. The concurrent twelve-level bot
run failed level 1 at x=83.7 of exit 92 after its five-minute budget, with a stall
recorded at 76. Both long runs were stopped after this evidence rather than
running an hour of cascading checks. Software rendering and contention are
possible contributors, not a diagnosis. The subsequent isolated level-1 run
**passed 3/3 checks with zero ride losses and no page errors**. This weakens the
case for a gameplay defect, but does not establish a green full browser suite.
Record and fix the test/environment cause before treating reruns as evidence.

## Delivery order and acceptance gates

Effort below is a rough estimate in focused developer-days, excluding waiting
for device playtests or design decisions. Deliver each row in small reviewed
slices; do not accumulate the whole plan on a branch.

| Order | Outcome / work | Primary files or seam | Acceptance evidence | Effort |
|---|---|---|---|---|
| **P0 / EERI-01** | Reconcile live v15.70 into source, locate missing Godot editor changes, fix misleading current docs/catalogue status | Three live-only browser files; Godot editor source; this handoff; Hub Eeri entry only | A source SHA accounts for every shipped change; normalized diff explains remaining Hub-only differences; no lost browser/Hub behavior | 1–2 |
| **P0 / EERI-02** | Establish reliable checks and release provenance | Browser smoke/bot timing and transition assertions; Godot runners; CI/release tooling | An isolated reproducible result for the first browser failure; full browser smoke, 12-level playthrough and clock-out pass on one head; all Godot scenes and generation checks pass; artifact records SHA/version/engine | 1–2 |
| **P1 / EERI-03** | Make saved authoring durable and safe | `leveleditor/level_exporter.gd`, export wrapper, authored scene location | Invalid levels never overwrite valid exports; authored scenes survive a clean clone/regeneration; actionable validation selects the offending node | 1–2 |
| **P1 / EERI-04** | Make scenery survive editing | Marker properties; scenery serialization/import/apply adapter | Place/move/delete/duplicate a cutout on every layer, change size/flip/opacity, undo/redo, save, close, reopen and play: same result and same layer; unrelated rows remain byte-stable where possible | 2–3 |
| **P1 / EERI-05** | Complete the game jobs and editor controls | MeshLibrary, machine kinds, sheet/flood/plank/job/finish/gate markers | Author each of the five existing jobs; correct machine type and work range; unsupported/missing job dependencies fail clearly; recover v15.70 work before rewriting it | 1–2 |
| **P1 / EERI-06** | Close Open -> Edit -> Validate -> Play -> Return | Existing editor plugin/dock, temporary preview roster/start slug; scene/import adapter | An author opens an existing room/reference, changes dressing and one gameplay object, plays from spawn or checkpoint, returns to the same selection, saves/reopens, without a script editor or console | 2–3 |
| **P2 / EERI-07** | Land completed polish already waiting in PRs | #17 -> #18, then independent #16/#15 as reviewed | Refresh on current main; palette and fringe render correctly in all four worlds; model node/clip contracts survive; reproducible before/after shots and payload measurement | 1–2 |
| **P2 / EERI-08** | Bring visible gameplay objects to the art standard | Godot pickups, sheet/plank/pump/rig presentation, World 4 dressing, browser cutout depth/alpha | No yellow-box pickup stand-ins or dominant grey depot slabs in reviewed scenes; obstacle states visibly change; World 3 artifacts isolated/fixed; no collision/readability regression | 2–4 |
| **P2 / EERI-09** | Polish the on-foot loop and machine handoffs | Input, kid, camera, hints, checkpoint, machine interaction in upstream JS then Godot parity | A new player can start, run/jump/climb/stomp, read/board a machine, complete its job, recover from a mistake and clock out; capture hesitation/missed-input/retry evidence on phone and iPad | 2–3 |
| **P3 / EERI-10** | Apply the proved World 1 standard to the campaign and release | All twelve rooms; UI/locales/saves; export/Hub deploy | All twelve real control paths verified; each world's clock-out and saved progress checked; screenshots and short clips reviewed; exact live Hub route tested after publication | 2–3 |

Planning envelope: roughly **3–5 focused weeks for one developer**, with scope
and estimates revised after EERI-01/02. The full editor may need more work if
campaign authoring requires a broader content adapter. Do not disguise that
architecture work as a quick dock-button change.

### Editor scope and source-of-truth guardrail

Use the existing Godot GridMap, Inspector, scene undo and Layers plugin. Add a
small level picker, validation/export/play controls, searchable asset palette
with thumbnails, layer visibility/lock/solo, and clear unsaved-change state.
Preserve selection and camera when returning from play. Gameplay objects stay
on PLAY; scenery can choose its depth. Test duplicate/undo/redo explicitly:
the current child-entered-tree snap hook may otherwise treat restoration as
a fresh placement.

For this release, keep `js/rooms.js` and `js/scenery.js` authoritative for the
twelve shipped levels. Import their compiled layout as editor reference and
apply deliberate changes back through an explicit adapter/diff. Start with
scenery, whose row format already exists; validate any full terrain conversion
as its own slice. Store authored `.tscn` scenes in a committed location, never
only in generated `data/`. Scratch-level exports and play previews can be
temporary. Generated output must not silently become a second canonical source.

The unresolved neutral-spec architecture from the historical handoff remains a
separate decision. It is not necessary to settle it before fixing safe exports,
scenery round-tripping, job coverage and one-button scratch-room playtesting.

**Editor usable gate:** record a ten-minute session doing the complete loop
above, including one invalid job, undo/redo, save/reopen and play. The author
must not need to edit scripts, wire a slug by hand, paste coordinates, or repair
generated data. More prefab-count tests alone do not close this milestone.

### Gameplay and visual priorities

1. Finish World 1 as the benchmark: start through its three levels to clock-out,
   with readable routes, hazards, prompts and a forgiving recovery loop. The
   age-six experience and the on-foot game decide acceptance.
2. Review camera, player silhouette, landing/contact, run/jump transitions,
   collectible readability, machine boarding/dismount, job feedback and retry
   together at **390x844 browser portrait** and **1180x820 Godot landscape**.
   Keep card/felt/balsa surfaces coherent and let interactive objects lead the
   eye. Add effects at real gameplay events only after a moving comparison.
3. Repair rendering/integration before generating replacement assets. The tree
   source image is sound. Many large machine GLBs are staged/unused; do not
   optimize the repository's largest files without a player network trace.
4. Extend the benchmark to each world. World 2's pump already provides its own
   job. Worlds 3/4 still repeat dig/span/crane patterns; record a design choice
   before adding RISE/AIM or another machine. Recommend polishing their existing
   layouts and presentation first; a new verb is a separate authored slice,
   including onboarding, hazards, input, art and both-runtime verification.
5. Do not lengthen/cut levels from estimates or an expert replay alone. PR #15
   correctly separates first-play timing from learned play. Use unfamiliar
   players and observe repeated failure, idle walking and uncertainty.

### Existing PRs to resolve

| PR | Plan |
|---|---|
| [#15 level-length measurement](https://github.com/mbace1/eeri/pull/15) | Refresh as documentation; retain the correction that no redesign is justified by expert timings |
| [#16 prop optimization](https://github.com/mbace1/eeri/pull/16) | Validate and land the reported ~1.5 MB saving on flag/large flag/checkpoint; retain manifest-version consistency check; do not optimize unused machine stock by size alone |
| [#17 fringe tint](https://github.com/mbace1/eeri/pull/17) | Review the four-world picture and merge before #18; resolve browser gate failures on the final head |
| [#18 palette export](https://github.com/mbace1/eeri/pull/18) | Depends on #17; adopt generated palette rather than retyping colors into Godot; check every world with actual rendering |

All four were open at audit time. Old PR check counts and local Windows image
paths in PR bodies are historical evidence, not current CI or usable review
artifacts. Attach portable pictures and rerun on the integrated head.

## Release definition

- A clean checkout regenerates levels, scenery, locale, glyphs, audio and assets
  with matching `--check` results. CI runs the required browser checks and every
  Godot scene, not just boot. Unknown exporter fields fail loudly.
- A tested source SHA builds both release targets. Record version, SHA, engine,
  artifact digest and test results together; keep diagnostics on separate URLs.
  Replace the hand-copied deployment habit with a repeatable Eeri-only publish
  step into the existing Hub. Do not overwrite unrelated cabinets or regenerate
  the entire live versions table from a stale main tree.
- On the supported phone: title, touch movement, simultaneous jump/run, pause,
  app background/resume, sound unlock, checkpoint recovery, save/reload and
  screen fitting. On the M2 iPad: landscape layout, DualSense focus/input,
  disconnect/reconnect, pause/resume and the same progression loop.
- Check fi/en/ja, readable control glyphs, 44px touch targets, reduced motion,
  shallow/deep-water distinction, collectible contrast and no hidden inputs.
- Capture a clip of each machine job, each world completion and representative
  movement. Check real-device loading, frame pacing and memory during a full
  world; choose a measured performance budget before calling performance done.
- Publish the tested artifacts, then follow the actual Hub -> Eeri -> Start ->
  gameplay -> Home route with both a fresh and returning browser. Verify the
  public version and retain a rollback artifact. A merge is not a release.

The historic Pixel/PowerVR Godot black screen is a known device limitation,
not a reason to block the working phone browser build or restart the same
renderer investigation during a polish pass.

## First executable slice

**EERI-01, followed immediately by export safety in EERI-03:** recover and
commit the live browser fixes into source, locate/recover the missing Godot
editor source, and make invalid export preserve the last good file. Close this
slice with the version/source diff and a valid-export -> invalid-export ->
reopen demonstration. EERI-02 can investigate the browser baseline alongside
this read-only reconciliation; release and gameplay changes wait for its result.

The next slice is scenery persistence, then the recorded editor loop. This
gives the art/gameplay pass a tool it can actually use and a reliable source
tree from which to ship.

## Evidence from this audit

Audit artifacts are in `/workspace/eeri-audit/` in the review workspace:
phone title and World 1–4 shots, browser-editor shot, Godot World 1/3/4 shots,
test summaries and the clean export probe. These are baseline pictures, not
new art. Browser gameplay images use debug level selection only to set up the
scene; the separately recorded title/start/movement path uses UI input.
All six existing asset/content generation `--check` commands also passed after
regeneration. See `summary.json` for the final machine-readable result and
`live-entry.log` for the public entry-path check.

## Historical record — Godot parity handoff, 2026-09-04

**Written 2026-09-04, at the end of a long Godot-parity session.**
Read this, then `CLAUDE.md`, then `EERI_GODOT_HANDOFF.md` §12 (the parity
status table). This file is the *situation*; those two are the *rules* and
the *detail*. If this file disagrees with them, they win and this file is
stale — say so rather than following it.

---

## 1. THE ONE THING TO KNOW FIRST: the repo forked

There are **two copies of Eeri's browser build**, and they are not the same:

| Where | What | Version |
|---|---|---|
| `~/src/eeri/js/` (this repo) | frozen since the split | **v15.37**, 2026-08-21 |
| `mbace1/Suds-Jack` → `eeri/js/` | kept moving for a week after | **v15.49**, 2026-08-28 |

This repo was split out of the Suds-Jack monorepo on 2026-08-23, but the
monorepo's own `eeri/` folder kept receiving real commits — twelve versions
of genuine new content, not just fixes. Nobody noticed until 2026-08-28.

**Owner direction, 2026-08-28:** a separate process was moving `js/` into
this repo. **THAT MIGRATION HAS NOW LANDED** — commit `0d46430`, "Bring the
browser build current: v15.37 -> v15.49", arrived while this handoff was
being written. `js/` here is now the real, current game and the table above
is history rather than a live warning.

**What that migration did NOT do**, and what this session fixed after it:
it brought `js/` across but not the Godot-side consequences. See §3.

### What that means for you, concretely

- `js/` in this repo is now **v15.49 and authoritative**. Read it directly.
- `mbace1/Suds-Jack`'s `eeri/` folder is now the stale copy. Do not edit it,
  and do not read it as canon — it is only useful as history.
- Still worth checking `git log --oneline -3` on both before assuming: the
  fork happened once and nothing structural prevents it happening again.

---

## 2. Where the Godot port actually stands

**All 14 test scenes green: 275 checks.** Run them all — a previous session
ran only `test_boot.tscn` (18 of the 272) for several sessions and did not
notice.

```sh
GODOT="/c/Users/Mikael/Documents/Codex/2026-08-20/can-you-connect-to-godot/tools/godot/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe"
cd ~/src/eeri/godot
for t in tests/*.tscn; do
  echo "$t: $("$GODOT" --headless --path . "res://$t" 2>&1 | grep -E '^[0-9]+ passed')"
done
```

Per-scene counts as of this handoff: audio 6, boot 18, dig 12, gizmos 19,
kid 19, leveleditor 15, locale 10, pieces 35, playthrough 25, progress 18,
ride 23, robot 38, run 18, shell 19.

`test_playthrough` runs 12 full level simulations and takes **~3 minutes** —
give it a generous timeout or run it in the background.

### Landed this session (all pushed to `origin/main`)

| Commit | What |
|---|---|
| `ca078e1` | terrain: strata bands, deep earth (replaced flat brown slabs) |
| `5a9a974` | grass is a separate asset — felt lip + fringe + shadow, per-band detail maps |
| `ebd02ea` | landscape is controller-only (no Game Boy plate); HUD matched to `index.html` |
| `a22b103` | pause menu + banners match the browser build; controller focus fixed |
| `67e3ce4` | the hint pill — full `setHint` cascade parity |
| `3ebaa83` | the clock-out building + the gate walk it belongs to |
| `95b4516` | an untamed machine is a threat again (work cycle + danger window) |
| `d41d406` | the flattener (World 1's 2nd machine, v15.45) — **engine code only** |

---

## 3. What is NOT done — the honest list

### 3.1 What the js migration broke, and what fixing it revealed

The migration (`0d46430`) brought `js/` to v15.49 but did not touch
`godot/`. Regenerating the level data (`node godot/tools/export-levels.mjs`)
then failed **five** checks across three scenes. All are now fixed, but the
*way* they failed is worth knowing:

- **`export-levels.mjs` silently dropped two new fields.** It carries an
  explicit allow-list (`bank`/`wall`/`girder`/…), so `sheet` (v15.45) and
  `planks` (v15.46) simply never reached Godot. **If a future js version
  adds a part, this file must be edited or the part vanishes without an
  error.** Same for `level_data.gd`, which parses its own allow-list —
  `planks` was added to the exporter and still didn't work until
  `level_data.gd` learned to read it.
- **The girder moved rooms.** `eeri-1-2` was the girder level; v15.45
  replaced its whole puzzle with the flattener + sheet. `test_pieces.gd`
  now points at `eeri-2-2`, which still spans one.
- **A real bug in my own flatten trigger.** I had approximated the drum's
  position as the machine's centre. The sheet is *solid terrain*, so the
  machine parks a body-width short and the centre never reaches it — the
  bot drove at it for 240 simulated seconds. `Machine.bucket_x()` now
  models the ~1.1-tile reach the drum actually has. **The comment admitting
  it was an approximation was written two sessions before the gate could
  catch it; the approximation was simply wrong.**
- **Level 4 was unfinishable** because the tipping plank did not exist.
  Ported now (§3.2 below).

### 3.2 The tipping plank IS ported (v15.46)

`scripts/plank.gd`, wired into `play.gd` (build/step/sync/teardown) and
into `kid.gd`'s platform pass. This forced one small generalisation that
`js/plank.js` explicitly predicts: **`top()` now takes an x**. A hoist's
deck is flat so it ignores the argument; a tipped plank's genuinely is not.

Verified by picture (a tipped board over the open trench) and by the bot
finishing Level 4.

### 3.3 Still not ported from v15.38–v15.49

- **v15.44 — per-world dressing off a catalog.** World 1 gets its own.
- **v15.39 — scenery becomes data.** Named as "the whole editor blocker".
- **v15.49 — one authored camera moment per world** (Phase C).
- **v15.45's `Sheet` visuals.** Godot draws a plain grey MultiMesh box; js
  `buildSheetModel()` draws buckled panels, a rivet line, a hazard stripe,
  torn scrap curling off the leading edge, and *changes material* once
  flattened ("read the change"). The mechanic is right; the art is a
  placeholder. Same for the plank: one brown box, where js draws a scored
  deck with seams, an underside, a fulcrum stub and painted end caps.
- **v15.41/42/48 — the level editor.** Godot has its own
  (`godot/leveleditor/`), so this is a *comparison*, not a port.

### 3.4 Open question, needs an owner decision (do not guess)

**`js/main.js` gives a ridden excavator free-form boom control at all times**
(`boomUp`/`boomDown`), not only during the dig puzzle. In Godot,
`_boom_node`/`_stick_node` are only ever written by the dig sequence and by
the untamed work cycle — never by ordinary riding input. Whether that free
play should be ported, or whether the dig/sling context is the only place
DESIGN wants it, is an owner call.

### 3.5 The bigger architectural question: `PORT.md`

`eeri/PORT.md` (now in this repo, dated 2026-08-21) describes a
**completely different seam** than what this repo does:

> a generator (`tools/spec.mjs`) emits ONE committed file, `spec/eeri.json`
> — level grids, reach/timing budgets, per-level report data — and the port
> reads **only that**.

It explicitly lists what the port should **never** read: `layers.js`,
`craft.js`, `palette.js` colour values, `glyphs.js`, the pad plates,
`index.html` CSS, `assets/2d/*` — because those are look-and-feel and the
two builds are *allowed to differ* there.

**This repo does not do that.** `godot/tools/export-levels.mjs` and
`export-glyphs.mjs` read straight out of `../js/`, and §3.1 above is a
direct consequence: an allow-list that silently drops new parts is exactly
the failure mode `PORT.md` designed `spec/eeri.json` to prevent.

The owner was asked to choose and answered **"not sure yet"**, then directed
the cheap path. **Unresolved — do not decide it alone.** It is a
multi-session refactor touching the pipeline all 275 gates depend on, and
it has two unanswered sub-questions (audio and locale are *content*, not
look — should they still cross? `PORT.md` doesn't say).

## 4. How to work on this repo

### Read first, in this order
1. `CLAUDE.md` — the working rules. They outrank convenience and your own
   judgment. §1 "one part per prompt", §3 lanes, §6 never-touch.
2. `EERI_GODOT_HANDOFF.md` §12 — the parity table + "Closed since, and what
   it cost to find". That section is deliberately unflattering; keep it so.
3. `PHASING.md` / `DESIGN.md` — canon, in the authority order `CLAUDE.md` §4
   sets out.

### The house rule that has caught the most bugs

> **A gate certifies WORKS and cannot see LOOKS.**

Any scene/art change ends in a **picture**. Use the harness:

```sh
cd ~/src/eeri/godot
EERI_SHOT=/c/Users/Mikael/src/eeri/godot/tools/_shot.png \
EERI_SHOT_DRIVE=run \
"$GODOT" --path . res://tools/shot.tscn --resolution 1180x820
```

`EERI_SHOT_DRIVE` values: `run`, `jump`, `climb`, `at` (+`EERI_SHOT_AT=x`),
`mount`, `ride`, `dig`, `stomp`, `bolts`, `wary`, `gate`. Also
`EERI_SHOT_LEVEL`, `EERI_SHOT_LANG`, `EERI_SHOT_TITLE`, `EERI_SHOT_PAUSE`,
`EERI_SHOT_GOLDEN`, `EERI_SHOT_CLOCKOUT`, `EERI_SHOT_GOT9`.
Output is git-ignored (`/godot/tools/_*.png`).

Screenshot at the **target device's** resolution — the iPad is 1180×820
landscape. Not the desktop's.

### The mistake this project keeps repeating

**Numbers written from memory instead of read off the file.** Three separate
catches in two sessions:
- `PAL_STEEL` shipped a 3-entry array missing `STEEL[0]`, plus a mistyped
  third value; `PAL_INK` and `PAL_GREEN_DK` each off by a hex digit.
- `Machine.SPEC` gave skidder and loader *invented* top speeds and body
  sizes. `js/excavator.js` fixes `TOP`/`ACCEL`/`hw`/`h` as **module-level
  constants** shared by every Excavator-classed machine; only `Crane` has
  its own — and those were off too.

**Always `git show origin/main:eeri/js/<file>` and read the actual value.**

### Other traps already paid for
See the **Godot** section of `~/.claude/CLAUDE.md` (global, shared across
projects) — `Input.action_press` vs `parse_input_event`, MultiMesh instance
colours needing `vertex_color_use_as_albedo`, the 100MB GitHub limit, the
PowerVR black screen, `EditorScript` not being instantiable headlessly.

One more, learned this session: **a `Label` handed to `add_child()` before
being moved into its real container stays where it first landed** — Godot
will not silently reparent. Hit twice in one session (HUD lines stacked at
0,0; the pause card's title/rows).

---

## 5. Environment

```sh
GODOT="/c/Users/Mikael/Documents/Codex/2026-08-20/can-you-connect-to-godot/tools/godot/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe"
GH="/c/Program Files/GitHub CLI/gh.exe"     # not on PATH
```

- Note the **doubled folder name** in `$GODOT` — not a typo.
- Use the `_console` binary or you lose every error message.
- `python` on PATH is the hermes venv (no Pillow). For image work:
  `~/.nano-banana/venv/Scripts/python.exe`.
- `git push` works non-interactively. There are **no PRs** on this repo —
  it works straight off `main`.
- `--import` needs **two passes** on a cold `.godot/`. If a `class_name`
  isn't found, run `--headless --path . --import` once to rescan.

## 6. State at handoff

- Working tree **clean**, all work **pushed** to `origin/main`.
- HEAD: the `.uid` commit on top of `d41d406`.
- 275/275 checks green.
- Browser build in *this* repo: **v15.49**, migration landed.
