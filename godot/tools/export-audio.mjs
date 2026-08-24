#!/usr/bin/env node
// EERI — render js/audio.js's synth kit to WAV.
//
// THE HOUSE RULE IS "SYNTHESISED, NEVER SAMPLED", and eeri/test/dev-menu.mjs
// fails on a binary under assets/audio to enforce it. That rule exists
// because WebAudio makes synthesis trivial and samples are weight.
//
// Godot inverts that: it is excellent at streaming samples and awkward at
// synthesis (AudioStreamGenerator, filling buffers by hand). Owner's call,
// 2026-08-24: "whatever works, music is placeholder."
//
// So the kit is still SYNTHESISED — just ahead of time, here, from the same
// voice table and the same two primitives. Nobody records anything and there
// is no second definition of what a stomp sounds like: change js/audio.js and
// re-run this. The WAVs land in the git-ignored data/, like every other
// generated thing.
//
// The primitives are ports of js/audio.js's _blip (an oscillator with an
// exponential decay and an optional frequency slide) and _noise (a bandpassed
// noise burst).
//
// Writes:  godot/data/audio/<voice>.wav
// Run:     node tools/export-audio.mjs [--check]

import { writeFileSync, mkdirSync, existsSync, readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const HERE = dirname(fileURLToPath(import.meta.url));
const OUT = join(HERE, '..', 'data', 'audio');
const CHECK = process.argv.includes('--check');

const RATE = 44100;

// Deterministic noise: a fixed seed, so re-running never produces a
// "different" file and --check cannot flap.
let _s = 0x2f6e2b1;
function rnd() {
  _s ^= _s << 13; _s ^= _s >>> 17; _s ^= _s << 5;
  return ((_s >>> 0) / 0xffffffff) * 2 - 1;
}

function mix(into, from) {
  for (let i = 0; i < from.length; i++) into[i] = (into[i] || 0) + from[i];
}

// js/audio.js _blip: gain 0 -> peak over 8ms, then exponential to silence.
function blip(freq, dur, type = 'square', peak = 0.25, slide = 0) {
  const n = Math.ceil(dur * RATE);
  const out = new Float32Array(n);
  let phase = 0;
  for (let i = 0; i < n; i++) {
    const t = i / RATE;
    const k = t / dur;
    const f = slide ? freq * Math.pow(Math.max(30, freq * slide) / freq, k) : freq;
    phase += (2 * Math.PI * f) / RATE;
    let v;
    switch (type) {
      case 'sine': v = Math.sin(phase); break;
      case 'triangle': v = (2 / Math.PI) * Math.asin(Math.sin(phase)); break;
      case 'sawtooth': v = 2 * (((phase / (2 * Math.PI)) % 1) - 0.5); break;
      default: v = Math.sin(phase) >= 0 ? 1 : -1; break;   // square
    }
    const attack = Math.min(1, t / 0.008);
    const decay = Math.pow(0.0001 / peak, k);
    out[i] = v * peak * attack * decay;
  }
  return out;
}

// js/audio.js _noise: a bandpassed burst, peak decaying exponentially.
// One-pole state-variable bandpass — close enough to a biquad for a 100ms
// burst, and it avoids importing a DSP library for six sound effects.
function noise(dur, peak = 0.2, freq = 900, q = 1) {
  const n = Math.ceil(dur * RATE);
  const out = new Float32Array(n);
  const f = 2 * Math.sin((Math.PI * Math.min(freq, RATE / 3)) / RATE);
  const damp = Math.min(1, 1 / Math.max(0.35, q));
  let low = 0, band = 0;
  for (let i = 0; i < n; i++) {
    const input = rnd();
    low += f * band;
    const high = input - low - damp * band;
    band += f * high;
    const decay = Math.pow(0.0001 / peak, i / n);
    out[i] = band * peak * decay;
  }
  return out;
}

// The voice table, transcribed 1:1 from js/audio.js. `bolt` is rendered at
// its base pitch; the game pitch-shifts it up the chain at playback.
const VOICES = {
  jump: () => blip(340, 0.16, 'square', 0.16, 2.0),
  land: () => noise(0.1, 0.16, 420, 1.2),
  bolt: () => blip(660, 0.1, 'triangle', 0.2, 1.5),
  mount: () => { const a = blip(180, 0.2, 'sawtooth', 0.2, 2.2); mix(a, noise(0.18, 0.12, 700)); return a; },
  stomp: () => { const a = noise(0.08, 0.24, 320, 2); const b = blip(240, 0.14, 'square', 0.18, 2.4); const o = new Float32Array(Math.max(a.length, b.length)); mix(o, a); mix(o, b); return o; },
  dismount: () => blip(300, 0.16, 'square', 0.15, 0.6),
  boom: () => noise(0.14, 0.09, 260, 3),
  clank: () => { const a = noise(0.12, 0.2, 1500, 4); const b = blip(210, 0.12, 'square', 0.12, 0.8); const o = new Float32Array(Math.max(a.length, b.length)); mix(o, a); mix(o, b); return o; },
  thunk: () => { const a = noise(0.26, 0.3, 150, 1); const b = blip(70, 0.34, 'sine', 0.24, 0.6); const o = new Float32Array(Math.max(a.length, b.length)); mix(o, a); mix(o, b); return o; },
  warn: () => { const one = blip(520, 0.09, 'square', 0.2); const o = new Float32Array(Math.ceil(0.22 * RATE)); mix(o, one); const off = Math.round(0.13 * RATE); for (let i = 0; i < one.length; i++) o[off + i] = (o[off + i] || 0) + one[i]; return o; },
  splat: () => { const a = noise(0.3, 0.26, 220, 0.8); const b = blip(120, 0.3, 'sawtooth', 0.16, 0.5); const o = new Float32Array(Math.max(a.length, b.length)); mix(o, a); mix(o, b); return o; },
};

function wav(samples) {
  const n = samples.length;
  const buf = Buffer.alloc(44 + n * 2);
  buf.write('RIFF', 0);
  buf.writeUInt32LE(36 + n * 2, 4);
  buf.write('WAVE', 8);
  buf.write('fmt ', 12);
  buf.writeUInt32LE(16, 16);
  buf.writeUInt16LE(1, 20);          // PCM
  buf.writeUInt16LE(1, 22);          // mono
  buf.writeUInt32LE(RATE, 24);
  buf.writeUInt32LE(RATE * 2, 28);
  buf.writeUInt16LE(2, 32);
  buf.writeUInt16LE(16, 34);
  buf.write('data', 36);
  buf.writeUInt32LE(n * 2, 40);
  for (let i = 0; i < n; i++) {
    const v = Math.max(-1, Math.min(1, samples[i]));
    buf.writeInt16LE(Math.round(v * 32767), 44 + i * 2);
  }
  return buf;
}

const files = new Map();
for (const [name, make] of Object.entries(VOICES)) {
  _s = 0x2f6e2b1;                    // reseed per voice: deterministic output
  files.set(`${name}.wav`, wav(make()));
}

if (CHECK) {
  const problems = [];
  for (const [n, body] of files) {
    const p = join(OUT, n);
    if (!existsSync(p)) problems.push(`data/audio/${n} is missing`);
    else if (readFileSync(p).compare(body) !== 0) problems.push(`data/audio/${n} has drifted`);
  }
  if (problems.length) {
    console.error(`FAIL: ${problems.length} problem(s)`);
    for (const p of problems) console.error(`  - ${p}`);
    process.exit(1);
  }
  console.log(`OK: ${files.size} voice(s) match js/audio.js`);
} else {
  mkdirSync(OUT, { recursive: true });
  let bytes = 0;
  for (const [n, body] of files) { writeFileSync(join(OUT, n), body); bytes += body.length; }
  console.log(`Rendered ${files.size} voice(s) into godot/data/audio/ (${(bytes / 1024).toFixed(0)} kB)`);
}
