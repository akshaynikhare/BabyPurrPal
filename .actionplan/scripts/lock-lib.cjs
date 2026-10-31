// Atomic mkdir serializes lock and stage changes. Busy mutexes are never auto-stolen.
const fs = require('fs'), path = require('path');
const { filesOfPlan, findPlan, projectPath, atomicWrite } = require('./plan-lib.cjs');
function transaction(ap, fn) {
  const dir = path.join(ap, 'locks'); fs.mkdirSync(dir, { recursive: true });
  const mutex = path.join(dir, '.mutex');
  try { fs.mkdirSync(mutex); }
  catch (err) { if (err.code === 'EEXIST') throw Error('Lock registry busy (.actionplan/locks/.mutex); retry. After a crash, a human must confirm no writer remains before removing it.'); throw err; }
  try { return fn(); } finally { fs.rmdirSync(mutex); }
}
function readLocks(ap) {
  return fs.readdirSync(path.join(ap, 'locks')).filter(f => f.endsWith('.json')).map(f => {
    const l = JSON.parse(fs.readFileSync(path.join(ap, 'locks', f), 'utf8'));
    if (!l.session || !Array.isArray(l.files) || f !== `${l.plan}.json`) throw Error(`Invalid lock ${f}; human review required`);
    return l;
  });
}
function owned(ap, id, session, required = false) {
  const lock = readLocks(ap).find(l => l.plan === id);
  if (lock && lock.session !== session) throw Error(`${id} is held by session ${lock.session}`);
  if (!lock && required) throw Error(`Claim ${id} before changing its stage`);
  return lock;
}
function overlaps(a, b) {
  // Conservatively cover case aliases on common case-insensitive host filesystems.
  if (['darwin', 'win32'].includes(process.platform)) { a = a.toLowerCase(); b = b.toLowerCase(); }
  return a === b || a.startsWith(`${b}/`) || b.startsWith(`${a}/`);
}
function claim(ap, id, session) {
  const root = path.dirname(ap), files = filesOfPlan(root, fs.readFileSync(findPlan(ap, id), 'utf8'));
  const previous = owned(ap, id, session);
  for (const other of readLocks(ap).filter(l => l.plan !== id)) {
    if (files.some(f => other.files.some(g => overlaps(f, projectPath(root, g))))) throw Error(`File overlap with ${other.plan} (session ${other.session})`);
  }
  atomicWrite(path.join(ap, 'locks', `${id}.json`), JSON.stringify({ plan: id, session, started: previous?.started || new Date().toISOString(), files }, null, 2) + '\n');
  return files.length;
}
function release(ap, id, session) {
  if (owned(ap, id, session)) fs.unlinkSync(path.join(ap, 'locks', `${id}.json`));
}
module.exports = { transaction, readLocks, owned, claim, release, overlaps };
