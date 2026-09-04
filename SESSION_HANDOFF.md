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
