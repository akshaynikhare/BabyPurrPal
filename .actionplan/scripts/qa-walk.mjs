#!/usr/bin/env node
// No-MCP walk driver. Own-process Chromium, incremental writes, headless under CI/agent sessions.
// Usage: node qa-walk.mjs --url <url> --out <dir> [--steps <file>] [--headed]
// Steps file (one per line):  goto <url> | click <role> <name...> | fill <label> <value...> | shot <slug> | wait <ms>
import fs from 'node:fs';
import path from 'node:path';
import { createRequire } from 'node:module';

const arg = (k, d) => { const i = process.argv.indexOf(k); return i > -1 ? process.argv[i + 1] : d; };
const url = arg('--url'); const out = arg('--out', '.actionplan/qa/walk');
if (!url) { console.error('usage: qa-walk.mjs --url <url> --out <dir> [--steps <file>] [--headed]'); process.exit(2); }

// resolve playwright from e2e/ (the one place it is installed)
let chromium;
try {
  const req = createRequire(path.resolve('e2e/package.json'));
  ({ chromium } = req('@playwright/test'));
} catch {
  console.error('[qa-walk] playwright not found — yours to run: cd e2e && npm install'); process.exit(1);
}

const headed = process.argv.includes('--headed') && !process.env.CI && !process.env.CLAUDE_SESSION_ID;
fs.mkdirSync(path.join(out, 'screenshots'), { recursive: true });
const append = (f, s) => fs.appendFileSync(path.join(out, f), s);
const MAXSHOTS = 40; let shots = 0;

const browser = await chromium.launch({ headless: !headed });
const page = await (await browser.newContext()).newPage();

page.on('console', (m) => { if (['warning', 'error'].includes(m.type())) append('console.log', `[${m.type()}] ${m.text()}\n`); });
page.on('response', (r) => {
  const req = r.request();
  if (req.method() !== 'GET' || r.status() >= 400)
    append('network.jsonl', JSON.stringify({ method: req.method(), url: r.url(), status: r.status() }) + '\n');
});

const journey = (s) => append('JOURNEY.md', `- ${s}\n`);
async function shot(slug) {
  if (++shots > MAXSHOTS) { journey(`SHOT CAP HIT (${MAXSHOTS}) — ${slug} skipped`); return; }
  await page.screenshot({ path: path.join(out, 'screenshots', `${String(shots).padStart(2, '0')}-${slug}.png`), fullPage: true });
}

await page.goto(url); journey(`goto ${url}`); await shot('start');

const stepsFile = arg('--steps');
if (stepsFile && fs.existsSync(stepsFile)) {
  for (const line of fs.readFileSync(stepsFile, 'utf8').split('\n').map((l) => l.trim()).filter((l) => l && !l.startsWith('#'))) {
    const [cmd, ...rest] = line.split(/\s+/);
    try {
      if (cmd === 'goto') { await page.goto(rest[0]); journey(line); }
      else if (cmd === 'click') { await page.getByRole(rest[0], { name: rest.slice(1).join(' ') }).first().click(); journey(line); }
      else if (cmd === 'fill') { await page.getByLabel(rest[0]).fill(rest.slice(1).join(' ')); journey(line); }
      else if (cmd === 'shot') { await shot(rest[0] || 'step'); journey(line); }
      else if (cmd === 'wait') { await page.waitForTimeout(+rest[0] || 500); }
      else journey(`UNKNOWN step: ${line}`);
    } catch (e) { journey(`FAILED: ${line} — ${String(e).split('\n')[0]}`); await shot('fail'); }
  }
}
await shot('end');
await browser.close();
console.log(`[qa-walk] done — evidence in ${out} (${shots} screenshot(s)). FINDINGS.md is yours to write from the evidence.`);
