import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {categories} from '../assets/js/forum-api.mjs';
import {boundedText,crumbItems,fallbackIndex,sortTopics,structureId,structurePosition,syncCategories} from '../assets/js/forum-structure.mjs';

test('builds fallback groups without dropping known boards',()=>{
 const index=fallbackIndex(['general','custom-board']);
 assert.equal(index.groups[0].id,'community');
 assert.equal(index.boards[0].name_de,'Allgemeines');
 assert.equal(index.boards[1].id,'custom-board');
 assert.equal(fallbackIndex().boards.length,4);
});

test('syncs live board ids into the shared category list',()=>{
 const list=['general','builds','help','suggestions'];
 syncCategories(list,[]);
 assert.deepEqual(list,['general','builds','help','suggestions']);
 syncCategories(list,['general','events']);
 assert.deepEqual(list,['general','events']);
 assert.ok(categories.includes('general'));
});

test('sorts pinned threads ahead of newer replies',()=>{
 const rows=sortTopics([
  {id:'b',pinned:false,created_at:'2026-10-02T00:00:00Z'},
  {id:'a',pinned:true,created_at:'2026-10-01T00:00:00Z'},
  {id:'c',pinned:false,created_at:'2026-10-03T00:00:00Z'}
 ]);
 assert.deepEqual(rows.map(row=>row.id),['a','c','b']);
});

test('breadcrumbs end on the current page',()=>{
 const items=crumbItems({forumLabel:'Forum',group:{label:'Community'},board:{id:'general',label:'Allgemeines'},topic:{label:'Hallo'}});
 assert.equal(items[0].href,'#forum');
 assert.equal(items[2].href,'#board/general');
 assert.equal(items[3].href,undefined);
 assert.equal(items[3].label,'Hallo');
 const board=crumbItems({forumLabel:'Forum',group:{label:'Community'},board:{id:'general',label:'Allgemeines'}});
 assert.equal(board.at(-1).href,undefined);
});

test('rejects unsafe structure ids and keeps text bounds',()=>{
 assert.equal(structureId(' Events '), 'events');
 assert.throws(()=>structureId('nope!'));
 assert.equal(structurePosition('4'),4);
 assert.throws(()=>structurePosition('0'));
 assert.equal(boundedText('  Hallo  ',2,20),'Hallo');
 assert.equal(boundedText('   ',0,20),'');
});

test('structure migration is additive and preserves edited names',()=>{
 const sql=fs.readFileSync(new URL('../supabase/migrations/20261025000300_forum_structure.sql',import.meta.url),'utf8');
 assert.match(sql,/security_invoker=true/);
 assert.match(sql,/where c\.id=s\.id and c\.name_de is null/);
 assert.match(sql,/on delete restrict/);
 assert.match(sql,/forum_categories_group_fkey/);
 assert.match(sql,/alter column group_id set default 'community'/);
 assert.match(sql,/alter column name_de set default 'Board'/);
 assert.doesNotMatch(sql,/drop table/i);
 assert.doesNotMatch(sql,/truncate/i);
});
