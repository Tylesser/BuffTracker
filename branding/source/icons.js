// Builds the Tylesser org logo and the addon icons (each embeds the Tylesser emblem as a badge).
// Usage: node icons.js <depsDir> <outDir>
const path = require('path'), fs = require('fs');
const [, , depsDir, outDir] = process.argv;
const { Resvg } = require(path.join(depsDir, 'node_modules', '@resvg', 'resvg-js'));

const f = (n) => Math.round(n * 100) / 100;

const defs = `
  <radialGradient id="bg" cx="50%" cy="42%" r="75%">
    <stop offset="0" stop-color="#2e2652"/>
    <stop offset="0.55" stop-color="#191430"/>
    <stop offset="1" stop-color="#090713"/>
  </radialGradient>
  <radialGradient id="arcane" cx="50%" cy="50%" r="50%">
    <stop offset="0" stop-color="#3fe0c0" stop-opacity="0.35"/>
    <stop offset="0.5" stop-color="#6a4bd8" stop-opacity="0.18"/>
    <stop offset="1" stop-color="#6a4bd8" stop-opacity="0"/>
  </radialGradient>
  <radialGradient id="hexFill" cx="50%" cy="35%" r="70%">
    <stop offset="0" stop-color="#2a2150"/>
    <stop offset="1" stop-color="#0d0a1c"/>
  </radialGradient>
  <linearGradient id="gold" x1="0" y1="0" x2="0" y2="1">
    <stop offset="0" stop-color="#fff2c0"/>
    <stop offset="0.3" stop-color="#f7cc55"/>
    <stop offset="0.7" stop-color="#c88a1e"/>
    <stop offset="1" stop-color="#8a5a0c"/>
  </linearGradient>
  <linearGradient id="goldDiag" x1="0" y1="0" x2="1" y2="1">
    <stop offset="0" stop-color="#fff2c0"/>
    <stop offset="0.45" stop-color="#e6ad3a"/>
    <stop offset="1" stop-color="#7a4d08"/>
  </linearGradient>
  <linearGradient id="goldSide" x1="0" y1="0" x2="1" y2="0">
    <stop offset="0" stop-color="#8a5a0c"/>
    <stop offset="0.3" stop-color="#e9b43c"/>
    <stop offset="0.55" stop-color="#ffe08a"/>
    <stop offset="1" stop-color="#9a650f"/>
  </linearGradient>
  <linearGradient id="goldTop" x1="0" y1="0" x2="1" y2="1">
    <stop offset="0" stop-color="#fff4c9"/>
    <stop offset="1" stop-color="#e0a53a"/>
  </linearGradient>
  <linearGradient id="gem" x1="0" y1="0" x2="1" y2="1">
    <stop offset="0" stop-color="#d4fff5"/>
    <stop offset="0.45" stop-color="#2fd6a8"/>
    <stop offset="1" stop-color="#075640"/>
  </linearGradient>
  <linearGradient id="ruby" x1="0" y1="0" x2="1" y2="1">
    <stop offset="0" stop-color="#ffd0d6"/>
    <stop offset="0.45" stop-color="#e0304e"/>
    <stop offset="1" stop-color="#5c0816"/>
  </linearGradient>
  <filter id="stone" x="0" y="0" width="100%" height="100%">
    <feTurbulence type="fractalNoise" baseFrequency="0.035" numOctaves="4" seed="7" result="n"/>
    <feColorMatrix in="n" type="matrix"
      values="0 0 0 0 0.75  0 0 0 0 0.7  0 0 0 0 1  0 0 0 0.9 -0.35"/>
  </filter>
  <filter id="glow" x="-60%" y="-60%" width="220%" height="220%">
    <feGaussianBlur stdDeviation="9" result="b"/>
    <feMerge><feMergeNode in="b"/><feMergeNode in="SourceGraphic"/></feMerge>
  </filter>
  <filter id="softGlow" x="-60%" y="-60%" width="220%" height="220%">
    <feGaussianBlur stdDeviation="4" result="b"/>
    <feMerge><feMergeNode in="b"/><feMergeNode in="SourceGraphic"/></feMerge>
  </filter>
  <filter id="shadow" x="-30%" y="-30%" width="160%" height="160%">
    <feDropShadow dx="0" dy="7" stdDeviation="7" flood-color="#000" flood-opacity="0.6"/>
  </filter>
  <clipPath id="tClip"><path d="${tPath()}"/></clipPath>
  <clipPath id="frameClip"><rect width="512" height="512" rx="30"/></clipPath>`;

function tPath() {
  return 'M146 168 Q150 160 160 160 H352 Q362 160 366 168 L346 212 H286 V362 L256 404 L226 362 V212 H166 Z';
}

function hexPoints(cx, cy, r) {
  const pts = [];
  for (let i = 0; i < 6; i++) {
    const a = (Math.PI / 3) * i - Math.PI / 2;
    pts.push([f(cx + r * Math.cos(a)), f(cy + r * Math.sin(a))]);
  }
  return pts;
}
const ptsAttr = (pts) => pts.map((p) => p.join(',')).join(' ');

function sparkle(x, y, s, color = '#fff8dc', opacity = 0.9) {
  const k = s * 0.22;
  return `<path d="M${x} ${y - s} L${x + k} ${y - k} L${x + s} ${y} L${x + k} ${y + k} L${x} ${y + s}
    L${x - k} ${y + k} L${x - s} ${y} L${x - k} ${y - k} Z" fill="${color}" opacity="${opacity}"/>`;
}

function gemStud(x, y, r, fill = 'url(#gem)') {
  return `<circle cx="${x}" cy="${y}" r="${r + 4}" fill="url(#goldDiag)" stroke="#3d2604" stroke-width="2.5"/>
    <circle cx="${x}" cy="${y}" r="${r}" fill="${fill}" stroke="#03261c" stroke-width="1.5"/>
    <circle cx="${x - r * 0.35}" cy="${y - r * 0.35}" r="${r * 0.3}" fill="#fff" opacity="0.8"/>`;
}

// Runic glyphs drawn in a 12x18 box centred on 0,0
const RUNES = [
  'M0 -9 V9 M0 -3 L6 -9 M0 3 L6 -3',
  'M-3 -9 V9 M-3 -4 L4 0 L-3 4',
  'M0 -9 V9 M0 -9 L-6 -3 M0 -9 L6 -3',
  'M-5 -9 L5 9 M5 -9 L-5 9',
  'M0 -9 L6 0 L0 9 L-6 0 Z',
  'M-4 -9 V9 M4 -9 V9 M-4 -3 L4 3',
  'M-3 9 V-9 L4 -4 L-3 1 L4 6',
  'M0 -9 V9 M-6 -5 L0 1 L6 -5',
];

function runeRing(cx, cy, r, count, size, opacity) {
  let s = `<g fill="none" stroke="#f6c94f" stroke-width="${f(2.2 * size)}" stroke-linecap="round"
    stroke-linejoin="round" opacity="${opacity}" filter="url(#softGlow)">`;
  for (let i = 0; i < count; i++) {
    const deg = (360 / count) * i;
    const a = (deg * Math.PI) / 180;
    const x = f(cx + r * Math.sin(a)), y = f(cy - r * Math.cos(a));
    s += `<path d="${RUNES[(i * 5) % RUNES.length]}" transform="translate(${x} ${y}) rotate(${f(deg)}) scale(${size})"/>`;
  }
  s += `</g>`;
  s += `<circle cx="${cx}" cy="${cy}" r="${r + 16 * size}" fill="none" stroke="#f6c94f" stroke-opacity="0.45" stroke-width="${f(2.5 * size)}"/>`;
  s += `<circle cx="${cx}" cy="${cy}" r="${r - 16 * size}" fill="none" stroke="#f6c94f" stroke-opacity="0.45" stroke-width="${f(2.5 * size)}"/>`;
  return s;
}

// Curved blade-like feather from base (bx,by) to tip (tx,ty)
function feather(bx, by, tx, ty, w) {
  const mx = (bx + tx) / 2, my = (by + ty) / 2;
  const dx = tx - bx, dy = ty - by, len = Math.hypot(dx, dy);
  const px = (-dy / len) * w, py = (dx / len) * w;
  return `<path d="M${bx} ${by} Q${f(mx + px)} ${f(my + py)} ${tx} ${ty} Q${f(mx - px * 0.35)} ${f(my - py * 0.35)} ${bx} ${by} Z"
    fill="url(#goldDiag)" stroke="#4a2f05" stroke-width="3" stroke-linejoin="round"/>
    <path d="M${bx} ${by} Q${f(mx + px * 0.3)} ${f(my + py * 0.3)} ${tx} ${ty}" fill="none" stroke="#fff2c0" stroke-opacity="0.5" stroke-width="2"/>`;
}

function wings() {
  const left = [
    [112, 180, 34, 92, 30],
    [104, 222, 14, 168, 34],
    [102, 264, 10, 248, 34],
    [108, 306, 26, 326, 30],
  ];
  let s = '<g filter="url(#shadow)">';
  for (const [bx, by, tx, ty, w] of left) {
    s += feather(bx, by, tx, ty, w);
    s += feather(512 - bx, by, 512 - tx, ty, -w);
  }
  return s + '</g>';
}

// The Tylesser emblem: hex frame + gems + bevelled T. Drawn around (256,256), radius ~186.
function emblem() {
  const outer = hexPoints(256, 256, 186);
  const inner = hexPoints(256, 256, 164);
  const innermost = hexPoints(256, 256, 150);
  let s = '';
  s += `<polygon points="${ptsAttr(outer)}" fill="url(#hexFill)" stroke="url(#gold)" stroke-width="20"
    stroke-linejoin="round" filter="url(#shadow)"/>`;
  s += `<polygon points="${ptsAttr(outer)}" fill="none" stroke="#3d2604" stroke-width="2.5" stroke-linejoin="round"/>`;
  s += `<polygon points="${ptsAttr(inner)}" fill="none" stroke="#3d2604" stroke-width="3" stroke-linejoin="round"/>`;
  s += `<polygon points="${ptsAttr(innermost)}" fill="none" stroke="#f6c94f" stroke-opacity="0.45" stroke-width="2.5"
    stroke-linejoin="round"/>`;
  s += `<circle cx="256" cy="262" r="120" fill="url(#arcane)"/>`;
  // rivets in the middle of each edge
  for (let i = 0; i < 6; i++) {
    const a = outer[i], b = outer[(i + 1) % 6];
    s += `<circle cx="${f((a[0] + b[0]) / 2)}" cy="${f((a[1] + b[1]) / 2)}" r="4.5" fill="#fff0b8" stroke="#5c3b07" stroke-width="2"/>`;
  }
  // gems on the corners; ruby at the bottom
  outer.forEach((p, i) => {
    if (i === 0) return;
    s += gemStud(p[0], p[1], 9, i === 3 ? 'url(#ruby)' : 'url(#gem)');
  });
  // T with bevel highlight, fuller and outline
  s += `<g filter="url(#shadow)">
    <path d="${tPath()}" fill="url(#gold)"/>
    <g clip-path="url(#tClip)">
      <polygon points="120,140 400,140 120,420" fill="#fff6d6" opacity="0.12"/>
      <rect x="140" y="160" width="240" height="10" fill="#fff6d6" opacity="0.35"/>
    </g>
    <path d="${tPath()}" fill="none" stroke="#4a2f05" stroke-width="5" stroke-linejoin="round"/>
    <path d="M256 228 V380" stroke="#6b4508" stroke-width="7" stroke-linecap="round"/>
    <path d="M253 228 V378" stroke="#fff6d2" stroke-opacity="0.6" stroke-width="2.5" stroke-linecap="round"/>
  </g>`;
  // crown gem on top of the hexagon and on the T
  s += `<g filter="url(#glow)">
    <polygon points="256,52 276,70 256,92 236,70" fill="url(#gem)" stroke="#3d2604" stroke-width="4" stroke-linejoin="round"/>
    <polygon points="256,160 281,186 256,212 231,186" fill="url(#gem)" stroke="#03261c" stroke-width="4" stroke-linejoin="round"/>
  </g>`;
  s += `<polygon points="256,166 270,180 256,186 242,180" fill="#fff" opacity="0.55"/>`;
  return s;
}

function background() {
  return `<rect width="512" height="512" fill="url(#bg)"/>
    <rect width="512" height="512" filter="url(#stone)" opacity="0.18"/>
    <circle cx="256" cy="256" r="250" fill="url(#arcane)" opacity="0.7"/>`;
}

// ---------------------------------------------------------------- org logo
const orgSvg = `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 512 512">
  <defs>${defs}</defs>
  ${background()}
  ${runeRing(256, 256, 226, 32, 1, 0.55)}
  ${wings()}
  ${emblem()}
  ${sparkle(118, 104, 12)}${sparkle(404, 118, 9)}${sparkle(410, 410, 11)}${sparkle(96, 398, 8)}
  ${sparkle(330, 228, 7, '#d4fff5', 0.8)}${sparkle(184, 300, 6, '#d4fff5', 0.7)}
</svg>`;

// ------------------------------------------------------------- addon icon
function coinStack(cx, baseY, height, w) {
  const rx = w / 2, ry = w * 0.2, top = baseY - height;
  let s = `<g filter="url(#shadow)">`;
  s += `<path d="M${cx - rx} ${top} L${cx - rx} ${baseY} A${rx} ${ry} 0 0 0 ${cx + rx} ${baseY} L${cx + rx} ${top} Z"
    fill="url(#goldSide)" stroke="#4a2f05" stroke-width="4"/>`;
  for (let y = baseY - 25; y > top + 12; y -= 25) {
    s += `<path d="M${cx - rx} ${y} A${rx} ${ry} 0 0 0 ${cx + rx} ${y}" fill="none" stroke="#6b4508" stroke-width="4"/>`;
  }
  s += `<ellipse cx="${cx}" cy="${top}" rx="${rx}" ry="${ry}" fill="url(#goldTop)" stroke="#4a2f05" stroke-width="4"/>`;
  s += `<ellipse cx="${cx}" cy="${top}" rx="${rx * 0.66}" ry="${ry * 0.62}" fill="none" stroke="#b07a1c" stroke-width="4"/>`;
  return s + `</g>`;
}

function squareFrame() {
  let s = `<rect x="12" y="12" width="488" height="488" rx="26" fill="none" stroke="url(#gold)" stroke-width="16"/>
    <rect x="4" y="4" width="504" height="504" rx="30" fill="none" stroke="#3d2604" stroke-width="3"/>
    <rect x="21" y="21" width="470" height="470" rx="20" fill="none" stroke="#3d2604" stroke-width="3"/>
    <rect x="30" y="30" width="452" height="452" rx="16" fill="none" stroke="#f6c94f" stroke-opacity="0.35" stroke-width="2.5"/>`;
  // ornate corner diamonds (top-left is covered by the Tylesser badge)
  for (const [x, y] of [[488, 24], [24, 488], [488, 488]]) {
    s += `<polygon points="${x},${y - 22} ${x + 22},${y} ${x},${y + 22} ${x - 22},${y}" fill="url(#goldDiag)"
      stroke="#3d2604" stroke-width="3"/>`;
    s += gemStud(x, y, 7);
  }
  // rivets along the edges
  for (const t of [128, 256, 384]) {
    s += `<circle cx="${t}" cy="20" r="4" fill="#fff0b8" stroke="#5c3b07" stroke-width="2"/>`;
    s += `<circle cx="${t}" cy="492" r="4" fill="#fff0b8" stroke="#5c3b07" stroke-width="2"/>`;
    s += `<circle cx="20" cy="${t}" r="4" fill="#fff0b8" stroke="#5c3b07" stroke-width="2"/>`;
    s += `<circle cx="492" cy="${t}" r="4" fill="#fff0b8" stroke="#5c3b07" stroke-width="2"/>`;
  }
  return s;
}

const addonSvg = `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 512 512">
  <defs>${defs}</defs>
  <g clip-path="url(#frameClip)">
    ${background()}
    ${runeRing(256, 280, 200, 28, 0.9, 0.28)}
    ${coinStack(160, 448, 112, 108)}
    ${coinStack(278, 448, 192, 108)}
    ${coinStack(396, 448, 256, 108)}
    <g filter="url(#glow)">
      <polyline points="150,246 230,184 290,212 392,116" fill="none" stroke="#2fd67f"
        stroke-width="28" stroke-linecap="round" stroke-linejoin="round"/>
      <polygon points="442,62 432,150 358,98" fill="#2fd67f" stroke="#2fd67f" stroke-width="10" stroke-linejoin="round"/>
    </g>
    ${sparkle(372, 66, 9)}${sparkle(214, 140, 7, '#d4fff5', 0.8)}
  </g>
  ${squareFrame()}
  <g transform="translate(104 104) scale(0.42) translate(-256 -256)" filter="url(#shadow)">
    ${emblem()}
  </g>
</svg>`;

// ---------------------------------------------------- vendor search icon
const vendorDefs = `
  <linearGradient id="leather" x1="0" y1="0" x2="1" y2="1">
    <stop offset="0" stop-color="#c58a52"/>
    <stop offset="0.5" stop-color="#8a5328"/>
    <stop offset="1" stop-color="#4a2a10"/>
  </linearGradient>
  <linearGradient id="leatherLight" x1="0" y1="0" x2="0" y2="1">
    <stop offset="0" stop-color="#d9a26a"/>
    <stop offset="1" stop-color="#8a5328"/>
  </linearGradient>
  <radialGradient id="lens" cx="40%" cy="35%" r="70%">
    <stop offset="0" stop-color="#e6fffb" stop-opacity="0.55"/>
    <stop offset="0.5" stop-color="#5fe0c8" stop-opacity="0.28"/>
    <stop offset="1" stop-color="#1c6f7a" stop-opacity="0.45"/>
  </radialGradient>
  <linearGradient id="wood" x1="0" y1="0" x2="1" y2="0">
    <stop offset="0" stop-color="#3a1f0c"/>
    <stop offset="0.5" stop-color="#7a4a22"/>
    <stop offset="1" stop-color="#2a1608"/>
  </linearGradient>`;

function coinFlat(cx, cy, r) {
  return `<ellipse cx="${cx}" cy="${cy + 4}" rx="${r}" ry="${r * 0.42}" fill="#7a4d08"/>
    <ellipse cx="${cx}" cy="${cy}" rx="${r}" ry="${r * 0.42}" fill="url(#goldTop)" stroke="#4a2f05" stroke-width="3"/>
    <ellipse cx="${cx}" cy="${cy}" rx="${r * 0.62}" ry="${r * 0.26}" fill="none" stroke="#b07a1c" stroke-width="3"/>`;
}

function sack() {
  return `<g filter="url(#shadow)">
    <path d="M206 176 C120 210 86 310 108 386 C124 444 182 462 242 462 C302 462 360 444 374 386
      C394 306 334 210 270 176 Z" fill="url(#leather)" stroke="#2e1606" stroke-width="5"/>
    <path d="M140 300 C150 250 180 215 214 196" fill="none" stroke="#e9b98a" stroke-opacity="0.35"
      stroke-width="10" stroke-linecap="round"/>
    <path d="M124 392 C150 440 200 448 242 448 C290 448 330 440 356 396" fill="none" stroke="#2e1606"
      stroke-opacity="0.6" stroke-width="3" stroke-dasharray="10 8"/>
    <path d="M206 176 L180 118 Q206 136 222 110 Q240 136 258 108 Q270 134 296 120 L270 176 Z"
      fill="url(#leatherLight)" stroke="#2e1606" stroke-width="5" stroke-linejoin="round"/>
    <path d="M198 174 Q238 192 278 174" fill="none" stroke="#3d2604" stroke-width="16" stroke-linecap="round"/>
    <path d="M198 174 Q238 192 278 174" fill="none" stroke="url(#gold)" stroke-width="10" stroke-linecap="round"/>
    <path d="M238 184 L224 222 M238 184 L256 220" stroke="url(#gold)" stroke-width="7" stroke-linecap="round"/>
    <circle cx="232" cy="336" r="44" fill="url(#gold)" stroke="#4a2f05" stroke-width="5"/>
    <circle cx="232" cy="336" r="30" fill="none" stroke="#8a5a0c" stroke-width="4"/>
    <path d="M232 314 L246 336 L232 358 L218 336 Z" fill="url(#gem)" stroke="#03261c" stroke-width="3"/>
  </g>
  ${coinFlat(118, 452, 30)}${coinFlat(166, 466, 26)}${coinFlat(86, 470, 24)}`;
}

function magnifier(cx, cy, r) {
  const dx = 0.6, dy = 0.8;
  const sx = f(cx + dx * (r + 10)), sy = f(cy + dy * (r + 10));
  const ex = f(sx + dx * 150), ey = f(sy + dy * 150);
  return `<g filter="url(#shadow)">
    <line x1="${sx}" y1="${sy}" x2="${ex}" y2="${ey}" stroke="#2a1608" stroke-width="40" stroke-linecap="round"/>
    <line x1="${sx}" y1="${sy}" x2="${ex}" y2="${ey}" stroke="url(#wood)" stroke-width="32" stroke-linecap="round"/>
    <line x1="${f(sx + dx * 50)}" y1="${f(sy + dy * 50)}" x2="${f(sx + dx * 62)}" y2="${f(sy + dy * 62)}"
      stroke="url(#gold)" stroke-width="36"/>
    <line x1="${f(sx + dx * 110)}" y1="${f(sy + dy * 110)}" x2="${f(sx + dx * 122)}" y2="${f(sy + dy * 122)}"
      stroke="url(#gold)" stroke-width="36"/>
    <line x1="${sx}" y1="${sy}" x2="${f(sx + dx * 18)}" y2="${f(sy + dy * 18)}" stroke="url(#gold)" stroke-width="30"/>
    <circle cx="${cx}" cy="${cy}" r="${r}" fill="url(#lens)"/>
    <path d="M${f(cx - r * 0.62)} ${f(cy - r * 0.2)} A${r * 0.66} ${r * 0.66} 0 0 1 ${f(cx - r * 0.1)} ${f(cy - r * 0.64)}"
      fill="none" stroke="#ffffff" stroke-opacity="0.75" stroke-width="10" stroke-linecap="round"/>
    <circle cx="${cx}" cy="${cy}" r="${r}" fill="none" stroke="#3d2604" stroke-width="30"/>
    <circle cx="${cx}" cy="${cy}" r="${r}" fill="none" stroke="url(#gold)" stroke-width="22"/>
    <circle cx="${cx}" cy="${cy}" r="${r - 11}" fill="none" stroke="#3d2604" stroke-width="2.5"/>
  </g>
  ${gemStud(f(cx), f(cy - r), 7)}`;
}

const vendorSvg = `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 512 512">
  <defs>${defs}${vendorDefs}</defs>
  <g clip-path="url(#frameClip)">
    ${background()}
    ${runeRing(256, 280, 200, 28, 0.9, 0.28)}
    ${sack()}
    ${magnifier(334, 232, 92)}
    ${sparkle(300, 196, 10)}${sparkle(410, 92, 8, '#d4fff5', 0.8)}
  </g>
  ${squareFrame()}
  <g transform="translate(104 104) scale(0.42) translate(-256 -256)" filter="url(#shadow)">
    ${emblem()}
  </g>
</svg>`;

// ------------------------------------------------------- stat delta icon
const statDefs = `
  <linearGradient id="steel" x1="0" y1="0" x2="1" y2="1">
    <stop offset="0" stop-color="#e8eef8"/>
    <stop offset="0.45" stop-color="#8d9ab3"/>
    <stop offset="1" stop-color="#363e52"/>
  </linearGradient>
  <linearGradient id="up" x1="0" y1="0" x2="0" y2="1">
    <stop offset="0" stop-color="#b9ffc8"/>
    <stop offset="0.5" stop-color="#2fd67f"/>
    <stop offset="1" stop-color="#0b6b38"/>
  </linearGradient>
  <linearGradient id="down" x1="0" y1="0" x2="0" y2="1">
    <stop offset="0" stop-color="#ffb3bd"/>
    <stop offset="0.5" stop-color="#e0304e"/>
    <stop offset="1" stop-color="#6a0a1a"/>
  </linearGradient>`;

function shield(cx, top, w, h) {
  const l = cx - w / 2, r = cx + w / 2, mid = top + h * 0.55, bottom = top + h;
  const outline = `M${l} ${top + 18} Q${cx} ${top - 14} ${r} ${top + 18} L${r} ${mid}
    Q${r} ${bottom - 40} ${cx} ${bottom} Q${l} ${bottom - 40} ${l} ${mid} Z`;
  return `<g filter="url(#shadow)">
    <path d="${outline}" fill="url(#steel)" stroke="#1d2232" stroke-width="6" stroke-linejoin="round"/>
    <path d="${outline}" fill="none" stroke="url(#gold)" stroke-width="14" stroke-linejoin="round"
      transform="translate(${cx} ${top + h / 2}) scale(0.9) translate(${-cx} ${-(top + h / 2)})"/>
    <path d="M${cx} ${top + 24} V${bottom - 30} M${l + 34} ${top + h * 0.38} H${r - 34}" stroke="#3d2604"
      stroke-width="12" stroke-linecap="round"/>
    <path d="M${cx} ${top + 24} V${bottom - 30} M${l + 34} ${top + h * 0.38} H${r - 34}" stroke="url(#gold)"
      stroke-width="7" stroke-linecap="round"/>
  </g>
  ${gemStud(cx, top + h * 0.38, 12)}`;
}

// Block arrow pointing up (dir = 1) or down (dir = -1), tip at (x, tipY)
function arrow(x, tipY, len, dir, fill) {
  const head = 70, half = 58, shaft = 24;
  const baseY = tipY + dir * head, endY = tipY + dir * len;
  return `<path d="M${x} ${tipY} L${x + half} ${baseY} L${x + shaft} ${baseY} L${x + shaft} ${endY}
    L${x - shaft} ${endY} L${x - shaft} ${baseY} L${x - half} ${baseY} Z" fill="${fill}" stroke="#14100a"
    stroke-width="6" stroke-linejoin="round"/>`;
}

const statSvg = `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 512 512">
  <defs>${defs}${statDefs}</defs>
  <g clip-path="url(#frameClip)">
    ${background()}
    ${runeRing(256, 280, 200, 28, 0.9, 0.28)}
    ${shield(226, 170, 220, 290)}
    <g filter="url(#glow)">
      ${arrow(392, 120, 190, 1, 'url(#up)')}
      ${arrow(392, 462, 150, -1, 'url(#down)')}
    </g>
    ${sparkle(392, 92, 10)}${sparkle(128, 452, 8, '#d4fff5', 0.8)}
  </g>
  ${squareFrame()}
  <g transform="translate(104 104) scale(0.42) translate(-256 -256)" filter="url(#shadow)">
    ${emblem()}
  </g>
</svg>`;

// ------------------------------------------------------ buff tracker icon
const buffDefs = `
  <radialGradient id="buffTile" cx="50%" cy="40%" r="75%">
    <stop offset="0" stop-color="#9dffe6"/>
    <stop offset="0.45" stop-color="#1fb48c"/>
    <stop offset="1" stop-color="#06392c"/>
  </radialGradient>`;

// A buff icon as the game draws it: a tile with rising chevrons, partly covered by the timer swirl.
function buffTile(x, y, size) {
  const cx = x + size / 2, cy = y + size / 2, r = size;
  const rx = 26;
  const a = (-90 * Math.PI) / 180, b = (30 * Math.PI) / 180;
  const chevron = (top) => `M${cx - 96} ${top + 84} L${cx} ${top} L${cx + 96} ${top + 84}`;
  return `<clipPath id="tileClip"><rect x="${x}" y="${y}" width="${size}" height="${size}" rx="${rx}"/></clipPath>
  <g filter="url(#shadow)">
    <rect x="${x}" y="${y}" width="${size}" height="${size}" rx="${rx}" fill="url(#buffTile)"/>
  </g>
  <g filter="url(#softGlow)" fill="none" stroke-linecap="round" stroke-linejoin="round">
    <path d="${chevron(y + 56)}" stroke="#3d2604" stroke-width="44"/>
    <path d="${chevron(y + 56)}" stroke="url(#gold)" stroke-width="30"/>
    <path d="${chevron(y + 156)}" stroke="#3d2604" stroke-width="44"/>
    <path d="${chevron(y + 156)}" stroke="url(#gold)" stroke-width="30"/>
  </g>
  <g clip-path="url(#tileClip)">
    <path d="M${cx} ${cy} L${f(cx + r * Math.cos(a))} ${f(cy + r * Math.sin(a))}
      A${r} ${r} 0 1 0 ${f(cx + r * Math.cos(b))} ${f(cy + r * Math.sin(b))} Z" fill="#04060c" opacity="0.5"/>
  </g>
  <rect x="${x}" y="${y}" width="${size}" height="${size}" rx="${rx}" fill="none" stroke="url(#gold)" stroke-width="14"/>
  <rect x="${x - 8}" y="${y - 8}" width="${size + 16}" height="${size + 16}" rx="${rx + 6}" fill="none" stroke="#3d2604" stroke-width="3"/>`;
}

const buffSvg = `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 512 512">
  <defs>${defs}${buffDefs}</defs>
  <g clip-path="url(#frameClip)">
    ${background()}
    ${runeRing(256, 280, 200, 28, 0.9, 0.28)}
    ${buffTile(146, 150, 300)}
    ${sparkle(430, 124, 10)}${sparkle(124, 440, 8, '#d4fff5', 0.8)}
  </g>
  ${squareFrame()}
  <g transform="translate(104 104) scale(0.42) translate(-256 -256)" filter="url(#shadow)">
    ${emblem()}
  </g>
</svg>`;

function render(svg, size) {
  return new Resvg(svg, { fitTo: { mode: 'width', value: size } }).render();
}

// 32-bit uncompressed TGA, top-left origin (what WoW expects for addon textures)
function toTga(rendered) {
  const { width, height } = rendered;
  const rgba = rendered.pixels;
  const header = Buffer.alloc(18);
  header[2] = 2;
  header.writeUInt16LE(width, 12);
  header.writeUInt16LE(height, 14);
  header[16] = 32;
  header[17] = 0x28;
  const body = Buffer.alloc(width * height * 4);
  for (let i = 0; i < width * height; i++) {
    body[i * 4] = rgba[i * 4 + 2];
    body[i * 4 + 1] = rgba[i * 4 + 1];
    body[i * 4 + 2] = rgba[i * 4];
    body[i * 4 + 3] = rgba[i * 4 + 3];
  }
  return Buffer.concat([header, body]);
}

fs.mkdirSync(outDir, { recursive: true });
fs.writeFileSync(path.join(outDir, 'tylesser-logo.svg'), orgSvg);
fs.writeFileSync(path.join(outDir, 'profitsort-icon.svg'), addonSvg);
fs.writeFileSync(path.join(outDir, 'tylesser-logo-512.png'), render(orgSvg, 512).asPng());
fs.writeFileSync(path.join(outDir, 'profitsort-icon-512.png'), render(addonSvg, 512).asPng());
fs.writeFileSync(path.join(outDir, 'profitsort-icon-400.png'), render(addonSvg, 400).asPng());
fs.writeFileSync(path.join(outDir, 'profitsort-icon-64.png'), render(addonSvg, 64).asPng());
fs.writeFileSync(path.join(outDir, 'Icon.tga'), toTga(render(addonSvg, 64)));
fs.writeFileSync(path.join(outDir, 'vendorsearch-icon.svg'), vendorSvg);
fs.writeFileSync(path.join(outDir, 'vendorsearch-icon-512.png'), render(vendorSvg, 512).asPng());
fs.writeFileSync(path.join(outDir, 'vendorsearch-icon-400.png'), render(vendorSvg, 400).asPng());
fs.writeFileSync(path.join(outDir, 'vendorsearch-icon-64.png'), render(vendorSvg, 64).asPng());
fs.writeFileSync(path.join(outDir, 'VendorSearchIcon.tga'), toTga(render(vendorSvg, 64)));
fs.writeFileSync(path.join(outDir, 'statdelta-icon.svg'), statSvg);
fs.writeFileSync(path.join(outDir, 'statdelta-icon-512.png'), render(statSvg, 512).asPng());
fs.writeFileSync(path.join(outDir, 'statdelta-icon-400.png'), render(statSvg, 400).asPng());
fs.writeFileSync(path.join(outDir, 'statdelta-icon-64.png'), render(statSvg, 64).asPng());
fs.writeFileSync(path.join(outDir, 'StatDeltaIcon.tga'), toTga(render(statSvg, 64)));
fs.writeFileSync(path.join(outDir, 'bufftracker-icon.svg'), buffSvg);
fs.writeFileSync(path.join(outDir, 'bufftracker-icon-512.png'), render(buffSvg, 512).asPng());
fs.writeFileSync(path.join(outDir, 'bufftracker-icon-400.png'), render(buffSvg, 400).asPng());
fs.writeFileSync(path.join(outDir, 'bufftracker-icon-64.png'), render(buffSvg, 64).asPng());
fs.writeFileSync(path.join(outDir, 'BuffTrackerIcon.tga'), toTga(render(buffSvg, 64)));
console.log('written to ' + outDir);
