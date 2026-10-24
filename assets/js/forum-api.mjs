export const categories=['general','builds','help','suggestions'];
export function validateConfig(config){
 const url=new URL(config.url);
 if(url.protocol!=='https:'||!url.hostname.endsWith('.supabase.co')||url.username||url.password||!config.key?.startsWith('sb_publishable_'))throw Error('Invalid public Supabase configuration');
 return config;
}
export function validateReply(value){
 const body=String(value).trim(); if(!body||body.length>10000)throw Error('Text: 1–10000 Zeichen / characters.'); return body;
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
  async login(email,password){return save(await request('/auth/v1/token?grant_type=password',{method:'POST',body:{email,password}}))},
  async signup(email,password,name){return save(await request('/auth/v1/signup',{method:'POST',body:{email,password,data:{display_name:name}}}))},
  async logout(){try{const current=await session();if(current)await request('/auth/v1/logout',{method:'POST',token:current.access_token})}finally{setSession(null)}}
 };
}
