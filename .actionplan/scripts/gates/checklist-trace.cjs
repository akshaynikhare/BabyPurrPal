#!/usr/bin/env node
// A TICKED coverage row must point at a real test: "- [x] R1 covered → <file> :: "<name>"".
// File must exist; the quoted name must appear in it. Unticked rows are fine (not done yet).
const fs = require('fs'), path = require('path');
const { runGate } = require('../gate-lib.cjs');

function collect(root) {
  const out = [];
  for (const stage of ['in-progress', 'archived']) {
    const dir = path.join(root, '.actionplan', stage);
    if (!fs.existsSync(dir)) continue;
    for (const f of fs.readdirSync(dir).filter((x) => x.endsWith('.md'))) {
      const body = fs.readFileSync(path.join(dir, f), 'utf8');
      const dod = (body.split(/^## Definition of Done$/m)[1] || '').split(/^## /m)[0];
      for (const row of dod.match(/^- \[x\] R\d+.*$/gm) || []) {
        const m = row.match(/→\s*([^\s:]+)\s*::\s*"([^"]+)"/);
        if (!m) { out.push({ key: `${f}|${row}`, display: `${f}: ticked R-row has no '→ file :: "name"': ${row.trim().slice(0, 80)}` }); continue; }
        const [, tf, name] = m;
        const tp = path.join(root, tf);
        if (!fs.existsSync(tp)) out.push({ key: `${f}|${tf}`, display: `${f}: test file missing — ${tf}` });
        else if (!fs.readFileSync(tp, 'utf8').includes(name)) out.push({ key: `${f}|${tf}|${name}`, display: `${f}: "${name}" not found in ${tf}` });
      }
    }
  }
  return out;
}

function selftest({ tmp }) {
  const dir = path.join(tmp, '.actionplan', 'in-progress');
  fs.mkdirSync(dir, { recursive: true });
  const plan = path.join(dir, 'AP-0001-x.md');
  fs.writeFileSync(plan, '## Definition of Done\n- [x] R1 covered → tests/a.test.ts :: "does it"\n');
  if (collect(tmp).length !== 1) return false;            // missing test file caught
  fs.mkdirSync(path.join(tmp, 'tests'), { recursive: true });
  fs.writeFileSync(path.join(tmp, 'tests', 'a.test.ts'), 'test("does it", () => {})\n');
  return collect(tmp).length === 0;
}

runGate({
  name: 'checklist-trace', mode: 'absolute', collect, selftest,
  remedy: 'Either write the named test or untick the row. A ticked coverage row is a claim — prove it.',
});
