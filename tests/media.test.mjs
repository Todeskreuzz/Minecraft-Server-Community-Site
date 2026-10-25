import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {embedsIn,mediaKindFromHeader,VIDEO_LINK_HINT,VIDEO_MAX_OUTPUT,VIDEO_MAX_SOURCE} from '../assets/js/forum-media.mjs';

test('thread links become click-to-load embeds',()=>{
 const found=embedsIn('Sieh https://youtu.be/dQw4w9wg und https://streamable.com/abc123 und https://medal.tv/games/minecraft/clips/MyClip');
 assert.deepEqual(found.map(item=>item.host),['youtube','streamable','medal']);
 assert.equal(found[0].src,'https://www.youtube-nocookie.com/embed/dQw4w9wg');
 assert.equal(found[1].src,'https://streamable.com/e/abc123');
 assert.equal(mediaKindFromHeader(Uint8Array.from([0x52,0x49,0x46,0x46,0,0,0,0,0x57,0x45,0x42,0x50])),'image');
 assert.equal(mediaKindFromHeader(Uint8Array.from([0x1a,0x45,0xdf,0xa3])),'video');
 assert.equal(VIDEO_MAX_SOURCE,100*1024*1024);
 assert.equal(VIDEO_MAX_OUTPUT,8*1024*1024);
 assert.match(VIDEO_LINK_HINT,/YouTube/);
 const sql=fs.readFileSync(new URL('../supabase/migrations/20261025000900_media.sql',import.meta.url),'utf8');
 assert.match(sql,/838860800/);
 assert.match(sql,/26214400/);
 assert.doesNotMatch(sql,/drop table|truncate/i);
});
