// Frame rate of an exported Rail Yard build in headless Chromium
// (SwiftShader WebGL, 480x860), the measurement docs/game1.md's
// performance passes quote. Serves the build itself.
//
//   node scripts/game1-fps.mjs [build dir]      (default static/game1/rail-yard)
//
// Prints FPS, WebGL draw calls and triangles per frame for three phases:
// Design with the camera still, dragging the view (camera moving every
// frame it gets input), and Play. Also saves a screenshot at the end of
// Play to the temp dir (path printed). SwiftShader rasterises on the CPU, so absolute numbers
// are low; compare builds with each other, not with a phone.
//
// To compare an old commit: git archive <sha> static/game1/rail-yard |
// tar -x -C /tmp/old --strip-components=3, then run on /tmp/old.
import http from 'http';
import fs from 'fs';
import path from 'path';
import os from 'os';
import { createRequire } from 'module';

const require = createRequire(import.meta.url);
let chromium;
try {
  ({ chromium } = require('playwright'));
} catch {
  ({ chromium } = require('/opt/node22/lib/node_modules/playwright'));
}

const root = path.resolve(process.argv[2] || 'static/game1/rail-yard');
const shot = path.join(os.tmpdir(), 'game1-fps-shot.png');
const types = {
  '.html': 'text/html', '.js': 'application/javascript', '.wasm': 'application/wasm',
  '.pck': 'application/octet-stream', '.png': 'image/png',
};
const srv = http.createServer((q, r) => {
  const url = decodeURIComponent(q.url.split('?')[0]);
  const f = path.join(root, url === '/' ? 'index.html' : url);
  fs.readFile(f, (e, d) => {
    if (e) { r.writeHead(404); r.end(); return; }
    r.writeHead(200, {
      'Content-Type': types[path.extname(f)] || 'application/octet-stream',
      'Cross-Origin-Opener-Policy': 'same-origin',
      'Cross-Origin-Embedder-Policy': 'require-corp',
    });
    r.end(d);
  });
});
await new Promise((res) => srv.listen(0, res));
const port = srv.address().port;

const args = ['--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--ignore-gpu-blocklist'];
const browser = await chromium.launch({ executablePath: '/opt/pw-browsers/chromium', args })
  .catch(() => chromium.launch({ args }));
const page = await browser.newPage({ viewport: { width: 480, height: 860 } });
// Count draw calls and triangles by wrapping WebGL's draw entry points.
await page.addInitScript(() => {
  window.__dc = 0;
  window.__tris = 0;
  for (const P of [WebGL2RenderingContext.prototype, WebGLRenderingContext.prototype]) {
    for (const fn of ['drawElements', 'drawArrays', 'drawElementsInstanced', 'drawArraysInstanced']) {
      const orig = P[fn];
      if (!orig) continue;
      const elements = fn.startsWith('drawElements');
      const instanced = fn.endsWith('Instanced');
      P[fn] = function (...a) {
        window.__dc++;
        window.__tris += ((elements ? a[1] : a[2]) / 3) * (instanced ? a[elements ? 4 : 3] : 1);
        return orig.apply(this, a);
      };
    }
  }
});
page.on('pageerror', (e) => console.log('pageerror', e.message));
await page.goto(`http://localhost:${port}/`);
await page.waitForTimeout(12000); // engine download + boot + demo layout

async function measure(label, ms) {
  const r = await page.evaluate((ms) => new Promise((res) => {
    const dc0 = window.__dc, tr0 = window.__tris, t0 = performance.now();
    let n = 0;
    function f() {
      n++;
      if (performance.now() - t0 < ms) requestAnimationFrame(f);
      else res({ fps: n / ((performance.now() - t0) / 1000), dc: (window.__dc - dc0) / n, tris: (window.__tris - tr0) / n });
    }
    requestAnimationFrame(f);
  }), ms);
  console.log(`${label.padEnd(8)} fps=${r.fps.toFixed(1)} drawcalls/frame=${r.dc.toFixed(0)} tris/frame=${r.tris.toFixed(0)}`);
}

await measure('design', 8000);
// Drag the ground (Select tool pans) for the whole measurement.
await page.mouse.move(240, 820);
await page.mouse.down();
let stop = false;
const mover = (async () => {
  let t = 0;
  while (!stop) {
    t++;
    await page.mouse.move(240 + 60 * Math.sin(t / 10), 820 - 40 * Math.abs(Math.sin(t / 17)));
  }
})();
await measure('panning', 6000);
stop = true;
await mover;
await page.mouse.up();
await page.waitForTimeout(500);
await page.mouse.click(24, 24); // Play, the first button in Design's top strip
await page.waitForTimeout(2000);
await measure('play', 8000);
await page.screenshot({ path: shot });
console.log(`screenshot ${shot}`);
await browser.close();
srv.close();
