import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';

test('role migration keeps a single fixed owner and lets moderators pin',()=>{
 const sql=fs.readFileSync(new URL('../supabase/migrations/20261025000600_roles.sql',import.meta.url),'utf8');
 assert.match(sql,/Owner is fixed/);
 assert.match(sql,/forum_can_moderate/);
 assert.match(sql,/order by p\.uid/);
 assert.match(sql,/role in \('owner','admin','moderator','dayone','member'\)/);
 assert.doesNotMatch(sql,/drop table|truncate/i);
});
