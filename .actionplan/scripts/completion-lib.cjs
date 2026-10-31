// Static completion evidence validation. It verifies attestations and hashes, not QA prose semantics
// or the identity of the human who ticks sign-off. Archived history need not match today's code.
const fs = require('fs'), path = require('path');
const { section, snapshot, sha, validateId } = require('./plan-lib.cjs');
const roles = ['ap-qa', 'ap-acceptance', 'ap-regression', 'ap-security', 'ap-cleanup'];
const field = (body, key) => (body.split('\n').find(l => l.startsWith(`${key}: `)) || '').slice(key.length + 2).trim();
function reviewRows(body) {
  return section(body, 'Reviews').split('\n').filter(l => /^\| ap-/.test(l)).map(l => l.split('|').slice(1, -1).map(s => s.trim()));
}
function latestRound(dir) {
  return Math.max(0, ...fs.readdirSync(dir).map(f => Number((f.match(/(?:brief|report|review|completion)-(\d+)\.md$/) || [])[1]) || 0));
}
function validateCompletion(root, plan, { current = true } = {}) {
  const errors = [];
  try {
    const body = fs.readFileSync(plan, 'utf8'), id = validateId(field(body, 'id'));
    const dod = section(body, 'Definition of Done');
    if (!dod.trim()) errors.push('Definition of Done is missing or empty');
    for (const label of ['Human sign-off', 'QA clean']) {
      const rows = dod.split('\n').filter(l => new RegExp(`^[-*] \\[[ xX-]\\] ${label}\\b`).test(l));
      if (rows.length !== 1 || !/^[-*] \[[xX]\]/.test(rows[0])) errors.push(`${label} must occur once and be explicitly checked`);
    }
    if (/^[-*] \[ \]/m.test(dod)) errors.push('Definition of Done has unresolved rows');
    if (/^[-*] \[ \]/m.test(section(body, 'Sprint tasks'))) errors.push('Sprint tasks have unchecked work; finish or park with reasons');
    if (section(body, 'Open questions').replace(/<!--[\s\S]*?-->/g, '').trim()) errors.push('Open questions remain');
    const dir = path.join(root, '.actionplan/qa', id);
    if (!fs.existsSync(dir)) throw Error('QA evidence directory missing');
    const round = latestRound(dir);
    if (!round) throw Error('No QA round on disk');
    const completion = fs.readFileSync(path.join(dir, `completion-${round}.md`), 'utf8');
    if (field(completion, 'Round') !== String(round)) errors.push('Completion round does not match latest QA round');
    const verification = fs.readFileSync(path.join(dir, 'verification.md'), 'utf8');
    const snap = field(verification, 'Snapshot');
    if (field(verification, 'Status') !== 'PASS' || !/^[a-f0-9]{64}$/.test(snap)) errors.push('Successful verification evidence missing');
    if (field(completion, 'Snapshot') !== snap || field(completion, 'Verification-SHA256') !== sha(verification)) errors.push('Completion does not match verification evidence');
    if (current && snapshot(root, body) !== snap) errors.push('Files or verification instructions changed; rerun verification and reviews before completion');
    const review = fs.readFileSync(path.join(dir, `review-${round}.md`), 'utf8');
    if (field(completion, 'Review-SHA256') !== sha(review)) errors.push('Review dispositions changed after sealing');
    const rows = reviewRows(completion);
    if (rows.length !== roles.length || rows.some(r => !roles.includes(r[0]))) errors.push('Completion must account for every reviewer');
    for (const role of roles) {
      const matches = rows.filter(r => r[0] === role);
      if (matches.length !== 1) { errors.push(`Missing or duplicate review: ${role}`); continue; }
      const [, status, report, hash, reason] = matches[0];
      if (!reason || /TODO|<.*>/.test(reason)) errors.push(`${role}: record a concrete review disposition`);
      if (status === 'SKIP' && role !== 'ap-qa' && report === '-' && hash === '-') continue;
      if (status !== 'PASS') { errors.push(`${role}: review is not PASS (only focused reviewers may SKIP with a reason)`); continue; }
      const prefix = role === 'ap-qa' ? 'report' : `${role}-report`;
      const m = (report || '').match(new RegExp(`^${prefix}-(\\d+)\\.md$`));
      if (!m || Number(m[1]) > round || (role === 'ap-qa' && Number(m[1]) !== round)) { errors.push(`${role}: invalid report for this round`); continue; }
      const newer = fs.readdirSync(dir).some(f => {
        const match = f.match(new RegExp(`^${prefix}-(\\d+)\\.md$`));
        return match && Number(match[1]) > Number(m[1]);
      });
      if (newer) errors.push(`${role}: a newer report exists`);
      const text = fs.readFileSync(path.join(dir, report), 'utf8');
      if (!text.trim() || sha(text) !== hash) errors.push(`${role}: report missing, empty or changed`);
    }
  } catch (err) { errors.push(err.message); }
  return errors;
}
module.exports = { roles, field, reviewRows, latestRound, validateCompletion };
