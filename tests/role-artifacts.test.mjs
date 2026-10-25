import test from 'node:test';
import assert from 'node:assert/strict';
import {artifactMarkup,effectsEnabled,createRankBadge,initRoleEffects} from '../assets/js/role-artifacts.mjs';

test('four roles have distinct local SVG artifacts and neutral members have none',()=>{
 const roles=['owner','dayone','admin','moderator'];
 assert.equal(new Set(roles.map(artifactMarkup)).size,4);
 for(const role of roles){const svg=artifactMarkup(role);assert.match(svg,/<svg/);assert.match(svg,/aria-hidden="true"/);assert.doesNotMatch(svg,/<script|https?:|<image/);}
 assert.equal(artifactMarkup('member'),'');assert.equal(artifactMarkup('<img>'),'');
});

test('motion controller handles visibility, reduced motion, persistence and removed badges',()=>{
 const originals=new Map(['document','matchMedia','localStorage','IntersectionObserver','MutationObserver','window'].map(key=>[key,Object.getOwnPropertyDescriptor(globalThis,key)]));
 const callbacks={},mutations=[];let saved=null,mediaCallback,intersectionCallback,unobserved=false;
 const badge={isConnected:true,classList:{toggle(name,value){this[name]=value},add(name){this[name]=true}}};
 const root={dataset:{},lang:'en'},button={setAttribute(key,value){this[key]=value}};
 const media={matches:false,addEventListener(type,callback){mediaCallback=callback}};
 try{
  globalThis.document={documentElement:root,body:{},hidden:false,querySelectorAll(){return badge.isConnected?[badge]:[]},addEventListener(type,fn){callbacks[type]=fn}};
  globalThis.matchMedia=()=>media;globalThis.localStorage={getItem(){return saved},setItem(key,value){saved=value}};
  globalThis.IntersectionObserver=class{constructor(fn){intersectionCallback=fn}observe(){}unobserve(){unobserved=true}};
  globalThis.MutationObserver=class{constructor(fn){mutations.push(fn)}observe(){}};
  globalThis.window={addEventListener(type,fn){callbacks[type]=fn}};
  initRoleEffects(button);assert.equal(root.dataset.roleEffects,'on');
  intersectionCallback([{target:badge,isIntersecting:false}]);assert.equal(badge.classList['rank-visible'],false);
  intersectionCallback([{target:badge,isIntersecting:true}]);assert.equal(badge.classList['rank-visible'],true);
  button.onclick();assert.equal(saved,'off');assert.equal(root.dataset.roleEffects,'off');
  button.onclick();media.matches=true;mediaCallback();assert.equal(root.dataset.roleEffects,'off');
  document.hidden=true;callbacks.visibilitychange();assert.equal(root.dataset.roleHidden,'true');
  badge.isConnected=false;mutations[0]();assert.equal(unobserved,true);
 }finally{for(const [key,descriptor] of originals)if(descriptor)Object.defineProperty(globalThis,key,descriptor);else delete globalThis[key]}
});
test('reduced motion overrides enabled storage and pause persists explicitly',()=>{
 assert.equal(effectsEnabled(null,false),true);assert.equal(effectsEnabled('off',false),false);
 assert.equal(effectsEnabled('on',true),false);assert.equal(effectsEnabled(null,true),false);
});
test('badge label stays text, decoration is separate and has no tab stop',()=>{
 const doc={createElement(tag){return {tag,children:[],dataset:{},setAttribute(k,v){this[k]=v},append(...children){this.children.push(...children)}}}};
 const badge=createRankBadge('owner','<Inhaber>',doc);
 assert.equal(badge.children.at(-1).textContent,'<Inhaber>');assert.equal(badge.children[0]['aria-hidden'],'true');
 assert.equal(badge.tabIndex,undefined);assert.equal(badge.children.at(-1).className,'rank-label');
});
