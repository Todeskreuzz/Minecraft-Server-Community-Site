import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {animatedKind,presetOk,slotObject} from '../assets/js/forum-profile.mjs';

test('day one migration keeps early UIDs and checks animation bytes',()=>{
 const sql=fs.readFileSync(new URL('../supabase/migrations/20261025000700_dayone.sql',import.meta.url),'utf8');
 assert.match(sql,/p\.uid <= 10/);
 assert.match(sql,/Day One only/);
 assert.match(sql,/2097152/);
 assert.match(sql,/aurora/);
 assert.doesNotMatch(sql,/drop table|truncate/i);
});

test('recognises GIF89a and animated WebP without treating a still as motion',()=>{
 const gif=Uint8Array.from([0x47,0x49,0x46,0x38,0x39,0x61,0,0]);
 const anim=Uint8Array.from([
  0x52,0x49,0x46,0x46,0,0,0,0,0x57,0x45,0x42,0x50,
  0x56,0x50,0x38,0x58,0x0a,0,0,0,0x02
 ]);
 const still=Uint8Array.from([0x52,0x49,0x46,0x46,0,0,0,0,0x57,0x45,0x42,0x50]);
 assert.equal(animatedKind(gif),'gif');
 assert.equal(animatedKind(anim),'anim');
 assert.equal(animatedKind(still),'');
 assert.equal(slotObject('avatar','gif'),'avatar.gif');
 assert.equal(slotObject('banner','anim'),'banner.anim.webp');
 assert.equal(slotObject('background',''),'background.webp');
 assert.equal(presetOk('aurora'),true);
 assert.equal(presetOk('voxels'),true);
 assert.equal(presetOk('motion'),false);
});
