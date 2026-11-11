# Eeri — producer design doc · game + editor + UGC

**Status:** living producer design doc · promoted 11 Nov 2026 as `PRODUCER_DESIGN.md`  
**Producer:** D-sign  
**Live:** https://mbace1.github.io/Suds-Jack/eeri/ · repo https://github.com/mbace1/eeri  
**Workflow:** [`docs/ACTIVEPRODUCER.md`](docs/ACTIVEPRODUCER.md)

This file does **not** replace the shipped [`DESIGN.md`](DESIGN.md).

### Relationship to existing canon

**Conflict rule:** `PHASING.md` (newest owner direction) and the shipped `DESIGN.md` still win contradictions, except for dated Decision log entries in this file, which override the specific older lines they name. Also defer to `ART_BRIEF.md`, `LEVELCRAFT.md`, `LEVEL2.md`, `EERI_GODOT_HANDOFF.md` §13, `godot/leveleditor/README.md`.

This file only adds **Decision 10 Nov 2026** on campaign polish, UGC, and who the editor is for. It does **not** reopen the Crafted World 80 / Tropical Freeze 20 ratio, the 12-level spine, or "don't rewrite levels 1–12 in the editor" unless a new decision says so.

---

## 1. Vision

A Mario 3 / Yoshi's Crafted World–shaped platformer for a six-year-old on a Tonka × Cat worksite: run, jump, stomp, climb, short machine rides. Browser leads features; Godot is the tablet/editor future (`CLAUDE.md` / handoff).

---

## 2. Pillars

1. **Platformer is the spine; rides are set-pieces** (`DESIGN.md` §0–1 / PHASING).
2. **One verb per level; four beats** (`LEVELCRAFT`).
3. **Generous for kids** — telegraph, no pixel-precision, checkpoints, no timer.
4. **Main campaign + UGC** (**Decision 10 Nov 2026**) — see §3.
5. **Editor is kid-simple and agent-drivable** (**Decision 10 Nov 2026**).

---

## 3. Structure (**Decision 10 Nov 2026** + canon)

| Lane | Role |
|---|---|
| **Main campaign** | Set levels (canon: 12 across 4 worlds today), **polished with editor cooperation** |
| **UGC section** | Additional levels and campaigns players (and agents) add |
| **Editor users** | Mikael, **kids/players**, and **AI agents** |
| **Agent levels** | Go **straight in without approval** |
| **Main levels for now** | **No approval checks either** (still incomplete) |
| **Sharing** | Players can **share UGC levels with each other** |

Canon reminder: editor authors **new** levels (worlds 5+); the twelve existing stay generated from `js/rooms.js` unless Mikael reopens that.

Agent-drivable means **structured data / API** (JSON export the game already understands), not only GUI clicking.

---

## 4. Gaps vs current build

| Design | Build | Gap |
|---|---|---|
| UGC section + player sharing | No UGC hub, no share pipeline | **Largest new product gap** |
| Kid-simple + agent API editor | Stock Godot GridMap editor exists; not kid-facing; not a first-class agent API beyond JSON export | UX + API |
| Main campaign polished via editor | 12 levels in browser; Godot incomplete; editor for 5+ | Polish + port |
| Android Godot black screen | Open in handoff | Device |

---

## 5. Decision log

### Decision 10 Nov 2026 — Campaign + UGC + editor audience
- **Mikael (paraphrase):** Main campaign of set levels polished with editor cooperation, plus a UGC section for additional levels and campaigns. Editor users: Mikael, kids/players, and AI agents — must be kid-simple and agent-drivable (structured data/API). Agent-built levels go straight in without approval; for now main levels need no checks either (incomplete). Players can share UGC levels with each other.
- **Locks:** as above.
- **Extends:** leveleditor / LEVELCRAFT; does not cancel 1–12 generation rule.

---

### Decision 10 Nov 2026 — UGC scope
- **Mikael:** "Full access is ok, but shorter recommended." — UGC can be single levels or full campaigns from day one; editor/UX should nudge toward shorter content.
- **Deferred:** sharing method ("That's for later").

### Decision 10 Nov 2026 — Main level approval
- **Mikael:** "As we polish them, they will get eventually approved." — main campaign levels gain approval individually as they are polished; no upfront gate.

---

## 6. Open questions

1. **DEFERRED (Mikael 10 Nov 2026: "That's for later")** — UGC sharing method (server browser, files/codes, other).
