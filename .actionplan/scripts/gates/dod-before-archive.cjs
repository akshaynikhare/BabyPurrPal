#!/usr/bin/env node
// Static archive contract: explicit DoD/sign-off and sealed verification/review evidence.
// Limitation: validates recorded attestations, not natural-language QA truth or signer identity.
const fs = require('fs'), path = require('path');
const { runGate } = require('../gate-lib.cjs');
const { validateCompletion } = require('../completion-lib.cjs');
const { sha } = require('../plan-lib.cjs');
function collect(root) {
  const dir = path.join(root, '.actionplan/archived');
  if (!fs.existsSync(dir)) return [];
  return fs.readdirSync(dir).filter(f => f.endsWith('.md')).flatMap(f =>
    validateCompletion(root, path.join(dir, f), { current: false }).map(message => ({ key: `${f}|${message}`, display: `${f}: ${message}` })));
}
function selftest({ tmp }) {
  const id = ['AP', '0001'].join('-'), ap = path.join(tmp, '.actionplan');
  const dir = path.join(ap, 'archived'), qa = path.join(ap, 'qa', id);
  fs.mkdirSync(dir, { recursive: true }); fs.mkdirSync(qa, { recursive: true });
  const plan = path.join(dir, `${id}-fixture.md`);
  fs.writeFileSync(plan, `id: ${id}\n`);
  fs.writeFileSync(path.join(qa, 'report-1.md'), 'An unresolved regression remains.\n');
  if (!collect(tmp).length) return false;
  const report = 'No issue found in the supplied diff.\n', snap = sha('recorded historical source');
  const verification = `# Verification\nStatus: PASS\nSnapshot: ${snap}\n`;
  fs.writeFileSync(path.join(qa, 'report-1.md'), report);
  fs.writeFileSync(path.join(qa, 'verification.md'), verification);
  const review = 'Recorded review dispositions for the fixture.\n';
  fs.writeFileSync(path.join(qa, 'review-1.md'), review);
  const rows = ['acceptance', 'regression', 'security', 'cleanup'].map(role => `| ap-${role} | SKIP | - | - | Trigger absent in this fixture |`).join('\n');
  fs.writeFileSync(path.join(qa, 'completion-1.md'), `Round: 1\nSnapshot: ${snap}\nVerification-SHA256: ${sha(verification)}\nReview-SHA256: ${sha(review)}\n## Reviews\n| ap-qa | PASS | report-1.md | ${sha(report)} | No findings |\n${rows}\n`);
  const good = `id: ${id}\n## Definition of Done\n- [x] QA clean\n- [x] Human sign-off\n`;
  for (const bad of [good.replace('- [x] Human sign-off', '- [-] Human sign-off'), good.replace('- [x] QA clean', '- [ ] QA clean'), `id: ${id}\n`]) {
    fs.writeFileSync(plan, bad); if (!collect(tmp).length) return false;
  }
  fs.writeFileSync(plan, good);
  if (collect(tmp).length) return false;
  fs.writeFileSync(path.join(qa, 'report-1.md'), 'Changed after sealing');
  if (!collect(tmp).length) return false;
  fs.writeFileSync(path.join(qa, 'report-1.md'), report);
  return collect(tmp).length === 0;
}
runGate({ name: 'dod-before-archive', mode: 'absolute', collect, selftest,
  remedy: 'Keep the plan in-progress until final verification, review dispositions and human sign-off are present. See references/completion.md.' });
