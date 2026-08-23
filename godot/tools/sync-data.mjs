#!/usr/bin/env node
// Copy canon into res://data — Godot can only load from res://, and a second
// hand-kept copy of the manifest is how a lineage forks (see
// assets/README.md and EERI_GODOT_HANDOFF.md §3).
//
// Copies:
//   ../assets/manifest.json  -> data/manifest.json
//   every {status:"live", file|files} leaf's referenced asset(s), same
//   relative path (assets/2d/x.webp -> data/2d/x.webp)
//
// Usage:
//   node tools/sync-data.mjs            copy
//   node tools/sync-data.mjs --check    fail if data/ has drifted from assets/
//
// `data/` is git-ignored on purpose (see ../.gitignore) — run this after
// every clone and after every manifest change upstream.

import { readFileSync, writeFileSync, mkdirSync, existsSync, copyFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const HERE = dirname(fileURLToPath(import.meta.url)); // godot/tools
const GODOT_ROOT = join(HERE, '..');                  // godot/
const ASSETS_ROOT = join(GODOT_ROOT, '..', 'assets');  // ../assets
const DATA_ROOT = join(GODOT_ROOT, 'data');            // godot/data

const CHECK = process.argv.includes('--check');

function readJSON(path) {
  return JSON.parse(readFileSync(path, 'utf8'));
}

// Walk the manifest collecting every leaf's file path(s), regardless of how
// deep it sits (layers nests world -> lane -> {status, file|files}).
function collectFiles(node, out) {
  if (node === null || typeof node !== 'object') return;
  if (Array.isArray(node)) {
    for (const v of node) collectFiles(v, out);
    return;
  }
  if ('status' in node && ('file' in node || 'files' in node)) {
    if (node.status === 'live') {
      const files = node.files ? node.files : [node.file];
      for (const f of files) out.push(f);
    }
    return;
  }
  for (const [k, v] of Object.entries(node)) {
    if (k.startsWith('_')) continue;
    collectFiles(v, out);
  }
}

function main() {
  const manifestSrc = join(ASSETS_ROOT, 'manifest.json');
  if (!existsSync(manifestSrc)) {
    console.error(`FAIL: ${manifestSrc} not found — run this from the eeri repo, not standalone`);
    process.exit(1);
  }
  const manifest = readJSON(manifestSrc);
  const files = [];
  collectFiles(manifest, files);

  const problems = [];
  const manifestDst = join(DATA_ROOT, 'manifest.json');

  if (CHECK) {
    if (!existsSync(manifestDst)) {
      problems.push('data/manifest.json is missing — run without --check first');
    } else if (readFileSync(manifestSrc, 'utf8') !== readFileSync(manifestDst, 'utf8')) {
      problems.push('data/manifest.json has drifted from assets/manifest.json');
    }
  } else {
    mkdirSync(DATA_ROOT, { recursive: true });
    writeFileSync(manifestDst, readFileSync(manifestSrc));
  }

  let copied = 0;
  for (const rel of files) {
    const src = join(ASSETS_ROOT, rel);
    const dst = join(DATA_ROOT, rel);
    if (!existsSync(src)) {
      problems.push(`live asset missing on disk: assets/${rel}`);
      continue;
    }
    if (CHECK) {
      if (!existsSync(dst)) {
        problems.push(`data/${rel} is missing`);
      } else if (readFileSync(src).compare(readFileSync(dst)) !== 0) {
        problems.push(`data/${rel} has drifted from assets/${rel}`);
      }
      continue;
    }
    mkdirSync(dirname(dst), { recursive: true });
    copyFileSync(src, dst);
    copied++;
  }

  if (CHECK) {
    if (problems.length) {
      console.error(`FAIL: ${problems.length} problem(s)`);
      for (const p of problems) console.error(`  - ${p}`);
      process.exit(1);
    }
    console.log(`OK: data/ matches assets/ — manifest + ${files.length} live file(s)`);
    return;
  }

  if (problems.length) {
    console.error(`Copied manifest + ${copied}/${files.length} live file(s); ${problems.length} problem(s):`);
    for (const p of problems) console.error(`  - ${p}`);
    process.exit(1);
  }
  console.log(`Copied manifest.json + ${copied} live file(s) into godot/data/`);
}

main();
