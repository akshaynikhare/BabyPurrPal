#!/usr/bin/env node
// Installer paths and replacement values are data; no shell interpolation or eval.
const fs = require('fs'), path = require('path'), { spawnSync } = require('child_process');
const kit = path.resolve(__dirname, '..');
function main() {
  const opts = {}, argv = process.argv.slice(2);
  for (let i = 0; i < argv.length; i++) {
    const key = argv[i];
    if (['--target', '--code'].includes(key)) {
      if (!argv[i + 1] || argv[i + 1].startsWith('--')) throw Error(`${key} needs a value`);
      opts[key] = argv[++i];
    } else if (['--dry-run', '--doctor', '--with-e2e', '--force', '--help'].includes(key)) opts[key] = true;
    else throw Error(`Unknown flag: ${key}`);
  }
  if (opts['--help']) { console.log('Usage: ./install.sh --target <dir> --code <2-3 letters> [--dry-run] [--doctor] [--with-e2e] [--force]'); return; }
  if (opts['--doctor']) {
    const r = spawnSync('bash', [path.join(kit, 'scripts/check-chromium.sh')], { stdio: 'inherit' });
    process.exitCode = r.status ?? 1; return;
  }
  if (!opts['--target'] || !/^[A-Za-z]{2,3}$/.test(opts['--code'] || '')) throw Error('--target and a 2-3 letter --code are required');
  const target = path.resolve(opts['--target']), code = opts['--code'].toUpperCase();
  if (/[\x00-\x1f]/.test(target)) throw Error('Target path must not contain control characters');
  const version = fs.readFileSync(path.join(kit, '../VERSION'), 'utf8').trim();
  const dry = opts['--dry-run'], force = opts['--force'];
  const at = rel => path.join(target, rel), exists = rel => fs.existsSync(at(rel));
  const say = text => console.log(`[install] ${text}`);
  const write = (rel, content) => {
    say(`${dry ? 'DRY: ' : ''}write ${rel}`);
    if (!dry) { fs.mkdirSync(path.dirname(at(rel)), { recursive: true }); fs.writeFileSync(at(rel), content); }
  };
  const mkdir = rel => { if (!dry) fs.mkdirSync(at(rel), { recursive: true }); };
  const seed = (rel, content) => {
    if (!exists(rel)) write(rel, content);
    else if (!fs.readFileSync(at(rel)).equals(Buffer.from(content))) {
      if (rel.endsWith('DECISIONS.md') || rel.endsWith('baseline.json')) say(`kept ${rel}`);
      else if (force) write(rel, content);
      else { write(`${rel}.kit-new`, content); say(`kept ${rel} — review ${rel}.kit-new`); }
    }
  };
  const extraE2E = opts['--with-e2e'] && !exists('e2e');
  if (!dry && !force && !extraE2E && exists('.actionplan/VERSION') && fs.readFileSync(at('.actionplan/VERSION'), 'utf8').trim() === version) {
    say(`no changes — kit ${version} already installed. (--force to reinstall kit-owned files)`); return;
  }
  let pkg = {};
  if (exists('package.json')) pkg = JSON.parse(fs.readFileSync(at('package.json'), 'utf8'));
  let pm = 'TODO(verify)';
  for (const [file, manager] of [['pnpm-lock.yaml', 'pnpm'], ['yarn.lock', 'yarn'], ['bun.lockb', 'bun'], ['bun.lock', 'bun'], ['package-lock.json', 'npm']]) if (exists(file)) pm = manager;
  const command = name => pkg.scripts?.[name] ? `${pm === 'TODO(verify)' ? 'npm' : pm} run ${name}` : `echo 'TODO(verify): ${name} command'; exit 1`;
  let apps = Array.isArray(pkg.workspaces) ? pkg.workspaces : pkg.workspaces?.packages || [];
  if (exists('pnpm-workspace.yaml')) apps = [...fs.readFileSync(at('pnpm-workspace.yaml'), 'utf8').matchAll(/^\s*-\s*['"]?([^'"\n!]+)['"]?\s*$/gm)].map(m => m[1].trim());
  const values = { NAME: path.basename(target), CODE: code, DATE: new Date().toISOString().slice(0, 10) };
  const render = (text, more = {}) => text.replace(/\{\{([A-Z_]+)\}\}/g, (match, key) => ({ ...values, ...more })[key] ?? match);
  const read = rel => fs.readFileSync(path.join(kit, rel), 'utf8');
  const copyTree = (src, dst) => {
    for (const e of fs.readdirSync(path.join(kit, src), { withFileTypes: true })) {
      if (e.isDirectory()) copyTree(`${src}/${e.name}`, `${dst}/${e.name}`);
      else if (e.isFile()) write(`${dst}/${e.name}`, fs.readFileSync(path.join(kit, src, e.name)));
    }
  };
  say(`kit ${version} → ${target}${dry ? ' (preview; no files written)' : ''}`);
  for (const dir of ['planned', 'in-progress', 'archived', 'audit', 'qa', 'locks', 'trend']) mkdir(`.actionplan/${dir}`);
  write('.actionplan/AP.md', read('AP.md'));
  write('.actionplan/LICENSE', fs.readFileSync(path.join(kit, '../LICENSE')));
  for (const dir of ['scripts', 'templates', 'references', 'prompts']) copyTree(dir, `.actionplan/${dir}`);
  if (!dry) for (const file of fs.readdirSync(at('.actionplan/scripts')).filter(f => f.endsWith('.sh'))) fs.chmodSync(at(`.actionplan/scripts/${file}`), 0o755);
  if (!exists('.actionplan/config.json')) write('.actionplan/config.json', JSON.stringify({
    code, name: values.NAME, detected: values.DATE, packageManager: pm, apps,
    commands: Object.fromEntries(['dev', 'test', 'lint', 'typecheck'].map(k => [k, command(k)])),
    ports: {}, srcDirs: ['src'], lanes: { orchestrator: 'session', complex: 'opus', bulk: 'sonnet' }, lockStaleHours: 8, qaMaxRounds: 3,
  }, null, 2) + '\n');
  for (const name of ['BACKLOG', 'DECISIONS', 'PATTERNS', 'FROZEN']) seed(`.actionplan/${name}.md`, read(`templates/${name}.md`));
  for (const dir of ['_architecture', '_design', '_workflow']) mkdir(`docs/${dir}`);
  for (const name of ['SDLC', 'ENGINEERING_STANDARD', 'SEO_MARKETING', 'BRAND_IDENTITY', 'DESIGN_SYSTEM']) {
    const dir = ['BRAND_IDENTITY', 'DESIGN_SYSTEM'].includes(name) ? '_design' : '_workflow';
    seed(`docs/${dir}/${name}.md`, render(read(`templates/${name}.md`)));
  }
  if (!exists('Makefile')) write('Makefile', render(read('templates/Makefile'), {
    CMD_DEV: command('dev'), CMD_TEST: command('test') + (pkg.scripts?.test ? ' $(ARGS)' : ''), CMD_LINT: command('lint'), CMD_TYPECHECK: command('typecheck'),
  }));
  else say('kept Makefile — kit gates run via node .actionplan/scripts/check.cjs');
  copyTree('commands', '.claude/commands/ap'); copyTree('agents', '.claude/agents');
  seed('.mcp.json', read('mcp.json'));
  for (const rel of ['CLAUDE.md', 'AGENTS.md']) {
    const block = render(read('templates/claude-block.md'));
    const old = exists(rel) ? fs.readFileSync(at(rel), 'utf8') : '';
    const starts = [...old.matchAll(/<!-- actionplan-kit:start[^\n]*?-->/g)];
    const start = starts[0]?.[0] || '<!-- actionplan-kit:start -->', end = '<!-- actionplan-kit:end -->';
    if (old.includes('actionplan-kit:start') || old.includes('actionplan-kit:end')) {
      if (old.split(start).length !== 2 || old.split(end).length !== 2 || old.indexOf(end) < old.indexOf(start)) {
        write(`${rel}.kit-new`, block); say(`damaged markers in ${rel}; review ${rel}.kit-new`); continue;
      }
      write(rel, old.slice(0, old.indexOf(start)).trimEnd() + '\n\n' + block + old.slice(old.indexOf(end) + end.length));
    } else write(rel, old.trimEnd() + '\n\n' + block);
  }
  if (extraE2E) copyTree('e2e', 'e2e');
  if (!dry && !exists('.actionplan/scripts/gates/no-plan-refs.baseline.json')) {
    const r = spawnSync(process.execPath, [at('.actionplan/scripts/gates/no-plan-refs.cjs'), '--update', '--bootstrap', '--plan', 'install', '--root', target], { cwd: target, stdio: 'inherit' });
    if (r.status !== 0) throw Error('Baseline bootstrap failed; installation remains incomplete');
  }
  write('.actionplan/VERSION', version + '\n');
  say(dry ? 'preview complete — no files written' : 'done');
  console.log('Next: node .actionplan/scripts/check.cjs · /ap:init');
  if (opts['--with-e2e']) console.log('Optional browser setup (you run): cd e2e && npm install && npx playwright install chromium');
}
try { main(); } catch (err) { console.error(`[install] ${err.message}`); process.exitCode = 2; }
