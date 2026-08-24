#!/usr/bin/env node
// EERI — turn js/lang.js's string table into Godot's CSV translation format.
//
// GENERATED, never transcribed. DESIGN §4.4 makes English the per-KEY
// fallback and the game is played by a Finnish six-year-old, so a second
// hand-kept copy of the Finnish is precisely the thing that must not exist:
// toko/ and piritori-eden both record shipping English-only entries in a
// pack with every gate green, because per-key fallback is correct behaviour
// AND completely silent.
//
// js/lang.js assigns document.documentElement.lang at module level, so it
// cannot simply be imported in bare node. The STRINGS literal is pure data,
// so it is sliced out and evaluated on its own rather than the module being
// stubbed — a stub would quietly diverge from what the browser actually runs.
//
// Writes:  godot/locale/ui.csv
// Run:     node tools/export-locale.mjs [--check]

import { readFileSync, writeFileSync, mkdirSync, existsSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const HERE = dirname(fileURLToPath(import.meta.url));
const SRC = join(HERE, '..', '..', 'js', 'lang.js');
const OUT_DIR = join(HERE, '..', 'locale');
const OUT = join(OUT_DIR, 'ui.csv');
const CHECK = process.argv.includes('--check');

const src = readFileSync(SRC, 'utf8');
const start = src.indexOf('export const STRINGS = {');
if (start < 0) {
  console.error('FAIL: could not find `export const STRINGS = {` in js/lang.js');
  process.exit(1);
}
// Walk braces from the opening one so a nested object cannot end the slice early.
const open = src.indexOf('{', start);
let depth = 0, end = -1;
for (let i = open; i < src.length; i++) {
  const ch = src[i];
  if (ch === '{') depth++;
  else if (ch === '}') { depth--; if (depth === 0) { end = i + 1; break; } }
}
if (end < 0) {
  console.error('FAIL: STRINGS literal is unbalanced');
  process.exit(1);
}
const STRINGS = (0, eval)('(' + src.slice(open, end) + ')');

const LANGS = ['en', 'fi', 'ja'];
for (const l of LANGS) {
  if (!STRINGS[l]) {
    console.error(`FAIL: js/lang.js has no "${l}" pack`);
    process.exit(1);
  }
}

// English is the key set AND the fallback (DESIGN §4.4).
const keys = Object.keys(STRINGS.en);
const problems = [];
for (const l of ['fi', 'ja']) {
  for (const k of keys) {
    if (!(k in STRINGS[l])) problems.push(`${l} is missing "${k}"`);
  }
  for (const k of Object.keys(STRINGS[l])) {
    if (!keys.includes(k)) problems.push(`${l} has "${k}", which English does not`);
  }
}

const esc = (s) => {
  const v = String(s ?? '');
  return /[",\n]/.test(v) ? '"' + v.replace(/"/g, '""') + '"' : v;
};
const rows = ['keys,' + LANGS.join(',')];
for (const k of keys) {
  rows.push([k, ...LANGS.map((l) => esc(STRINGS[l][k] ?? STRINGS.en[k]))].join(','));
}
const body = rows.join('\n') + '\n';

if (problems.length) {
  console.error(`FAIL: ${problems.length} problem(s) in js/lang.js`);
  for (const p of problems) console.error(`  - ${p}`);
  process.exit(1);
}

if (CHECK) {
  if (!existsSync(OUT)) {
    console.error('FAIL: godot/locale/ui.csv is missing — run without --check');
    process.exit(1);
  }
  if (readFileSync(OUT, 'utf8') !== body) {
    console.error('FAIL: godot/locale/ui.csv has drifted from js/lang.js');
    process.exit(1);
  }
  console.log(`OK: ${keys.length} key(s) x ${LANGS.length} language(s) match js/lang.js`);
} else {
  mkdirSync(OUT_DIR, { recursive: true });
  writeFileSync(OUT, body);
  console.log(`Wrote ${keys.length} key(s) x ${LANGS.length} language(s) to godot/locale/ui.csv`);
}
