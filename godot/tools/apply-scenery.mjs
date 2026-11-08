#!/usr/bin/env node
// Apply a reviewed editor world's rows to the canonical JS authoring source.
// Default: describe the change. --write applies it and regenerates Godot data.
import {readFileSync, writeFileSync, renameSync, readdirSync, existsSync} from 'node:fs';
import {dirname, resolve, join, extname, sep} from 'node:path';
import {fileURLToPath, pathToFileURL} from 'node:url';
import {spawnSync} from 'node:child_process';
import {isDeepStrictEqual} from 'node:util';

const ROOT = resolve(dirname(fileURLToPath(import.meta.url)), '../..');
const input = process.argv.slice(2).find(a => !a.startsWith('--'));
if (!input) { console.error('Usage: node godot/tools/apply-scenery.mjs <export.json> [--write]'); process.exit(1); }
const document = JSON.parse(readFileSync(resolve(input), 'utf8'));
const modulePath = join(ROOT, 'js/scenery.js');
const {SCENERY, PROPS, withDefaults} = await import(pathToFileURL(modulePath));
const {LAYER_Z} = await import(pathToFileURL(join(ROOT, 'js/palette.js')));
const world = document.world;
const normalize = rows => rows.map(row => {
  const value = {...withDefaults(row), layer:row.layer || PROPS[row.prop]?.layer || 'play'};
  if (PROPS[row.prop]?.art) {
    value.flip = Boolean(value.flip);
    value.o ??= 1;
    value.z ??= value.layer === 'play' ? -0.85 : LAYER_Z[value.layer.toUpperCase()];
  }
  if (row.prop === 'lamp') value.colour = value.colour.toLowerCase();
  return value;
});
const stable = value => {
  if (Array.isArray(value)) return value.map(stable);
  if (value && typeof value === 'object') return Object.fromEntries(Object.keys(value).sort().map(k=>[k,stable(value[k])]));
  return typeof value === 'number' ? Math.round(value * 100000) / 100000 : value;
};
const equal = (a,b) => isDeepStrictEqual(stable(a),stable(b));
if (!Object.hasOwn(SCENERY, world) || !Array.isArray(document.scenery)) throw new Error('Open a campaign level before applying world art.');
const rows = document.scenery;
const layers = new Set(['play', ...Object.keys(LAYER_Z).map(k=>k.toLowerCase())]);
for (const row of rows) {
  if (!PROPS[row.prop]) throw new Error(`Unknown art piece: ${row.prop}`);
  if (!Number.isFinite(row.x)) throw new Error('Every placed piece needs a finite x position.');
  for (const key of ['y','z','h','o']) if (row[key] !== undefined && !Number.isFinite(row[key])) throw new Error(`Invalid ${key} on ${row.prop}.`);
  if (row.h !== undefined && row.h <= 0) throw new Error('Art height must be positive.');
  if (row.o !== undefined && (row.o < 0 || row.o > 1)) throw new Error('Opacity must be between zero and one.');
  if (row.layer !== undefined && !layers.has(row.layer)) throw new Error(`Unknown layer: ${row.layer}`);
}
const current = normalize(SCENERY[world]);
const changed = !equal(current, normalize(rows));
if (changed && (!Array.isArray(document.source_scenery) || !equal(current, normalize(document.source_scenery)))) {
  throw new Error('World art changed since this draft was opened. Reopen the current source before applying this draft.');
}
const summary = {world, before:current.length, after:rows.length, changed, appliesTo:'all three levels in this world'};
if (!process.argv.includes('--write') || !changed) { console.log(JSON.stringify(summary)); process.exit(0); }

// Find the one authored world array, respecting nested arrays, strings and
// comments. Only that array is replaced; the other worlds keep their bytes.
const source = readFileSync(modulePath, 'utf8');
const match = new RegExp(`^  ${world}: \\[`, 'm').exec(source);
if (!match) throw new Error(`Cannot locate the ${world} authoring array.`);
const start = match.index + match[0].length - 1;
let end = start, depth = 0, quote = '', escaped = false, comment = '';
for (; end < source.length; end++) {
  const c = source[end], next = source[end+1];
  if (comment === '//') { if (c === '\n') comment=''; continue; }
  if (comment === '/*') { if (c === '*' && next === '/') {comment='';end++;} continue; }
  if (quote) { if (escaped) escaped=false; else if (c==='\\') escaped=true; else if(c===quote) quote=''; continue; }
  if (c==='/' && (next==='/' || next==='*')) {comment='/'+next;end++;continue;}
  if (c==='"' || c==="'" || c==='`') {quote=c;continue;}
  if (c==='[') depth++;
  if (c===']' && --depth===0) break;
}
if (depth !== 0) throw new Error('The world array is incomplete; source was not changed.');
const replacement = JSON.stringify(rows, null, 2).replaceAll('\n', '\n  ');
const edits = new Map([[modulePath, source.slice(0,start)+replacement+source.slice(end+1)]]);

// A changed imported module needs a fresh URL, as do modules whose import
// bytes changed. Propagate once per module, keeping one token per path.
const files = [join(ROOT,'index.html'),join(ROOT,'dev.html')];
for (const folder of ['js','dev','test','godot/tools']) {
  for (const name of readdirSync(join(ROOT,folder))) if (['.js','.mjs','.cjs'].includes(extname(name))) files.push(join(ROOT,folder,name));
}
const originals = new Map(files.map(file=>[file,readFileSync(file,'utf8')]));
const references = [];
for (const [file,text] of originals) {
  for (const m of text.matchAll(/(['"])((?:\.\.?\/)[^'"\s]+\.js)\?v=(\d+)\1/g)) {
    const target = resolve(dirname(file),m[2]);
    if (target.startsWith(ROOT+sep)) references.push({file,target,spec:m[2],version:Number(m[3])});
  }
}
const queue = [modulePath], bumped = new Set();
while (queue.length) {
  const target = queue.shift();
  if (bumped.has(target)) continue;
  bumped.add(target);
  const refs = references.filter(r=>r.target===target);
  const version = Math.max(0,...refs.map(r=>r.version))+1;
  for (const ref of refs) {
    let text = edits.get(ref.file) ?? originals.get(ref.file);
    const next = text.replaceAll(ref.spec+'?v='+ref.version,ref.spec+'?v='+version);
    if (next===text) continue;
    edits.set(ref.file,next);
    if (extname(ref.file)==='.js') queue.push(ref.file);
  }
}
for (const [file] of edits) if (readFileSync(file,'utf8') !== (originals.get(file) ?? source)) throw new Error('A source file changed during apply; retry with the current draft.');
for (const [file,text] of edits) {writeFileSync(file+'.tmp',text);renameSync(file+'.tmp',file);}
const exporter = join(ROOT,'godot/tools/export-scenery.mjs');
if (existsSync(exporter)) {
  const generated = spawnSync(process.execPath,[exporter],{encoding:'utf8'});
  if (generated.status!==0) throw new Error('Source saved, but Godot data regeneration failed: '+generated.stderr);
}
console.log(JSON.stringify({...summary,written:true,files:[...edits.keys()].map(f=>f.slice(ROOT.length+1))}));
