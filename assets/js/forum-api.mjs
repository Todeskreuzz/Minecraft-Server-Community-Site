export const categories=['general','builds','help','suggestions'];
export function validateConfig(config){
 const url=new URL(config.url);
 if(url.protocol!=='https:'||!url.hostname.endsWith('.supabase.co')||url.username||url.password||!config.key?.startsWith('sb_publishable_'))throw Error('Invalid public Supabase configuration');
 return config;
}
export function validateReply(value){
 const body=String(value).trim(); if(!body||body.length>10000)throw Error('Text: 1–10000 Zeichen / characters.'); return body;
}
const authKeys=['access_token','expires_in','expires_at','refresh_token','token_type','type','provider_token','provider_refresh_token','error','error_code','error_description','code','message','sb'];
const confirmTypes=new Set(['signup','email','invite','email_change']);
export function authRedirect(href){
 const url=new URL(href);
 if(url.protocol!=='http:'&&url.protocol!=='https:')throw Error('Invalid redirect');
 return url.origin+url.pathname;
}
export function authReturn(href){
 const url=new URL(href);
 const hash=new URLSearchParams(url.hash.replace(/^#/,''));
 const has=key=>hash.has(key)||url.searchParams.has(key);
 const value=key=>hash.get(key)??url.searchParams.get(key);
 if(!['access_token','refresh_token','error','error_code','error_description','code','sb'].some(has)&&!confirmTypes.has(value('type')))return null;
 const error=Boolean(value('error')||value('error_code')||value('error_description'));
 const access=value('access_token'),refresh=value('refresh_token'),type=value('type')||'';
 const confirmation=confirmTypes.has(type)||has('code');
 const hashAuth=['access_token','refresh_token','error','error_code','error_description','code','sb','type','expires_in','expires_at','token_type','provider_token','provider_refresh_token'].some(key=>hash.has(key));
 const errorCode=value('error_code')||'',errorName=value('error')||'';
 for(const key of authKeys)url.searchParams.delete(key);
 if(hashAuth)url.hash='';
 return {href:url.origin+url.pathname+url.search+url.hash,type,error,errorCode,errorName,confirmation,session:!error&&access&&refresh?{access_token:access,refresh_token:refresh,expires_in:Number(value('expires_in'))||3600,token_type:value('token_type')||'bearer'}:null};
}
export function withCaptcha(body,captchaToken){
 if(!captchaToken)return body;
 return {...body,gotrue_meta_security:{captcha_token:captchaToken}};
}
export function repeatedSignup(data){
 const identities=data?.identities??data?.user?.identities;
 return Array.isArray(identities)&&identities.length===0;
}
export function validateTopic(title,body,category){
 title=String(title).trim(); if(title.length<3||title.length>120)throw Error('Titel / title: 3–120 Zeichen / characters.');
 if(!categories.includes(category))throw Error('Unbekannte Kategorie / unknown category.');
 return {title,body:validateReply(body),category_id:category};
}
export function createApi(config,getSession,setSession,fetcher=fetch){
 validateConfig(config);
 async function request(path,{method='GET',body,token}={}){
  const response=await fetcher(config.url+path,{method,headers:{apikey:config.key,...(token?{Authorization:'Bearer '+token}:{}),'Content-Type':'application/json',Prefer:'return=representation'},...(body!==undefined?{body:JSON.stringify(body)}:{}),signal:AbortSignal.timeout(20000)});
  const data=await response.json().catch(()=>null);
  if(!response.ok)throw Error(data?.msg||data?.message||data?.error_description||data?.error||`HTTP ${response.status}`);
  return data;
 }
 function save(data){if(data?.access_token){data.expires_at=Math.floor(Date.now()/1000)+(data.expires_in||3600);setSession(data)}return data}
 let refreshing;
 async function session(){
  let current=getSession();
  if(current&&current.expires_at<Date.now()/1000+60){
   if(!refreshing)refreshing=request('/auth/v1/token?grant_type=refresh_token',{method:'POST',body:{refresh_token:current.refresh_token}}).then(save).catch(()=>{setSession(null);throw Error('Bitte erneut anmelden / please sign in again.')}).finally(()=>{refreshing=null});
   current=await refreshing;
  }return current;
 }
 return {
  session,
  async db(path,options={}){const current=await session();return request('/rest/v1/'+path,{...options,token:current?.access_token})},
  async guardedPost(payload){const current=await session();if(!current?.access_token)throw Error('Bitte erneut anmelden / please sign in again.');const response=await fetcher(config.url+'/functions/v1/turnstile-post',{method:'POST',headers:{apikey:config.key,Authorization:'Bearer '+current.access_token,'Content-Type':'application/json'},body:JSON.stringify(payload),signal:AbortSignal.timeout(20000)});if(response.status===404)return {fallback:true};const data=await response.json().catch(()=>null);if(!response.ok)throw Error(data?.error||data?.message||`HTTP ${response.status}`);return data},
  async login(email,password,captchaToken){return save(await request('/auth/v1/token?grant_type=password',{method:'POST',body:withCaptcha({email,password},captchaToken)}))},
  async signup(email,password,name,href=globalThis.location?.href,captchaToken){return save(await request('/auth/v1/signup?redirect_to='+encodeURIComponent(authRedirect(href)),{method:'POST',body:withCaptcha({email,password,data:{display_name:name}},captchaToken)}))},
  async recover(email,href=globalThis.location?.href,captchaToken){return request('/auth/v1/recover?redirect_to='+encodeURIComponent(authRedirect(href)),{method:'POST',body:withCaptcha({email},captchaToken)})},
  async signInAnonymously(captchaToken){return save(await request('/auth/v1/signup',{method:'POST',body:withCaptcha({data:{}},captchaToken)}))},
  async useSession(tokens){const user=await request('/auth/v1/user',{token:tokens.access_token});if(!user?.id)throw Error('Bitte erneut anmelden / please sign in again.');return save({access_token:tokens.access_token,refresh_token:tokens.refresh_token,expires_in:Number(tokens.expires_in)||3600,token_type:tokens.token_type||'bearer',user})},
  async logout(){try{const current=await session();if(current)await request('/auth/v1/logout',{method:'POST',token:current.access_token})}finally{setSession(null)}},
  async upload(path,body,contentType='application/octet-stream'){const current=await session();if(!current?.access_token)throw Error('Bitte erneut anmelden / please sign in again.');const response=await fetcher(config.url+'/storage/v1/object/'+path,{method:'POST',headers:{apikey:config.key,Authorization:'Bearer '+current.access_token,'Content-Type':contentType,'x-upsert':'true'},body,signal:AbortSignal.timeout(20000)});const data=await response.json().catch(()=>null);if(!response.ok)throw Error(data?.message||data?.error||`HTTP ${response.status}`);return data},
  async removeObject(path){const current=await session();if(!current?.access_token)throw Error('Bitte erneut anmelden / please sign in again.');const response=await fetcher(config.url+'/storage/v1/object/'+path,{method:'DELETE',headers:{apikey:config.key,Authorization:'Bearer '+current.access_token},signal:AbortSignal.timeout(20000)});if(response.status===404)return null;const data=await response.json().catch(()=>null);if(!response.ok)throw Error(data?.message||data?.error||`HTTP ${response.status}`);return data}
 };
}
