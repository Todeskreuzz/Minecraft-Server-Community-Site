import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {createApi, validateTopic, validateReply, validateConfig, authRedirect, authReturn, repeatedSignup, withCaptcha} from '../assets/js/forum-api.mjs';
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
test('signup passes redirect_to from the current page location',async()=>{
 const calls=[];
 const api=createApi({url:'https://example.supabase.co',key:'sb_publishable_test'},()=>null,()=>{},async(url,options)=>{calls.push({url,body:options.body});return {ok:true,json:async()=>({})}});
 await api.signup('ada@example.com','longpassword','Ada','https://todeskreuzz.github.io/Minecraft-Server-Community-Site/?lost=1#forum');
 await api.signup('ann@example.com','longpassword','Ann','http://127.0.0.1:8018/index.html#play');
 assert.equal(authRedirect('https://todeskreuzz.github.io/Minecraft-Server-Community-Site/#topic/abc'),'https://todeskreuzz.github.io/Minecraft-Server-Community-Site/');
 assert.equal(new URL(calls[0].url).searchParams.get('redirect_to'),'https://todeskreuzz.github.io/Minecraft-Server-Community-Site/');
 assert.equal(new URL(calls[1].url).searchParams.get('redirect_to'),'http://127.0.0.1:8018/index.html');
 assert.equal(JSON.parse(calls[0].body).data.display_name,'Ada');
 assert.equal(JSON.parse(calls[0].body).redirect_to,undefined);
 assert.throws(()=>authRedirect('javascript:alert(1)'));
});
test('auth return strips token and error params without dropping the site path',()=>{
 const ok=authReturn('https://todeskreuzz.github.io/Minecraft-Server-Community-Site/#access_token=aaa&expires_in=3600&refresh_token=bbb&token_type=bearer&type=signup');
 assert.equal(ok.href,'https://todeskreuzz.github.io/Minecraft-Server-Community-Site/');
 assert.deepEqual(ok.session,{access_token:'aaa',refresh_token:'bbb',expires_in:3600,token_type:'bearer'});
 assert.equal(ok.confirmation,true); assert.equal(ok.error,false);
 const bad=authReturn('https://todeskreuzz.github.io/Minecraft-Server-Community-Site/?next=1&error=access_denied&error_code=otp_expired&error_description=Email+link+is+invalid#forum');
 assert.equal(bad.href,'https://todeskreuzz.github.io/Minecraft-Server-Community-Site/?next=1#forum');
 assert.equal(bad.session,null); assert.equal(bad.error,true); assert.equal(bad.errorCode,'otp_expired'); assert.equal(bad.errorName,'access_denied');
 const hashExpired=authReturn('https://todeskreuzz.github.io/Minecraft-Server-Community-Site/#error=access_denied&error_code=otp_expired&error_description=Email+link+is+invalid+or+has+expired');
 assert.equal(hashExpired.href,'https://todeskreuzz.github.io/Minecraft-Server-Community-Site/');
 assert.equal(hashExpired.error,true); assert.equal(hashExpired.errorCode,'otp_expired'); assert.equal(hashExpired.errorName,'access_denied'); assert.equal(hashExpired.session,null);
 const queryExpired=authReturn('http://127.0.0.1:8018/?error=access_denied&error_code=otp_expired');
 assert.equal(queryExpired.href,'http://127.0.0.1:8018/'); assert.equal(queryExpired.errorCode,'otp_expired'); assert.equal(queryExpired.error,true);
 const both=authReturn('https://todeskreuzz.github.io/Minecraft-Server-Community-Site/#access_token=aaa&refresh_token=bbb&error=access_denied&type=signup');
 assert.equal(both.session,null); assert.equal(both.error,true); assert.equal(both.href.includes('access_token'),false);
 const code=authReturn('http://127.0.0.1:8018/?code=abc123');
 assert.equal(code.href,'http://127.0.0.1:8018/'); assert.equal(code.confirmation,true); assert.equal(code.session,null);
 assert.equal(authReturn('http://127.0.0.1:8018/#forum'),null);
 assert.equal(authReturn('http://127.0.0.1:8018/#topic/11111111-1111-1111-1111-111111111111'),null);
});
test('repeated signup is an empty identities list and is not stored as a session',async()=>{
 assert.equal(repeatedSignup({id:'user-1',email:'ada@example.com',identities:[]}),true);
 assert.equal(repeatedSignup({user:{identities:[]}}),true);
 assert.equal(repeatedSignup({id:'user-1',identities:[{identity_id:'id-1',provider:'email'}]}),false);
 assert.equal(repeatedSignup({access_token:'token',user:{identities:[{provider:'email'}]}}),false);
 assert.equal(repeatedSignup({}),false);
 const calls=[];
 const api=createApi({url:'https://example.supabase.co',key:'sb_publishable_test'},()=>null,()=>{throw Error('session must stay empty')},async(url,options)=>{calls.push({url,body:options.body});return {ok:true,json:async()=>({id:'user-1',email:'ada@example.com',identities:[]})}});
 const result=await api.signup('ada@example.com','longpassword','Ada','http://127.0.0.1:8018/');
 assert.equal(repeatedSignup(result),true);
 assert.equal(result.access_token,undefined);
 assert.equal(JSON.parse(calls[0].body).email,'ada@example.com');
});
test('confirmation tokens load the user and become the session',async()=>{
 let session=null; const calls=[];
 const api=createApi({url:'https://example.supabase.co',key:'sb_publishable_test'},()=>session,value=>session=value,async(url,options)=>{calls.push({url,authorization:options.headers.Authorization});return {ok:true,json:async()=>({id:'user-1',email:'ada@example.com',is_anonymous:false})}});
 const result=await api.useSession({access_token:'aaa',refresh_token:'bbb',expires_in:3600,token_type:'bearer'});
 assert.equal(calls[0].url,'https://example.supabase.co/auth/v1/user');
 assert.equal(calls[0].authorization,'Bearer aaa');
 assert.equal(result.user.id,'user-1'); assert.equal(session.refresh_token,'bbb'); assert.equal(session.user.is_anonymous,false);
});
test('auth requests carry a Turnstile token and omit it when absent',async()=>{
 const config=JSON.parse(fs.readFileSync(new URL('../assets/data/config.json',import.meta.url),'utf8'));
 assert.equal(config.security.turnstileSiteKey,'0x4AAAAAAFktyAS3q220b4E7');
 assert.deepEqual(withCaptcha({email:'a@b.c'},''),{email:'a@b.c'});
 assert.deepEqual(withCaptcha({email:'a@b.c'},'tok'),{email:'a@b.c',gotrue_meta_security:{captcha_token:'tok'}});
 const calls=[];
 const api=createApi({url:'https://example.supabase.co',key:'sb_publishable_test'},()=>null,()=>{},async(url,options)=>{calls.push({url,body:JSON.parse(options.body)});return {ok:true,json:async()=>({access_token:'aaa',refresh_token:'bbb',expires_in:3600})}});
 await api.login('ada@example.com','longpassword','tok-login');
 await api.signup('ada@example.com','longpassword','Ada','https://todeskreuzz.github.io/Minecraft-Server-Community-Site/','tok-signup');
 await api.recover('ada@example.com','https://todeskreuzz.github.io/Minecraft-Server-Community-Site/#forum','tok-reset');
 await api.signInAnonymously('tok-anon');
 assert.equal(calls[0].body.gotrue_meta_security.captcha_token,'tok-login');
 assert.equal(calls[0].body.password,'longpassword');
 assert.equal(calls[1].body.gotrue_meta_security.captcha_token,'tok-signup');
 assert.equal(calls[1].body.data.display_name,'Ada');
 assert.equal(new URL(calls[2].url).pathname.endsWith('/auth/v1/recover'),true);
 assert.equal(calls[2].body.gotrue_meta_security.captcha_token,'tok-reset');
 assert.equal(calls[2].body.email,'ada@example.com');
 assert.deepEqual(calls[3].body,{data:{},gotrue_meta_security:{captcha_token:'tok-anon'}});
 const plain=createApi({url:'https://example.supabase.co',key:'sb_publishable_test'},()=>null,()=>{},async(url,options)=>{calls.push({url,body:JSON.parse(options.body)});return {ok:true,json:async()=>({})}});
 await plain.login('ada@example.com','longpassword');
 assert.equal(calls[4].body.gotrue_meta_security,undefined);
});
test('failed remote logout still clears the local identity',async()=>{
 let session={access_token:'token',refresh_token:'refresh',expires_at:Date.now()/1000+3600,user:{id:'owner'}};
 const api=createApi({url:'https://example.supabase.co',key:'sb_publishable_test'},()=>session,value=>session=value,async()=>{throw Error('Network unavailable')});
 await assert.rejects(api.logout(),/Network unavailable/);
 assert.equal(session,null);
});
