#!/usr/bin/env node
// Dead relative links in governance docs — prose pointing at nothing is how kits rot.
const fs = require('fs'), path = require('path');
const { runGate, walk } = require('../gate-lib.cjs');

function collect(root) {
  const out = [];
  for (const base of ['.actionplan', 'docs']) {
    const dir = path.join(root, base);
    for (const f of walk(dir, { exts: ['.md'], excludes: ['node_modules', 'qa', 'locks'] })) {
      const body = fs.readFileSync(f, 'utf8');
      for (const m of body.matchAll(/\[[^\]]*\]\(([^)]+)\)/g)) {
        const target = m[1].split('#')[0].trim();
        if (!target || /^(https?:|mailto:|\{\{)/.test(m[1])) continue;
        const resolved = path.resolve(path.dirname(f), target);
        if (!fs.existsSync(resolved)) {
          const rel = path.relative(root, f);
          out.push({ key: `${rel}|${target}`, display: `${rel}: dead link → ${target}` });
        }
      }
    }
  }
  return out;
}

function selftest({ tmp }) {
  const dir = path.join(tmp, 'docs');
  fs.mkdirSync(dir, { recursive: true });
  const f = path.join(dir, 'a.md');
  fs.writeFileSync(f, 'see [the plan](./missing.md)\n');
  if (collect(tmp).length !== 1) return false;
  fs.writeFileSync(path.join(dir, 'missing.md'), 'here\n');
  return collect(tmp).length === 0;
}

runGate({
  name: 'doc-links', mode: 'absolute', collect, selftest,
  remedy: 'Fix the path or delete the claim. A doc that points at nothing teaches the next agent to write to nothing.',
});
