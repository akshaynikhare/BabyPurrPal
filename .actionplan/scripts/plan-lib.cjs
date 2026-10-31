// Shared plan parsing and path validation. Paths are data, never evaluated code.
const fs = require('fs'), path = require('path'), crypto = require('crypto');
const stages = ['planned', 'in-progress', 'archived', 'audit'];
const sha = value => crypto.createHash('sha256').update(value).digest('hex');
function section(body, heading) {
  const lines = body.replace(/\r/g, '').split('\n'), start = lines.indexOf(`## ${heading}`);
  if (start < 0) return '';
  const end = lines.findIndex((line, i) => i > start && /^## /.test(line));
  return lines.slice(start + 1, end < 0 ? undefined : end).join('\n');
}
function validateId(id) {
  if (!/^[A-Za-z]{2,3}-\d{4,}$/.test(id || '')) throw Error('Expected a plan id: <CODE>-<number>');
  return id;
}
function findPlan(ap, id) {
  validateId(id);
  const matches = stages.flatMap(stage => {
    const dir = path.join(ap, stage);
    return fs.existsSync(dir) ? fs.readdirSync(dir).filter(f => f.startsWith(`${id}-`) && f.endsWith('.md')).map(f => path.join(dir, f)) : [];
  });
  if (matches.length !== 1) throw Error(`Expected one plan for ${id}; found ${matches.length}`);
  return matches[0];
}
function inside(root, file) {
  const rel = path.relative(root, file);
  return rel !== '..' && !rel.startsWith(`..${path.sep}`) && !path.isAbsolute(rel);
}
function projectPath(root, value) {
  if (!value || path.isAbsolute(value) || /[\x00-\x1f<>*?{}]/.test(value)) throw Error(`Use a concrete relative path: ${value}`);
  root = fs.realpathSync(root);
  const file = path.resolve(root, value);
  if (!inside(root, file)) throw Error(`Path escapes project: ${value}`);
  let ancestor = file;
  while (!fs.existsSync(ancestor)) {
    try { if (fs.lstatSync(ancestor).isSymbolicLink()) throw Error(`Unresolved symlink: ${value}`); }
    catch (err) { if (err.code !== 'ENOENT') throw err; }
    ancestor = path.dirname(ancestor);
  }
  const resolved = path.resolve(fs.realpathSync(ancestor), path.relative(ancestor, file));
  if (!inside(root, resolved)) throw Error(`Symlink escapes project: ${value}`);
  const relative = path.relative(root, resolved).split(path.sep).join('/');
  if (!relative) throw Error('Name a file, not the project root');
  return relative;
}
function filesOfPlan(root, body) {
  const files = section(body, 'Files touched').split('\n').filter(l => /^\|/.test(l))
    .map(l => l.split('|')[1].trim().replace(/^`|`$/g, ''))
    .filter(l => l && l !== 'File' && !/^[-: ]+$/.test(l));
  if (!files.length) throw Error('Files touched must list at least one concrete file (including light plans)');
  const normalized = [...new Set(files.map(f => projectPath(root, f)))].sort();
  for (const f of normalized) if (fs.existsSync(path.join(root, f)) && !fs.statSync(path.join(root, f)).isFile()) throw Error(`Name a file, not a directory: ${f}`);
  return normalized;
}
function snapshot(root, body) {
  const entries = filesOfPlan(root, body).map(f => {
    const p = path.join(root, f);
    if (fs.existsSync(p) && !fs.statSync(p).isFile()) throw Error(`Files touched must name files, not directories: ${f}`);
    return [f, fs.existsSync(p) ? sha(fs.readFileSync(p)) : 'absent'];
  });
  const config = JSON.parse(fs.readFileSync(path.join(root, '.actionplan/config.json'), 'utf8'));
  return sha(JSON.stringify({ entries, verification: section(body, 'Verification'), criteria: section(body, 'Acceptance criteria'), commands: config.commands }));
}
function atomicWrite(file, contents) {
  const tmp = `${file}.${process.pid}.tmp`;
  try { fs.writeFileSync(tmp, contents, { flag: 'wx' }); fs.renameSync(tmp, file); }
  finally { if (fs.existsSync(tmp)) fs.unlinkSync(tmp); }
}
module.exports = { section, validateId, findPlan, projectPath, filesOfPlan, snapshot, sha, atomicWrite, stages };
