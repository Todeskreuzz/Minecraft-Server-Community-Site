import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {groupTag,minecraftName,safeCommandToken,teamColors} from '../assets/js/forum-groups.mjs';

test('group tags and minecraft names stay inside the bridge alphabet',()=>{
 assert.equal(groupTag('faf'),'FAF');
 assert.throws(()=>groupTag('no tag'));
 assert.equal(minecraftName(' Steve_1 '),'Steve_1');
 assert.equal(minecraftName(''),'');
 assert.throws(()=>minecraftName('no'));
 assert.equal(safeCommandToken('FAF'),'FAF');
 assert.throws(()=>safeCommandToken('FAF; say hi'));
 assert.ok(teamColors.includes('gold'));
 const sql=fs.readFileSync(new URL('../supabase/migrations/20261025000800_groups.sql',import.meta.url),'utf8');
 assert.match(sql,/player_groups/);
 assert.doesNotMatch(sql,/forum_groups/);
 assert.match(sql,/bridge_secret|set_bridge_secret/);
 assert.doesNotMatch(sql,/drop table|truncate/i);
});
