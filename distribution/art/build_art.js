#!/usr/bin/env node
// Renders the world art (world.js) to PNGs for the iOS asset catalog, @1x/@2x/@3x.
//   node distribution/art/build_art.js            → App/Resources/Assets.xcassets/Art/*.imageset
//   node distribution/art/build_art.js --check    → render nothing; validate grids and the item map
// Needs Playwright with Chromium (set PLAYWRIGHT_PATH if it isn't resolvable from here).
'use strict';
const fs = require('fs');
const path = require('path');
const W = require('./world.js');

const ROOT = path.resolve(__dirname, '../..');
const OUT = path.join(ROOT, 'App/Resources/Assets.xcassets/Art');
const THEMES = ['den', 'atelier'];

// name → { art, pt: [w, h] } (points; the PNGs are 1×, 2× and 3× that).
function inventory() {
  const list = [];
  const add = (name, art, scale) => list.push({ name, art, pt: [Math.round(art.w * scale), Math.round(art.h * scale)] });
  for (const t of THEMES) {
    add(`garden-${t}`, W.garden(t), 3);
    for (const p of Object.keys(W.PLACES)) add(`stage-${p}-${t}`, W.stage(p, t), 3);
    for (const m of W.MOODS) { const a = W.mascot(t, m); add(`mascot-${m}-${t}`, a, 112 / a.w); }
    for (const k of Object.keys(W.ICONS)) add(`icon-${k}-${t}`, W.pictogram(k, t), 3);
    for (const k of ['ok', 'again', 'miss']) add(`stamp-${k}-${t}`, W.stamp(k, t), 2);
  }
  return list;
}

const svgOf = (a) => `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 ${a.w} ${a.h}" width="100%" height="100%" preserveAspectRatio="none"${a.crisp ? ' shape-rendering="crispEdges"' : ''}>` +
  a.paths.map((p) => `<path d="${p.d}" fill="${p.fill}" stroke="${p.stroke}" stroke-width="${p.sw}" opacity="${p.op}"${p.dash ? ` stroke-dasharray="${p.dash}"` : ''} stroke-linecap="round" stroke-linejoin="round"/>`).join('') + '</svg>';

function check() {
  const problems = [];
  for (const [k, g] of Object.entries(W.ICONS)) if (g.length !== 12 || g.some((r) => r.length !== 12)) problems.push(`icon ${k} is not 12 × 12`);
  for (const m of W.MOODS) { const g = W.mochiGrid(m); if (g.length !== 24 || g.some((r) => r.length !== 28)) problems.push(`mochi ${m} is not 28 × 24`); }
  for (const icon of new Set([...Object.values(W.ITEM_ICON), ...Object.values(W.PACK_ICON)])) if (!W.ICONS[icon]) problems.push(`no pictogram "${icon}"`);
  return problems;
}

async function main() {
  const problems = check();
  if (problems.length) { console.error(problems.join('\n')); process.exit(1); }
  if (process.argv.includes('--check')) { console.log('art ok'); return; }
  const { chromium } = require(process.env.PLAYWRIGHT_PATH || 'playwright');
  const browser = await chromium.launch(process.env.CHROMIUM_PATH ? { executablePath: process.env.CHROMIUM_PATH } : {});
  fs.rmSync(OUT, { recursive: true, force: true });
  fs.mkdirSync(OUT, { recursive: true });
  fs.writeFileSync(path.join(OUT, 'Contents.json'), JSON.stringify({ info: { author: 'xcode', version: 1 }, properties: { 'provides-namespace': true } }, null, 2) + '\n');
  const items = inventory();
  for (const scale of [1, 2, 3]) {
    const page = await browser.newPage({ deviceScaleFactor: scale, viewport: { width: 400, height: 400 } });
    for (const it of items) {
      const dir = path.join(OUT, `${it.name}.imageset`);
      fs.mkdirSync(dir, { recursive: true });
      await page.setViewportSize({ width: it.pt[0], height: it.pt[1] });
      await page.setContent(`<html><body style="margin:0;background:transparent"><div id="a" style="width:${it.pt[0]}px;height:${it.pt[1]}px">${svgOf(it.art)}</div></body></html>`);
      await page.locator('#a').screenshot({ path: path.join(dir, `${it.name}@${scale}x.png`), omitBackground: true });
    }
    await page.close();
  }
  for (const it of items) {
    const crisp = it.art.crisp;
    fs.writeFileSync(path.join(OUT, `${it.name}.imageset`, 'Contents.json'), JSON.stringify({
      images: [1, 2, 3].map((s) => ({ filename: `${it.name}@${s}x.png`, idiom: 'universal', scale: `${s}x` })),
      info: { author: 'xcode', version: 1 },
      // Pixel art must not be smoothed when scaled; the ink art may be.
      properties: crisp ? { 'preserves-vector-representation': false, 'template-rendering-intent': 'original' } : { 'template-rendering-intent': 'original' },
    }, null, 2) + '\n');
  }
  // What the app needs alongside the pictures: the item → pictogram map and the map labels.
  fs.writeFileSync(path.join(ROOT, 'App/Resources/art-manifest.json'), JSON.stringify({
    packIcon: W.PACK_ICON, itemIcon: W.ITEM_ICON, places: W.placeLabels(), map: { w: 118, h: 100 },
  }, null, 2) + '\n');
  await browser.close();
  console.log(`rendered ${items.length} images × 3 scales into ${path.relative(ROOT, OUT)}`);
}

main().catch((e) => { console.error(e); process.exit(1); });
