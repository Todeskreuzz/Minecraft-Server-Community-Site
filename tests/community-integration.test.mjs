import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
const read=path=>fs.readFileSync(new URL('../'+path,import.meta.url),'utf8');
test('pack catalog uses pinned official files and distinguishes extras from mods',()=>{
 const pack=JSON.parse(read('assets/data/modpack.json')),config=JSON.parse(read('assets/data/config.json'));
 assert.equal(pack.entries.length,50);assert.equal(pack.entries.filter(x=>x.kind==='mod').length,39);
 assert.equal(new Set(pack.entries.map(x=>x.id)).size,50);
 for(const item of pack.entries){assert.match(item.fileUrl,/^https:\/\/www\.curseforge\.com\/minecraft\/(mc-mods|shaders|texture-packs)\/[a-z0-9-]+\/files\/\d+$/);assert.ok(item.fileUrl.endsWith('/'+item.fileId));assert.ok(item.description_de&&item.description_en)}
 assert.equal(config.modCount,39);assert.equal(config.modpack.downloadUrl,'assets/downloads/friends-and-foes.zip');
 assert.ok(pack.omitted.includes('overrides/mods/ColoredSigns.jar'));
});
test('anonymous action is outside the login form and makes no anonymous auth call',()=>{
 const html=read('index.html'),js=read('assets/js/forum.mjs');
 const form=html.slice(html.indexOf('<form id="authForm"'),html.indexOf('</form>',html.indexOf('<form id="authForm"')));
 assert.doesNotMatch(form,/anonymousButton/);
 assert.match(html,/<section id="anonymousSection"/);
 assert.doesNotMatch(js,/api\.signInAnonymously/);
});
test('profile editing is isolated from public profile and follows do not modify friendships',()=>{
 const html=read('index.html');
 const profile=html.slice(html.indexOf('<section id="profileView"'),html.indexOf('<section id="profileEditView"'));
 assert.doesNotMatch(profile,/<form/);assert.match(profile,/editProfileButton/);assert.match(profile,/showFollowers/);
 const sql=read('supabase/migrations/20261025001300_followers.sql');
 assert.doesNotMatch(sql,/insert into.*friendships|update.*forum_owner_names/i);
 assert.match(sql,/security invoker/);
});
test('removing profile media is staged until save, so Cancel can discard it',()=>{
 const js=read('assets/js/forum.mjs');
 const action=js.slice(js.indexOf("document.querySelectorAll('[data-clear-media]')"),js.indexOf("$('profileForm').onsubmit="));
 assert.doesNotMatch(action,/removeSlotFiles|api\.db/);
 assert.match(action,/pendingClears\.add/);
 assert.match(js,/\[\.\.\.pendingClears\]/);
});
test('launcher handler accepts a fixed URI and never uses shell evaluation or policy bypass',()=>{
 const launch=read('assets/launcher/Launch-FriendsAndFoes.ps1');
 assert.match(launch,/\^friendsandfoes:\/\/join\/\?\$/);
 assert.match(launch,/\$args\.Count -ne 0/);
 assert.match(launch,/& \$settings\.prism/);
 for(const file of ['Launch','Install','Uninstall'])assert.doesNotMatch(read('assets/launcher/'+file+'-FriendsAndFoes.ps1'),/Invoke-Expression|ExecutionPolicy|EncodedCommand/i);
});
