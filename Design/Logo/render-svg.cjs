const fs = require('node:fs');
const { Resvg } = require('@resvg/resvg-js');
const svg = fs.readFileSync(0, 'utf8');
const rendered = new Resvg(svg, {
  fitTo: { mode: 'width', value: Number(process.argv[3]) },
  font: { loadSystemFonts: false },
}).render();
fs.writeFileSync(process.argv[2], rendered.asPng());
