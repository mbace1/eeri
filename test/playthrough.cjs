// EERI playthrough gate — a bot actually FINISHES every level.
//
// Why this exists, precisely. `test/rooms.mjs` proves a room is
// *reachable*: the steps are inside the jump budget, the gaps inside the
// run, the machine's track unbroken by holes. It passed SITE 1 while
// SITE 1 was impossible — a wrecking ball stood on the excavator's only
// route to the bank it had to dig, and since a hit takes the RIDE it
// threw you out of the cab every attempt. The bank could never come down.
// A proof about geometry cannot see that; only playing can.
//
// So this plays. It runs right, jumps when the run is blocked or a hole
// is ahead, boards a machine when one is in the way of progress, uses the
// verb the room needs, and it must reach the flag. If a level cannot be
// finished by a bot that never gives up, it cannot be finished.
//
// Run: NODE_PATH=$(npm root -g) node test/playthrough.cjs
const { chromium } = require('playwright');
const http = require('http'); const fs = require('fs'); const path = require('path');
const ROOT = path.resolve(__dirname, '..');
const MIME = { '.html': 'text/html', '.js': 'text/javascript', '.json': 'application/json', '.png': 'image/png', '.glb': 'model/gltf-binary' };
const srv = http.createServer((req, res) => {
  let p = path.join(ROOT, decodeURIComponent(req.url.split('?')[0]));
  if (fs.existsSync(p) && fs.statSync(p).isDirectory()) p = path.join(p, 'index.html');
  if (!fs.existsSync(p)) { res.writeHead(404); return res.end('no'); }
  res.writeHead(200, { 'Content-Type': MIME[path.extname(p)] || 'application/octet-stream' });
  fs.createReadStream(p).pipe(res);
});

let pass = 0, fail = 0;
const ok = (n, c, d) => { c ? (pass++, console.log('  ok   ' + n)) : (fail++, console.log('  FAIL ' + n + (d ? ' → ' + d : ''))); };

// The bot lives in test/bot.cjs — `clockout.cjs` drives the same one, and
// a second copy of it would drift the way every other duplicated list in
// this repo has. See that file for what it does and when it stops.
const { BOT } = require('./bot.cjs');

srv.listen(0, '127.0.0.1', async () => {
  const base = 'http://127.0.0.1:' + srv.address().port;
  const b = await chromium.launch();
  const page = await b.newPage({ viewport: { width: 480, height: 270 } });
  const errs = [];
  page.on('pageerror', (e) => errs.push(e.message));

  await page.goto(base + '/?skip', { waitUntil: 'load' });
  await page.waitForFunction(() => !!window.__eeri && window.__eeri.player.grounded, null, { timeout: 20000 });
  const total = await page.evaluate(() => window.__eeri.debug.rooms());
  if (!Number.isInteger(total) || total < 1) { console.log('  FAIL could not read the level count'); process.exit(1); }
  console.log(`playing ${total} level(s) — the bot never gives up, so a stall is a real wall\n`);

  // ONE LEVEL AT A TIME when asked: `node playthrough.cjs 1` runs level 2
  // alone. Six levels is several minutes a run, and iterating on the one
  // that failed should not cost the five that passed.
  const only = process.argv[2] === undefined ? null : Number(process.argv[2]);
  for (let i = 0; i < total; i++) {
    if (only !== null && i !== only) continue;
    await page.evaluate((n) => window.__eeri.debug.goSite(n), i);
    // WAIT FOR THE ROOM, not for a number of milliseconds. A level change now
    // fades down, builds and fades up (js/main.js's veil), so a flat 1200 ms
    // could hand the bot a room that is still being assembled — and it would
    // report that as a wall. `transitioning` is the game's own answer to "is
    // the change finished".
    await page.waitForFunction((n) => window.__eeri.site() === n
      && !window.__eeri.debug.transitioning(), i, { timeout: 30000 }).catch(() => {});
    await page.waitForTimeout(400);
    const name = await page.evaluate(() => window.__eeri.level.def.name);
    // The sandbox has no GPU, so the game runs in slow motion and the
    // budget is wall-clock generous rather than tuned to real play. The
    // viewport is small for the same reason: fewer pixels to rasterise is
    // the cheapest speed-up available to a software renderer.
    const r = await page.evaluate(new Function('return ' + BOT)(), 300000);
    ok(`${name} can be finished`, r.finished,
      `got to x=${r.best} of ${r.exit}, mode=${r.mode}${r.stalls.length ? `, stalled at ${r.stalls}` : ''}`);
    // the ride is meant to be lost to a mistake, not to the level's layout
    ok(`${name} does not keep throwing you out of the cab (${r.rideLosses})`,
      !r.finished || r.rideLosses <= 3,
      `lost the ride ${r.rideLosses} times — something is standing on the machine's route`);
  }

  ok('no page errors across the whole playthrough', errs.length === 0, errs.slice(0, 2).join(' | '));

  await b.close(); srv.close();
  console.log(`\n${pass} passed, ${fail} failed`);
  process.exit(fail ? 1 : 0);
});
