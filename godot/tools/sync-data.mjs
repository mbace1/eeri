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
// ...except .glb files, which are DEQUANTIZED on the way in. Every model in
// assets/3d requires KHR_mesh_quantization, which Godot 4.7.2's glTF importer
// does not support — all seven live models fail to import untouched. See
// GODOT_PORT_ANALYSIS.md §1 for the full diagnosis; the short version is that
// quantization is the only blocker (EXT_texture_webp imports fine), it came
// from art-src/tools/compress-models.mjs making a correct browser-side call
// that a second engine does not share, and undoing it here is FREE in the
// shipped game because Godot re-encodes meshes into its own format at import
// and never carries the .glb.
//
// Usage:
//   node tools/sync-data.mjs            copy/convert
//   node tools/sync-data.mjs --check    fail if data/ has drifted from assets/
//
// `data/` is git-ignored (see ../.gitignore) — run this after every clone and
// after every manifest change upstream.

import { readFileSync, writeFileSync, mkdirSync, existsSync, copyFileSync, rmSync } from 'node:fs';
import { createHash } from 'node:crypto';
import { execFileSync } from 'node:child_process';
import { dirname, join, extname, delimiter } from 'node:path';
import { tmpdir } from 'node:os';
import { fileURLToPath } from 'node:url';

const HERE = dirname(fileURLToPath(import.meta.url)); // godot/tools
const GODOT_ROOT = join(HERE, '..');                  // godot/
const ASSETS_ROOT = join(GODOT_ROOT, '..', 'assets');  // ../assets
const DATA_ROOT = join(GODOT_ROOT, 'data');            // godot/data

// Which source bytes each derived file came from. A plain byte comparison
// cannot check a TRANSFORMED file (data/3d/x.glb is deliberately not equal to
// assets/3d/x.glb), so --check verifies provenance instead: the source is
// still the file this output was derived from.
const STAMP = join(DATA_ROOT, '.sync-stamp.json');

const CHECK = process.argv.includes('--check');
const sha = (buf) => createHash('sha256').update(buf).digest('hex');

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

// Resolve the CLI once, as a JS entrypoint we run with THIS node binary.
//
// Not by name: on Windows an npm global bin is a `.cmd` shim, and Node 22
// refuses to execFile a `.cmd` at all (EINVAL — it is the fix for
// CVE-2024-27980), while the extensionless shim is a shell script Windows
// cannot exec (ENOENT). Going through `shell: true` would work but means
// quoting every path forever. Resolving the package's own `bin` and handing
// it to `process.execPath` sidesteps the whole class: no shell, no shim, no
// PATH dependency, and the same code path on every OS.
let GLTF_CLI = null;
function haveGltfTransform() {
  if (GLTF_CLI) return true;
  // npm root -g, without spawning npm: global node_modules sits beside the
  // node binary on most installs, and NODE_PATH covers the rest.
  const roots = [];
  if (process.env.NODE_PATH) roots.push(...process.env.NODE_PATH.split(delimiter).filter(Boolean));
  roots.push(join(dirname(process.execPath), 'node_modules'));
  roots.push(join(dirname(process.execPath), '..', 'lib', 'node_modules'));
  for (const r of roots) {
    const cand = join(r, '@gltf-transform', 'cli', 'bin', 'cli.js');
    if (existsSync(cand)) { GLTF_CLI = cand; return true; }
  }
  return false;
}

// Dequantize one .glb. Returns true on success. Verifies the node/clip/skin
// contract survived — the same guard art-src/tools/compress-models.mjs applies
// on the way in, for the same reason: those names ARE the seam the game drives
// (`house`/`boom`/`stick`/`bucket` on a machine, the clip list on the kid), so
// a transform that quietly renames or merges them breaks articulation with
// everything still nominally "working".
function contract(file) {
  const d = readFileSync(file);
  if (d.toString('ascii', 0, 4) !== 'glTF') throw new Error('not a glb');
  const len = d.readUInt32LE(12);
  const j = JSON.parse(d.toString('utf8', 20, 20 + len));
  return {
    nodes: (j.nodes || []).map((n) => n.name).filter(Boolean).sort().join('|'),
    clips: (j.animations || []).map((a) => a.name).filter(Boolean).sort().join('|'),
    skins: (j.skins || []).length,
    required: (j.extensionsRequired || []).slice().sort().join('|'),
  };
}

function dequantize(src, dst) {
  const tmp = join(tmpdir(), `eeri-dq-${process.pid}-${Math.random().toString(36).slice(2)}.glb`);
  try {
    execFileSync(process.execPath, [GLTF_CLI, 'dequantize', src, tmp], { stdio: 'pipe' });
    const a = contract(src), b = contract(tmp);
    if (a.nodes !== b.nodes || a.clips !== b.clips || a.skins !== b.skins) {
      throw new Error('contract moved during dequantize (nodes/clips/skins differ)');
    }
    if (b.required.split('|').includes('KHR_mesh_quantization')) {
      throw new Error('still requires KHR_mesh_quantization after dequantize');
    }
    mkdirSync(dirname(dst), { recursive: true });
    copyFileSync(tmp, dst);
    return true;
  } finally {
    try { rmSync(tmp, { force: true }); } catch {}
  }
}

function main() {
  const manifestSrc = join(ASSETS_ROOT, 'manifest.json');
  if (!existsSync(manifestSrc)) {
    console.error(`FAIL: ${manifestSrc} not found — run this from the eeri repo, not standalone`);
    process.exit(1);
  }
  const manifest = JSON.parse(readFileSync(manifestSrc, 'utf8'));
  const files = [];
  collectFiles(manifest, files);

  const problems = [];
  const manifestDst = join(DATA_ROOT, 'manifest.json');
  const glbs = files.filter((f) => extname(f).toLowerCase() === '.glb');

  // ---- check mode: verify provenance, never re-transform -------------------
  if (CHECK) {
    if (!existsSync(manifestDst)) {
      problems.push('data/manifest.json is missing — run without --check first');
    } else if (readFileSync(manifestSrc, 'utf8') !== readFileSync(manifestDst, 'utf8')) {
      problems.push('data/manifest.json has drifted from assets/manifest.json');
    }
    const stamp = existsSync(STAMP) ? JSON.parse(readFileSync(STAMP, 'utf8')) : null;
    if (!stamp) problems.push('data/.sync-stamp.json is missing — run without --check first');

    for (const rel of files) {
      const src = join(ASSETS_ROOT, rel);
      const dst = join(DATA_ROOT, rel);
      if (!existsSync(src)) { problems.push(`live asset missing on disk: assets/${rel}`); continue; }
      if (!existsSync(dst)) { problems.push(`data/${rel} is missing`); continue; }
      if (extname(rel).toLowerCase() === '.glb') {
        // transformed: compare the SOURCE's hash against what it was built from
        const want = stamp && stamp[rel];
        if (!want) problems.push(`data/${rel} has no provenance stamp`);
        else if (want !== sha(readFileSync(src))) problems.push(`assets/${rel} changed since data/ was built`);
      } else if (readFileSync(src).compare(readFileSync(dst)) !== 0) {
        problems.push(`data/${rel} has drifted from assets/${rel}`);
      }
    }
    if (problems.length) {
      console.error(`FAIL: ${problems.length} problem(s)`);
      for (const p of problems) console.error(`  - ${p}`);
      process.exit(1);
    }
    console.log(`OK: data/ matches assets/ — manifest + ${files.length} live file(s), ${glbs.length} dequantized`);
    return;
  }

  // ---- copy/convert mode ---------------------------------------------------
  if (glbs.length && !haveGltfTransform()) {
    console.error('FAIL: `gltf-transform` is not on PATH, and every .glb needs dequantizing');
    console.error('      for Godot 4.7.2 to import it at all (GODOT_PORT_ANALYSIS.md §1).');
    console.error('      Install the dev-only CLI:  npm install -g @gltf-transform/cli');
    process.exit(1);
  }

  mkdirSync(DATA_ROOT, { recursive: true });
  writeFileSync(manifestDst, readFileSync(manifestSrc));

  const stamp = {};
  let copied = 0, converted = 0;
  for (const rel of files) {
    const src = join(ASSETS_ROOT, rel);
    const dst = join(DATA_ROOT, rel);
    if (!existsSync(src)) { problems.push(`live asset missing on disk: assets/${rel}`); continue; }
    if (extname(rel).toLowerCase() === '.glb') {
      try {
        dequantize(src, dst);
        stamp[rel] = sha(readFileSync(src));
        converted++;
      } catch (e) {
        problems.push(`dequantize failed for ${rel}: ${String(e.message).split('\n')[0]}`);
      }
      continue;
    }
    mkdirSync(dirname(dst), { recursive: true });
    copyFileSync(src, dst);
    copied++;
  }
  writeFileSync(STAMP, JSON.stringify(stamp, null, 2));

  if (problems.length) {
    console.error(`Copied ${copied}, dequantized ${converted}; ${problems.length} problem(s):`);
    for (const p of problems) console.error(`  - ${p}`);
    process.exit(1);
  }
  console.log(`Copied manifest.json + ${copied} file(s), dequantized ${converted} model(s) into godot/data/`);
}

main();
