#!/usr/bin/env node
// EERI — the button faces, exported from js/glyphs.js as SVG.
//
// DESIGN §6.4 is absolute: NO KEY CAPS OR MOUSE ICONS, EVER. The buttons show
// what EERI DOES — a running figure, a climbing figure, a tucked jump — not
// what you press, because the player is six and the game must read the same
// on a pad, a keyboard and a thumb.
//
// js/glyphs.js says why it is code and not a file: "a glyph set that is a
// file is a glyph set that gets out of step with the text, and DESIGN §6.4
// says it must be ONE set used by both." That still holds — this exports FROM
// that one set, so there is no second drawing to drift.
//
// Godot renders SVG natively, so the vector survives to any button size.
//
// Writes:  godot/data/glyphs/<name>.svg
// Run:     node tools/export-glyphs.mjs [--check]

import { writeFileSync, mkdirSync, existsSync, readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const HERE = dirname(fileURLToPath(import.meta.url));
const OUT = join(HERE, '..', 'data', 'glyphs');
const CHECK = process.argv.includes('--check');

const { GLYPHS } = await import(new URL('../../js/glyphs.js', import.meta.url));

// `currentColor` inherits from CSS in a browser and means nothing to an SVG
// rasteriser, so it is resolved to the ink the buttons are drawn in. Godot
// then modulates the texture per state, which is how a pressed button dims.
const INK = '#20242b';

const files = new Map();
for (const [name, make] of Object.entries(GLYPHS)) {
  const svg = String(make()).replaceAll('currentColor', INK);
  files.set(`${name}.svg`, svg);
}

if (CHECK) {
  const problems = [];
  for (const [n, body] of files) {
    const p = join(OUT, n);
    if (!existsSync(p)) problems.push(`data/glyphs/${n} is missing`);
    else if (readFileSync(p, 'utf8') !== body) problems.push(`data/glyphs/${n} has drifted from js/glyphs.js`);
  }
  if (problems.length) {
    console.error(`FAIL: ${problems.length} problem(s)`);
    for (const p of problems) console.error(`  - ${p}`);
    process.exit(1);
  }
  console.log(`OK: ${files.size} glyph(s) match js/glyphs.js`);
} else {
  mkdirSync(OUT, { recursive: true });
  for (const [n, body] of files) writeFileSync(join(OUT, n), body);
  console.log(`Wrote ${files.size} glyph(s) into godot/data/glyphs/: ${[...files.keys()].map((f) => f.replace('.svg', '')).join(' ')}`);
}
