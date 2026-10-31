#!/usr/bin/env node
// Executes the plan's explicit verification commands, configured lint/typecheck and kit gates.
// Commands are intentionally executable plan instructions; only the orchestrator invokes this.
const fs = require('fs'), path = require('path'), { spawnSync } = require('child_process');
const { findPlan, section, snapshot, atomicWrite } = require('./plan-lib.cjs');
const ap = path.resolve(__dirname, '..'), root = path.dirname(ap);
let output;
try {
  const id = process.argv[2], plan = findPlan(ap, id), body = fs.readFileSync(plan, 'utf8');
  const dir = path.join(ap, 'qa', id); fs.mkdirSync(dir, { recursive: true });
  output = path.join(dir, 'verification.md');
  // Invalidate earlier success before parsing or launching any checks.
  atomicWrite(output, '# Verification\nStatus: FAIL\nReason: verification started but has not completed\n');
  const before = snapshot(root, body), block = section(body, 'Verification');
  const blocks = [...block.matchAll(/```(?:bash|sh)\s*\n([\s\S]*?)```/g)];
  if (!blocks.length) throw Error('Verification needs a bash/sh block with explicit targeted commands');
  const script = blocks.map(m => m[1]).join('\n');
  if (!script.replace(/^\s*#.*$/gm, '').trim() || /<command>|TODO\(verify\)/.test(script)) throw Error('Fill in Verification commands before running');
  const cfg = JSON.parse(fs.readFileSync(path.join(ap, 'config.json'), 'utf8'));
  const checks = [
    ['Plan verification', 'bash', ['-e', '-o', 'pipefail', '-c', script]],
    ...['typecheck', 'lint'].map(k => {
      const cmd = cfg.commands?.[k];
      if (typeof cmd !== 'string' || !cmd.trim() || /TODO\(verify\)/.test(cmd)) throw Error(`Configure commands.${k} before verification`);
      return [k, 'bash', ['-e', '-o', 'pipefail', '-c', cmd]];
    }),
    ['ActionPlan gates', process.execPath, [path.join(__dirname, 'check.cjs')]],
  ];
  let passed = true;
  const records = [];
  for (const [label, command, args] of checks) {
    const r = spawnSync(command, args, { cwd: root, encoding: 'utf8', maxBuffer: 16 * 1024 * 1024 });
    const text = (r.stdout || '') + (r.stderr || '') + (r.error ? r.error.message : '');
    const status = !r.error && r.status === 0 ? 'PASS' : 'FAIL';
    console.log(`[verify] ${label}: ${status}`); if (text) process.stdout.write(text);
    const fence = '`'.repeat(Math.max(3, ...[...text.matchAll(/`+/g)].map(m => m[0].length + 1)));
    records.push(`## ${label}\nStatus: ${status}\nCommand: ${command}\nArguments: ${JSON.stringify(args)}\nExit: ${r.status ?? 'error'}\n${fence}text\n${text}\n${fence}`);
    if (status === 'FAIL') { passed = false; break; }
  }
  const after = snapshot(root, fs.readFileSync(plan, 'utf8'));
  if (before !== after) { passed = false; records.push('Checks changed scoped files or the plan; inspect edits and rerun.'); }
  atomicWrite(output, `# Verification\nStatus: ${passed ? 'PASS' : 'FAIL'}\nSnapshot: ${after}\nRecorded: ${new Date().toISOString()}\n\n${records.join('\n\n')}\n`);
  if (!passed) process.exitCode = 1;
} catch (err) {
  console.error(`[verify] FAIL — ${err.message}`);
  if (output) atomicWrite(output, `# Verification\nStatus: FAIL\nReason: ${err.message}\n`);
  process.exitCode = 1;
}
