# Session handoff — Godot parity work

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

**Owner direction, 2026-08-28:** a **separate process/agent is moving `js/`
into this repo**. That migration had **not** landed as of this writing —
`js/flattener.js` and `js/plank.js` still do not exist here, and
`VERSIONS.md` still reads v15.37.

### What that means for you, concretely

- **DO NOT touch `js/`, `assets/`, `art-src/`, `index.html`, `VERSIONS.md`
  in this repo.** Someone else owns that migration. Two agents editing the
  same files is how this project got three forked lineages already.
- **DO read `mbace1/Suds-Jack`'s current `eeri/js/` as reference.** That is
  the real, current game. Working clone at `~/src/Suds-Jack` (may be behind;
  `git fetch origin` and read `origin/main:eeri/js/...` via `git show`).
- **Work only inside `godot/`.** That is what the last session did and it is
  why there was zero collision risk.

### Read the JS via git, not the working tree

`~/src/Suds-Jack`'s checked-out tree is itself behind `origin/main`. Always:

```sh
cd ~/src/Suds-Jack && git fetch origin
git show origin/main:eeri/js/flattener.js
git show origin/main:eeri/VERSIONS.md | sed -n '3p'    # current version
```

---

## 2. Where the Godot port actually stands

**All 14 test scenes green: 272 checks.** Run them all — a previous session
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
kid 19, leveleditor 15, locale 10, pieces 32, playthrough 25, progress 18,
ride 23, robot 38, run 18, shell 19.

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

### 3.1 The flattener has no level data (blocked on the js migration)

`d41d406` ported the *engine code* — `Rigs.flattener()`, `Pieces.Sheet`,
the dwell-timer trigger in `play.gd`, the `hFlatten` hint. What did **not**
come with it is **eeri-1-2's own room data**.

In the real game (v15.45) that room now parks a **flattener + a `sheet`
rect**. This repo's generated level data still describes the **old**
excavator + girder span. So:

- `tests/test_pieces.gd`'s new Sheet checks use a **hand-authored fixture**,
  not `LevelData.load_slug("eeri-1-2")`.
- **`test_pieces.gd`'s EXISTING girder test against that same slug will need
  REWRITING, not just re-running** — the girder is gone from that room in
  the current game.
- After the js migration lands, re-run `node godot/tools/export-levels.mjs`
  and expect that test to fail. That failure is correct.

### 3.2 Not yet ported from Suds-Jack (v15.38 → v15.49)

Roughly in descending order of how much they'd change the port:

- **v15.46 — the tipping plank** (`js/plank.js`). World 2's own gizmo: a
  rigid beam pivoting at its centre, no held verb. Same "answers weight,
  not a button" family as the flattener. Probably the next best slice.
- **v15.44 — per-world dressing off a catalog.** World 1 gets its own.
- **v15.39 — scenery becomes data.** Named as "the whole editor blocker".
- **v15.49 — one authored camera moment per world** (Phase C).
- **v15.45's `Sheet` visual states.** Godot draws a plain grey MultiMesh
  box; js `buildSheetModel()` draws buckled panels, a rivet line, a hazard
  stripe, torn scrap curling off the leading edge, and *changes material*
  once flattened ("read the change"). Deliberately deferred — the mechanic
  is right, the art is a placeholder.
- **v15.41/42/48 — the level editor.** Godot has its own
  (`godot/leveleditor/`), so this is a *comparison*, not a port.

### 3.3 Open question, needs an owner decision (do not guess)

**`js/main.js` gives a ridden excavator free-form boom control at all times**
(`boomUp`/`boomDown`), not only during the dig puzzle. In Godot,
`_boom_node`/`_stick_node` are only ever written by the dig sequence and by
the new untamed work cycle — never by ordinary riding input. Whether that
free play should be ported, or whether the dig/sling context is the only
place DESIGN wants it, is an owner call.

### 3.4 The bigger architectural question: `PORT.md`

`Suds-Jack:eeri/PORT.md` (dated 2026-08-21, two days *before* the split)
describes a **completely different seam** than what this repo does:

> a generator (`eeri/tools/spec.mjs`) emits ONE committed file,
> `spec/eeri.json` — level grids, reach/timing budgets, per-level report
> data — and the port reads **only that**.

It explicitly lists what the port should **never** read: `layers.js`,
`craft.js`, `palette.js` colour values, `glyphs.js`, the pad plates,
`index.html` CSS, `assets/2d/*` — because those are look-and-feel and the
two builds are *allowed to differ* there.

**This repo does not do that.** It keeps a full copy of `js/` + `assets/` +
`art-src/` beside `godot/`, and `godot/tools/export-levels.mjs` /
`export-glyphs.mjs` read straight out of `../js/`. `~/src/eeri`'s own docs
never mention `PORT.md`, `spec.mjs`, or `spec/eeri.json`.

The owner was asked to choose and chose **"not sure yet"**, then directed
the cheap path (migrate js/, keep working). **So this is unresolved and
should not be decided by an agent acting alone.** If PORT.md's design is
ever adopted it is a multi-session refactor touching the pipeline all 272
gates depend on, and it has two unanswered sub-questions (audio and locale
are *content*, not look — should they still cross? PORT.md doesn't say).

---

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
- 272/272 checks green.
- Browser build in *this* repo: still v15.37, awaiting the migration.
