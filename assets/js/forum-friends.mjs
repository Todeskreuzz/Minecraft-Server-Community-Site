export function parseFriendUid(value){
 const digits=String(value||'').trim().replace(/^#/,'');
 if(!/^\d{1,9}$/.test(digits))return null;
 const uid=Number(digits);
 return Number.isSafeInteger(uid)&&uid>=1?uid:null;
}
export function isOnline(lastSeen,now=Date.now()){
 const then=new Date(lastSeen).getTime();
 return Number.isFinite(then)&&now-then<180000;
}
export function friendBuckets(rows,now=Date.now()){
 const incoming=[],outgoing=[],online=[],offline=[],blocked=[];
 for(const row of rows||[]){
  if(row.relation==='incoming')incoming.push(row);
  else if(row.relation==='outgoing')outgoing.push(row);
  else if(row.relation==='blocked')blocked.push(row);
  else if(isOnline(row.last_seen,now))online.push(row);
  else offline.push(row);
 }
 return {incoming,outgoing,online,offline,blocked};
}
