// render_dc.mjs
// Famlist – rendert eine Design-Datei (*.dc.html) ohne support.js als PNG (Chrome headless).
//
// Aufruf:  node scripts/render_dc.mjs <datei.dc.html> <ausgabe.png> [skalierung=2]
//
// Vorgehen: renderVals() aus dem <script type="text/x-dc"> mit den Standard-Props ausführen,
// {{w.*}}-Platzhalter im <x-dc>-Inhalt ersetzen, <helmet> in den <head> setzen und die Größe aus
// "$preview" (z. B. 208 × 248) als Fenster verwenden. 1 CSS-px = 1 pt; Skalierung 2 = @2x wie der Simulator.

import { readFileSync, writeFileSync, mkdtempSync } from 'node:fs';
import { execFileSync } from 'node:child_process';
import { tmpdir } from 'node:os';
import { join } from 'node:path';

const [input, output, scaleArg] = process.argv.slice(2);
if (!input || !output) { console.error('Aufruf: node scripts/render_dc.mjs <datei.dc.html> <ausgabe.png> [skalierung]'); process.exit(1); }
const scale = Number(scaleArg ?? 2);
const src = readFileSync(input, 'utf8');

const script = src.match(/<script type="text\/x-dc"[^>]*data-props='([^']*)'[^>]*>([\s\S]*?)<\/script>/);
if (!script) throw new Error('Kein x-dc-Script gefunden');
const propsSpec = JSON.parse(script[1]);
const props = Object.fromEntries(Object.entries(propsSpec).filter(([k]) => !k.startsWith('$')).map(([k, v]) => [k, v.default]));
const preview = propsSpec.$preview ?? { width: 390, height: 844 };

class DCLogic { constructor() { this.props = props; } }
const Component = new Function('DCLogic', `${script[2]}; return Component;`)(DCLogic);
const vals = new Component().renderVals();

const lookup = (path) => path.split('.').reduce((o, k) => (o == null ? undefined : o[k]), vals);
const body = src.match(/<x-dc>([\s\S]*?)<\/x-dc>/)[1];
const helmet = (body.match(/<helmet>([\s\S]*?)<\/helmet>/) ?? [, ''])[1];
const content = body.replace(/<helmet>[\s\S]*?<\/helmet>/, '').replace(/\{\{\s*([\w.]+)\s*\}\}/g, (m, p) => {
  const v = lookup(p);
  if (v === undefined) throw new Error(`Platzhalter ohne Wert: ${p}`);
  return String(v);
});

const html = `<!doctype html><html><head><meta charset="utf-8">${helmet}</head><body>${content}</body></html>`;
const dir = mkdtempSync(join(tmpdir(), 'dc-'));
const page = join(dir, 'page.html');
writeFileSync(page, html);
execFileSync('/Applications/Google Chrome.app/Contents/MacOS/Google Chrome', [
  '--headless=new', '--disable-gpu', '--hide-scrollbars', `--force-device-scale-factor=${scale}`,
  `--window-size=${preview.width},${preview.height}`, '--virtual-time-budget=4000',
  `--screenshot=${output}`, `file://${page}`,
], { stdio: 'ignore' });
console.log(`${output} (${preview.width}×${preview.height} @${scale}x)`);
