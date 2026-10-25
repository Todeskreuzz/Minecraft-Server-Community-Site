import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {countdownLabel,parseJars,parseMods,rolloutAdvice,storageLine} from '../assets/js/forum-updates.mjs';

test('rollout advice follows players and update size',()=>{
 assert.equal(rolloutAdvice({players:0,kind:'small'}),'now');
 assert.equal(rolloutAdvice({players:3,kind:'small'}),'delay');
 assert.equal(rolloutAdvice({players:0,kind:'large'}),'scheduled');
 assert.equal(rolloutAdvice({players:4,kind:'large'}),'scheduled');
 assert.equal(rolloutAdvice({players:0,kind:'small',requested:'delay'}),'delay');
 assert.equal(countdownLabel(Date.now()+120000,Date.now(),'de'),'Neustart in 2 Min.');
 assert.equal(countdownLabel(Date.now()-1000,Date.now(),'de'),'Der Neustart läuft.');
 assert.equal(storageLine(5242880,524288000).label,'5 / 500 MB');
 assert.deepEqual(parseMods('added Example 1.2\nremoved OldMod'),[{action:'added',name:'Example',version:'1.2'},{action:'removed',name:'OldMod',version:''}]);
 assert.equal(parseJars('https://cdn.modrinth.com/data/example/versions/example.jar aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa example.jar')[0].file,'example.jar');
 assert.throws(()=>parseJars('https://evil.example/a.jar bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb a.jar'),/Invalid update/);
 const sql=fs.readFileSync(new URL('../supabase/migrations/20261025001000_updates.sql',import.meta.url),'utf8');
 assert.match(sql,/forum_is_admin/);
 assert.match(sql,/bridge_report/);
 assert.doesNotMatch(sql,/drop table|truncate/i);
});
