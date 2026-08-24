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
- **The download is the real cost, and it is now measured rather than
  guessed — see §4, which has been rewritten.** A real Eeri web export is
  **21.6 MB over the wire**. Of that, **9.6 MB is the Godot engine** and only
  **11.9 MB is the whole game** — all four worlds, every model. The browser
  build's equivalent full content is ~14 MB, so Godot's content is actually
  *smaller*; the engine is the entire penalty.
- **The first measurement said 45 MB and was a misconfiguration, not a
  verdict.** Godot's default texture import is lossless, so it decoded this
  game's already-lossy WebP and re-encoded it lossless. One import default
  took the pack from 35.7 MB to 12.2 MB. Any future size claim about this
  project should be re-measured before it is believed.
- **Owner direction, 2026-08-24: Godot takes the hub cabinet at feature
  parity**, and is the future for every catalogue port. §4 records what that
  costs and the two things worth doing about it.

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

## 4. The download — measured, and better than first feared

**Measured on a real export of this project, 2026-08-24** (Godot 4.7.2,
`web_nothreads_release`, gzip -9, all four worlds packed):

| | Over the wire |
|---|---|
| `index.wasm` — the engine | **9.6 MB** (37.7 raw) |
| `index.pck` — the whole game | **11.9 MB** (12.2 raw) |
| `index.js` + shell | 0.1 MB |
| **Total** | **21.6 MB** |

Against the browser build, also measured: **~7.3 MB to reach level 1**, with
later worlds streamed on demand, and **~14 MB** for the complete content set.

So the honest comparison is **not** "7 MB versus 45 MB". It is:

- **Content: Godot 11.9 MB vs browser ~14 MB.** Godot's pack is *smaller*,
  because its texture and mesh encoding beats shipping raw WebP and GLB.
- **Engine: Godot 9.6 MB vs browser ~0.8 MB** (vendored three.js).
- **Delivery: Godot arrives all at once; the browser build streams.** This is
  the part that still matters most on a phone — first play costs 21.6 MB
  rather than 7.3 MB, even though the totals are closer than they look.

### The 45 MB scare, and the lesson in it

The first export measured **45.1 MB** with a `.pck` that gzip could not
compress at all (35.7 → 35.4 MB). That was not the engine being fat; it was
**Godot's default texture import being lossless**. Every layer in `assets/2d`
is already lossy WebP, so the default decoded it and re-encoded it lossless —
7.6 MB of source art becoming ~30 MB of pack.

`project.godot` now sets `importer_defaults/texture` to lossy (mode 1, q0.90).
**That one setting is worth 23.5 MB**, more than every other size decision in
this document combined. Piritori found the same class of bug — a 2048px
texture for a face rendered at 584px, 6 MB for nothing.

*The general rule this earns: on this project, a size number that has not
been re-measured since the last import-settings change is not evidence.*

### What is still worth doing

1. **Re-measure on a real phone on a real connection**, not just gzip maths.
   21.6 MB on a good connection is a few seconds; on bad rural 4G it is not.
2. **The engine cost is fixed and unavoidable** — no optimisation reaches it,
   and it is the price of the decision already taken.
3. **Cache aggressively.** A service worker makes the 9.6 MB engine a
   first-visit cost only. The arcade already ships workers for two other
   cabinets, so the pattern exists in the family.
4. **`export_filter="all_resources"` packs unreferenced files** — Piritori
   shipped a 5.9 MB orphan that way. It is deliberate here *only* because no
   scene references a model yet, so a dependency filter would pack nothing and
   the measurement would lie. Revisit when real scenes exist.

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

## 6. Owner decisions — answered 2026-08-24

| Question | Answer | Consequence |
|---|---|---|
| Restore `gltf-transform`? | **yes** | done; all 7 models import (§1) |
| Hub shape? | **Godot takes the cabinet at feature parity** | not two cabinets; §2's table is the parity checklist |
| Audio? | **whatever works — music is placeholder** | samples are fine in the Godot build; §3.3's gated "never sampled" rule does not bind the port |
| Future or experiment? | **the future, for every catalogue port** | settles §3.6: convert levels **once** into a Godot-owned format. The browser build is frozen, not co-developed, so there is no dual-source drift to design around |

**What that last answer removes.** §3.6 worried about two sources of level
truth diverging. With the browser build frozen at parity and retired after,
there is only ever one live source — so the cheap option (convert once) and
the correct option (own the format) become the same option.

**What still needs an owner call, later rather than now:**

- **The reduced-motion / accessibility floor** (§3.5). Godot loses the DOM's
  free accessibility. Low practical cost for this player, but it is a real
  regression and should be a decision rather than a discovery.
- **When the browser cabinet actually switches over.** "Feature parity" is
  defined by §2's table; someone has to call it met, on a phone, playing it.
