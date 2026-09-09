// EERI clock-out gate — GATE C: "a full world plays start to clock-out
// with meta counting" (PHASING.md §3, Phase C).
//
// Why this exists, precisely. Every BUILD item in Phase C shipped — the
// camera moments, World 1's second machine, bolts, golden bolts,
// blueprints, level-select, the clock-out beat — but the gate that closes
// the phase was never written, and `playthrough.cjs` cannot close it: it
// calls `goSite(i)` for every level in turn, so it proves twelve levels
// are each finishable and proves NOTHING about a world. A world is the
// unit Phase C is about. Three levels in sequence, the golden bolts
// banking out of each one into the next, and a gate at the end that puts
// up what you built.
//
// It also guards a regression this project has already shipped once, and
// which nothing but a comment in `js/main.js` currently protects. From
// that comment: with World 2 built, raising World 1's big flag advanced
// straight to level 4 and "the gate — the world's whole curtain — became
// unreachable". The rule is that A LEVEL WITH A GATE DOES NOT
// AUTO-ADVANCE: the flag raises and you walk out yourself. That is one
// assertion here, and it is the one most likely to break, because it is
// an ABSENCE — nothing happening — and absences are what regress quietly.
//
// What it deliberately does not assert: a big score. The bot is the dumb
// one from `bot.cjs` and the golden bolts are hidden by design, so it
// banks few or none of them. A gate that only ever saw 0/9 would prove
// the building exists and nothing about what it reads, so the FULL
// reading is seeded through `debug.setGolden()` — the dev hook that
// exists for exactly this, in main.js's own words: "a bot that collects
// nothing can only ever show the first [reading], so this is how the
// other eight get looked at."
//
// Run: NODE_PATH=$(npm root -g) node test/clockout.cjs
const { chromium } = require('playwright');
const http = require('http'); const fs = require('fs'); const path = require('path');
const { BOT } = require('./bot.cjs');

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

// The world under test is World 1 — three levels, sites 0..2, the gate on
// the third. PER_WORLD is 3 (js/levelid.js) and every world's last level
// carries an `exitAt`, so this shape holds for any of them; World 1 is
// chosen because it is the one a player actually meets first.
const PER_WORLD = 3, FIRST = 0, GATED = 2;

srv.listen(0, '127.0.0.1', async () => {
  const base = 'http://127.0.0.1:' + srv.address().port;
  const b = await chromium.launch();
  // Small viewport for the same reason playthrough.cjs uses one: this
  // sandbox has no GPU, and fewer pixels to rasterise is the cheapest
  // speed-up a software renderer has.
  const page = await b.newPage({ viewport: { width: 480, height: 270 } });
  const errs = [];
  page.on('pageerror', (e) => errs.push(e.message));

  await page.goto(base + '/?skip', { waitUntil: 'load' });
  await page.waitForFunction(() => !!window.__eeri && window.__eeri.player.grounded, null, { timeout: 20000 });

  const parts = await page.evaluate(() => window.__eeri.debug.buildParts());
  ok(`the world's building is ${PER_WORLD} levels x 3 golden bolts`, parts === 9, `buildParts() = ${parts}`);

  // Start of the world, and the ONLY goSite this test performs. Everything
  // after it has to be the game moving itself, because "a world plays" is
  // the whole claim.
  await page.evaluate((n) => window.__eeri.debug.goSite(n), FIRST);
  await page.waitForFunction((n) => window.__eeri.site() === n
    && !window.__eeri.debug.transitioning(), FIRST, { timeout: 30000 }).catch(() => {});
  await page.waitForTimeout(400);

  const seen = [];          // one row per level actually played
  let seeded = 0, card = null;

  for (let step = 0; step < PER_WORLD; step++) {
    const at = await page.evaluate(() => window.__eeri.site());
    const name = await page.evaluate(() => window.__eeri.level.def.name);
    const before = await page.evaluate(() => window.__eeri.debug.counts());

    // The meta has to be REAL in every level, not just present at the end:
    // a level with no bolts in it cannot count towards a hundred, and a
    // level with no golden bolts cannot put up a third of a building.
    ok(`${name} carries bolts to count (${before.ofBolts})`, before.ofBolts > 0, JSON.stringify(before));
    ok(`${name} carries its three golden bolts`, before.ofGolden === 3, JSON.stringify(before));

    // On the gated level, seed the building's FULL reading before the bot
    // reaches the gate — see the header. Read the real banked figure first
    // and report it, so the honest number is still visible in the output.
    if (at === GATED) {
      const real = await page.evaluate(() => window.__eeri.debug.worldGolden());
      console.log(`       (banked by the bot across the world: ${real}/${parts} — seeding ${parts} to read the finished building)`);
      await page.evaluate((n) => window.__eeri.debug.setGolden(n), parts);
      seeded = await page.evaluate(() => window.__eeri.debug.worldGolden());
      ok('the dev hook can seed the building to full', seeded === parts,
        `worldGolden() = ${seeded} after setGolden(${parts})`);
    }

    const r = await page.evaluate(new Function('return ' + BOT)(), 300000);
    ok(`${name} plays through`, r.finished,
      `got to x=${r.best} of ${r.exit}, mode=${r.mode}${r.stalls.length ? `, stalled at ${r.stalls}` : ''}`);
    seen.push({ at, name });
    if (!r.finished) break;

    // READ THE CURTAIN IMMEDIATELY, in one evaluate, before any waiting.
    // Clocking out starts a four-second timer (js/main.js) that removes the
    // card, sets `cleared` back to false and loads the next world. Settling
    // the veil first and sampling afterwards would sometimes be reading the
    // world AFTER this one — and the failure would look like "the card was
    // never put up" rather than "the test was late", which is the kind of
    // false accusation a gate must not make.
    const now = await page.evaluate(() => ({
      site: window.__eeri.site(),
      cleared: window.__eeri.debug.cleared(),
      flag: window.__eeri.debug.flag(),
      worldGolden: window.__eeri.debug.worldGolden(),
      card: (document.getElementById('clear') || {}).textContent || null,
    }));

    if (now.cleared) {
      card = now.card;
      // ---- the world ended at its gate -------------------------------
      ok('the world clocked out at its gate', true);

      // THE REGRESSION GUARD. If the flag had auto-advanced this level the
      // way it does on levels 1 and 2, the site index would have moved off
      // the gated level and the gate would never have been reached — which
      // is exactly the bug main.js records. Still being ON the gated level
      // with its flag up is the proof that it did not.
      ok('the gated level did not auto-advance when its flag raised',
        now.site === GATED, `site=${now.site}, expected ${GATED}`);
      ok('…and its big flag was raised first', !!now.flag && now.flag.raised && now.flag.big,
        JSON.stringify(now.flag));
      break;
    }

    // ---- an ungated level: the game moved itself on -------------------
    ok(`${name} handed the world on by itself`, now.site === at + 1,
      `site went ${at} → ${now.site} without goSite being called`);

    // NOW settle. The site index moves inside goSite() before the veil has
    // lifted, so the next lap must not read a room that is still being
    // assembled — the same trap playthrough.cjs documents, where a flat
    // wait handed the bot a half-built room and it reported a wall.
    await page.waitForFunction(() => !window.__eeri.debug.transitioning(), null, { timeout: 30000 }).catch(() => {});
    await page.waitForTimeout(400);
  }

  ok(`the world played all ${PER_WORLD} of its levels in sequence`,
    seen.length === PER_WORLD && seen.every((s, i) => s.at === FIRST + i),
    seen.map((s) => s.at).join(' → '));

  // ---- the curtain itself ---------------------------------------------
  // A building described in text is a score; this one is built into the
  // scene AND summarised on a card. The card is what a player reads, so
  // it is what the gate reads. Captured in the sample above, not re-read
  // here, for the four-second reason given there.
  ok('clocking out puts a card up', !!card, String(card));

  if (card) {
    ok(`the card names what the world built, ${parts}/${parts}`,
      card.includes(`${parts}/${parts}`), card);
    // ⬡ bolts and ✦ golden, both for the whole run — the two glyphs are
    // the design's own (js/main.js), and a card that lost its numbers
    // would still contain them, so the digits are what is checked.
    ok('the card carries the run totals', /⬡\s*\d+/.test(card) && /✦\s*\d+/.test(card), card);
  }

  ok('no page errors across the whole world', errs.length === 0, errs.slice(0, 2).join(' | '));

  await b.close(); srv.close();
  console.log(`\n${pass} passed, ${fail} failed`);
  process.exit(fail ? 1 : 0);
});
