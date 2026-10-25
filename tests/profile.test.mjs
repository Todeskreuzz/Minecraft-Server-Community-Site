import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {SHRINK_ERROR,avatarRank,displayRole,fitSteps,formatLocal,imageKind,padUid,parseInstant,parseProfileHash,presetOk,previewLabel,profileBadges,profilePath,publicMediaUrl,webpHeaderHex} from '../assets/js/forum-profile.mjs';

test('pads UIDs to at least two digits and keeps larger numbers',()=>{
 assert.equal(padUid(1),'01');
 assert.equal(padUid(10),'10');
 assert.equal(padUid(100),'100');
 assert.equal(profilePath(7),'#u/07');
 assert.throws(()=>padUid(0));
 assert.equal(parseProfileHash('#/u/01'),1);
 assert.equal(parseProfileHash('#u/100'),100);
 assert.equal(parseProfileHash('#forum'),null);
 assert.equal(parseProfileHash('#u/0'),null);
});

test('recognises image signatures and WebP headers',()=>{
 const png=Uint8Array.from([0x89,0x50,0x4e,0x47,0x0d,0x0a,0x1a,0x0a,0,0]);
 const jpeg=Uint8Array.from([0xff,0xd8,0xff,0xe0]);
 const webp=Uint8Array.from([0x52,0x49,0x46,0x46,0,0,0,0,0x57,0x45,0x42,0x50]);
 const svg=Uint8Array.from([0x3c,0x73,0x76,0x67]);
 assert.equal(imageKind(png),'png');
 assert.equal(imageKind(jpeg),'jpeg');
 assert.equal(imageKind(webp),'webp');
 assert.equal(imageKind(svg),'');
 assert.equal(webpHeaderHex(webp),'\\x524946460000000057454250');
 assert.throws(()=>webpHeaderHex(png));
});

test('image fit loop stays inside the requested bounds',()=>{
 const steps=fitSteps();
 assert.equal(steps.length,7);
 assert.equal(steps[0].quality,0.84);
 assert.equal(steps[0].scale,1);
 assert.ok(steps.every(step=>step.quality>=0.4&&step.quality<=0.84));
 assert.ok(steps[6].scale<steps[0].scale);
 assert.equal(SHRINK_ERROR,'Das Bild lässt sich nicht ausreichend verkleinern. Bitte ein kleineres Bild wählen.');
 assert.equal(previewLabel(262144),'256 KB · Metadaten entfernt');
 assert.equal(previewLabel(1),'1 KB · Metadaten entfernt');
 assert.equal(presetOk('grove'),true);
 assert.equal(presetOk('animated'),false);
 assert.equal(publicMediaUrl('https://example.supabase.co/','user/avatar.webp'),'https://example.supabase.co/storage/v1/object/public/profile-media/user/avatar.webp');
});

test('profile migration keeps UIDs and checks WebP before linking media',()=>{
 const sql=fs.readFileSync(new URL('../supabase/migrations/20261025000400_profiles.sql',import.meta.url),'utf8');
 assert.match(sql,/where uid is null/);
 assert.match(sql,/order by created_at, id/);
 assert.match(sql,/UID is permanent/);
 assert.match(sql,/security_invoker = true/);
 assert.match(sql,/52494646/);
 assert.match(sql,/57454250/);
 assert.match(sql,/262144/);
 assert.match(sql,/20971520/);
 assert.match(sql,/profile-media/);
 assert.doesNotMatch(sql,/drop table|truncate/i);
});

test('naive timestamps are UTC and profiles keep the date in the visitor zone',()=>{
 const instant=parseInstant('2026-10-24T17:52:00');
 assert.equal(instant.toISOString(),'2026-10-24T17:52:00.000Z');
 assert.equal(parseInstant('2026-10-24 17:52:29').toISOString(),'2026-10-24T17:52:29.000Z');
 assert.equal(parseInstant('2026-10-24T19:52:00+02:00').toISOString(),'2026-10-24T17:52:00.000Z');
 const berlin=instant.toLocaleString('de',{timeZone:'Europe/Berlin',hour:'2-digit',minute:'2-digit',hourCycle:'h23'});
 assert.match(berlin,/19:52/);
 const zoned=instant.toLocaleString('de',{dateStyle:'medium',timeStyle:'short'});
 assert.equal(formatLocal('2026-10-24T17:52:00','de',true),zoned);
 const dateOnly=formatLocal('2026-10-24T17:52:29.581655+00:00','de',false);
 assert.equal(dateOnly,instant.toLocaleDateString('de',{dateStyle:'medium'}));
 assert.equal(dateOnly.includes(':'),false);
 assert.equal(formatLocal('','de',false),'');
 assert.equal(formatLocal('not-a-date','en',true),'');
});

test('owner uid 1 keeps the owner mark and also earns Day One',()=>{
 const owner={role:'owner',is_owner:true,uid:1};
 assert.equal(displayRole(owner),'owner');
 assert.deepEqual(profileBadges(owner),['owner','dayone']);
 assert.equal(avatarRank(owner),'owner');
 assert.deepEqual(profileBadges({role:'dayone',uid:3}),['dayone']);
 assert.deepEqual(profileBadges({role:'member',uid:11}),[]);
 assert.equal(avatarRank({role:'member',uid:4}),'dayone');
 assert.equal(avatarRank({role:'member',uid:20}),'member');
 assert.equal(avatarRank({role:'admin',uid:2}),'admin');
});

test('profile markup uses the fallback banner, rank avatar, and stat cards',()=>{
 const html=fs.readFileSync(new URL('../index.html',import.meta.url),'utf8');
 const css=fs.readFileSync(new URL('../assets/css/forum.css',import.meta.url),'utf8');
 const js=fs.readFileSync(new URL('../assets/js/forum.mjs',import.meta.url),'utf8');
 assert.doesNotMatch(html,/id="profileScene"/);
 assert.match(html,/id="profileBanner" class="profile-banner preset-fallback"/);
 assert.match(html,/id="moreButton"/);
 assert.match(html,/class="nav-extra"/);
 assert.match(css,/\.profile-id \.avatar\{margin-top:-56px/);
 assert.doesNotMatch(js,/profileScene/);
 assert.match(html,/id="profileRanks"/);
 assert.match(html,/class="stat-card"/);
 assert.match(css,/\.preset-fallback\{/);
 assert.match(css,/\.avatar-default\.avatar-owner\{/);
 assert.match(js,/formatLocal\(card\.created_at,lang,false\)/);
 assert.match(js,/preset-'\+\(preset\|\|'fallback'\)/);
 assert.match(js,/noThreadsNote/);
 const reduced=css.lastIndexOf('@media(prefers-reduced-motion:reduce)');
 assert.ok(css.indexOf('.preset-fallback{')<reduced);
 assert.ok(css.trimEnd().endsWith('}'));
});
