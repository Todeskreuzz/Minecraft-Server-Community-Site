import test from 'node:test';
import assert from 'node:assert/strict';
import {paintProfileShortcut} from '../assets/js/header-profile.mjs';

function shortcut(){const doc={createElement(){return {className:'',textContent:''}}};return {ownerDocument:doc,children:[],hidden:true,replaceChildren(...children){this.children=children},removeAttribute(key){delete this[key]}}}
test('own profile is a direct link with safe readable name and separate UID',()=>{
 const link=shortcut();paintProfileShortcut(link,{uid:1},'<Tim>','Mein Profil');
 assert.equal(link.href,'#u/01');assert.equal(link.hidden,false);
 assert.deepEqual(link.children.map(e=>e.textContent),['<Tim>','#01','Mein Profil']);
 assert.equal(link.children[0].innerHTML,undefined);
});
test('logout removes stale private name and own-profile destination',()=>{
 const link=shortcut();paintProfileShortcut(link,{uid:1},'Tim','Mein Profil');paintProfileShortcut(link,null,'','My profile');
 assert.equal(link.hidden,true);assert.equal(link.href,undefined);assert.equal(link.children.length,0);
});
