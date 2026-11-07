// Source application is checked in a disposable repo, never this checkout.
import {mkdtempSync,mkdirSync,copyFileSync,readFileSync,writeFileSync,rmSync,readdirSync} from 'node:fs';
import {tmpdir} from 'node:os';
import {resolve,join,dirname} from 'node:path';
import {fileURLToPath} from 'node:url';
import {spawnSync} from 'node:child_process';
import assert from 'node:assert/strict';
import {SCENERY,PROPS,withDefaults} from '../js/scenery.js?v=65';
const ROOT=resolve(dirname(fileURLToPath(import.meta.url)),'..');
const temp=mkdtempSync(join(tmpdir(),'eeri-world-art-'));
let passed=0;
const check=(name,value)=>{assert.ok(value,name);console.log('  ok  '+name);passed++;};
try {
  for(const folder of ['js','dev','test','godot/tools'])mkdirSync(join(temp,folder),{recursive:true});
  for(const name of readdirSync(join(ROOT,'js')))if(name.endsWith('.js'))copyFileSync(join(ROOT,'js',name),join(temp,'js',name));
  for(const name of ['index.html','dev.html'])copyFileSync(join(ROOT,name),join(temp,name));
  copyFileSync(join(ROOT,'dev/inspector.js'),join(temp,'dev/inspector.js'));
  for(const name of ['apply-scenery.mjs','export-scenery.mjs'])copyFileSync(join(ROOT,'godot/tools',name),join(temp,'godot/tools',name));
  const original=readFileSync(join(temp,'js/scenery.js'),'utf8');
  const sceneryVersion=Number(/scenery\.js\?v=(\d+)/.exec(readFileSync(join(ROOT,'js/layers.js'),'utf8'))[1]);
  const source=SCENERY.grove.map(row=>({...withDefaults(row),layer:row.layer||PROPS[row.prop]?.layer||'play'}));
  const rows=[...source,{prop:'treeSpruce',x:5.5,y:4,z:-14,layer:'far',h:3.2,o:0.42,flip:true}];
  const input=join(temp,'draft.json');
  const fixture={world:'grove',source_scenery:source,scenery:rows};
  writeFileSync(input,JSON.stringify(fixture));
  const run=(...args)=>spawnSync(process.execPath,[join(temp,'godot/tools/apply-scenery.mjs'),input,...args],{encoding:'utf8'});
  let result=run();
  check('review describes the three-level world change',result.status===0 && JSON.parse(result.stdout).changed);
  check('review does not write the source',readFileSync(join(temp,'js/scenery.js'),'utf8')===original);
  result=run('--write');
  check('apply succeeds',result.status===0 || (console.log(result.stderr),false));
  const data=JSON.parse(readFileSync(join(temp,'godot/data/scenery.json'),'utf8'));
  check('the canonical source regenerates the added art for Godot',data.worlds.grove.length===source.length+1);
  assert.deepEqual(data.worlds.grove.at(-1),rows.at(-1));passed++;
  const other=SCENERY.groundworks.map(row=>({...withDefaults(row),layer:row.layer||PROPS[row.prop]?.layer||'play'}));
  check('unrelated world placements are preserved',JSON.stringify(data.worlds.groundworks)===JSON.stringify(other));
  const edited=readFileSync(join(temp,'js/scenery.js'),'utf8');
  result=run('--write');
  check('applying the same draft twice is harmless',result.status===0 && !JSON.parse(result.stdout).changed
    && readFileSync(join(temp,'js/scenery.js'),'utf8')===edited);
  fixture.scenery=[...rows.slice(0,-1),{...rows.at(-1),x:9}];
  writeFileSync(input,JSON.stringify(fixture));
  result=run('--write');
  check('a stale draft cannot overwrite newer source',result.status!==0 && result.stderr.includes('changed since'));
  check('rejecting a stale draft leaves source intact',readFileSync(join(temp,'js/scenery.js'),'utf8')===edited);
  fixture.source_scenery=data.worlds.grove;
  fixture.scenery=[{prop:'missing-art',x:1}];writeFileSync(input,JSON.stringify(fixture));
  result=run('--write');check('unknown art is rejected before writing',result.status!==0 && result.stderr.includes('Unknown art'));
  const references=new Map();
  for(const folder of ['js','dev'])for(const name of readdirSync(join(temp,folder))) {
    const file=join(temp,folder,name);if(!name.endsWith('.js'))continue;
    const text=readFileSync(file,'utf8');
    for(const m of text.matchAll(/(['"])((?:\.\.?\/)[^'"\s]+\.js)\?v=(\d+)\1/g)) {
      const target=resolve(dirname(file),m[2]);
      if(!references.has(target))references.set(target,new Set());
      references.get(target).add(m[3]);
    }
  }
  check('cache updates leave one URL token per imported module',[...references.values()].every(set=>set.size===1));
  check('the changed scenery module gets a fresh URL',references.get(join(temp,'js/scenery.js')).has(String(sceneryVersion+1)));
  console.log(`\n${passed} passed, 0 failed`);
} finally {rmSync(temp,{recursive:true,force:true});}
