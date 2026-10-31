#!/usr/bin/env node
// Plan ids never appear in code — the plan points at code, code never points back.
// Ratchet (an adopted repo may carry old refs). Keys are content-hashed so line moves don't re-key.
const fs = require('fs'), path = require('path');
const { runGate, walk, hash, config } = require('../gate-lib.cjs');

const CODE_EXTS = ['.ts', '.tsx', '.js', '.jsx', '.mjs', '.cjs', '.vue', '.svelte', '.py', '.go', '.rb', '.rs', '.java', '.kt', '.swift', '.sh'];
const EXCLUDES = ['node_modules', '.git', '.actionplan', 'docs', '.claude', 'dist', 'build', 'coverage', '.next'];

function collect(root) {
  const code = (config(root).code || 'AP').replace(/[^A-Za-z]/g, '');
  const re = new RegExp(`\\b${code}-\\d{4}\\b`);
  const out = [];
  for (const f of walk(root, { exts: CODE_EXTS, excludes: EXCLUDES })) {
    const lines = fs.readFileSync(f, 'utf8').split('\n');
    lines.forEach((l, i) => {
      if (re.test(l)) {
        const rel = path.relative(root, f);
        out.push({ key: `${rel}#${hash(l.trim())}`, display: `${rel}:${i + 1}  ${l.trim().slice(0, 90)}` });
      }
    });
  }
  return out;
}

function selftest({ tmp }) {
  fs.mkdirSync(path.join(tmp, '.actionplan'), { recursive: true });
  fs.writeFileSync(path.join(tmp, '.actionplan', 'config.json'), '{"code":"AP"}');
  const f = path.join(tmp, 'a.ts');
  fs.writeFileSync(f, 'const x = 1; // fixes AP-0001\n');
  if (collect(tmp).length !== 1) return false;           // planted violation must be caught
  fs.writeFileSync(f, 'const x = 1;\n');
  return collect(tmp).length === 0;                       // fixed version must pass
}

runGate({
  name: 'no-plan-refs', mode: 'ratchet', collect, selftest,
  remedy: 'Remove the plan id from code. The plan\'s checklist points at the file/test — code never points back.',
});
