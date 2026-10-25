const JAR_HOSTS=['cdn.modrinth.com','github.com','objects.githubusercontent.com','mediafilez.forgecdn.net','edge.forgecdn.net','media.forgecdn.net'];
export function rolloutAdvice({players=0,kind='small',requested=''}={}){
 if(requested==='now'||requested==='delay'||requested==='scheduled')return requested;
 if(kind==='large')return 'scheduled';
 if(Number(players)>0)return 'delay';
 return 'now';
}
export function countdownLabel(startsAt,now=Date.now(),lang='de'){
 const ms=new Date(startsAt).getTime()-now;
 if(!Number.isFinite(ms))return '';
 if(ms<=0)return lang==='de'?'Der Neustart läuft.':'The restart is underway.';
 const minutes=Math.max(1,Math.ceil(ms/60000));
 return lang==='de'?`Neustart in ${minutes} Min.`:`Restart in ${minutes} min.`;
}
export function storageLine(bytes,limit){
 const used=Math.max(0,Number(bytes)||0);
 const cap=Number(limit)||1;
 const pct=Math.min(100,Math.round(used/cap*100));
 return {used,pct,label:Math.round(used/1048576)+' / '+Math.round(cap/1048576)+' MB'};
}
export function parseMods(text){
 return String(text||'').split('\n').map(line=>line.trim()).filter(Boolean).map(line=>{
  const match=line.match(/^(added|removed|updated)\s+(\S+)(?:\s+(\S+))?$/i);
  if(!match||match[2].length>64||(match[3]||'').length>32)throw Error('Invalid update');
  return {action:match[1].toLowerCase(),name:match[2],version:match[3]||''};
 });
}
export function parseJars(text){
 return String(text||'').split('\n').map(line=>line.trim()).filter(Boolean).map(line=>{
  const parts=line.split(/\s+/);
  if(parts.length!==3)throw Error('Invalid update');
  const [url,sha,file]=parts;
  let host='';
  try{host=new URL(url).host}catch{throw Error('Invalid update')}
  if(!url.startsWith('https://')||!JAR_HOSTS.includes(host)||!/^[a-f0-9]{64}$/.test(sha.toLowerCase())||!/^[A-Za-z0-9._-]{1,64}\.jar$/.test(file))throw Error('Invalid update');
  return {url,sha256:sha.toLowerCase(),file};
 });
}
