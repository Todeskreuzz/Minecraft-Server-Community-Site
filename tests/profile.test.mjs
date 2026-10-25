import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {SHRINK_ERROR,fitSteps,imageKind,padUid,parseProfileHash,presetOk,previewLabel,profilePath,publicMediaUrl,webpHeaderHex} from '../assets/js/forum-profile.mjs';

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
