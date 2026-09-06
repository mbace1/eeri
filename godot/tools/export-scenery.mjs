#!/usr/bin/env node
// EERI — carry the SCENERY rows and the art catalogue across to Godot.
//
// The rule this repo lives by is in CLAUDE.md: **content is authored once and
// flows; code is not shared.** Levels flow (export-levels.mjs), strings flow,
// glyphs flow, audio flows, the art manifest flows. Scenery never did — and
// on 2026-09-06 that bill came due twice over:
//
//   · everything the art lane made this week — World 3's felt treeline, the
//     lamps, World 1 and 2's dressing vocabulary, every piece the rebuilt
//     level editor can place — was invisible to the port;
//   · and `godot/scripts/dressing34.gd`, a hand-port of the OLD
//     js/world34-dressing.js, was still drawing the fourteen flat green discs
//     the browser build deleted in v15.55. Two implementations of one thing,
//     drifting, which is the single failure mode the rule exists to prevent.
//
// So this is that seam. It emits ONE file, and it emits it by importing the
// real modules rather than by transcribing them, for the same reason
// export-levels.mjs runs the real compiler: a hand-copied list is a second
// source of truth, and a generated one cannot drift because regenerating is
// the only way to change it.
//
// Writes:  godot/data/scenery.json
//            { art: { name: {file,label,layer,h} … },
//              props: { name: {label,layer,fields} … },
//              worlds: { groundworks: [row…], … } }
//
// Rows are emitted THROUGH `withDefaults`, so every field a row leans on is
// present in the file. Godot then needs no copy of the defaults table — which
// is exactly the trap `export-levels.mjs` fell into with its allow-list, where
// a new part reached the port as `null` with no error until two separate files
// learned about it (SESSION_HANDOFF §3.1). There is no allow-list here: the
// row is written whole.
//
// Run:  node tools/export-scenery.mjs
//       node tools/export-scenery.mjs --check    (fail if data/ has drifted)
import { writeFileSync, mkdirSync, existsSync, readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const HERE = dirname(fileURLToPath(import.meta.url));
const OUT = join(HERE, '..', 'data');
const CHECK = process.argv.includes('--check');

const { SCENERY, PROPS, withDefaults } = await import(new URL('../../js/scenery.js', import.meta.url));
const { ART } = await import(new URL('../../js/artprops.js', import.meta.url));

// The lane depths are the browser build's own. Copying the NUMBERS would be
// the second-source-of-truth mistake again, so they come out of palette.js.
const { LAYER_Z } = await import(new URL('../../js/palette.js', import.meta.url));

const worlds = {};
for (const [world, rows] of Object.entries(SCENERY)) {
  worlds[world] = rows.map((row) => {
    const full = withDefaults(row);
    // `layer` is what the port needs to know which lane to mount on: the row's
    // own if it set one (the editor writes it), else the prop's default.
    full.layer = row.layer || PROPS[row.prop]?.layer || 'play';
    return full;
  });
}

const payload = {
  // the catalogue, so the port can mount a cutout it has never heard of by
  // name — the same reason the editor reads it rather than keeping a list
  art: ART,
  // the field declarations, for a Godot-side editor later; harmless now and
  // the thing a hand-port would forget
  props: Object.fromEntries(Object.entries(PROPS).map(([k, v]) => [k, { label: v.label, layer: v.layer || 'play', art: v.art ?? null }])),
  layerZ: LAYER_Z,
  // `play` is not a painted lane and has no LAYER_Z entry; it is the depth a
  // dressing cutout sits at, in front of `near` and behind anything the
  // player can touch. js/layers.js's own number.
  playZ: -0.85,
  worlds,
  count: Object.values(worlds).reduce((n, r) => n + r.length, 0),
};

const body = JSON.stringify(payload, null, 2);
const file = join(OUT, 'scenery.json');

if (CHECK) {
  if (!existsSync(file)) {
    console.error('FAIL: data/scenery.json is missing');
    process.exit(1);
  }
  if (readFileSync(file, 'utf8') !== body) {
    console.error('FAIL: data/scenery.json has drifted from js/scenery.js');
    process.exit(1);
  }
  console.log(`OK: data/scenery.json matches — ${payload.count} row(s) across ${Object.keys(worlds).length} world(s)`);
} else {
  mkdirSync(OUT, { recursive: true });
  writeFileSync(file, body);
  console.log(`Wrote data/scenery.json — ${payload.count} row(s), ${Object.keys(ART).length} art piece(s)`);
  for (const [w, rows] of Object.entries(worlds)) {
    const kinds = [...new Set(rows.map((r) => r.prop))].join(', ');
    console.log(`  ${w.padEnd(12)} ${String(rows.length).padStart(2)} row(s)  ${kinds}`);
  }
}
