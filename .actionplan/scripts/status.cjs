#!/usr/bin/env node
// Board + velocity + MIRROR. Only computed numbers speak; nothing to show -> "MIRROR: clean."
const fs = require('fs'), path = require('path');
const AP = path.join(__dirname, '..');
let cfg = {}; try { cfg = JSON.parse(read(path.join(AP, 'config.json')) || '{}'); } catch { console.error('[status] .actionplan/config.json is malformed — using defaults'); }
const STALE_H = cfg.lockStaleHours || 8;

function read(p) { try { return fs.readFileSync(p, 'utf8'); } catch { return null; } }
function plans(stage) {
  const dir = path.join(AP, stage);
  if (!fs.existsSync(dir)) return [];
  return fs.readdirSync(dir).filter(f => f.endsWith('.md')).map(f => {
    const t = read(path.join(dir, f)) || '';
    const fm = (k) => (t.match(new RegExp(`^${k}: (.*)$`, 'm')) || [])[1];
    const boxes = t.match(/^- \[[ x-]\]/gm) || [];
    const done = t.match(/^- \[x\]/gm) || [];
    return { file: f, id: fm('id') || f.split('-').slice(0, 2).join('-'), title: fm('title') || f,
      opened: fm('opened'), mtime: fs.statSync(path.join(dir, f)).mtimeMs,
      total: boxes.length, done: done.length, body: t };
  });
}
const days = (iso) => iso ? Math.floor((Date.now() - new Date(iso)) / 864e5) : null;

const planned = plans('planned'), prog = plans('in-progress'), arch = plans('archived');

console.log('── BOARD ──────────────────────────────');
console.log(`backlog ${planned.length} · in-progress ${prog.length} · archived ${arch.length}`);
for (const p of prog) console.log(`  ${p.id}  ${p.title}  ${p.done}/${p.total} ticked  (day ${days(p.opened)})`);

// velocity: archived in last 14 days (by archive-move time, not open date)
const recent = arch.filter(p => (Date.now() - p.mtime) / 864e5 <= 14).length;
console.log(`velocity: ${recent} stories archived / 14 days`);

const mirror = [];
// stuck sprints
for (const p of prog) { const d = days(p.opened); if (d !== null && d > 7) mirror.push(`${p.id} in-progress ${d} days. A sprint is days, not weeks. Split it or kill it.`); }
// criteria without a named test (R-rows in DoD lacking "→")
let rTotal = 0, rBare = 0;
for (const p of [...prog, ...planned]) {
  const dod = (p.body.split(/^## Definition of Done$/m)[1] || '').split(/^## /m)[0];
  const rows = dod.match(/^- \[[ x-]\] R\d.*/gm) || [];
  rTotal += rows.length; rBare += rows.filter(r => !r.includes('→')).length;
}
if (rBare > 0) mirror.push(`Acceptance criteria without a named test: ${rBare} of ${rTotal}. You are shipping hope.`);
// open questions in in-progress plans
for (const p of prog) {
  const oq = (p.body.split(/^## Open questions$/m)[1] || '').split(/^## /m)[0];
  const qs = (oq.match(/^- /gm) || []).length;
  if (qs > 0) mirror.push(`${p.id} is in-progress with ${qs} open question(s). Code before clarity — that is the bug factory.`);
}
// baseline growth from trend
const trend = read(path.join(AP, 'trend', 'gates.tsv'));
if (trend) {
  const by = {};
  for (const l of trend.trim().split('\n')) { const [d, g, c] = l.split('\t'); (by[g] = by[g] || []).push(+c); }
  for (const [g, cs] of Object.entries(by)) { let ups = 0; for (let i = 1; i < cs.length; i++) if (cs[i] > cs[i - 1]) ups++;
    if (ups > 0) mirror.push(`Gate '${g}' baseline grew ${ups} time(s). That is debt, not progress.`); }
}
// stale locks
const locksDir = path.join(AP, 'locks');
if (fs.existsSync(locksDir)) for (const f of fs.readdirSync(locksDir).filter(f => f.endsWith('.json'))) {
  try {
    const l = JSON.parse(read(path.join(locksDir, f)));
    const h = Math.floor((Date.now() - new Date(l.started)) / 36e5);
    if (h >= STALE_H) mirror.push(`Stale lock: ${l.plan}, ${h}h old (session ${l.session}). Steal it or release it.`);
  } catch { mirror.push(`Unreadable lock file: locks/${f}. Fix or delete it — until then nothing it held is protected.`); }
}
// QA round-3 stalls
const qaDir = path.join(AP, 'qa');
if (fs.existsSync(qaDir)) {
  const r3 = fs.readdirSync(qaDir).filter(id => fs.existsSync(path.join(qaDir, id, 'report-3.md'))).length;
  if (r3 > 0) mirror.push(`QA hit round 3 on ${r3} plan(s) — briefs too vague or diffs too big.`);
}
console.log('── MIRROR ─────────────────────────────');
console.log(mirror.length ? mirror.map(m => '  ' + m).join('\n') : '  MIRROR: clean.');
