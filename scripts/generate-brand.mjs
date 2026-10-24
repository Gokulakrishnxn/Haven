import fs from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { createRequire } from 'node:module';

// Uses the site's existing Sharp dependency. Run npm ci in site first.
const root = path.resolve(path.dirname(fileURLToPath(import.meta.url)), '..');
const require = createRequire(path.join(root, 'site/package.json'));
const sharp = require('sharp');
const dir = path.join(root, 'brand');
await fs.mkdir(dir, { recursive: true });

// Canonical 256-unit silhouette. Keep native HavenBrand and HavenMark in sync.
const silhouette = 'M72 28 C90 28 100 40 104 58 L110 84 C112 94 118 100 128 100 C138 100 144 94 146 84 L152 58 C156 40 166 28 184 28 C208 28 224 46 224 70 C224 86 216 104 216 128 C216 152 224 170 224 186 C224 210 208 228 184 228 C166 228 156 216 152 198 L146 172 C144 162 138 156 128 156 C118 156 112 162 110 172 L104 198 C100 216 90 228 72 228 C48 228 32 210 32 186 C32 170 40 152 40 128 C40 104 32 86 32 70 C32 46 48 28 72 28 Z';
const palettes = {
  cyan: ['#00D7F4', '#06A9ED', '#9AF8FF', '#1375DC'],
  mint: ['#00E9BE', '#00CBBF', '#C1FFF0', '#009DA5'],
  coral: ['#FF6080', '#FF3D63', '#FFD4CD', '#F62653'],
  gold: ['#F5D719', '#F2BE00', '#FFF7B5', '#DF9700'],
};
const svg = (content, viewBox = '0 0 256 256', size = 256) => `<svg xmlns="http://www.w3.org/2000/svg" width="${size}" height="${size}" viewBox="${viewBox}">${content}</svg>`;
const eyeMask = (eyes = true) => `<mask id="face"><rect width="256" height="256" fill="white"/>${eyes ? '<g class="eyes"><rect x="106" y="117" width="12" height="22" rx="6" fill="black"/><rect x="138" y="117" width="12" height="22" rx="6" fill="black"/></g>' : ''}</mask>`;
const mark = (color = '#141718', eyes = true) => `<defs>${eyeMask(eyes)}</defs><path d="${silhouette}" fill="${color}" mask="url(#face)"/>`;
const write = (name, value) => fs.writeFile(path.join(dir, name), value);
const png = async (name, content, size) => {
  await sharp(Buffer.from(content), { density: 144 }).resize(size, size).png().toFile(path.join(dir, name));
};

for (const [name, color] of [['dark', '#141718'], ['light', '#FFFFFF']]) {
  const source = svg(`<title>Haven companion</title>${mark(color)}`);
  await write(`haven-mark-${name}.svg`, source);
  await png(`haven-mark-${name}.png`, source, 1024);
}
const menu = svg(`<title>Haven menu bar template</title><path fill="black" d="${silhouette}"/>`, '16 16 224 224');
await write('haven-menu-template.svg', menu);
await png('haven-menu-template.png', menu, 18);
await png('haven-menu-template@2x.png', menu, 36);

// Outlined custom wordmark: deliberately font-independent, with a soft lowercase rhythm.
const wordLetters = `<path d="M0 0V66M0 38C0 15 35 15 35 38V66M94 26V66M94 44C94 16 54 16 54 44C54 72 94 72 94 44M115 26L134 66L153 26M173 46H211C211 16 172 15 172 46C172 66 195 73 209 60M233 66V26M233 42C233 17 269 17 269 42V66" fill="none" stroke-width="9" stroke-linecap="round" stroke-linejoin="round"/>`;
for (const [name, color] of [['dark', '#141718'], ['light', '#FFFFFF']]) {
  const source = `<svg xmlns="http://www.w3.org/2000/svg" width="680" height="160" viewBox="0 0 680 160"><title>Haven</title><g transform="translate(0 -4) scale(.64)">${mark(color)}</g><g stroke="${color}" transform="translate(199 34) scale(1.6)">${wordLetters}</g></svg>`;
  await write(`haven-wordmark-${name}.svg`, source);
}

function icon(color, face = 'idle') {
  const [base, depth, light, shadow] = palettes[color];
  let eyes = '<rect x="106" y="117" width="12" height="22" rx="6"/><rect x="138" y="117" width="12" height="22" rx="6"/>';
  if (face === 'working') eyes = '<rect x="103" y="123" width="10" height="12" rx="5"/><rect x="123" y="113" width="10" height="32" rx="5"/><rect x="143" y="123" width="10" height="12" rx="5"/>';
  if (face === 'done') eyes = '<path d="M103 128 Q112 114 121 128 M135 128 Q144 114 153 128" fill="none" stroke="white" stroke-width="7" stroke-linecap="round"/>';
  if (face === 'attention') eyes = '<circle cx="112" cy="128" r="8"/><circle cx="144" cy="128" r="8"/>';
  return svg(`<title>Haven ${color} app icon</title><defs>
  <clipPath id="tile"><rect x="64" y="64" width="896" height="896" rx="202"/></clipPath>
  <linearGradient id="base" x1="0" y1="0" x2="1" y2="1"><stop stop-color="${base}"/><stop offset=".6" stop-color="${depth}"/><stop offset="1" stop-color="${base}"/></linearGradient>
  <radialGradient id="bloom"><stop stop-color="${light}" stop-opacity=".95"/><stop offset=".45" stop-color="${light}" stop-opacity=".38"/><stop offset="1" stop-color="${light}" stop-opacity="0"/></radialGradient>
  <linearGradient id="ribbon" x1="0" y1="0" x2="1" y2="1"><stop stop-color="white" stop-opacity="0"/><stop offset=".5" stop-color="white" stop-opacity=".8"/><stop offset="1" stop-color="white" stop-opacity="0"/></linearGradient>
  <filter id="soft"><feGaussianBlur stdDeviation="16"/></filter><filter id="grain"><feTurbulence type="fractalNoise" baseFrequency=".8" numOctaves="3" stitchTiles="stitch"/><feColorMatrix type="saturate" values="0"/><feComponentTransfer><feFuncA type="linear" slope=".11"/></feComponentTransfer><feBlend in="SourceGraphic" mode="soft-light"/></filter>
  </defs><g clip-path="url(#tile)"><rect x="64" y="64" width="896" height="896" fill="url(#base)"/><ellipse cx="930" cy="90" rx="640" ry="590" fill="url(#bloom)"/><ellipse cx="120" cy="900" rx="600" ry="480" fill="url(#bloom)"/><path d="M-100 735C180 730 340 455 455 220S690 -45 1100 -120" fill="none" stroke="${shadow}" stroke-opacity=".18" stroke-width="120" filter="url(#soft)"/><path d="M-100 710C180 705 340 430 455 195S690 -70 1100 -145" fill="none" stroke="url(#ribbon)" stroke-width="55" filter="url(#soft)"/><path d="M0 785C330 760 470 600 625 338S865 125 1080 110" fill="none" stroke="url(#ribbon)" stroke-width="90" filter="url(#soft)" opacity=".7"/><rect x="64" y="64" width="896" height="896" fill="transparent" filter="url(#grain)"/></g><rect x="65" y="65" width="894" height="894" rx="201" fill="none" stroke="white" stroke-opacity=".26" stroke-width="2"/><g transform="translate(147.2 147.2) scale(2.85)"><path d="${silhouette}" fill="#141718"/><g fill="white">${eyes}</g></g>`, '0 0 1024 1024', 1024);
}
for (const [i, color] of Object.keys(palettes).entries()) {
  const source = icon(color, ['idle', 'working', 'done', 'attention'][i]);
  await write(`haven-app-${color}.svg`, source);
  await png(`haven-app-${color}.png`, source, 1024);
}
const animated = svg(`<title>Haven animated companion</title><style>.body{transform-origin:128px 128px;animation:breathe 4s ease-in-out infinite}.eyes{transform-box:fill-box;transform-origin:center;animation:blink 5.2s linear infinite}@keyframes breathe{0%,100%{transform:translateY(0) scale(1)}50%{transform:translateY(-3px) scale(1.018,.985)}}@keyframes blink{0%,42%,46%,100%{transform:scaleY(1)}44%{transform:scaleY(.12)}}@media(prefers-reduced-motion:reduce){.body,.eyes{animation:none}}</style><g class="body">${mark('#141718')}</g>`);
await write('haven-mark-animated.svg', animated);
// An inverse export for dark backgrounds uses exactly the same animation.
await write('haven-mark-animated-light.svg', animated.replace('fill="#141718"', 'fill="#FFFFFF"'));

const iconset = path.join(dir, 'Haven.iconset');
await fs.mkdir(iconset, { recursive: true });
for (const size of [16, 32, 128, 256, 512]) {
  for (const scale of [1, 2]) {
    await sharp(path.join(dir, 'haven-app-cyan.png')).resize(size * scale).png().toFile(path.join(iconset, `icon_${size}x${size}${scale === 2 ? '@2x' : ''}.png`));
  }
}
// Modern ICNS is a big-endian container of PNG representations. Writing it
// directly also works in environments where iconutil cannot access ImageIO.
const representations = [
  ['icp4',16,1], ['icp5',32,1], ['icp6',32,2], ['ic07',128,1],
  ['ic08',256,1], ['ic09',512,1], ['ic10',512,2],
  ['ic11',16,2], ['ic12',32,2], ['ic13',128,2], ['ic14',256,2],
];
const chunks = await Promise.all(representations.map(async ([kind,size,scale]) => {
  const data = await fs.readFile(path.join(iconset, `icon_${size}x${size}${scale === 2 ? '@2x' : ''}.png`));
  const header = Buffer.alloc(8); header.write(kind); header.writeUInt32BE(data.length + 8,4);
  return Buffer.concat([header,data]);
}));
const icnsHeader = Buffer.alloc(8); icnsHeader.write('icns'); icnsHeader.writeUInt32BE(8 + chunks.reduce((n,c) => n+c.length,0),4);
await write('Haven.icns', Buffer.concat([icnsHeader,...chunks]));
await fs.mkdir(path.join(root, 'Sources/Haven/Resources'), { recursive: true });
await fs.copyFile(path.join(dir, 'haven-app-cyan.png'), path.join(root, 'Sources/Haven/Resources/HavenAppIcon.png'));
// A PNG-backed ICO replaces the starter Next icon without another dependency.
const favicon = await sharp(path.join(dir, 'haven-app-cyan.png')).resize(64).png().toBuffer();
const ico = Buffer.alloc(22); ico.writeUInt16LE(1,2); ico.writeUInt16LE(1,4); ico[6]=64; ico[7]=64; ico.writeUInt16LE(1,10); ico.writeUInt16LE(32,12); ico.writeUInt32LE(favicon.length,14); ico.writeUInt32LE(22,18);
await fs.writeFile(path.join(root, 'site/app/favicon.ico'), Buffer.concat([ico, favicon]));
await fs.copyFile(path.join(dir, 'haven-app-cyan.png'), path.join(root, 'site/app/apple-icon.png'));

const publicDir = path.join(root, 'site/public/brand');
await fs.mkdir(publicDir, { recursive: true });
for (const file of await fs.readdir(dir, { withFileTypes: true })) {
  if (file.isFile() && /\.(svg|png|icns)$/.test(file.name)) await fs.copyFile(path.join(dir,file.name),path.join(publicDir,file.name));
}
console.log('Generated logo SVGs, four app icons, menu templates, animated SVGs, macOS iconset/ICNS, and website icons.');
