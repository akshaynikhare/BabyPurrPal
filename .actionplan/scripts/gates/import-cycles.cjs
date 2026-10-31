#!/usr/bin/env node
// Circular imports fail unconditionally — a cycle is never baselined. Tarjan SCC over relative imports.
const fs = require('fs'), path = require('path');
const { runGate, walk, config } = require('../gate-lib.cjs');

const EXTS = ['.ts', '.tsx', '.js', '.jsx', '.mjs', '.cjs'];
const resolve = (from, spec) => {
  const base = path.resolve(path.dirname(from), spec);
  for (const c of [base, ...EXTS.map((e) => base + e), ...EXTS.map((e) => path.join(base, 'index' + e))])
    if (fs.existsSync(c) && fs.statSync(c).isFile()) return c;
  return null;
};

function collect(root) {
  const dirs = (config(root).srcDirs || ['src']).map((d) => path.join(root, d));
  const files = dirs.flatMap((d) => walk(d, { exts: EXTS, excludes: ['node_modules', 'dist', 'build'] }));
  const graph = new Map(files.map((f) => [f, []]));
  for (const f of files) {
    const src = fs.readFileSync(f, 'utf8');
    for (const m of src.matchAll(/(?:from|require\()\s*['"](\.[^'"]+)['"]/g)) {
      const t = resolve(f, m[1]);
      if (t && graph.has(t)) graph.get(f).push(t);
    }
  }
  // Tarjan
  let idx = 0; const index = new Map(), low = new Map(), on = new Set(), stack = [], sccs = [];
  function strong(v) {
    index.set(v, idx); low.set(v, idx); idx++; stack.push(v); on.add(v);
    for (const w of graph.get(v) || []) {
      if (!index.has(w)) { strong(w); low.set(v, Math.min(low.get(v), low.get(w))); }
      else if (on.has(w)) low.set(v, Math.min(low.get(v), index.get(w)));
    }
    if (low.get(v) === index.get(v)) {
      const scc = []; let w;
      do { w = stack.pop(); on.delete(w); scc.push(w); } while (w !== v);
      if (scc.length > 1) sccs.push(scc);
    }
  }
  for (const f of files) if (!index.has(f)) strong(f);
  return sccs.map((scc) => {
    const rels = scc.map((f) => path.relative(root, f)).sort();
    return { key: rels.join('→'), display: `cycle (${rels.length}): ${rels.join(' → ')}` };
  });
}

function selftest({ tmp }) {
  const dir = path.join(tmp, 'src');
  fs.mkdirSync(dir, { recursive: true });
  fs.writeFileSync(path.join(dir, 'a.ts'), "import { b } from './b'\nexport const a = 1\n");
  fs.writeFileSync(path.join(dir, 'b.ts'), "import { a } from './a'\nexport const b = 2\n");
  if (collect(tmp).length !== 1) return false;
  fs.writeFileSync(path.join(dir, 'b.ts'), 'export const b = 2\n');
  return collect(tmp).length === 0;
}

runGate({
  name: 'import-cycles', mode: 'absolute', collect, selftest,
  remedy: 'Break the cycle — extract the shared piece into a third module. Cycles are never baselined.',
});
