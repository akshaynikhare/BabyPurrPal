#!/usr/bin/env node
// e2e locators: getByRole/getByLabel/getByText only. Test ids are a parallel accessibility tree nobody audits.
const fs = require('fs'), path = require('path');
const { runGate, walk } = require('../gate-lib.cjs');

function collect(root) {
  const out = [];
  const dir = path.join(root, 'e2e');
  for (const f of walk(dir, { exts: ['.ts', '.js', '.mjs'], excludes: ['node_modules', 'playwright-report', 'test-results'] })) {
    const lines = fs.readFileSync(f, 'utf8').split('\n');
    lines.forEach((l, i) => {
      if (/getByTestId\(|\[data-testid/.test(l)) {
        const rel = path.relative(root, f);
        out.push({ key: `${rel}:${i + 1}`, display: `${rel}:${i + 1}  ${l.trim().slice(0, 80)}` });
      }
    });
  }
  return out;
}

function selftest({ tmp }) {
  const dir = path.join(tmp, 'e2e', 'specs');
  fs.mkdirSync(dir, { recursive: true });
  const f = path.join(dir, 'a.spec.ts');
  fs.writeFileSync(f, "page.getByTestId('save')\n");
  if (collect(tmp).length !== 1) return false;
  fs.writeFileSync(f, "page.getByRole('button', { name: 'Save' })\n");
  return collect(tmp).length === 0;
}

runGate({
  name: 'locator-policy', mode: 'absolute', collect, selftest,
  remedy: 'Use getByRole/getByLabel/getByText — find things the way a user does.',
});
