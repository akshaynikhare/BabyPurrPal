#!/usr/bin/env node
// Seal the orchestrator's explicit review dispositions; never infer verdicts from free-form prose.
const fs = require('fs'), path = require('path');
const { findPlan, snapshot, sha, atomicWrite } = require('./plan-lib.cjs');
const { field, roles, reviewRows, latestRound } = require('./completion-lib.cjs');
try {
  const ap = path.resolve(__dirname, '..'), root = path.dirname(ap), [id, round] = process.argv.slice(2);
  const plan = findPlan(ap, id), dir = path.join(ap, 'qa', id);
  if (!/^[1-9]\d*$/.test(round || '') || latestRound(dir) !== Number(round)) throw Error('Use the latest QA round');
  const verification = fs.readFileSync(path.join(dir, 'verification.md'), 'utf8');
  const snap = snapshot(root, fs.readFileSync(plan, 'utf8'));
  if (field(verification, 'Status') !== 'PASS' || field(verification, 'Snapshot') !== snap) throw Error('Run verification against final files first');
  const review = fs.readFileSync(path.join(dir, `review-${round}.md`), 'utf8');
  const rows = reviewRows(review);
  if (rows.length !== roles.length || roles.some(role => rows.filter(r => r[0] === role).length !== 1)) throw Error('Account for all five reviewers exactly once');
  const sealed = rows.map(([role, status, report, reason]) => {
    if (!reason || /TODO|<.*>/.test(reason)) throw Error(`${role}: record a concrete disposition`);
    if (status === 'SKIP' && role !== 'ap-qa' && report === '-') return [role, status, '-', '-', reason];
    if (status !== 'PASS') throw Error(`${role} has unresolved findings or uncertainty`);
    const prefix = role === 'ap-qa' ? 'report' : `${role}-report`;
    const m = (report || '').match(new RegExp(`^${prefix}-(\\d+)\\.md$`));
    if (!m || Number(m[1]) > Number(round) || (role === 'ap-qa' && m[1] !== round)) throw Error(`${role}: invalid report`);
    if (fs.readdirSync(dir).some(f => { const n = f.match(new RegExp(`^${prefix}-(\\d+)\\.md$`)); return n && Number(n[1]) > Number(m[1]); })) throw Error(`${role}: a newer report exists`);
    const content = fs.readFileSync(path.join(dir, report), 'utf8');
    if (!content.trim()) throw Error(`${role}: empty report`);
    return [role, status, report, sha(content), reason];
  });
  atomicWrite(path.join(dir, `completion-${round}.md`), `# Completion evidence\nRound: ${round}\nSnapshot: ${snap}\nVerification-SHA256: ${sha(verification)}\nReview-SHA256: ${sha(review)}\n\n## Reviews\n| Agent | Status | Report | SHA256 | Reason |\n|---|---|---|---|---|\n${sealed.map(r => '| ' + r.join(' | ') + ' |').join('\n')}\n`);
  console.log('[finish] Evidence sealed. Human sign-off remains for the human.');
} catch (err) { console.error(`[finish] REFUSED — ${err.message}`); process.exitCode = 1; }
