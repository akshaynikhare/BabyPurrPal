#!/usr/bin/env node
// Ratchet harness. A gate = { name, mode: 'absolute'|'ratchet', collect(root), remedy, selftest(lib) }.
// Semantics: keys are content-fingerprinted; --update only shrinks (growth needs --bootstrap --plan <id>);
// every baseline change appends to trend/gates.tsv; --selftest must fail on a planted violation first.
const fs = require('fs'), path = require('path'), crypto = require('crypto'), os = require('os');

const AP = path.join(__dirname, '..');
const ROOT = path.resolve(AP, '..');

const hash = (s) => crypto.createHash('sha1').update(s).digest('hex').slice(0, 10);

function walk(dir, { exts = null, excludes = [] } = {}, out = []) {
  if (!fs.existsSync(dir)) return out;
  for (const e of fs.readdirSync(dir, { withFileTypes: true })) {
    if (excludes.includes(e.name)) continue;
    const p = path.join(dir, e.name);
    if (e.isDirectory()) walk(p, { exts, excludes }, out);
    else if (!exts || exts.includes(path.extname(e.name))) out.push(p);
  }
  return out;
}

function config(root) {
  try { return JSON.parse(fs.readFileSync(path.join(root, '.actionplan', 'config.json'), 'utf8')); }
  catch { try { return JSON.parse(fs.readFileSync(path.join(AP, 'config.json'), 'utf8')); } catch { return {}; } }
}

function runGate(gate) {
  const argv = process.argv.slice(2);
  const has = (f) => argv.includes(f);
  const root = argv.includes('--root') ? path.resolve(argv[argv.indexOf('--root') + 1]) : ROOT;

  if (has('--selftest')) {
    const tmp = fs.mkdtempSync(path.join(os.tmpdir(), `gate-${gate.name}-`));
    try {
      const ok = gate.selftest({ tmp, walk, hash, collect: (r) => gate.collect(r) });
      console.log(`[${gate.name}] selftest ${ok ? 'OK — fails on planted violation, passes when fixed' : 'FAILED'}`);
      process.exitCode = ok ? 0 : 1;
      return;
    } finally { fs.rmSync(tmp, { recursive: true, force: true }); }
  }

  const items = gate.collect(root); // [{key, display}]
  const basePath = path.join(__dirname, 'gates', `${gate.name}.baseline.json`);

  if (gate.mode === 'absolute') {
    if (items.length) {
      console.error(`[${gate.name}] FAIL — ${items.length} violation(s):`);
      for (const i of items) console.error(`  ${i.display}`);
      console.error(`\n${gate.remedy}`);
      process.exit(1);
    }
    console.log(`[${gate.name}] OK — 0 violations`);
    return;
  }

  // ratchet
  const keys = new Set(items.map((i) => i.key));
  if (has('--update')) {
    const prev = fs.existsSync(basePath) ? JSON.parse(fs.readFileSync(basePath, 'utf8')) : null;
    if (prev && keys.size > prev.count && !has('--bootstrap')) {
      console.error(`[${gate.name}] REFUSED — baseline would grow ${prev.count} → ${keys.size}. Growth needs --bootstrap --plan <id>.`);
      process.exit(1);
    }
    const plan = argv.includes('--plan') ? argv[argv.indexOf('--plan') + 1] : (prev ? prev.plan : 'bootstrap');
    fs.writeFileSync(basePath, JSON.stringify({
      _comment: `Accepted debt (${plan}). Burn it down; never add to it. Regenerate: node ${path.relative(root, __filename)} --update`,
      gate: gate.name, mode: 'ratchet', recorded: new Date().toISOString().slice(0, 10),
      plan, count: keys.size, items: [...keys].sort(),
    }, null, 2) + '\n');
    const trendDir = path.join(AP, 'trend'); fs.mkdirSync(trendDir, { recursive: true });
    fs.appendFileSync(path.join(trendDir, 'gates.tsv'), `${new Date().toISOString().slice(0, 10)}\t${gate.name}\t${keys.size}\t${plan}\n`);
    console.log(`[${gate.name}] baseline recorded — ${keys.size} item(s)`);
    return;
  }

  if (!fs.existsSync(basePath)) {
    console.error(`[${gate.name}] baseline missing — run with --update (or --update --bootstrap --plan <id>)`);
    process.exit(1);
  }
  const baseline = new Set(JSON.parse(fs.readFileSync(basePath, 'utf8')).items || []);
  const added = items.filter((i) => !baseline.has(i.key));
  const fixed = [...baseline].filter((k) => !keys.has(k));
  console.log(`[${gate.name}] ${items.length} found (baseline ${baseline.size})`);
  if (fixed.length) console.log(`[${gate.name}] ${fixed.length} baselined item(s) now fixed — shrink the baseline with --update`);
  if (added.length) {
    console.error(`[${gate.name}] FAIL — ${added.length} new:`);
    for (const i of added) console.error(`  ${i.display}`);
    console.error(`\n${gate.remedy}`);
    process.exit(1);
  }
  console.log(`[${gate.name}] OK — no new violations`);
}

module.exports = { runGate, walk, hash, config, AP, ROOT };
