# The Godot port — what to fix, what to redesign, and what it costs

**Written 2026-08-24, after the split.** This is an analysis and a set of
proposed decisions, not canon. It answers three questions the owner asked:

1. can the Godot build be playable through the hub with all the same features?
2. is the glTF import failure affecting *design*, not just tooling?
3. where would a feature be genuinely **better** in Godot — and if so, should
   it be redesigned now rather than ported first and improved later?

Everything marked **measured** was run against this repo on 2026-08-24.
Everything marked *judgement* is an argument, and the owner's to overrule.

---

## 0. The short version

- **The import blocker is one extension, and it is narrow — and it is now
  FIXED.** `KHR_mesh_quantization`, not webp, not rigging. `sync-data.mjs`
  dequantizes on sync; all seven models import with contracts intact. Free in
  the final build, because Godot re-encodes meshes on import anyway.
- **It is not a design problem.** It is a pipeline problem with a design
  *smell* behind it (§1.4): `assets/3d/` holds compressed deliverables with no
  masters, because the compression tool overwrites in place.
- **The thing that IS a design problem is the download.** Measured: the
  browser build reaches playable in **~7 MB**; a Godot web export starts at
  **~10 MB of engine before any content** and Piritori's real one measured
  **~33 MB over the wire**. For a game whose player is a six-year-old opening
  a hub cabinet on a phone, that is the single biggest usability regression on
  the table, and it is not fixable by optimisation — it is the price of the
  engine.
- **So the honest recommendation is: the Godot port should not replace the
  browser build on the hub.** Ship it as a second cabinet, or as a desktop/
  native build, and keep the web cabinet on the existing build. §4 lays out
  the options.

---

## 1. The import blocker (question 2)

### 1.1 What actually fails — measured, and worse than first reported

A genuinely cold import (`.godot/` **and** the `.import` sidecars removed —
this matters, see §1.5) fails on **all seven** live GLBs:

```
bolt_v1  checkpoint_v1  eeri_v5  excavator_v1
flag_big_v1  flag_v1  token_bolt_v1
```

`EERI_GODOT_HANDOFF.md` §3 first reported four, and said the rigged kid
imported clean. **That was wrong** and is corrected there now. The four-file
figure came from a run where stale `.import` sidecars let Godot skip the files
it had already processed — the exact "a gate that cannot fail is a finding,
not a pass" trap this family of projects keeps writing down.

### 1.2 The cause is one extension, and only one

Every GLB in `assets/3d/` declares:

```
extensionsRequired = ["EXT_texture_webp", "KHR_mesh_quantization"]
generator          = glTF-Transform v4.4.2
```

**Measured, separately:** a GLB requiring only `EXT_texture_webp` (the
pre-compression `excavator_v1` recovered from commit `e8d9e0a`) imports into
Godot 4.7.2 **cleanly** — four webp textures extracted, a real `.scn`
produced. So webp is supported and quantization is the sole blocker.

**And the rig contract survives.** Loading that imported excavator and walking
its node tree returns all eight names the game drives:

```
house · boom · stick · bucket · seat · step · wheels · beacon
```

That is the thing that actually decides whether the first ride machine can
exist in Godot, and it is a yes.

### 1.3 Where it came from, and why it was right

`art-src/tools/compress-models.mjs` runs `gltf-transform quantize` then
`gltf-transform webp`. Its header explains itself well: `assets/3d` had
reached 56 MB, the machines were the cost, most of it float32 vertex data.
Both extensions were chosen specifically because **three.js decodes them
natively with no extra decoder to ship** — Draco and meshopt were rejected for
exactly that reason. For a no-build-step browser game that is the correct
call, and the tool even guards the node/clip contract before writing.

It is not a mistake. It is a browser-specific optimisation that a second
engine does not share.

### 1.4 The one real design smell

```js
if (!DRY) writeFileSync(src, readFileSync(t2));   // overwrites the original
```

The compression is **destructive and in-place**, so `assets/3d/` holds
compressed *deliverables* and there are **no masters**. Recovery from git
history is only a partial escape: `excavator_v1` predates the compression
commit and can be recovered, but `eeri_v5` and `flag_v1` **were born
compressed** — they postdate it, so there is no uncompressed version of the
kid anywhere in the repo.

That is worth fixing on its own merits, independently of Godot: a pipeline
whose only copy of an asset is the lossy one cannot re-target a second
renderer, cannot raise quality later, and cannot change compression choices
without re-running Meshy. *Judgement: masters belong in `art-src/`, and
`assets/` should be generated.* It is not urgent and it is not this port's
job, but it is the reason this problem existed at all.

### 1.5 Fix options

Dequantization is a **data-layout expansion**, not a re-render: it turns
int16/int8 attributes back into float32. Precision already lost at quantize
time stays lost — but that is precisely what the browser build ships today, so
the Godot build would look *identical to the live game*, not worse.

**Crucially it is free in the final build.** Godot does not ship the `.glb`;
it re-encodes meshes into its own format at import and packs those. So
dequantizing into the git-ignored `godot/data/` costs some disk on a developer
machine and **nothing** in the exported game.

| # | Option | Cost | Verdict |
|---|---|---|---|
| A | Restore `gltf-transform` and add a dequantize pass to `godot/tools/sync-data.mjs` | one dev-only npm tool | **recommended** — it is not a new dependency, it is a tool this project already documents and shells out to; it never runs in the game and never ships |
| B | Write a ~150-line dequantizer in `godot/tools/`, no dependencies | our own code to own and test | viable, and honest to the no-dependency rule; more code than the problem deserves |
| C | Stop compressing in place; keep masters, compress only on deploy | pipeline rework, touches the browser build | the right long-term fix (§1.4), wrong thing to do *first* |
| D | Register a `GLTFDocumentExtension` for quantization | most work, most fragile | no |

**DECIDED 2026-08-24: A, and it is done.** `sync-data.mjs` dequantizes on
sync; `test_boot.tscn` proves all seven import with contracts intact. The
owner approved the tool restoration. Original argument, kept for the record:
`CLAUDE.md` §2 says to stop and ask before adding any dependency. The argument that it is a *restoration* rather
than an addition: `compress-models.mjs` already invokes `gltf-transform` and
documents it as project toolchain; it is simply not installed on this machine
any more. It is the exact shape of the `fontTools` exception Piritori already
took — offline, build-time, never shipped.

---

## 2. Feature parity — what "all the same features" actually means

What the browser build has today, and what porting each one costs. **This is
the checklist behind question 1.**

| Feature | Browser build | Port cost |
|---|---|---|
| 12 levels, 4 worlds | `js/rooms.js` — a room *compiler*, code not data | **highest single cost.** §3.6 |
| run / jump / stomp / climb | `js/kid.js`, hand-rolled kinematics on a proved reach budget | medium — and do **not** hand it to Godot physics, §3.2 |
| machine rides (excavator, crane, hoist) | per-machine modules driving named nodes | medium; rig contract confirmed intact (§1.2) |
| 5-lane parallax diorama | `js/layers.js`, real z, `LAYER_TINT` baked | low — Godot does this natively and better (§3.1) |
| fi / en / ja | `js/lang.js`, English per-key fallback | low — Godot `tr()` + CSV is better (§3.4) |
| glyph controls, no key caps ever | `js/glyphs.js`, inline SVG | medium — must be redrawn, §3.5 |
| touch padplate, portrait + landscape | drawn plate + transparent DOM hit areas | medium |
| bolts x/100 · golden 3/3 · blueprints | game state + HUD | low |
| midway checkpoints, infinite retries | `js/level.js` | low |
| per-world clock-out | `js/clockout.js` | low |
| level addressing `#eeri-1-2` | `js/levelid.js` | low — and Godot needs its own answer, §3.7 |
| title screen, `?skip` | `js/intro.js` | low |
| synthesised SFX, never sampled | WebAudio | **a regression risk**, §3.3 |
| dev/FX pack | `dev.html` frames `index.html` | rebuild or drop |
| offline / instant load | no build step, ~7 MB | **cannot be matched**, §4 |

---

## 3. Where Godot is genuinely better — and where it is not

Question 3, taken seriously in both directions. *All judgement unless marked.*

### 3.1 Better: the diorama, and it is not close

`layers.js` fakes depth with five textured planes at authored z and a tint
baked into each painting. Godot gives real cameras, real depth-of-field, and
crucially **real lights and soft shadows**. `ART_BRIEF.md`'s 80% reference is
Yoshi's Crafted World — *"toy-diorama materiality, visible hand-built set,
soft friendly light"* — and soft friendly light is the one thing a flat
unlit browser stack fundamentally cannot do. A single soft directional light
with contact shadows on cutout layers is the closest this project has ever
been able to get to its own stated reference.

**Redesign now, not later:** if the Godot build is going to exist, its
lighting model should be authored deliberately from the start rather than
reproducing the baked-tint flatness it no longer needs. `LAYER_TINT`'s baked
depth haze should probably become real fog, so it responds to the light.

### 3.2 WORSE if done naively: movement. Do not use the physics engine.

Godot's `CharacterBody3D` + `move_and_slide` is the obvious path and it is a
**trap here**. `DESIGN.md` §4 fixes a *proved* reach budget — apex 2.65
tiles, run-jump 4.85 across, every gap proved with a full tile of slack,
**no pixel-precision jumps ever** — and `test/rooms.mjs` (246 checks) proves
every room against those exact numbers.

A physics-engine character is frame-dependent, solver-dependent and
tunable-by-feel. Hand it the levels and the room prover's guarantees stop
being guarantees. *Port `kid.js`'s kinematics literally* — fixed timestep,
scripted arc, same constants — and use Godot only for collision *queries*,
not for integrating motion. Then the existing prover still means something.

This is the single highest-risk item in the port and the easiest to get
wrong, because the wrong version is the one the engine makes easy.

### 3.3 Worse: audio. This one needs an owner decision.

House rule, gated on purpose: **sound is synthesised, never sampled** — a
binary under `assets/audio/` fails `test/dev-menu.mjs` deliberately. That rule
exists because WebAudio makes synthesis trivial and samples are weight.

Godot inverts that. It is excellent at streaming samples and awkward at
synthesis (`AudioStreamGenerator`, filling buffers by hand). Options: port the
synth by hand (real work, worse ergonomics), or **ship samples for the Godot
build only** — which changes a stated rule for one target. *Judgement: samples
are the right call for Godot, but that is the owner's rule to change, and per
`EERI_DEV_PACK.md` "changing the gate is part of changing the decision."*

### 3.4 Better: localisation, input, and UI plumbing

- **`tr()` + a CSV** with a real coverage gate beats a hand-kept JS object.
  Piritori's `tools/check-locale.mjs` already fails on a missing cell, an
  untranslated cell identical to English, and a mismatched format specifier —
  copy it wholesale.
- **`InputMap`** gives gamepad, keyboard and touch actions with remapping for
  free. `DESIGN.md` §5 is controller-first; this is strictly better than
  hand-rolled polling.
- **`Control` anchors + safe areas** handle notches and the 44px floor more
  honestly than absolutely-positioned DOM over a canvas.

### 3.5 Neutral-to-worse: accessibility

Worth saying plainly because it usually goes unsaid. The browser build's
controls are **real DOM buttons** — screen-reader reachable, focusable, and
measurable by the existing gates. Godot draws its own UI and is **not**
accessible to assistive tech in the same way. For this specific game (a
six-year-old, controller-first, no reading required) the practical cost is
low, but it is a real loss and should be a known trade rather than a
discovery.

### 3.6 The biggest unsolved question: levels are code, not data

`js/rooms.js` + `js/parts.js` is a **room compiler**, not a level format.
There is no JSON to import. Three options:

1. **Convert once** — script that walks the JS and emits Godot resources.
   Fast, but forks the levels: two sources that will drift.
2. **Author a real level format** and make *both* builds read it. Correct,
   and the largest single piece of work in the whole port.
3. **Godot reads the JS as data** at build time. Ugly but keeps one source.

*Judgement: (2) is right if the Godot build is the future; (1) is right if it
is an experiment. That depends entirely on §4, which is the owner's call.*
`PHASING.md`'s lane table puts `rooms.js` in **Design/Level**, so this is not
an Engine-lane decision to make quietly.

### 3.7 Small but real: the address must survive

`/eeri/#eeri-1-2` is a shareable link and `DESIGN.md` §4 treats it as a
feature ("what makes one shareable for a playtest"). A Godot web export can
read `location.hash` through JavaScriptBridge; a native build needs
`--level 1-2`. Cheap, easy to forget, and `CLAUDE.md` §5 ("debug affordances
are features") says build it in the same step as levels, not after.

---

## 4. The download — the honest blocker for "playable through the hub"

**Measured, this repo, 2026-08-24:**

| | Payload |
|---|---|
| Browser build, reaching level 1 | `index.html` + `js/` 584 KB · three.js 824 KB · live GLBs 5.0 MB · groundworks layers 908 KB ≈ **7.3 MB** |
| Browser build, all four worlds' layer art | 7.6 MB (streamed per world, never up front) |
| Piritori's real Godot web export | **58 MB on disk**, wasm 37 MB + pck 19 MB; its README measures **~33 MB over the wire** gzipped |

The engine wasm alone compresses to ~9.6 MB. **That is the floor before a
single bolt of Eeri exists**, and it arrives *before the game starts* — where
the browser build streams world 2's art only when world 2 begins.

`CLAUDE.md` (Piritori's, §9) already names this: *"Runs well on a mid-range
Android phone is a phase gate, not a pre-release check... The download is
part of this."*

So "playable through the hub with all the same features" is achievable in
every respect **except** this one, and this one is not an optimisation
problem. Options:

| Option | What the player gets | Judgement |
|---|---|---|
| **Two cabinets** — keep `eeri/` on the browser build, add `eeri-godot/` | phone players keep the 7 MB instant game; the Godot build is there for whoever wants it | **recommended.** Mirrors what already happened with `piritori/` + `piritori-godot/`; costs nothing to try and reverses cleanly |
| One cabinet, Godot replaces browser | one build to maintain, 3–4× the download, slower cold start on a phone | only if the Godot build clearly wins on feel, and only after a real phone test |
| Godot for **native/desktop** only, browser stays web | best of both; Godot's real advantages (light, shadow, controller) land where size does not matter | strong alternative, and the honest home for a 3D diorama |

The deciding evidence should be a **measurement, not this document**: build
the Godot export, put it on a real phone on a real connection, and time it
against the live cabinet. That is a Phase-0 task and it is cheap.

---

## 5. Proposed plan

Ordered so the riskiest, cheapest-to-falsify things happen first.

**Phase 0 — prove the two blockers, before building anything** *(small)*
1. Owner decision on `gltf-transform` (§1.5 option A).
2. Dequantize pass in `sync-data.mjs`; assert all 7 GLBs import and the
   excavator's 8 nodes resolve — extend `test_boot.tscn`.
3. Export the empty-ish project to web, **measure the real payload**, load it
   on a phone. Decide §4 on that number.

**Phase 1 — one level, on foot** *(the 80%)*
4. Port `kid.js` kinematics literally (§3.2), fixed timestep, no `move_and_slide` integration.
5. One level, hand-built, matching `EERI 1-1`'s layout: run, jump, stomp, climb.
6. Godot room prover mirroring `test/rooms.mjs`'s reach budget.
7. Deliberate lighting pass (§3.1) — the first thing that would justify the port.

**Phase 2 — the ride, and the seam**
8. Excavator: mount, drive `boom`/`stick`/`bucket`, dismount, Yoshi rule.
9. `InputMap` + redrawn glyphs (§3.4, §3.5), touch plate, 44px floor.

**Phase 3 — everything that makes it the same game**
10. Level format decision (§3.6) — **needs Design/Level lane, not Engine**.
11. Locale CSV + coverage gate; audio decision (§3.3); addressing (§3.7).
12. Hub deployment per §4's chosen shape.

---

## 6. What I need from the owner

1. **`gltf-transform`** — restore it as a dev-only tool? (§1.5 A) Blocks everything.
2. **Hub shape** — two cabinets, replacement, or native-only? (§4) Decides §3.6.
3. **Audio** — port the synth, or allow samples in the Godot build only? (§3.3)
4. **Is the Godot build the future, or an experiment?** Everything in §3.6
   and §4 hangs off this one answer, and it is the only question here that
   nobody but the owner can answer.
