// Builds Media/Ring.tga: the round border for icons shown as circles (BuffTracker only).
// Usage: node ring-art.js <depsDir> <outDir>
// The ring is white so the addon can color it (gold, ruby, grey) with SetVertexColor. Like the square
// Tylesser double border: an outer line, a dark gap and an inner line.
const path = require('path'), fs = require('fs');
const [, , depsDir, outDir] = process.argv;
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

const ring = `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 128 128">
  <circle cx="64" cy="64" r="61.5" fill="none" stroke="#ffffff" stroke-width="4"/>
  <circle cx="64" cy="64" r="58" fill="none" stroke="#000000" stroke-width="3"/>
  <circle cx="64" cy="64" r="55" fill="none" stroke="#ffffff" stroke-width="3"/>
</svg>`;

const rendered = new Resvg(ring, { fitTo: { mode: 'width', value: 128 } }).render();
fs.writeFileSync(path.join(outDir, 'Ring.tga'), toTga(rendered));
console.log('Ring.tga written');
