import test from 'node:test';
import assert from 'node:assert/strict';
import {filterMods,launchUri,modPath,readOnlySession,stepNumber} from '../assets/js/community.mjs';

test('temporary anonymous mode never creates a backend identity',()=>{
 const values=new Map([['faf-session','old']]);
 const storage={setItem:(k,v)=>values.set(k,v),removeItem:k=>values.delete(k)};
 assert.equal(readOnlySession(storage),null);
 assert.equal(values.has('faf-session'),false);
 assert.equal(values.get('faf-anonymous'),'1');
});
test('mod search and paths handle names safely',()=>{
 const mods=[{id:'create',name:'Create',author:'simibubi'},{id:'alexs-mobs',name:"Alex’s Mobs",author:'sbom_xela'}];
 assert.deepEqual(filterMods(mods,'SIMIBUBI'),[mods[0]]);
 assert.equal(filterMods(mods,'none').length,0);
 assert.equal(modPath('create'),'#mod/create');
 assert.throws(()=>modPath('../bad'));
});
test('direct start exposes only one fixed action and no untrusted parameters',()=>{
 assert.equal(launchUri('play.example.net:25565'),'friendsandfoes://join');
 for(const value of ['', 'localhost', 'example.net & calc', 'https://example.net','example.net:99999'])assert.equal(launchUri(value),'');
});
test('wizard bounds and resets invalid stored progress',()=>{
 assert.equal(stepNumber(-1),0);assert.equal(stepNumber(99),3);assert.equal(stepNumber('bad'),0);
});
