import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {formTooFast,honeypotTripped,MIN_FILL_MS} from '../assets/js/forum-spam.mjs';
import {createApi} from '../assets/js/forum-api.mjs';

test('honeypot and minimum fill time gate the composer',()=>{
 assert.equal(honeypotTripped(''),false);
 assert.equal(honeypotTripped('  '),false);
 assert.equal(honeypotTripped('https://spam.example'),true);
 assert.equal(formTooFast(Date.now()-MIN_FILL_MS,Date.now()),false);
 assert.equal(formTooFast(Date.now()-1000,Date.now()),true);
 assert.equal(formTooFast(0,Date.now()),true);
 const sql=fs.readFileSync(new URL('../supabase/migrations/20261025001100_spam.sql',import.meta.url),'utf8');
 const fn=fs.readFileSync(new URL('../supabase/functions/turnstile-post/index.ts',import.meta.url),'utf8');
 assert.match(sql,/Slow down/);
 assert.match(sql,/Please wait 30 seconds between topics/);
 assert.match(sql,/grant execute on function public.get_turnstile_secret\(\), private.get_turnstile_secret\(\) to service_role/);
 assert.doesNotMatch(sql,/drop table|truncate/i);
 assert.match(fn,/challenges\.cloudflare\.com\/turnstile\/v0\/siteverify/);
 assert.match(fn,/get_turnstile_secret/);
 assert.doesNotMatch(fn,/0x4AAAA|turnstile_secret_key\s*[:=]\s*['\"][^'\"]+/);
});

test('guarded post uses the edge function and falls back only when it is absent',async()=>{
 const config={url:'https://example.supabase.co',key:'sb_publishable_example'};
 let session={access_token:'user-token',expires_at:Math.floor(Date.now()/1000)+3600};
 const calls=[];
 const api=createApi(config,()=>session,value=>{session=value},async(url,options)=>{
  calls.push({url,body:options.body,auth:options.headers.Authorization});
  if(String(url).endsWith('/turnstile-post')&&calls.length===1)return new Response('',{status:404});
  return new Response(JSON.stringify({rows:[{id:'topic-1'}]}),{status:201,headers:{'Content-Type':'application/json'}});
 });
 const missing=await api.guardedPost({kind:'topic',captcha_token:'token',title:'Hallo',body:'Text',category_id:'general'});
 assert.equal(missing.fallback,true);
 const posted=await api.guardedPost({kind:'topic',captcha_token:'token',title:'Hallo',body:'Text',category_id:'general'});
 assert.equal(posted.rows[0].id,'topic-1');
 assert.equal(calls[1].auth,'Bearer user-token');
 assert.match(calls[1].body,/captcha_token/);
});
