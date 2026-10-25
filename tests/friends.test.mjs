import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {friendBuckets,isOnline,parseFriendUid} from '../assets/js/forum-friends.mjs';

test('reads a friend UID and ignores everything else',()=>{
 assert.equal(parseFriendUid('#07'),7);
 assert.equal(parseFriendUid('100'),100);
 assert.equal(parseFriendUid(''),null);
 assert.equal(parseFriendUid('#0'),null);
 assert.equal(parseFriendUid('abc'),null);
});

test('splits friends into requests and presence',()=>{
 const now=Date.parse('2026-10-25T12:00:00Z');
 const rows=[
  {id:'a',relation:'incoming'},
  {id:'b',relation:'outgoing'},
  {id:'c',relation:'accepted',last_seen:'2026-10-25T11:59:00Z'},
  {id:'d',relation:'accepted',last_seen:'2026-10-25T10:00:00Z'},
  {id:'e',relation:'blocked'}
 ];
 const buckets=friendBuckets(rows,now);
 assert.deepEqual(buckets.incoming.map(row=>row.id),['a']);
 assert.deepEqual(buckets.outgoing.map(row=>row.id),['b']);
 assert.deepEqual(buckets.online.map(row=>row.id),['c']);
 assert.deepEqual(buckets.offline.map(row=>row.id),['d']);
 assert.equal(isOnline('2026-10-25T11:58:00Z',now),true);
 assert.equal(isOnline(null,now),false);
 const sql=fs.readFileSync(new URL('../supabase/migrations/20261025000500_friends.sql',import.meta.url),'utf8');
 assert.match(sql,/copy_legacy_friends/);
 assert.match(sql,/status = 'accepted'/);
 assert.doesNotMatch(sql,/drop table|truncate/i);
 assert.match(sql,/private\.forum_friends/);
});
