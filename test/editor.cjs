// Browser editor layout and the Hub's public pause/resume contract.
// Run: node test/editor.cjs (Playwright is a development tool).
const { chromium } = require('playwright');
const http = require('node:http');
const fs = require('node:fs');
const path = require('node:path');
const ROOT = path.resolve(__dirname, '..');
const MIME = {'.html':'text/html','.js':'text/javascript','.css':'text/css',
  '.json':'application/json','.svg':'image/svg+xml','.webp':'image/webp',
  '.png':'image/png','.glb':'model/gltf-binary'};
let passed = 0, failed = 0;
const check = (name, value, detail = '') => {
  console.log(`  ${value ? 'ok  ' : 'FAIL'} ${name}${value || !detail ? '' : ': ' + detail}`);
  value ? passed++ : failed++;
};
const server = http.createServer((req, res) => {
  let file = path.join(ROOT, decodeURIComponent(req.url.split('?')[0]));
  if (fs.existsSync(file) && fs.statSync(file).isDirectory()) file = path.join(file, 'index.html');
  if (!fs.existsSync(file)) { res.writeHead(404); res.end(); return; }
  res.writeHead(200, {'Content-Type': MIME[path.extname(file)] || 'application/octet-stream'});
  fs.createReadStream(file).pipe(res);
});
(async () => {
  await new Promise(resolve => server.listen(0, '127.0.0.1', resolve));
  let browser;
  try {
    browser = await chromium.launch();
    const page = await browser.newPage({viewport:{width:780,height:600}});
    const errors = [];
    page.on('pageerror', error => errors.push(error.message));
    await page.goto(`http://127.0.0.1:${server.address().port}/dev.html`);
    await page.waitForFunction(() => window.__insp && window.frames[0].__eeri?.player.grounded,
      null, {timeout:90000});
    // The inspector is normally reached through the game's pause menu.
    const game = page.frameLocator('#game');
    await game.locator('canvas').click({position:{x:400,y:100}});
    await page.keyboard.press('Escape');
    await game.locator('[data-a="devtools"]').click();
    await page.locator('.ed').waitFor({state:'visible'});
    const layout = () => page.evaluate(() => {
      const editor = document.querySelector('.ed');
      const bar = editor.querySelector('.topbar').getBoundingClientRect();
      const body = editor.querySelector('.body').getBoundingClientRect();
      const panel = editor.querySelector('.panel');
      return {position:getComputedStyle(editor).position,
        font:getComputedStyle(editor).fontFamily,barBottom:bar.bottom,bodyTop:body.top,
        panelFits:panel.scrollWidth <= panel.clientWidth + 1,
        overflow:[...panel.querySelectorAll('*')].filter(e =>
          e.getBoundingClientRect().right > panel.getBoundingClientRect().right + 1)
          .map(e=>({tag:e.tagName,cl:e.className,width:e.getBoundingClientRect().width}))};
    });
    let state = await layout();
    check('the editor wrapper has its fixed, click-through layout', state.position === 'fixed');
    check('the editor uses its readable UI font', !state.font.includes('Times'));
    check('the sidebar clears the toolbar', state.bodyTop >= state.barBottom);
    check('palette labels fit their panel', state.panelFits, JSON.stringify(state));
    await page.setViewportSize({width:667,height:375});
    await page.waitForFunction(() => {
      const bar = document.querySelector('.ed .topbar').getBoundingClientRect();
      return document.querySelector('.ed .body').getBoundingClientRect().top >= bar.bottom;
    });
    state = await layout();
    check('a wrapped toolbar does not cover the layer rail', state.bodyTop >= state.barBottom);
    await page.locator('[data-a="close"]').click();
    const initial = await page.evaluate(() => {
      const w = window.frames[0];
      w.__tokoTable.pause();
      return {x:w.__eeri.player.x,recap:w.__tokoTable.recap()};
    });
    await game.locator('canvas').click({position:{x:300,y:100}});
    await page.keyboard.down('ArrowRight');
    await page.waitForTimeout(800);
    const heldX = await page.evaluate(() => window.frames[0].__eeri.player.x);
    check('the public table pause holds gameplay while input is pressed', Math.abs(heldX-initial.x)<0.001);
    check('the public table recap names the current level', initial.recap?.[0]?.includes('1-1'));
    await page.evaluate(() => window.frames[0].__tokoTable.resume());
    await page.waitForFunction(x => window.frames[0].__eeri.player.x > x + 0.5, initial.x,
      {timeout:30000});
    await page.keyboard.up('ArrowRight');
    check('gameplay resumes after the table closes', true);
    check('the browser editor and game raise no page errors', errors.length===0, errors.join(' | '));
  } finally {
    await browser?.close();
    await new Promise(resolve => server.close(resolve));
  }
  console.log(`\n${passed} passed, ${failed} failed`);
  process.exitCode = failed ? 1 : 0;
})().catch(error => { console.error(error); process.exitCode = 1; server.close(); });
