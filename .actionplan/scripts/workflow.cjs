#!/usr/bin/env node
const fs = require('fs'), path = require('path');
const { section, validateId, findPlan, projectPath, filesOfPlan, atomicWrite, stages } = require('./plan-lib.cjs');
const { transaction, readLocks, owned, claim, release, overlaps } = require('./lock-lib.cjs');
const ap = path.resolve(__dirname, '..'), root = path.dirname(ap);
const session = process.env.ACTIONPLAN_SESSION_ID;
function frozen(file) {
  const p = path.join(ap, 'FROZEN.md');
  if (!fs.existsSync(p)) return false;
  for (const line of fs.readFileSync(p, 'utf8').split('\n')) {
    const m = line.match(/^- (\S+)/); if (!m) continue;
    const glob = m[1].replace(/`/g, '').replace(/^\.\//, '');
    const re = glob.replace(/[.+^${}()|[\]\\]/g, '\\$&').replace(/\*+/g, '.*').replace(/\?/g, '.');
    if (new RegExp(`^${re}$`).test(file)) return true;
  }
  return false;
}
function main() {
  if (!session) throw Error('Use lock.sh/stage.sh or set ACTIONPLAN_SESSION_ID');
  const [kind, action, value] = process.argv.slice(2);
  transaction(ap, () => {
    if (kind === 'stage') {
      const id = validateId(action), to = ({ 'in-progres': 'in-progress', inprogress: 'in-progress' })[value] || value;
      if (!stages.includes(to)) throw Error('Unknown stage');
      const src = findPlan(ap, id), body = fs.readFileSync(src, 'utf8');
      owned(ap, id, session, to === 'in-progress');
      if (to === 'in-progress' && section(body, 'Open questions').replace(/<!--[\s\S]*?-->/g, '').trim()) throw Error('Answer all open questions before starting');
      if (to === 'archived') {
        const problems = require('./completion-lib.cjs').validateCompletion(root, src);
        if (problems.length) throw Error(problems.join('\n'));
      }
      const dst = path.join(ap, to, path.basename(src));
      if (src !== dst) {
        if (fs.existsSync(dst)) throw Error('Destination already exists');
        if (!/^stage: .*$/m.test(body)) throw Error('Missing stage field');
        atomicWrite(src, body.replace(/^stage: .*$/m, `stage: ${to}`)); fs.renameSync(src, dst);
      }
      if (to !== 'in-progress') release(ap, id, session);
      console.log(`[stage] ${id} → ${to}`);
      if (to === 'archived') console.log('[stage] retro: append What worked / What to change to the plan.');
      return;
    }
    if (kind !== 'lock') throw Error('Expected lock or stage');
    if (['claim', 'release', 'steal'].includes(action)) validateId(value);
    if (action === 'claim') {
      for (const file of filesOfPlan(root, fs.readFileSync(findPlan(ap, value), 'utf8'))) if (frozen(file)) throw Error(`FROZEN: ${file}`);
      console.log(`[lock] ${value} claimed ${claim(ap, value, session)} file(s) for ${session}`);
    } else if (action === 'release') {
      release(ap, value, session); console.log(`[lock] ${value} released`);
    } else if (action === 'steal') {
      const l = readLocks(ap).find(l => l.plan === value);
      if (!l) throw Error('No such lock');
      const config = JSON.parse(fs.readFileSync(path.join(ap, 'config.json'), 'utf8'));
      const hours = Number(config.lockStaleHours ?? 8), age = Date.now() - Date.parse(l.started);
      if (!(hours > 0) || !Number.isFinite(age) || age < hours * 3600000) throw Error('Lock is not stale');
      if (!process.argv.includes('--human-confirmed')) throw Error('A human must authorize stale takeover; rerun with --human-confirmed after approval');
      fs.unlinkSync(path.join(ap, 'locks', `${value}.json`)); console.log(`[lock] stale ${value} released for takeover`);
    } else if (action === 'check' || action === 'frozen') {
      const p = projectPath(root, value);
      if (action === 'frozen') { if (frozen(p)) throw Error(`FROZEN: ${p}`); }
      else for (const l of readLocks(ap)) if (l.files.some(f => overlaps(p, projectPath(root, f)))) throw Error(`Locked by ${l.plan} (session ${l.session})`);
      console.log('free');
    } else if (action === 'list') {
      for (const l of readLocks(ap)) console.log(`${l.plan}  ${l.session}  since ${l.started}  ${l.files.length} file(s)`);
    } else throw Error('Usage: lock.sh claim|release|steal <id> | check|frozen <path> | list');
  });
}
try { main(); } catch (err) { console.error(`[workflow] REFUSED — ${err.message}`); process.exitCode = 3; }
