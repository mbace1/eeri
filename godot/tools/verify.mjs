#!/usr/bin/env node
// Verify the generated seam and every runtime/editor test scene in one run.
// The report records dirty files so a local check cannot impersonate a release.
import {mkdirSync, readdirSync, readFileSync, writeFileSync} from 'node:fs';
import {resolve, dirname, join} from 'node:path';
import {fileURLToPath} from 'node:url';
import {spawnSync} from 'node:child_process';

const root = resolve(dirname(fileURLToPath(import.meta.url)), '../..');
const godot = process.env.GODOT || 'godot';
const git = (...args) => {
  const result = spawnSync('git', args, {cwd:root, encoding:'utf8'});
  if (result.status !== 0) throw new Error(result.stderr || 'Git metadata unavailable');
  return result.stdout.trim();
};
const report = {
  source:git('rev-parse','HEAD'),
  tree:git('rev-parse','HEAD^{tree}'),
  version:/^## (v\S+)/m.exec(readFileSync(join(root,'VERSIONS.md'),'utf8'))?.[1],
  dirty:git('status','--porcelain'),
  engine:'', started:new Date().toISOString(), checks:[], passed:false,
};
const run = (name, command, args, timeout=120000) => {
  const result = spawnSync(command,args,{cwd:root,encoding:'utf8',timeout});
  const output = (result.stdout || '') + (result.stderr || '');
  // Godot 4.6 emits this shutdown-only resource warning in existing suites.
  // Keep it in the report; script/runtime/import errors still fail.
  const errors = output.replace(/^ERROR: \d+ resources? still in use at exit \(run with --verbose for details\)\.\n\s+at: .*\n?/gm,'');
  const passed = result.status === 0 && !result.error && !/SCRIPT ERROR|^ERROR:/m.test(errors);
  report.checks.push({name,passed,status:result.status,output});
  console.log(`${passed ? 'ok' : 'FAIL'}  ${name}`);
  if (!passed) throw new Error(output.slice(-8000) || String(result.error));
  return output;
};
try {
  report.engine = run('engine version',godot,['--version']).trim();
  for (const name of ['sync-data','export-levels','export-locale','export-glyphs',
    'export-audio','export-scenery','export-palette']) {
    run(name,process.execPath,[`godot/tools/${name}.mjs`,'--check']);
  }
  run('resource import',godot,['--headless','--path','godot','--import']);
  for (const name of readdirSync(join(root,'godot/tests')).sort()) {
    if (/^test_.*\.tscn$/.test(name)) {
      run(name,godot,['--headless','--path','godot',`res://tests/${name}`]);
    }
  }
  run('canonical scenery application',process.execPath,['test/scenery-apply.mjs']);
  if (git('status','--porcelain') !== report.dirty) throw new Error('Source changed during verification; rerun on the final tree.');
  report.passed = true;
} catch (error) {
  console.error(error.message);
  process.exitCode = 1;
} finally {
  report.finished = new Date().toISOString();
  mkdirSync(join(root,'build'),{recursive:true});
  writeFileSync(join(root,'build/verification.json'),JSON.stringify(report,null,2)+'\n');
  console.log('Report: build/verification.json');
  if (report.dirty) console.log('Local working tree has changes; this report is not a clean release record.');
}
