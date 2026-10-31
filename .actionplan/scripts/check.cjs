#!/usr/bin/env node
// Dedicated gate entry point: independent of the target project's Makefile.
const fs = require('fs'), path = require('path'), { spawnSync } = require('child_process');
const dir = path.join(__dirname, 'gates');
const gates = fs.readdirSync(dir).filter(f => f.endsWith('.cjs')).sort();
if (!gates.length) { console.error('[check] No gates installed'); process.exit(1); }
for (const file of gates) {
  const r = spawnSync(process.execPath, [path.join(dir, file), ...process.argv.slice(2)], { stdio: 'inherit' });
  if (r.error || r.status !== 0) { if (r.error) console.error(r.error.message); process.exit(r.status || 1); }
}
