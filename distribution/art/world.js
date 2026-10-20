// Memory Garden · World art engine
// One description of the garden, two ways to draw it:
//   • the Den (MaoMao): night-time pixel art — palette shading and ordered dithering, no outlines;
//   • the Atelier (Salma): morning ink-and-wash — ink lines, soft washes, hatching for shade.
// Scenes are lists of shapes with materials; the renderers turn them into plain SVG path data
// ({ d, fill, stroke, sw, op }) so the canvas, the install site and the iOS asset build can all
// draw the same art. Coordinates are in "cells" (the Den's pixel unit).
(function (root) {
  'use strict';

  // ───────────── deterministic randomness (independent of the engine RNG) ─────────────
  function rng(seed) {
    let h = 2166136261 >>> 0;
    for (const ch of String(seed)) { h ^= ch.charCodeAt(0); h = Math.imul(h, 16777619) >>> 0; }
    return () => { h += 0x6D2B79F5; let t = h; t = Math.imul(t ^ (t >>> 15), t | 1); t ^= t + Math.imul(t ^ (t >>> 7), t | 61); return ((t ^ (t >>> 14)) >>> 0) / 4294967296; };
  }

  // ───────────── materials ─────────────
  // Den: [base, shade, light]. Atelier: wash colour, wash opacity, hatch density for shade (0–1).
  const MAT = {
    stone:      { den: ['#4B3B66', '#3A2E50', '#5E4C7E'], at: ['#E3D5B6', 0.85, 0.6] },
    stoneLight: { den: ['#5E4C7E', '#4B3B66', '#76629A'], at: ['#EFE5CF', 0.9, 0.4] },
    wood:       { den: ['#6A4A3A', '#4E3529', '#86604B'], at: ['#D9BFA0', 0.8, 0.6] },
    rose:       { den: ['#C27C9E', '#9E5F7E', '#E3A0BE'], at: ['#E8B4C8', 0.75, 0.5] },
    amber:      { den: ['#D9A441', '#A97A28', '#F2C46A'], at: ['#EBC97A', 0.75, 0.5] },
    teal:       { den: ['#3E8C8C', '#2C6A6A', '#5BB0A8'], at: ['#9CCFC4', 0.75, 0.5] },
    terracotta: { den: ['#C0563B', '#8E3E2A', '#DE7A5C'], at: ['#E3A08C', 0.75, 0.5] },
    indigo:     { den: ['#4A4FA3', '#363A80', '#6670C4'], at: ['#AEB4E6', 0.75, 0.5] },
    sage:       { den: ['#6F9E80', '#4F7A60', '#94C2A3'], at: ['#BFD8C2', 0.8, 0.45] },
    foliage:    { den: ['#2F5D4A', '#24483A', '#3E7A5F'], at: ['#BFD8C2', 0.7, 0.55] },
    foliageDark:{ den: ['#24483A', '#1B372D', '#2F5D4A'], at: ['#A9C9B4', 0.7, 0.6] },
    trunk:      { den: ['#4E3529', '#3A271E', '#6A4A3A'], at: ['#B89A7A', 0.8, 0.5] },
    brass:      { den: ['#D9B45A', '#A8842F', '#FFE08A'], at: ['#D8B86A', 0.9, 0.3] },
    paper:      { den: ['#E9E4F0', '#BDB6C9', '#FFFFFF'], at: ['#FFFBF2', 1, 0.1] },
    lit:        { den: ['#FFE08A', '#F2C46A', '#FFF4D6'], at: ['#F6E3A8', 0.9, 0] },
    glass:      { den: ['#2B3F6B', '#1E2E52', '#3A5590'], at: ['#C9DCEB', 0.7, 0.3] },
    water:      { den: ['#2B3F6B', '#22335A', '#3A5590'], at: ['#B9D3E6', 0.6, 0.3] },
    pathStone:  { den: ['#3A2E50', '#2E2440', '#4B3B66'], at: ['#E3D5B6', 0.9, 0] },
    ground:     { den: ['#1E2530', '#191F29', '#252E3B'], at: ['#EFE6D0', 0, 0] },
    hillFar:    { den: ['#251E3C', '#1E1832', '#2E2648'], at: ['#DCE7DE', 0.5, 0.25] },
    hillNear:   { den: ['#1F2A30', '#1A2328', '#283841'], at: ['#CFE0D3', 0.55, 0.35] },
    ink:        { den: ['#241B2F', '#17121F', '#2E2640'], at: ['#1E2A44', 1, 0] },
    lantern:    { den: ['#FF6B6B', '#C94A4A', '#FFB3A0'], at: ['#E3A08C', 0.9, 0] },
    plate:      { den: ['#E9E4F0', '#BDB6C9', '#FFFFFF'], at: ['#FFFBF2', 1, 0.2] },
    cloth:      { den: ['#8E3B46', '#6B2B35', '#B5525F'], at: ['#E2B3B8', 0.7, 0.4] },
    night:      { den: ['#1A1430', '#120E1E', '#241B3F'], at: ['#F3EAD4', 0, 0] },
  };
  const INK = '#1E2A44';
  // Each place has its own hue, used by the place's building and by its game's stage and chips.
  const PLACES = {
    journey:     { name: 'Palace',  mat: 'rose',       den: '#E3A0BE', at: '#A0446E', motif: 'doors and keys' },
    gathering:   { name: 'Hall',    mat: 'amber',      den: '#F2C46A', at: '#8A5A00', motif: 'lanterns and portraits' },
    numberVault: { name: 'Vault',   mat: 'teal',       den: '#5BB0A8', at: '#1F6B66', motif: 'dial and brass' },
    kitchen:     { name: 'Kitchen', mat: 'terracotta', den: '#DE7A5C', at: '#A8442F', motif: 'tickets and plates' },
    lookout:     { name: 'Tower',   mat: 'indigo',     den: '#8F96E6', at: '#3A4290', motif: 'telescope and sky' },
    dayRecall:   { name: 'Journal', mat: 'sage',       den: '#94C2A3', at: '#3F6B4E', motif: 'paper and ink' },
  };

  // ───────────── geometry helpers ─────────────
  const ellipsePoly = (cx, cy, rx, ry, n = 28) => Array.from({ length: n }, (_, i) => { const a = (i / n) * Math.PI * 2; return [cx + Math.cos(a) * rx, cy + Math.sin(a) * ry]; });
  const rectPoly = (x, y, w, h) => [[x, y], [x + w, y], [x + w, y + h], [x, y + h]];
  function polyOf(s) {
    if (s.t === 'rect') return rectPoly(s.x, s.y, s.w, s.h);
    if (s.t === 'ellipse') return ellipsePoly(s.cx, s.cy, s.rx, s.ry);
    if (s.t === 'poly') return s.pts;
    return null;
  }
  function inPoly(x, y, pts) {
    let inside = false;
    for (let i = 0, j = pts.length - 1; i < pts.length; j = i++) {
      const [xi, yi] = pts[i], [xj, yj] = pts[j];
      if ((yi > y) !== (yj > y) && x < ((xj - xi) * (y - yi)) / (yj - yi) + xi) inside = !inside;
    }
    return inside;
  }
  function bbox(pts) { const xs = pts.map((p) => p[0]), ys = pts.map((p) => p[1]); return { x0: Math.min(...xs), x1: Math.max(...xs), y0: Math.min(...ys), y1: Math.max(...ys) }; }
  const distSeg = (px, py, [ax, ay], [bx, by]) => { const dx = bx - ax, dy = by - ay, l = dx * dx + dy * dy || 1; let t = ((px - ax) * dx + (py - ay) * dy) / l; t = Math.max(0, Math.min(1, t)); return Math.hypot(px - ax - t * dx, py - ay - t * dy); };
  // Keep the part of a polygon on one side of the line through `a` with normal `n` (Sutherland–Hodgman).
  function clipHalf(pts, a, n) {
    const out = [], side = (p) => (p[0] - a[0]) * n[0] + (p[1] - a[1]) * n[1];
    for (let i = 0; i < pts.length; i++) {
      const p = pts[i], q = pts[(i + 1) % pts.length], sp = side(p), sq = side(q);
      if (sp >= 0) out.push(p);
      if ((sp >= 0) !== (sq >= 0)) { const t = sp / (sp - sq); out.push([p[0] + (q[0] - p[0]) * t, p[1] + (q[1] - p[1]) * t]); }
    }
    return out;
  }
  function shadePoly(pts, side, frac = 0.38) {
    const b = bbox(pts);
    if (side === 'right') return clipHalf(pts, [b.x1 - (b.x1 - b.x0) * frac, 0], [1, 0]);
    if (side === 'left') return clipHalf(pts, [b.x0 + (b.x1 - b.x0) * frac, 0], [-1, 0]);
    if (side === 'bottom') return clipHalf(pts, [0, b.y1 - (b.y1 - b.y0) * frac], [0, 1]);
    if (side === 'top') return clipHalf(pts, [0, b.y0 + (b.y1 - b.y0) * frac], [0, -1]);
    return pts;
  }

  // ───────────── Den renderer: pixel grid ─────────────
  const BAYER = [[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]];
  function pixelRender(scene) {
    const W = scene.w, H = scene.h, grid = new Array(W * H).fill(null);
    const put = (x, y, c) => { if (x >= 0 && y >= 0 && x < W && y < H && c) grid[y * W + x] = c; };
    for (const s of scene.shapes) {
      if (s.atOnly) continue;
      if (s.t === 'sky') {
        const y0 = s.y0 || 0, hh = s.h || H - y0;
        for (let y = y0; y < Math.min(H, y0 + hh); y++) for (let x = 0; x < W; x++) {
          const f = ((y - y0) / hh) * (s.bands.length - 1), i = Math.floor(f), r = f - i;
          put(x, y, r * 16 > BAYER[y % 4][x % 4] ? s.bands[Math.min(i + 1, s.bands.length - 1)] : s.bands[i]);
        }
        continue;
      }
      if (s.t === 'px') { put(s.x, s.y, s.c); continue; }
      if (s.t === 'sprite') { s.rows.forEach((row, dy) => [...row].forEach((ch, dx) => { if (ch !== '.') put(s.x + dx, s.y + dy, s.pal[ch]); })); continue; }
      const m = MAT[s.m] || MAT.stone, [base, shade, light] = s.color ? [s.color, s.color, s.color] : m.den;
      if (s.t === 'line') {
        const w = s.w || 1; const b = bbox(s.pts);
        for (let y = Math.floor(b.y0 - w); y <= Math.ceil(b.y1 + w); y++) for (let x = Math.floor(b.x0 - w); x <= Math.ceil(b.x1 + w); x++) {
          let d = Infinity; for (let i = 0; i < s.pts.length - 1; i++) d = Math.min(d, distSeg(x + 0.5, y + 0.5, s.pts[i], s.pts[i + 1]));
          if (d <= w / 2 && (!s.dash || (Math.floor((x + y) / s.dash) % 2 === 0))) put(x, y, base);
        }
        continue;
      }
      const pts = polyOf(s); if (!pts) continue;
      const b = bbox(pts), sh = s.shade ? shadePoly(pts, s.shade, s.shadeFrac) : null;
      const band = s.shade === 'right' || s.shade === 'left' ? (b.x1 - b.x0) * 0.12 : (b.y1 - b.y0) * 0.12;
      for (let y = Math.floor(b.y0); y <= Math.ceil(b.y1); y++) for (let x = Math.floor(b.x0); x <= Math.ceil(b.x1); x++) {
        const cx = x + 0.5, cy = y + 0.5;
        if (!inPoly(cx, cy, pts)) continue;
        let c = base;
        if (sh && sh.length > 2 && inPoly(cx, cy, sh)) c = shade;
        else if (sh && sh.length > 2 && band > 0.8) {
          // a dithered band where shade meets light
          const sb = bbox(sh), d = s.shade === 'right' ? sb.x0 - cx : s.shade === 'left' ? cx - sb.x1 : s.shade === 'bottom' ? sb.y0 - cy : cy - sb.y1;
          if (d >= 0 && d < band && (1 - d / band) * 16 > BAYER[y % 4][x % 4]) c = shade;
        }
        if (s.lightTop && y === Math.floor(b.y0)) c = light;
        put(x, y, c);
      }
    }
    // Rows of equal colour become one path per colour: compact and crisp.
    const byColor = {};
    for (let y = 0; y < H; y++) {
      let x = 0;
      while (x < W) {
        const c = grid[y * W + x];
        if (!c) { x++; continue; }
        let n = 1; while (x + n < W && grid[y * W + x + n] === c) n++;
        (byColor[c] = byColor[c] || []).push(`M${x} ${y}h${n}v1h-${n}z`);
        x += n;
      }
    }
    return { w: W, h: H, crisp: true, paths: Object.entries(byColor).map(([fill, ds]) => ({ d: ds.join(''), fill, stroke: 'none', sw: 0, op: 1 })) };
  }

  // ───────────── Atelier renderer: ink and wash ─────────────
  const f2 = (n) => Math.round(n * 100) / 100;
  const polyD = (pts) => 'M' + pts.map((p) => f2(p[0]) + ' ' + f2(p[1])).join('L') + 'Z';
  function hatchLines(pts, gap, angle) {
    if (!pts || pts.length < 3) return '';
    const b = bbox(pts), ca = Math.cos(angle), sa = Math.sin(angle);
    // Lines x·cos + y·sin = k, for k across the box; each is clipped to the polygon (even–odd).
    const ks = pts.map((p) => p[0] * ca + p[1] * sa), k0 = Math.min(...ks), k1 = Math.max(...ks);
    let d = '';
    for (let k = k0 + gap / 2; k < k1; k += gap) {
      const hits = [];
      for (let i = 0; i < pts.length; i++) {
        const p = pts[i], q = pts[(i + 1) % pts.length], vp = p[0] * ca + p[1] * sa - k, vq = q[0] * ca + q[1] * sa - k;
        if ((vp >= 0) !== (vq >= 0)) { const t = vp / (vp - vq); hits.push([p[0] + (q[0] - p[0]) * t, p[1] + (q[1] - p[1]) * t]); }
      }
      hits.sort((u, v) => (u[0] * -sa + u[1] * ca) - (v[0] * -sa + v[1] * ca));
      for (let i = 0; i + 1 < hits.length; i += 2) d += `M${f2(hits[i][0])} ${f2(hits[i][1])}L${f2(hits[i + 1][0])} ${f2(hits[i + 1][1])}`;
    }
    return d;
  }
  function inkRender(scene) {
    const out = [];
    const ink = (d, sw, op) => out.push({ d, fill: 'none', stroke: INK, sw, op: op == null ? 1 : op });
    for (const s of scene.shapes) {
      if (s.denOnly) continue;
      if (s.t === 'sky') { if (s.atBg) out.push({ d: `M0 0H${scene.w}V${scene.h}H0Z`, fill: s.atBg, stroke: 'none', sw: 0, op: 1 }); continue; }
      if (s.t === 'px' || s.t === 'sprite') continue;
      if (s.t === 'line') {
        const d = 'M' + s.pts.map((p) => f2(p[0]) + ' ' + f2(p[1])).join('L');
        out.push({ d, fill: 'none', stroke: s.inkColor || INK, sw: s.atW || 0.45, op: s.atOp == null ? 0.9 : s.atOp, dash: s.dash ? `${s.dash * 0.5} ${s.dash * 0.7}` : '' });
        continue;
      }
      const pts = polyOf(s); if (!pts) continue;
      const m = MAT[s.m] || MAT.stone, [wash, washOp, hatch] = m.at;
      const d = s.t === 'ellipse' ? `M${f2(s.cx - s.rx)} ${f2(s.cy)}a${f2(s.rx)} ${f2(s.ry)} 0 1 0 ${f2(2 * s.rx)} 0a${f2(s.rx)} ${f2(s.ry)} 0 1 0 ${f2(-2 * s.rx)} 0Z` : polyD(pts);
      if (washOp > 0 && !s.noWash) out.push({ d, fill: s.atColor || wash, stroke: 'none', sw: 0, op: s.atOpacity || washOp });
      if (s.shade && hatch > 0 && !s.noHatch) {
        const h = hatchLines(shadePoly(pts, s.shade, s.shadeFrac), Math.max(0.55, 1.4 - hatch), s.hatchAngle || (s.shade === 'left' ? -Math.PI / 4 : Math.PI / 4));
        if (h) ink(h, 0.18, 0.55);
      }
      if (!s.noInk) ink(d, s.inkW || 0.42, s.inkOp);
    }
    return { w: scene.w, h: scene.h, crisp: false, paths: out };
  }

  const render = (scene, theme) => (theme === 'atelier' ? inkRender(scene) : pixelRender(scene));

  // ───────────── building blocks ─────────────
  const R = (x, y, w, h, m, o) => Object.assign({ t: 'rect', x, y, w, h, m }, o || {});
  const P = (pts, m, o) => Object.assign({ t: 'poly', pts, m }, o || {});
  const E = (cx, cy, rx, ry, m, o) => Object.assign({ t: 'ellipse', cx, cy, rx, ry, m }, o || {});
  const L = (pts, m, w, o) => Object.assign({ t: 'line', pts, m, w }, o || {});

  function tree(x, y, s = 1, dark) {
    return [R(x - 0.8 * s, y - 2 * s, 1.6 * s, 4 * s, 'trunk', { shade: 'right' }),
      E(x, y - 5 * s, 4.2 * s, 4 * s, dark ? 'foliageDark' : 'foliage', { shade: 'right', shadeFrac: 0.45 }),
      E(x - 1.4 * s, y - 6.6 * s, 1.8 * s, 1.4 * s, dark ? 'foliage' : 'sage', { noInk: true, noHatch: true, atOpacity: 0.4 })];
  }
  function cypress(x, y, s = 1) { return [E(x, y - 6 * s, 2.2 * s, 6.5 * s, 'foliageDark', { shade: 'right', shadeFrac: 0.5 })]; }
  function bush(x, y, s = 1) { return [E(x, y, 3 * s, 1.8 * s, 'foliage', { shade: 'bottom', shadeFrac: 0.5 })]; }
  function windowLit(x, y, w = 2, h = 3) { return [R(x, y, w, h, 'lit', { inkW: 0.3 })]; }

  // The six places, drawn at (x, y) = bottom centre.
  const LANDMARKS = {
    journey: (x, y) => [ // a small palace: walls, crenellations, a central tower with a rose roof, a flag
      R(x - 10, y - 11, 20, 11, 'stone', { shade: 'right', lightTop: true }),
      ...[0, 1, 2, 3, 4].map((i) => R(x - 10 + i * 4.5, y - 13, 2.4, 2, 'stone')),
      R(x - 3.5, y - 19, 7, 19, 'stoneLight', { shade: 'right' }),
      P([[x - 4.8, y - 19], [x, y - 26], [x + 4.8, y - 19]], 'rose', { shade: 'right' }),
      L([[x, y - 26], [x, y - 31]], 'ink', 0.6, { atW: 0.35 }), P([[x, y - 31], [x + 4, y - 30], [x, y - 29]], 'rose', { noHatch: true }),
      P([[x - 2, y], [x - 2, y - 4], [x, y - 6], [x + 2, y - 4], [x + 2, y]], 'wood', { shade: 'right' }),
      ...windowLit(x - 1, y - 15, 2, 3), ...windowLit(x - 8, y - 7, 2, 2.6), ...windowLit(x + 6, y - 7, 2, 2.6),
    ],
    gathering: (x, y) => [ // a pavilion: platform, columns, amber roof, string lights
      R(x - 12, y - 2.4, 24, 2.4, 'stone', { shade: 'bottom' }),
      ...[-9, -3, 3, 9].map((dx) => R(x + dx - 0.9, y - 12, 1.8, 9.6, 'paper', { shade: 'right' })),
      P([[x - 13.5, y - 12], [x, y - 20], [x + 13.5, y - 12]], 'amber', { shade: 'right' }),
      R(x - 13.5, y - 12.8, 27, 1.2, 'wood'),
      ...[-10, -6, -2, 2, 6, 10].map((dx, i) => E(x + dx, y - 10.2 + (i % 2) * 0.7, 0.75, 0.75, 'lit', { inkW: 0.25 })),
    ],
    numberVault: (x, y) => [ // a vault: stone block, dome, a big teal door with a brass dial
      R(x - 9, y - 13, 18, 13, 'stone', { shade: 'right', lightTop: true }),
      P(ellipsePoly(x, y - 13, 7, 4.5, 24).filter((p) => p[1] <= y - 13 + 0.01), 'teal', { shade: 'right' }),
      E(x, y - 6.5, 5, 5, 'teal', { shade: 'right' }), E(x, y - 6.5, 2.4, 2.4, 'brass', { shade: 'bottom' }),
      L([[x - 4.2, y - 6.5], [x + 4.2, y - 6.5]], 'brass', 0.7, { atW: 0.3 }), L([[x, y - 10.7], [x, y - 2.3]], 'brass', 0.7, { atW: 0.3 }),
    ],
    kitchen: (x, y) => [ // a cottage with a terracotta roof and a smoking chimney
      R(x - 9, y - 10, 18, 10, 'wood', { shade: 'right', lightTop: true }),
      P([[x - 11, y - 10], [x, y - 18], [x + 11, y - 10]], 'terracotta', { shade: 'right' }),
      R(x + 4, y - 19, 2.6, 5, 'stone', { shade: 'right' }),
      R(x - 2, y - 5.5, 4, 5.5, 'paper', { shade: 'right' }), ...windowLit(x - 7, y - 7.5, 3, 2.6), ...windowLit(x + 4, y - 7.5, 3, 2.6),
    ],
    lookout: (x, y) => [ // a tall tower with an indigo cap and a brass telescope
      R(x - 4, y - 26, 8, 26, 'indigo', { shade: 'right', lightTop: true }),
      R(x - 5.5, y - 28, 11, 2.2, 'stone', { shade: 'bottom' }),
      P([[x - 5, y - 28], [x, y - 33], [x + 5, y - 28]], 'indigo', { shade: 'right' }),
      L([[x + 2, y - 29.5], [x + 7.5, y - 32.5]], 'brass', 1.1, { atW: 0.55 }),
      ...windowLit(x - 1, y - 21, 2, 3), ...windowLit(x - 1, y - 12, 2, 3),
      P([[x - 1.6, y], [x - 1.6, y - 3.5], [x, y - 5], [x + 1.6, y - 3.5], [x + 1.6, y]], 'wood'),
    ],
    dayRecall: (x, y) => [ // a reading nook: a little roof on posts, a desk with an open book and a lamp
      R(x - 8, y - 9, 1.2, 9, 'wood'), R(x + 6.8, y - 9, 1.2, 9, 'wood'),
      P([[x - 10, y - 9], [x, y - 14], [x + 10, y - 9]], 'sage', { shade: 'right' }),
      R(x - 5, y - 4, 10, 1.4, 'wood', { shade: 'bottom' }), R(x - 4, y - 2.6, 1, 2.6, 'wood'), R(x + 3, y - 2.6, 1, 2.6, 'wood'),
      P([[x - 3.6, y - 4], [x - 0.2, y - 5.4], [x - 0.2, y - 4]], 'paper'), P([[x + 0.2, y - 4], [x + 0.2, y - 5.4], [x + 3.6, y - 4]], 'paper'),
      E(x + 4.2, y - 6.4, 1.1, 1.1, 'lit', { inkW: 0.25 }),
    ],
  };

  // Stepping stones along a quadratic curve, skipping the ends (where the buildings stand).
  function steppingStones(a, m, b, gap, skipStart, skipEnd) {
    const at = (t) => [(1 - t) * (1 - t) * a[0] + 2 * (1 - t) * t * m[0] + t * t * b[0], (1 - t) * (1 - t) * a[1] + 2 * (1 - t) * t * m[1] + t * t * b[1]];
    let len = 0, prev = at(0); const samples = [[0, 0]];
    for (let i = 1; i <= 100; i++) { const p = at(i / 100); len += Math.hypot(p[0] - prev[0], p[1] - prev[1]); samples.push([i / 100, len]); prev = p; }
    const out = [];
    for (let d = skipStart; d < len - skipEnd; d += gap) {
      const t = samples.find((s) => s[1] >= d)[0], [x, y] = at(t);
      out.push(E(x, y, 1.25, 0.8, 'pathStone', { lightTop: true, inkW: 0.28, inkOp: 0.8 }));
    }
    return out;
  }

  // ───────────── the garden map (118 × 100 cells) ─────────────
  const MAP_PLACES = { journey: [26, 33], gathering: [91, 32], numberVault: [22, 74], kitchen: [61, 58], lookout: [99, 80], dayRecall: [60, 92] };
  function gardenScene() {
    const r = rng('garden'), shapes = [], W = 118, H = 100;
    shapes.push({ t: 'sky', bands: ['#120E1E', '#17122A', '#1C1634', '#221A3E'], h: 38, atBg: '#F6EEDB' });
    shapes.push(R(0, 30, W, H - 30, 'ground', { noInk: true }));
    // moon (Den) / sun (Atelier) — the same disc, two times of day
    shapes.push(E(98, 9, 5, 5, 'paper', { atColor: '#F6E3A8', atOpacity: 0.7, noHatch: true, inkW: 0.3 }));
    shapes.push(E(96.6, 8, 1.1, 1, 'paper', { color: '#D8D2E2', noInk: true, noWash: true }));
    // hills
    const hill = (y0, amp, seed, m) => { const pts = [[0, H]]; for (let x = 0; x <= W; x += 3) pts.push([x, y0 - amp * (0.6 * Math.sin(x / 13 + seed) + 0.4 * Math.sin(x / 7 + seed * 2))]); pts.push([W, H]); return P(pts, m, { inkW: 0.35 }); };
    shapes.push(hill(30, 4, 1.3, 'hillFar'), hill(38, 3, 4.1, 'hillNear'));
    shapes.push(R(0, 40, W, H - 40, 'ground', { noInk: true }));
    shapes.push({ t: 'sky', y0: 36, h: 64, bands: ['#1A2328', '#1E2A2C', '#22302F', '#1E2A2C'] });
    // paths: from the kitchen (the hub) out to every place
    const hub = MAP_PLACES.kitchen;
    for (const k of Object.keys(MAP_PLACES)) {
      if (k === 'kitchen') continue;
      const [x, y] = MAP_PLACES[k], mx = (x + hub[0]) / 2 + (r() - 0.5) * 8, my = (y + hub[1]) / 2 + (r() - 0.5) * 6;
      shapes.push(...steppingStones([hub[0], hub[1] + 1.5], [mx, my], [x, y + 1.5], 3.4, 4, 3));
    }
    // water: a little pond
    shapes.push(E(41, 55, 6.5, 2.4, 'water', { shade: 'bottom', inkW: 0.35 }), L([[38, 54.6], [41.5, 54.6]], 'paper', 0.4, { color: '#5E7BB8', atOp: 0.4, atW: 0.2 }));
    // trees and bushes (fixed spots, kept clear of the places)
    [[8, 50, 1, 0], [42, 44, 0.9, 1], [77, 46, 1, 0], [112, 52, 1.1, 1], [40, 70, 0.8, 0], [8, 96, 1.1, 1], [84, 96, 0.9, 0], [112, 96, 1, 1]].forEach(([x, y, s, d]) => shapes.push(...tree(x, y, s, d)));
    [[46, 33], [70, 34], [114, 36]].forEach(([x, y]) => shapes.push(...cypress(x, y, 0.8)));
    [[30, 62], [76, 76], [104, 60], [16, 86], [44, 90], [76, 86]].forEach(([x, y]) => shapes.push(...bush(x, y, 0.9)));
    // flowers
    for (let i = 0; i < 26; i++) { const x = Math.floor(r() * W), y = 44 + Math.floor(r() * 54); const c = ['#E3A0BE', '#F2C46A', '#B9A3E3'][i % 3]; shapes.push({ t: 'px', x, y, c }); }
    // the places
    for (const [k, [x, y]] of Object.entries(MAP_PLACES)) shapes.push(...LANDMARKS[k](x, y));
    // stars (Den only, drawn as single pixels)
    for (let i = 0; i < 30; i++) shapes.push({ t: 'px', x: Math.floor(r() * W), y: Math.floor(r() * 26), c: r() < 0.7 ? '#FFF4D6' : '#B9A3E3' });
    return { w: W, h: H, shapes };
  }

  // Ambient motion: fireflies at night (Den), drifting petals in the morning (Atelier).
  function ambient(theme, count, w, h, seed) {
    const r = rng(seed || 'ambient');
    return Array.from({ length: count }, (_, i) => ({ x: r() * w, y: h * 0.3 + r() * h * 0.65, delay: (r() * 6).toFixed(2), dur: (5 + r() * 5).toFixed(2), size: theme === 'atelier' ? 1.2 + r() * 1.2 : 1, color: theme === 'atelier' ? ['#E8B4C8', '#D8B86A', '#BFD8C2'][i % 3] : ['#E6F59A', '#FFE08A'][i % 2] }));
  }

  // ───────────── game stages (130 × 84 cells; sits behind the top of each game screen) ─────────────
  function stageBase(place, opts) {
    const SW = 130, SH = 84, shapes = [], hue = PLACES[place];
    const indoor = opts && opts.indoor;
    if (indoor) {
      shapes.push({ t: 'sky', bands: ['#211A36', '#2A2142', '#342A50', '#3D3160'], h: 60, atBg: '#F6EEDB' });
      shapes.push(R(0, 0, SW, 60, 'stone', { atOnly: true, atOpacity: 0.35, noInk: true }));
      shapes.push(R(0, 60, SW, 24, 'wood', { shade: 'bottom', shadeFrac: 0.6, noInk: true, atOpacity: 0.5 }));
      shapes.push(L([[0, 60], [SW, 60]], 'ink', 0.6, { atW: 0.4 }));
    } else {
      shapes.push({ t: 'sky', bands: ['#120E1E', '#17122A', '#1C1634', '#221A3E'], h: 60, atBg: '#F6EEDB' });
      shapes.push(R(0, 58, SW, 26, 'ground', { noInk: true }));
    }
    return { SW, SH, shapes, hue };
  }
  const STAGES = {
    journey: () => { // a palace corridor: arches receding to a lit door
      const { SW, SH, shapes } = stageBase('journey', { indoor: true });
      for (let i = 0; i < 4; i++) {
        const w = 70 - i * 15, h = 54 - i * 11, x = SW / 2 - w / 2, y = 60 - h;
        shapes.push(P([[x, 60], [x, y + w * 0.25], [SW / 2, y], [x + w, y + w * 0.25], [x + w, 60]], 'stoneLight', { color: ['#5E4C7E', '#4B3B66', '#3A2E50', '#2E2440'][i], noWash: i > 0, atOpacity: 0.25, inkW: 0.35, noHatch: true }));
      }
      shapes.push(P([[SW / 2 - 7, 60], [SW / 2 - 7, 44], [SW / 2, 39], [SW / 2 + 7, 44], [SW / 2 + 7, 60]], 'rose', { shade: 'right' }));
      shapes.push(E(SW / 2 + 4, 51, 0.8, 0.8, 'brass', { inkW: 0.2 }));
      [[14, 28], [116, 28]].forEach(([x, y]) => { shapes.push(R(x - 1.5, y, 3, 6, 'brass', { inkW: 0.3 }), E(x, y - 1.6, 1.6, 2.2, 'lit', { inkW: 0.25 })); });
      for (let i = 0; i < 7; i++) shapes.push(R(16 + i * 15, 66 + (i % 2), 9, 1.2, 'rose', { noInk: true, atOpacity: 0.5 }));
      return { w: SW, h: SH, shapes };
    },
    gathering: () => { // a party hall: curtains, string lights, a long table with flowers
      const { SW, SH, shapes } = stageBase('gathering', { indoor: true });
      shapes.push(P([[0, 0], [22, 0], [12, 48], [0, 52]], 'cloth', { shade: 'right' }), P([[SW, 0], [SW - 22, 0], [SW - 12, 48], [SW, 52]], 'cloth', { shade: 'left' }));
      const pts = []; for (let x = 6; x <= SW - 6; x += 4) pts.push([x, 10 + 5 * Math.sin((x / SW) * Math.PI)]);
      shapes.push(L(pts, 'ink', 0.4, { atW: 0.25 }));
      pts.forEach(([x, y], i) => { if (i % 2 === 0) shapes.push(E(x, y + 1.6, 1, 1.3, i % 4 ? 'lit' : 'amber', { inkW: 0.22 })); });
      shapes.push(R(14, 62, SW - 28, 4, 'cloth', { shade: 'bottom' }), R(18, 66, 2, 10, 'wood'), R(SW - 20, 66, 2, 10, 'wood'));
      [[34, 61], [64, 61], [94, 61]].forEach(([x, y]) => { shapes.push(R(x - 1, y - 4, 2, 4, 'glass', { inkW: 0.25 }), E(x, y - 5.5, 2.4, 2, 'rose', { noHatch: true }), E(x - 2, y - 4.8, 1.4, 1.2, 'amber', { noHatch: true })); });
      return { w: SW, h: SH, shapes };
    },
    numberVault: () => { // a vault wall: brickwork, a great dial in the middle
      const { SW, SH, shapes } = stageBase('numberVault', { indoor: true });
      for (let y = 4; y < 58; y += 6) for (let x = (y / 6) % 2 ? -6 : 0; x < SW; x += 12) shapes.push(R(x + 0.5, y, 11, 5, 'stone', { shade: 'bottom', shadeFrac: 0.25, atOpacity: 0.25, inkW: 0.18, inkOp: 0.5, noHatch: true }));
      shapes.push(E(SW / 2, 32, 25, 25, 'teal', { shade: 'right' }), E(SW / 2, 32, 19, 19, 'stoneLight', { shade: 'bottom', atOpacity: 0.6 }), E(SW / 2, 32, 6, 6, 'brass', { shade: 'bottom' }));
      for (let i = 0; i < 10; i++) { const a = (i / 10) * Math.PI * 2 - Math.PI / 2; shapes.push(R(SW / 2 + Math.cos(a) * 15.5 - 0.6, 32 + Math.sin(a) * 15.5 - 0.6, 1.2, 1.2, 'brass', { inkW: 0.18 })); }
      [[-14, 0], [14, 0], [0, -14], [0, 14]].forEach(([dx, dy]) => shapes.push(L([[SW / 2, 32], [SW / 2 + dx * 0.55, 32 + dy * 0.55]], 'brass', 1, { atW: 0.5 })));
      return { w: SW, h: SH, shapes };
    },
    kitchen: () => { // a kitchen: shelves with jars, a ticket rail, the counter
      const { SW, SH, shapes } = stageBase('kitchen', { indoor: true });
      shapes.push(R(6, 8, SW - 12, 1.6, 'brass', { inkW: 0.3 })); // the ticket rail
      [24, 40].forEach((y) => { shapes.push(R(8, y, 40, 1.6, 'wood', { shade: 'bottom' })); [12, 20, 28, 36, 44].forEach((x, i) => shapes.push(R(x - 2.5, y - 6, 5, 6, ['terracotta', 'sage', 'amber', 'teal', 'rose'][(i + y) % 5], { shade: 'right' }), R(x - 2.8, y - 7, 5.6, 1.2, 'wood'))); });
      shapes.push(R(78, 14, 34, 28, 'glass', { shade: 'right', atOpacity: 0.4 }), L([[95, 14], [95, 42]], 'wood', 1), L([[78, 28], [112, 28]], 'wood', 1));
      shapes.push(R(0, 52, SW, 8, 'stone', { shade: 'bottom', lightTop: true }));
      [[30, 51], [64, 51], [98, 51]].forEach(([x, y]) => shapes.push(E(x, y, 7, 1.8, 'plate', { shade: 'bottom' })));
      return { w: SW, h: SH, shapes };
    },
    lookout: () => { // a tower window onto the sky: stars and a moon at night, clouds and birds by day
      const { SW, SH, shapes } = stageBase('lookout', { indoor: true });
      const win = [[18, 62], [18, 24], [SW / 2, 5], [SW - 18, 24], [SW - 18, 62]];
      shapes.push(P(win, 'night', { color: '#110D22', atColor: '#EAF1F6', atOpacity: 1, inkW: 0.7 }));
      const r = rng('lookout-sky');
      for (let i = 0; i < 40; i++) { const x = 20 + r() * (SW - 40), y = 8 + r() * 50; if (inPoly(x, y, win)) shapes.push({ t: 'px', x: Math.floor(x), y: Math.floor(y), c: r() < 0.75 ? '#FFF4D6' : '#B9A3E3' }); }
      shapes.push(E(92, 20, 5, 5, 'paper', { color: '#E9E4F0', atColor: '#F6E3A8', atOpacity: 0.8, noHatch: true, inkW: 0.3 }), E(94, 18.5, 4.4, 4.6, 'night', { color: '#110D22', denOnly: true }));
      [[34, 22, 9], [60, 40, 12], [84, 50, 8]].forEach(([x, y, w]) => shapes.push(P([[x, y], [x + w * 0.2, y - 2.4], [x + w * 0.5, y - 3.2], [x + w * 0.8, y - 2.2], [x + w, y]], 'paper', { atOnly: true, atOpacity: 0.9, inkW: 0.3 })));
      [[44, 30], [50, 27]].forEach(([x, y]) => shapes.push(L([[x - 2, y - 1], [x, y], [x + 2, y - 1]], 'ink', 0.4, { atOnly: true, atW: 0.3 })));
      shapes.push(L([[SW / 2, 5], [SW / 2, 62]], 'wood', 1.4, { atW: 0.55 }), L([[18, 36], [SW - 18, 36]], 'wood', 1.4, { atW: 0.55 }));
      shapes.push(R(14, 60, SW - 28, 3, 'stone', { shade: 'bottom', lightTop: true }));
      shapes.push(L([[96, 72], [116, 60]], 'brass', 2.4, { atW: 1.2 }), L([[106, 66], [102, 80]], 'wood', 1, { atW: 0.4 }), L([[106, 66], [110, 80]], 'wood', 1, { atW: 0.4 }));
      return { w: SW, h: SH, shapes };
    },
    dayRecall: () => { // a writing desk: paper, ink pot, lamp, a window
      const { SW, SH, shapes } = stageBase('dayRecall', { indoor: true });
      shapes.push(R(82, 10, 30, 30, 'glass', { shade: 'right', atOpacity: 0.45 }), L([[97, 10], [97, 40]], 'wood', 1), L([[82, 25], [112, 25]], 'wood', 1));
      shapes.push(R(0, 52, SW, 8, 'wood', { shade: 'bottom', lightTop: true }));
      shapes.push(P([[30, 52], [36, 44], [70, 44], [64, 52]], 'paper', { shade: 'bottom', shadeFrac: 0.2 }));
      for (let i = 0; i < 4; i++) shapes.push(L([[38 + i * 0.8, 46 + i * 1.5], [64 + i * 0.8, 46 + i * 1.5]], 'ink', 0.4, { atW: 0.2, atOp: 0.5 }));
      shapes.push(E(80, 50, 3, 2.2, 'ink', { inkW: 0.3 }), L([[80, 48], [86, 40]], 'paper', 0.6, { atW: 0.3 }));
      shapes.push(R(14, 30, 2, 22, 'brass'), P([[8, 30], [15, 22], [22, 30]], 'sage', { shade: 'right' }), E(15, 31.5, 3, 1.4, 'lit', { inkW: 0.25 }));
      return { w: SW, h: SH, shapes };
    },
  };
  STAGES.review = () => { const s = gardenScene(); return { w: s.w, h: s.h, shapes: s.shapes }; };

  // ───────────── stamps ─────────────
  function stamp(kind, theme) {
    const den = theme !== 'atelier';
    const c = { ok: den ? '#9FE3C8' : '#1F5C4A', again: den ? '#FFD27A' : '#8A5A00', miss: den ? '#FF9DB0' : '#A8442F' }[kind];
    const ring = [], N = 24; for (let i = 0; i < N; i++) { const a = (i / N) * Math.PI * 2, r = i % 2 ? 9 : 10; ring.push([12 + Math.cos(a) * r, 12 + Math.sin(a) * r]); }
    const mark = kind === 'ok' ? 'M7 12.5l3.4 3.4L17.5 8.5' : kind === 'again' ? 'M16.5 9a5.5 5.5 0 1 0 1 5M16.5 5.5V9H13' : 'M8 8l8 8M16 8l-8 8';
    return { w: 24, h: 24, paths: [{ d: polyD(ring), fill: c, stroke: 'none', sw: 0, op: den ? 1 : 0.16 }, { d: polyD(ring), fill: 'none', stroke: c, sw: 1.1, op: 1 },
      { d: mark, fill: 'none', stroke: den ? '#17121F' : c, sw: 2, op: 1 }] };
  }

  // ───────────── mascots ─────────────
  // Mochi (the Den): a 28 × 24 pixel raccoon with a flower crown and a hoodie, built from a shared
  // head plus per-mood eyes, mouth, body and extras. The Professor (the Atelier): an ink-and-wash
  // raccoon in tweed, glasses and a bow tie, on a 56 × 48 box (the same 7 : 6 frame).
  const MOODS = ['idle', 'happy', 'thinking', 'cheer', 'oops', 'sleep', 'wave'];
  const MOCHI_PAL = { B: '#6A4A3A', D: '#5E5872', G: '#8F8AA0', H: '#B9A3E3', K: '#241B2F', L: '#E9E4F0', M: '#2E2640', N: '#1B1626', O: '#FFE08A', P: '#F4A7C6', R: '#E86A92', W: '#FFFFFF', c: '#7FD6F0', h: '#8E76C4', p: '#D97BA6', s: '#BDB6C9' };
  const MOCHI_HEAD = [
    '............PP.PP...', '..KKK.......PpKpP...', '.KGGGK......PPKPPK..', '.KGpGGK......KGpGK..',
    '.KGGGGGKKKKKKGGGGK..', '..KGGGGGGDDGGGGGK...', '.KGGLLLLGDDGLLLLGK..', '.KGLLLLLLGGLLLLLLGK.',
    'KGMMMMMLLLLLLMMMMMGK', 'EYES1', 'EYES2', 'KGMMMMMLLLLLLMMMMMGK',
    '.KGLPPLLLNNLLLPPLGK.', 'MOUTH1', 'MOUTH2', '...KKLLLLKKLLLLKK...',
  ];
  const EYES = {
    open: ['KMMMWKMMLLLLMMWKMMMK', 'KMMMKKMMLLLLMMKKMMMK'],
    happy: ['KMMMLLMMLLLLMMLLMMMK', 'KMMLMMLMLLLLMLMMLMMK'],
    closed: ['KMMMMMMMLLLLMMMMMMMK', 'KMMLLLMMLLLLMMLLLMMK'],
    up: ['KMMMMWKMLLLLMMMWKMMK', 'KMMMMKKMLLLLMMMKKMMK'],
    wide: ['KMMWKWMMLLLLMMWKWMMK', 'KMMKKKMMLLLLMMKKKMMK'],
  };
  const MOUTHS = {
    w: ['.KGLLLLLLLLLLLLLLGK.', '..KGLLLLKLLKLLLLGK..'],
    smile: ['.KGLLLLLKLLKLLLLLGK.', '..KGLLLLLKKLLLLLGK..'],
    open: ['.KGLLLLLKKKKLLLLLGK.', '..KGLLLLKRRKLLLLGK..'],
    o: ['.KGLLLLLLKKLLLLLLGK.', '..KGLLLLLKKLLLLLGK..'],
    side: ['.KGLLLLLLLLLLLLLLGK.', '..KGLLLLLLLKKKLLGK..'],
  };
  const BODY = {
    rest: ['......KHHKKKKKKKKKKHHK......', '.....KHHHHHHHhhHHHHHHHK.....', '....KHHHHHHHHhhHHHHHHHHK....', '....KHHHHHHHHhhHHHHHHHHK....',
      '....KHHKGGKHHhhHHKGGKHHK....', '....KHHKGGKHHhhHHKGGKHHK....', '....KHHHKKHHHhhHHHKKHHHK....', '.....KKKKKKKKKKKKKKKKKK.....'],
    open: ['......KHHKKKKKKKKKKHHK......', '.....KHHHHHHHhhHHHHHHHK.....', '....KHHHHHHHHhhHHHHHHHHK....', '....KHHHHHHHHhhHHHHHHHHK....',
      '....KHHHHHHHHhhHHHHHHHHK....', '....KHHHHHHHHhhHHHHHHHHK....', '....KHHHHHHHHhhHHHHHHHHK....', '.....KKKKKKKKKKKKKKKKKK.....'],
    oneDown: ['......KHHKKKKKKKKKKHHK......', '.....KHHHHHHHhhHHHHHHHK.....', '....KHHHHHHHHhhHHHHHHHHK....', '....KHHHHHHHHhhHHHHHHHHK....',
      '....KHHKGGKHHhhHHHHHHHHK....', '....KHHKGGKHHhhHHHHHHHHK....', '....KHHHKKHHHhhHHHHHHHHK....', '.....KKKKKKKKKKKKKKKKKK.....'],
  };
  // [x, y, rows] drawn over the figure (rows use the same palette; '.' leaves what's under).
  const mirror = (rows) => rows.map((r) => [...r].reverse().join(''));
  const ARM_UP = ['..KKK.', '.KGGGK', '.KGGGK', '.KGGGK', '..KHHK', '..KHHK', '..KHHK', '.KHHK.', '.KHHK.', '.KHHK.', 'KHHK..', 'KHHK..'];
  const ARM_CHEEK = ['..KKK.', '.KGGGK', '.KGGGK', '.KHHK.', '.KHHK.', 'KHHK..', 'KHHK..', 'KHHK..', 'KHK...'];
  const PAW_UP_R = [22, 6, ARM_UP], PAW_UP_L = [0, 6, mirror(ARM_UP)];
  const MOCHI_MOODS = {
    idle: { eyes: 'open', mouth: 'w', body: 'rest', extras: [] },
    happy: { eyes: 'happy', mouth: 'smile', body: 'rest', extras: [[25, 4, ['.O.', 'OWO', '.O.']]] },
    thinking: { eyes: 'up', mouth: 'side', body: 'oneDown', extras: [[16, 14, ['KKK.', 'KGGK', 'KGGK', '.KK.']], [24, 0, ['.OO.', 'O..O', '...O', '..O.', '..O.', '....', '..O.']]] },
    cheer: { eyes: 'happy', mouth: 'open', body: 'open', extras: [PAW_UP_L, PAW_UP_R, [2, 2, ['.O.', 'OWO', '.O.']], [24, 1, ['.H.', 'HWH', '.H.']]] },
    oops: { eyes: 'wide', mouth: 'o', body: 'open', extras: [[0, 9, mirror(ARM_CHEEK)], [22, 9, ARM_CHEEK], [25, 2, ['.c.', 'ccc', 'cWc', '.c.']]] },
    sleep: { eyes: 'closed', mouth: 'w', body: 'rest', extras: [[23, 0, ['HHHH', '..H.', '.H..', 'HHHH']], [26, 5, ['hh', '.h', 'hh']]] },
    wave: { eyes: 'happy', mouth: 'smile', body: 'oneDown', extras: [PAW_UP_R, [21, 3, ['O..', '...', '..O']], [26, 3, ['O']], [27, 6, ['O']]] },
  };
  function mochiGrid(mood) {
    const m = MOCHI_MOODS[mood] || MOCHI_MOODS.idle, W = 28, H = 24;
    const g = Array.from({ length: H }, () => Array(W).fill('.'));
    const draw = (x, y, rows) => rows.forEach((row, dy) => [...row].forEach((ch, dx) => { if (ch !== '.' && y + dy < H && x + dx < W && x + dx >= 0) g[y + dy][x + dx] = ch; }));
    draw(4, 0, MOCHI_HEAD.map((r) => r === 'EYES1' ? EYES[m.eyes][0] : r === 'EYES2' ? EYES[m.eyes][1] : r === 'MOUTH1' ? MOUTHS[m.mouth][0] : r === 'MOUTH2' ? MOUTHS[m.mouth][1] : r));
    draw(0, 16, BODY[m.body]);
    m.extras.forEach(([x, y, rows]) => draw(x, y, rows));
    return g.map((r) => r.join(''));
  }
  function gridRender(rows, pal) {
    const H = rows.length, W = rows[0].length, byColor = {};
    rows.forEach((row, y) => { let x = 0; while (x < W) { const ch = row[x]; if (ch === '.') { x++; continue; } let n = 1; while (row[x + n] === ch) n++; const c = pal[ch]; (byColor[c] = byColor[c] || []).push(`M${x} ${y}h${n}v1h-${n}z`); x += n; } });
    return { w: W, h: H, crisp: true, paths: Object.entries(byColor).map(([fill, ds]) => ({ d: ds.join(''), fill, stroke: 'none', sw: 0, op: 1 })) };
  }

  // The Professor, in ink. Every part is a path; moods swap eyes, mouth, arms and extras.
  const PROF = { fur: '#D9D4DF', furDark: '#4A4458', ivory: '#FFFBF2', tweed: '#C9A887', tweedDark: '#9C7B5C', brass: '#A8842F', gold: '#D8B86A', pink: '#E8B4C8', sky: '#B9D3E6' };
  function professorPaths(mood) {
    const out = [], fill = (d, c, op) => out.push({ d, fill: c, stroke: 'none', sw: 0, op: op == null ? 1 : op }), line = (d, sw, c, op) => out.push({ d, fill: 'none', stroke: c || INK, sw: sw || 0.7, op: op == null ? 1 : op });
    const both = (d, c, sw) => { fill(d, c); line(d, sw); };
    const hatch = (pts, gap, ang, op) => { const d = hatchLines(pts, gap, ang); if (d) line(d, 0.28, INK, op || 0.4); };
    const paw = (x, y, rx, ry) => both(`M${x - rx} ${y}a${rx} ${ry} 0 1 0 ${2 * rx} 0a${rx} ${ry} 0 1 0 ${-2 * rx} 0Z`, PROF.furDark, 0.6);
    const sleeve = (pts) => { const d = polyD(pts); both(d, PROF.tweed, 0.6); hatch(pts, 1.3, Math.PI / 4, 0.35); };
    // body: tweed jacket, shirt, lapels, bow tie
    const body = [[9, 48], [10, 42], [15, 37.5], [22, 35.4], [34, 35.4], [41, 37.5], [46, 42], [47, 48]];
    both(polyD(body), PROF.tweed, 0.7); hatch(body, 1.5, Math.PI / 4, 0.3); hatch(clipHalf(body, [36, 0], [1, 0]), 1.5, -Math.PI / 4, 0.3);
    both('M23 35.6L28 44L33 35.6Z', PROF.ivory, 0.6);
    line('M22 35.8L25.5 47.5M34 35.8L30.5 47.5', 0.6);
    both('M28 38.4L23.4 35.8L23.4 41Z', PROF.gold, 0.55); both('M28 38.4L32.6 35.8L32.6 41Z', PROF.gold, 0.55); both('M26.8 38.4a1.2 1.2 0 1 0 2.4 0a1.2 1.2 0 1 0 -2.4 0Z', PROF.brass, 0.5);
    // ears
    both('M11.5 15L13 3.5L22 10.5Z', PROF.fur, 0.7); fill('M13.6 12L14.2 6.4L19 10.4Z', PROF.pink, 0.8);
    both('M44.5 15L43 3.5L34 10.5Z', PROF.fur, 0.7); fill('M42.4 12L41.8 6.4L37 10.4Z', PROF.pink, 0.8);
    // head, mask, stripe, muzzle, nose
    both('M8 22C8 12 17 7.5 28 7.5C39 7.5 48 12 48 22C48 30 40 34.5 28 34.5C16 34.5 8 30 8 22Z', PROF.fur, 0.75);
    fill('M28 8L26.2 15.5L28 18.5L29.8 15.5Z', PROF.furDark, 0.85);
    fill('M9.4 19C14 15.4 22 16.6 28 20C34 16.6 42 15.4 46.6 19C46 25 40.5 26.4 34.5 24.6C31.5 23.6 29.4 25 28 25.4C26.6 25 24.5 23.6 21.5 24.6C15.5 26.4 10 25 9.4 19Z', PROF.furDark, 0.88);
    both('M21 28.5C21 24.8 24 23.4 28 23.4C32 23.4 35 24.8 35 28.5C35 31.8 32 33.2 28 33.2C24 33.2 21 31.8 21 28.5Z', PROF.ivory, 0.6);
    both('M25.6 25.6Q28 24.2 30.4 25.6Q28 28.4 25.6 25.6Z', INK, 0.4);
    // eyes
    const eyes = { idle: 'open', happy: 'happy', thinking: 'up', cheer: 'happy', oops: 'wide', sleep: 'closed', wave: 'happy' }[mood] || 'open';
    for (const cx of [20.5, 35.5]) {
      if (eyes === 'open' || eyes === 'up' || eyes === 'wide') {
        const r = eyes === 'wide' ? 2.2 : 1.7, dy = eyes === 'up' ? -0.9 : 0;
        fill(`M${cx - r} 20.6a${r} ${r} 0 1 0 ${2 * r} 0a${r} ${r} 0 1 0 ${-2 * r} 0Z`, '#FFFFFF');
        fill(`M${cx - 1 + 0.4} ${20.6 + dy}a1 1 0 1 0 2 0a1 1 0 1 0 -2 0Z`, INK);
      } else if (eyes === 'happy') line(`M${cx - 2} 21.6Q${cx} 18.6 ${cx + 2} 21.6`, 0.75, '#FFFFFF');
      else line(`M${cx - 2} 20.4Q${cx} 22.4 ${cx + 2} 20.4`, 0.75, '#FFFFFF');
    }
    // glasses (slipped down a little when asleep)
    const gy = mood === 'sleep' ? 22 : 20.6;
    line(`M16.1 ${gy}a4.4 4.4 0 1 0 8.8 0a4.4 4.4 0 1 0 -8.8 0ZM31.1 ${gy}a4.4 4.4 0 1 0 8.8 0a4.4 4.4 0 1 0 -8.8 0ZM24.9 ${gy - 0.4}Q28 ${gy - 1.8} 31.1 ${gy - 0.4}`, 0.85, PROF.brass);
    // mouth
    const mouth = { idle: 'M26 30.2Q28 31.6 30 30.2', happy: 'M25 29.8Q28 32.8 31 29.8', thinking: 'M27 30.6L30.4 30', cheer: 'M25 29.6Q28 33.8 31 29.6Z', oops: 'M27 30.8a1 1.2 0 1 0 2 0a1 1.2 0 1 0 -2 0Z', sleep: 'M26.6 30.4Q28 31.2 29.4 30.4', wave: 'M25 29.8Q28 32.8 31 29.8' }[mood] || 'M26 30.2Q28 31.6 30 30.2';
    if (mood === 'cheer' || mood === 'oops') both(mouth, mood === 'cheer' ? '#C98A9A' : INK, 0.55); else line(mouth, 0.6);
    // arms and extras
    const restL = () => paw(19, 46.4, 3, 2.1), restR = () => paw(37, 46.4, 3, 2.1);
    const sparkle = (x, y, r, c) => both(`M${x} ${y - r}Q${x + r * 0.2} ${y - r * 0.2} ${x + r} ${y}Q${x + r * 0.2} ${y + r * 0.2} ${x} ${y + r}Q${x - r * 0.2} ${y + r * 0.2} ${x - r} ${y}Q${x - r * 0.2} ${y - r * 0.2} ${x} ${y - r}Z`, c || PROF.gold, 0.4);
    if (mood === 'idle' || mood === 'happy' || mood === 'sleep') { restL(); restR(); }
    if (mood === 'happy') sparkle(50, 8, 2.4);
    if (mood === 'sleep') { line('M42 5.5h4l-4 4h4', 0.65); line('M48.5 1h2.6l-2.6 2.6h2.6', 0.55); }
    if (mood === 'wave' || mood === 'cheer') { sleeve([[41, 38.5], [47, 24], [52, 26], [46.5, 41.5]]); paw(49.6, 22.4, 3.2, 3); line('M53.8 15.4Q55.8 18 55 21.2M51.4 14.2Q54 14.6 55.4 16.4', 0.5, INK, 0.7); }
    if (mood === 'wave') restL();
    if (mood === 'cheer') { sleeve([[15, 38.5], [9, 24], [4, 26], [9.5, 41.5]]); paw(6.4, 22.4, 3.2, 3); sparkle(4, 8, 2.6); sparkle(52, 6, 2, PROF.pink); }
    if (mood === 'thinking') { restL(); sleeve([[40, 47], [34.6, 37.6], [38.6, 35.8], [44.5, 45]]); paw(35, 34.6, 3, 2.3); line('M47 7Q47 3 50.6 3Q54.2 3 54.2 6.2Q54.2 8.6 51.2 9.6L51.2 11.6', 0.75); fill('M50.6 14a0.65 0.65 0 1 0 1.3 0a0.65 0.65 0 1 0 -1.3 0Z', INK); }
    if (mood === 'oops') { sleeve([[13, 40], [9.6, 29], [13.4, 28], [17, 39]]); paw(10.6, 26.6, 2.8, 2.6); sleeve([[43, 40], [46.4, 29], [42.6, 28], [39, 39]]); paw(45.4, 26.6, 2.8, 2.6); both('M48 6Q45.6 10.6 48 11.6Q50.4 10.6 48 6Z', PROF.sky, 0.5); }
    return { w: 56, h: 48, crisp: false, paths: out };
  }
  const mascot = (theme, mood) => (theme === 'atelier' ? professorPaths(mood) : gridRender(mochiGrid(mood), MOCHI_PAL));

  // ───────────── pictograms (12 × 12) ─────────────
  // One grid per kind of thing a Journey item can be. The Den shows them as pixels; the Atelier as
  // an engraved print — a soft wash with ink stippling, denser where the grid is darker.
  const ICON_PAL = { K: '#241B2F', W: '#FFFFFF', L: '#E9E4F0', s: '#BDB6C9', R: '#E86A92', O: '#FFE08A', o: '#E0B040', Y: '#D9B45A', G: '#6FBF8A', g: '#3E7A5F', B: '#8A5A3A', C: '#7FD6F0', c: '#3D9CC4', P: '#F4A7C6', V: '#B9A3E3', v: '#8E76C4', T: '#5BB0A8', X: '#DE7A5C', N: '#8F8AA0' };
  const ICONS = {
    food: ['....L..L....', '...L..L.....', '....L..L....', '............', '.KKKKKKKKKK.', 'KOOOoOOOoOOK', 'KWWWWWWWWWWK', '.KWWWWWWWWK.', '.KsWWWWWWsK.', '..KsWWWWsK..', '...KKKKKK...', '............'],
    drink: ['....L.L.....', '...L.L......', '....L.L.....', '.KKKKKKKK...', '.KBBBBBBK...', '.KWWWWWWKKK.', '.KWWWWWWK.K.', '.KWWWWWWK.K.', '.KWWWWWWKKK.', '..KWWWWK....', 'KssssssssK..', '.KKKKKKKK...'],
    fruit: ['......g.....', '.....gG.....', '...KKKKK....', '..KRRRRRK...', '.KRRWRRRRK..', '.KRWRRRRRK..', '.KRRRRRRRK..', '.KRRRRRRRK..', '..KRRRRRK...', '...KKKKK....', '............', '............'],
    tool: ['............', '..KKKKKK....', '.KNNNNNNK...', '.KNNNNNNKK..', '..KKKBKK....', '....KBK.....', '....KBK.....', '....KBK.....', '....KBK.....', '....KBK.....', '....KBK.....', '.....K......'],
    document: ['............', '............', 'KKKKKKKKKKKK', 'KLKWWWWWWKLK', 'KLLKWWWWKLLK', 'KLLLKWWKLLLK', 'KLLLLKKLLLLK', 'KLLLLRRLLLLK', 'KLLLLLLLLLLK', 'KKKKKKKKKKKK', '............', '............'],
    plant: ['....PPP.....', '...PPOPP....', '....PPP.....', '.....g......', '..GG.g......', '...GGg.GG...', '.....gGG....', '.....g......', '..KKKKKKK...', '..KXXXXXK...', '...KXXXK....', '...KKKKK....'],
    place: ['.....K......', '....KOK.....', '...KYYYK....', '..KYYYYYK...', '.KKKKKKKKK..', '.KLKLKLKLK..', '.KLKLKLKLK..', '.KLKLKLKLK..', 'KKKKKKKKKKK.', 'KsssssssssK.', 'KKKKKKKKKKK.', '............'],
    clothing: ['............', '...KK..KK...', '..KVVKKVVK..', '.KVVVVVVVVK.', 'KVVVVVVVVVVK', 'KVKVVVVVVKVK', '.K.KVVVVK.K.', '...KVVVVK...', '...KVVVVK...', '...KvvvvK...', '...KKKKKK...', '............'],
    health: ['............', '....KKKK....', '...K....K...', '.KKKKKKKKKK.', '.KWWWWWWWWK.', '.KWWWRRWWWK.', '.KWRRRRRRWK.', '.KWRRRRRRWK.', '.KWWWRRWWWK.', '.KWWWWWWWWK.', '.KKKKKKKKKK.', '............'],
    sky: ['.........O..', '........OOO.', '....KKKK.O..', '...KTTTTK...', '..KTTTTTTK..', 'OOKTTTTTTKOO', '..KTTTTTTK..', '...KTTTTK...', '....KKKK....', '..O.........', '............', '............'],
    vehicle: ['............', '............', '...KKKKKK...', '..KCCKCCCK..', '.KKCCKCCCKK.', 'KRRRRRRRRRRK', 'KRWRRRRRRRRK', 'KRRRRRRRRRRK', 'KKNNKKKKNNKK', '.KNNK..KNNK.', '..KK....KK..', '............'],
    money: ['............', '............', 'KKKKKKKKKKKK', 'KGGGGGGGGGGK', 'KGgGGKKGGgGK', 'KGGGKGGKGGGK', 'KGGGKGGKGGGK', 'KGgGGKKGGgGK', 'KGGGGGGGGGGK', 'KKKKKKKKKKKK', '............', '............'],
    gift: ['............', '...KK..KK...', '..KRRKKRRK..', '...KKRRKK...', '.KKKKRRKKKK.', '.KPPPRRPPPK.', '.KKKKRRKKKK.', '..KPPRRPPK..', '..KPPRRPPK..', '..KPPRRPPK..', '..KKKKKKKK..', '............'],
    light: ['.....O......', '....OOO.....', '....OWO.....', '.....K......', '....KWK.....', '....KWK.....', '....KWK.....', '....KWK.....', '....KWK.....', '..KKKKKKK...', '..KYYYYYK...', '...KKKKK....'],
    music: ['............', '....KKKKKK..', '....KVVVVK..', '....K....K..', '....K....K..', '....K....K..', '..KKK..KKK..', '.KVVK.KVVK..', '.KVVK.KVVK..', '..KK...KK...', '............', '............'],
    device: ['............', '....KKK.....', '.KKKKKKKKKK.', '.KNNNNNNNNK.', '.KNNKKKKNNK.', '.KNKCCCCKNK.', '.KNKCWCCKNK.', '.KNKCCCCKNK.', '.KNNKKKKNNK.', '.KNNNNNNNNK.', '.KKKKKKKKKK.', '............'],
    book: ['............', '.KKKKKKKKK..', '.KRRRRRRRK..', '.KRWWWWWRK..', '.KRRRRRRRK..', '.KRRRRRRRK..', '.KRRRRRRRK..', '.KRRRRRRRK..', '.KRRRRRRRKK.', '.KLLLLLLLLK.', '.KKKKKKKKKK.', '............'],
    bag: ['............', '....KKKK....', '....K..K....', '.KKKKKKKKKK.', '.KXXXXXXXXK.', '.KXXKXXKXXK.', '.KXXKXXKXXK.', '.KXXKXXKXXK.', '.KXXXXXXXXK.', '.KKKKKKKKKK.', '..K......K..', '............'],
    sun: ['............', '.....O......', '..O..O..O...', '....KKK.....', '...KOOOK....', '.OOKOOOKOO..', '...KOOOK....', '....KKK.....', '..O..O..O...', '.....O......', '............', '............'],
    pan: ['............', '............', '..KKKKK.....', '.KNNNNNK....', 'KNNOONNK....', 'KNNOWNNKKKKK', 'KNNNNNNKBBBK', '.KNNNNNKKKKK', '..KKKKK.....', '............', '............', '............'],
    spice: ['............', '...KKKKKK...', '...KBBBBK...', '..KKKKKKKK..', '..KXXXXXXK..', '..KXOXXOXK..', '..KXXXXXXK..', '..KXXOXXXK..', '..KXXXXXXK..', '..KKKKKKKK..', '............', '............'],
    person: ['............', '....KKKK....', '...KLLLLK...', '...KLLLLK...', '...KLLLLK...', '....KKKK....', '..KKKKKKKK..', '.KTTTTTTTTK.', '.KTTTTTTTTK.', '.KTTTTTTTTK.', '.KKKKKKKKKK.', '............'],
    calendar: ['............', '..K....K....', '.KKKKKKKKKK.', '.KRRRRRRRRK.', '.KKKKKKKKKK.', '.KWWWWWWWWK.', '.KWKWWKWWWK.', '.KWWWWWWWWK.', '.KWWKWWKWWK.', '.KWWWWWWWWK.', '.KKKKKKKKKK.', '............'],
    water: ['.....K......', '....KCK.....', '....KCK.....', '...KCCCK....', '..KCCCCCK...', '..KCWCCCK...', '..KCWCCCK...', '..KCCCCCK...', '...KCCCK....', '....KKK.....', '............', '............'],
    compass: ['............', '...KKKKKK...', '..KLLLLLLK..', '.KLLLRLLLLK.', '.KLLLRRLLLK.', '.KLLLKKLLLK.', '.KLLLccLLLK.', '.KLLLLcLLLK.', '..KLLLLLLK..', '...KKKKKK...', '............', '............'],
    balloon: ['...KKKK.....', '..KPPPPK....', '.KPWPPPPK...', '.KPWPPPPK...', '.KPPPPPPK...', '..KPPPPK....', '...KPPK.....', '....KK......', '.....K......', '....K.......', '.....K......', '............'],
    home: ['.....KK.....', '....KXXK....', '...KXXXXK...', '..KXXXXXXK..', '.KKKKKKKKKK.', '..KLLLLLLK..', '..KLOLKKLK..', '..KLLLKBBK..', '..KLLLKBBK..', '..KKKKKKKK..', '............', '............'],
  };
  // Which pictogram each Journey item gets: a pack default, then per-keyword exceptions.
  const PACK_ICON = { errands: 'bag', beach: 'sun', groceries: 'food', karahi: 'pan', planets: 'sky', wedding: 'gift', morning: 'sun', wonders: 'place', camping: 'compass', repairs: 'tool', party: 'balloon', doctor: 'health', southasia: 'place', spices: 'spice', garden: 'plant', istanbul: 'place' };
  const ITEM_ICON = {
    'dry cleaning': 'clothing', stamps: 'document', 'library book': 'book', 'car wash': 'vehicle', candles: 'light', parcel: 'gift', 'electricity bill': 'money',
    haircut: 'person', 'light bulbs': 'light', 'old clothes': 'clothing', medicine: 'health', flowers: 'plant', 'dinner table': 'food', 'bicycle tyre': 'vehicle', letter: 'document',
    towel: 'clothing', 'flip-flops': 'clothing', 'water bottle': 'water', 'sun hat': 'clothing', swimsuit: 'clothing', novel: 'book', snacks: 'food', camera: 'device', 'phone charger': 'device',
    'first-aid kit': 'health', 'picnic mat': 'bag', milk: 'drink', tomatoes: 'fruit', onions: 'fruit', bananas: 'fruit', spinach: 'plant', lemons: 'fruit', tea: 'drink', garlic: 'fruit',
    chicken: 'food', ginger: 'fruit', salt: 'spice', 'red chilli': 'spice', 'black pepper': 'spice', 'green chillies': 'fruit', yogurt: 'food', 'garam masala': 'spice', coriander: 'plant', oil: 'pan',
    invitations: 'document', caterer: 'food', 'mehndi artist': 'person', photographer: 'device', 'tailor fitting': 'clothing', sweets: 'food', 'fairy lights': 'light', music: 'music', car: 'vehicle', rings: 'gift',
    'glass of water': 'water', stretch: 'person', sunlight: 'sun', 'three goals': 'document', breakfast: 'food', 'no phone': 'device', 'short walk': 'compass',
    tent: 'home', 'sleeping bag': 'bag', torch: 'light', matches: 'light', rope: 'tool', kettle: 'drink', 'rain jacket': 'clothing', 'insect spray': 'health', pillow: 'home', marshmallows: 'food',
    'light switch': 'light', 'the cake': 'food', 'paper plates': 'food', juice: 'drink', 'party games': 'gift', gifts: 'gift', napkins: 'document', streamers: 'balloon', 'ice cream': 'food',
    sleep: 'calendar', 'eye test': 'health', 'coriander seeds': 'spice', 'bay leaves': 'plant', 'tomato plants': 'fruit', 'a lemon tree': 'fruit', 'a bosphorus cruise': 'water',
  };
  const itemIcon = (packID, keyword) => ITEM_ICON[String(keyword).toLowerCase()] || PACK_ICON[packID] || 'gift';
  function stippleRender(rows, pal) {
    const out = [], H = rows.length, W = rows[0].length, wash = {}, dots = [];
    const lum = (hex) => { const n = parseInt(hex.slice(1), 16); return (0.2126 * (n >> 16) + 0.7152 * ((n >> 8) & 255) + 0.0722 * (n & 255)) / 255; };
    rows.forEach((row, y) => [...row].forEach((ch, x) => {
      if (ch === '.') return;
      const c = pal[ch];
      if (ch !== 'K') (wash[c] = wash[c] || []).push(`M${x - 0.08} ${y - 0.08}h1.16v1.16h-1.16z`);
      const t = ch === 'K' ? 1 : Math.max(0, 0.75 - lum(c));
      for (const [dx, dy] of [[0.27, 0.27], [0.75, 0.3], [0.3, 0.76], [0.74, 0.73]]) {
        const r = ch === 'K' ? 0.26 : 0.07 + t * 0.2;
        if (ch !== 'K' && t < 0.12 && (x + y + dx * 4) % 3 > 0.5) continue;
        dots.push(`M${(x + dx - r).toFixed(2)} ${(y + dy).toFixed(2)}a${r.toFixed(2)} ${r.toFixed(2)} 0 1 0 ${(2 * r).toFixed(2)} 0a${r.toFixed(2)} ${r.toFixed(2)} 0 1 0 ${(-2 * r).toFixed(2)} 0`);
      }
    }));
    for (const [c, ds] of Object.entries(wash)) out.push({ d: ds.join(''), fill: c, stroke: 'none', sw: 0, op: 0.55 });
    out.push({ d: dots.join(''), fill: INK, stroke: 'none', sw: 0, op: 0.85 });
    return { w: W, h: H, crisp: false, paths: out };
  }
  const pictogram = (kind, theme) => { const rows = ICONS[kind] || ICONS.gift; return theme === 'atelier' ? stippleRender(rows, ICON_PAL) : gridRender(rows, ICON_PAL); };

  const World = {
    MAT, PLACES, MAP_PLACES, render,
    garden: (theme) => render(gardenScene(), theme),
    stage: (place, theme) => render((STAGES[place] || STAGES.review)(), theme),
    ambient, stamp, rng, hatchLines, MOODS, mascot, mochiGrid, gridRender,
    ICONS, PACK_ICON, ITEM_ICON, itemIcon, pictogram,
    // Where each place's label sits on the 118 × 100 map (bottom-centre of the building + a gap).
    placeLabels: () => Object.entries(MAP_PLACES).map(([game, [x, y]]) => ({ game, name: PLACES[game].name, x, y: y + 2.2 })),
  };
  if (typeof module !== 'undefined' && module.exports) module.exports = World;
  root.MGWorld = World;
})(typeof window !== 'undefined' ? window : globalThis);
