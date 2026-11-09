// Builds the shared Tylesser "Runestone" UI textures: the round emblem medallion and the hex studs.
// Usage: node style-art.js <depsDir> <logoSvg> <outDir>
// Writes Emblem.tga (128), Stud.tga and StudRuby.tga (32) for Media/.
const path = require('path'), fs = require('fs');
const [, , depsDir, logoSvg, outDir] = process.argv;
const { Resvg } = require(path.join(depsDir, 'node_modules', '@resvg', 'resvg-js'));

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

const render = (svg, size) => new Resvg(svg, { fitTo: { mode: 'width', value: size } }).render();

// Emblem medallion: the logo cut to a circle inside a gold ring.
const logo = fs.readFileSync(logoSvg, 'utf8');
const inner = logo.replace(/^[\s\S]*?<svg[^>]*>/, '').replace(/<\/svg>\s*$/, '');
const medallion = `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 512 512">
  <defs>
    <clipPath id="disc"><circle cx="256" cy="256" r="226"/></clipPath>
    <linearGradient id="ring" x1="0" y1="0" x2="0" y2="1">
      <stop offset="0" stop-color="#fff2c0"/><stop offset="0.35" stop-color="#f0c24e"/>
      <stop offset="0.7" stop-color="#c88a1e"/><stop offset="1" stop-color="#8a5a0c"/>
    </linearGradient>
  </defs>
  <g clip-path="url(#disc)"><g transform="translate(-28 -28) scale(1.11)">${inner}</g></g>
  <circle cx="256" cy="256" r="236" fill="none" stroke="url(#ring)" stroke-width="22"/>
  <circle cx="256" cy="256" r="249" fill="none" stroke="#4a2f05" stroke-width="8"/>
  <circle cx="256" cy="256" r="224" fill="none" stroke="#4a2f05" stroke-width="4"/>
</svg>`;

const stud = (gemTop, gemMid, gemBottom) => `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 32 32">
  <defs>
    <linearGradient id="g" x1="0" y1="0" x2="1" y2="1">
      <stop offset="0" stop-color="#fff2c0"/><stop offset="0.45" stop-color="#e6ad3a"/><stop offset="1" stop-color="#7a4d08"/>
    </linearGradient>
    <linearGradient id="gem" x1="0" y1="0" x2="1" y2="1">
      <stop offset="0" stop-color="${gemTop}"/><stop offset="0.45" stop-color="${gemMid}"/><stop offset="1" stop-color="${gemBottom}"/>
    </linearGradient>
  </defs>
  <polygon points="16,2 28.1,9 28.1,23 16,30 3.9,23 3.9,9" fill="url(#g)" stroke="#4a2f05" stroke-width="2" stroke-linejoin="round"/>
  <circle cx="16" cy="16" r="6.5" fill="url(#gem)" stroke="#1a1005" stroke-width="1.2"/>
  <circle cx="14" cy="14" r="1.8" fill="#fff" opacity="0.8"/>
</svg>`;

fs.mkdirSync(outDir, { recursive: true });
fs.writeFileSync(path.join(outDir, 'Emblem.tga'), toTga(render(medallion, 128)));
fs.writeFileSync(path.join(outDir, 'Stud.tga'), toTga(render(stud('#d4fff5', '#2fd6a8', '#075640'), 32)));
fs.writeFileSync(path.join(outDir, 'StudRuby.tga'), toTga(render(stud('#ffd0d6', '#e0304e', '#5c0816'), 32)));
fs.writeFileSync(path.join(outDir, 'emblem-preview.png'), render(medallion, 128).asPng());
fs.writeFileSync(path.join(outDir, 'stud-preview.png'), render(stud('#d4fff5', '#2fd6a8', '#075640'), 64).asPng());
console.log('wrote', outDir);
