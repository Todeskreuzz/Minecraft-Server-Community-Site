import test from 'node:test';
import assert from 'node:assert/strict';
import {createApi, validateTopic, validateReply, validateConfig} from '../assets/js/forum-api.mjs';
test('accepts publishable config only',()=>{
 assert.throws(()=>validateConfig({url:'http://evil.test',key:'sb_secret_bad'}));
 assert.throws(()=>validateConfig({url:'https://example.supabase.co',key:'sb_secret_bad'}));
 assert.doesNotThrow(()=>validateConfig({url:'https://example.supabase.co',key:'sb_publishable_test'}));
});
test('validates topic/reply bounds and categories',()=>{
 assert.throws(()=>validateTopic(' ','hello','general'));
 assert.throws(()=>validateTopic('valid title','a','not-a-category'));
 assert.throws(()=>validateReply(' '.repeat(30)));
 assert.throws(()=>validateReply('x'.repeat(10001)));
 assert.deepEqual(validateTopic(' Hello world ',' Some text ','general'),{title:'Hello world',body:'Some text',category_id:'general'});
});
test('refreshes expiring session and authenticates database requests',async()=>{
 const calls=[]; let session={access_token:'old',refresh_token:'refresh',expires_at:1};
 const api=createApi({url:'https://example.supabase.co',key:'sb_publishable_test'},()=>session,s=>session=s,async(url,options)=>{
  calls.push({url,options}); return {ok:true,json:async()=>url.includes('grant_type=refresh_token')?{access_token:'new',refresh_token:'next',expires_in:3600}:{data:'ok'}};
 });
 await api.db('topics'); assert.equal(calls.length,2); assert.equal(calls[1].options.headers.Authorization,'Bearer new'); assert.equal(session.refresh_token,'next');
});
test('database errors are surfaced without exposing request credentials',async()=>{
 const api=createApi({url:'https://example.supabase.co',key:'sb_publishable_test'},()=>null,()=>{},async()=>({ok:false,status:403,json:async()=>({message:'permission denied'})}));
 await assert.rejects(api.db('owner_settings'),/permission denied/);
});
test('failed remote logout still clears the local identity',async()=>{
 let session={access_token:'token',refresh_token:'refresh',expires_at:Date.now()/1000+3600,user:{id:'owner'}};
 const api=createApi({url:'https://example.supabase.co',key:'sb_publishable_test'},()=>session,value=>session=value,async()=>{throw Error('Network unavailable')});
 await assert.rejects(api.logout(),/Network unavailable/);
 assert.equal(session,null);
});
