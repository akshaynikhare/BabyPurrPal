#!/usr/bin/env node
// Zero code while questions are open: an in-progress plan may not carry open questions.
const fs = require('fs'), path = require('path');
const { runGate } = require('../gate-lib.cjs');

function collect(root) {
  const out = [];
  const dir = path.join(root, '.actionplan', 'in-progress');
  if (!fs.existsSync(dir)) return out;
  for (const f of fs.readdirSync(dir).filter((x) => x.endsWith('.md'))) {
    const body = fs.readFileSync(path.join(dir, f), 'utf8');
    const oq = (body.split(/^## Open questions$/m)[1] || '').split(/^## /m)[0];
    const qs = (oq.match(/^- \S/gm) || []).length;
    if (qs > 0) out.push({ key: `${f}|${qs}`, display: `${f}: ${qs} open question(s) while in-progress — answer them first (/ap:ask)` });
  }
  return out;
}

function selftest({ tmp }) {
  const dir = path.join(tmp, '.actionplan', 'in-progress');
  fs.mkdirSync(dir, { recursive: true });
  const plan = path.join(dir, 'AP-0001-x.md');
  fs.writeFileSync(plan, '## Open questions\n- Q1 — reset on API activity?\n\n## Decisions\n');
  if (collect(tmp).length !== 1) return false;
  fs.writeFileSync(plan, '## Open questions\n\n## Decisions\n| Q1 | input only | timer is UX |\n');
  return collect(tmp).length === 0;
}

runGate({
  name: 'open-questions', mode: 'absolute', collect, selftest,
  remedy: 'Run /ap:ask — every question answered in one batch, answers land in ## Decisions, questions deleted.',
});
