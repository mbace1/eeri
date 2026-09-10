// The bot both playing gates drive, in ONE copy.
//
// It was written for `playthrough.cjs` and lived inside it as a string.
// `clockout.cjs` needs the same bot — the same dumb "go right, jump when
// stuck, board a machine when one is in the way" — and this repo's whole
// standing lesson is that a second copy of a thing drifts from the first
// (the precache list a token behind the page; the two hub pages; the
// hand-ported dressing still drawing art the browser build had deleted).
// So it moved here rather than being pasted twice.
//
// It is a STRING on purpose: it runs inside the page via `page.evaluate`,
// because it has to act every frame and a CDP round trip per frame would
// take an hour per level.
//
// Its contract, for whoever reads it next: it stops when the level it
// started in ends — either the site index changed under it (the flag
// raised and the game moved on) or `debug.cleared()` went true (the world
// clocked out at its gate). Both gates depend on that, and `clockout.cjs`
// depends on it being BOTH, since a gated level does not auto-advance.
// and a round trip per frame over CDP would take an hour per level.
// It is deliberately DUMB — no level knowledge, no waypoints. It knows
// only: go right; jump when stuck or over a hole; if something is in the
// way that a machine clears, go get the machine and use it.
module.exports.BOT = `async (budgetMs) => {
  const E = window.__eeri;
  const sleep = (m) => new Promise((r) => setTimeout(r, m));
  const t0 = Date.now();
  const startSite = E.site();
  let best = -Infinity, stuck = 0, jumping = false, jT = 0, act = 0;
  const log = [];
  // A tireless bot will eventually beat a level a child would put down, so
  // "finished" is not enough — count what it COST. Losing the ride means
  // walking back and reading the machine again; more than a couple of those
  // in one level is a hostile arrangement even though it is passable.
  let rideLosses = 0, wasRiding = false;

  const need = () => {
    // what, if anything, only the machine can clear — and where it is
    const d = E.level.def, q = E.player;
    if (d.bank && E.debug.bank() && !E.debug.bank().cleared) return { at: d.bank.c0, verb: 'down' };
    if (d.wall && E.debug.wall() && !E.debug.wall().cleared) return { at: d.wall.c0, verb: 'down' };
    // the flattener needs no held verb at all (DESIGN §8.4) — 'down' here
    // does nothing and costs nothing; parking near the sheet is the whole
    // job, so the bot just has to arrive and sit still long enough.
    if (d.sheet && E.debug.sheet() && !E.debug.sheet().cleared) return { at: d.sheet.c0, verb: 'down' };
    // the girder is TWO actions, not one: pick it off its stack first, then
    // carry it to the seating window at the lip. A bot that only ever drove
    // at the gap sat there holding the verb with an empty hook.
    // WORLD 2: a flooded trench is the pump's job. Same shape as the bank —
    // drive at it and hold the verb — so it costs the bot one entry.
    if (d.flooded && E.debug.flooded && E.debug.flooded() && !E.debug.flooded().cleared) {
      return { at: d.flooded.c0, verb: 'down' };
    }
    if (d.girder && E.debug.girder()) {
      const g = E.debug.girder();
      if (g.state === 0) return { at: d.girder.stackX, verb: 'down' };
      if (g.state === 1) return { at: (d.girder.seat.x0 + d.girder.seat.x1) / 2, verb: 'down' };
    }
    return null;
  };

  // is the kid standing at a pipe mouth?
  const q0 = (E) => {
    const pl = E.player;
    for (const q of (E.debug.pipes() || [])) {
      for (const m of [q.a, q.b]) {
        if (Math.abs(pl.x - (m.c + 0.5)) < 0.7 && Math.abs(pl.y - m.cy) < 0.6) return q;
      }
    }
    return null;
  };

  while (Date.now() - t0 < budgetMs) {
    await sleep(16);
    if (E.site() !== startSite || E.debug.cleared()) break;   // finished it
    const q = E.player, mode = E.mode();
    if (wasRiding && mode === 'foot') rideLosses++;
    wasRiding = (mode === 'riding');

    if (mode === 'riding') {
      const job = need();
      const m = E.debug.excPos();
      // job done — GET OUT. The flag only finishes on foot, and a bot that
      // stays in the cab drives happily past the end of the level forever.
      if (!job) {
        E.debug.release('down'); E.debug.release('right'); E.debug.release('left');
        if (Date.now() - act > 400) { E.debug.press('action'); E.debug.release('action'); act = Date.now(); }
        continue;
      }
      // drive at the job, then hold the verb
      const dx = job.at - m.x;
      if (Math.abs(dx) > 2.2) {
        E.debug.release('down');
        E.debug.press(dx > 0 ? 'right' : 'left');
        E.debug.release(dx > 0 ? 'left' : 'right');
      } else {
        E.debug.release('right'); E.debug.release('left');
        E.debug.press('down');                                // dig / sling / swing
      }
      continue;
    }

    if (mode !== 'foot') continue;                            // mid mount/dismount

    // on foot: always rightward
    E.debug.press('right');
    if (q.x > best + 0.01) { best = q.x; stuck = 0; } else stuck++;

    // THE PIPE. The bot's whole vocabulary is right/left/jump/down/action/up,
    // and it has stalled on an unknown verb once already (the climb), so the
    // rule is the same shape: standing at a mouth and getting nowhere means
    // go in. It stays deliberately dumb — no routing, no idea where the far
    // end is — because a pipe that only helps a bot that plans is a pipe a
    // six-year-old will not find either.
    if (stuck > 40 && E.debug.pipes) {
      const q = q0(E);
      if (q && Date.now() - act > 400) {
        E.debug.press('action'); E.debug.release('action'); act = Date.now();
      }
    }

    // jump when the run is blocked, or a hole is coming
    const ahead = E.level.groundTop(q.x + 1.0, q.y + 0.1);
    if (q.grounded && (Math.abs(q.vx) < 1.0 || ahead < q.y - 0.5) && !jumping) {
      E.debug.press('jump'); jumping = true; jT = q.t;
    }
    // HOLD THE JUMP IN GAME SECONDS, NOT WALL SECONDS. His jump is variable
    // height — letting go while rising cuts it to a hop — and the loop
    // clamps dt to 33 ms, so under a software renderer at 13 fps the game
    // clock runs at less than half real time. A 420 ms wall-clock hold was
    // five frames, i.e. 0.17 s of HIS time: every jump in the gate was a
    // hop, and the bot sat under the first two-high step in seven levels
    // reporting a wall that is not there. player.t is the same clock the
    // jump is integrated on, so this holds for as long as a thumb would.
    if (jumping && q.t - jT > 0.42) { E.debug.release('jump'); jumping = false; }

    // stuck for a while and there is a machine job outstanding? go board it
    if (stuck > 90) {
      const job = need();
      const m = E.debug.excPos();
      if (job) {
        const dx = m.x - q.x;
        if (Math.abs(dx) > 1.6) {
          E.debug.press(dx > 0 ? 'right' : 'left');
          E.debug.release(dx > 0 ? 'left' : 'right');
        } else if (Date.now() - act > 300) {
          E.debug.press('action'); E.debug.release('action'); act = Date.now();
        }
      }
      if (stuck > 90 && stuck % 40 === 0) log.push(Math.round(q.x));
    }
  }
  for (const k of ['right', 'left', 'jump', 'down', 'action']) E.debug.release(k);
  return {
    finished: E.site() !== startSite || E.debug.cleared(),
    x: +E.player.x.toFixed(1), best: +best.toFixed(1),
    exit: E.level.def.exit.x, mode: E.mode(), stalls: log.slice(0, 6), rideLosses,
  };
}`;
