export const boardIcons=['message','grid','help','idea'];
export const seededGroup={id:'community',position:1,name_de:'Community',name_en:'Community',description_de:'Gespräche, Bauwerke, Fragen und Ideen.',description_en:'Conversations, builds, questions and ideas.'};
export const seededBoards=[
 {id:'general',position:1,group_id:'community',name_de:'Allgemeines',name_en:'General',description_de:'Vorstellen, Plaudern und alles rund um den Server.',description_en:'Introductions, chat and everything about the server.',icon:'message'},
 {id:'builds',position:2,group_id:'community',name_de:'Bauwerke & Projekte',name_en:'Builds & projects',description_de:'Zeigt eure Bauwerke und Projekte.',description_en:'Show your builds and projects.',icon:'grid'},
 {id:'help',position:3,group_id:'community',name_de:'Fragen & Hilfe',name_en:'Questions & help',description_de:'Fragen zur Technik, zum Modpack und zum Spiel.',description_en:'Questions about tech, the modpack and the game.',icon:'help'},
 {id:'suggestions',position:4,group_id:'community',name_de:'Ideen & Vorschläge',name_en:'Ideas & suggestions',description_de:'Ideen für den Server und die Community.',description_en:'Ideas for the server and the community.',icon:'idea'}
];
export function label(row,lang){if(!row)return '';return (lang==='en'?row.name_en:row.name_de)||row.name_de||row.name_en||row.id||''}
export function blurb(row,lang){if(!row)return '';return (lang==='en'?row.description_en:row.description_de)||''}
export function fallbackIndex(ids){
 const source=Array.isArray(ids)&&ids.length?ids:seededBoards.map(board=>board.id);
 const boards=source.map((id,index)=>{
  const known=seededBoards.find(board=>board.id===id);
  return known?{...known,thread_count:0,post_count:0}:{id,position:index+1,group_id:'community',name_de:id,name_en:id,description_de:'',description_en:'',icon:'message',thread_count:0,post_count:0};
 });
 return {groups:[{...seededGroup}],boards};
}
export function syncCategories(target,ids){
 const next=[...new Set((ids||[]).filter(id=>typeof id==='string'&&/^[a-z0-9-]{2,32}$/.test(id)))];
 if(!next.length)return target;
 target.splice(0,target.length,...next);
 return target;
}
export function sortTopics(rows){
 return [...rows].sort((a,b)=>{
  const pin=Number(Boolean(b.pinned))-Number(Boolean(a.pinned));
  if(pin)return pin;
  const time=new Date(b.created_at).getTime()-new Date(a.created_at).getTime();
  if(time)return time;
  return String(b.id).localeCompare(String(a.id));
 });
}
export function crumbItems({forumLabel,group,board,topic}){
 const items=[{label:forumLabel,href:'#forum'}];
 if(group?.label)items.push({label:group.label,href:'#forum'});
 if(board?.label)items.push({label:board.label,href:topic?'#board/'+board.id:undefined});
 if(topic?.label)items.push({label:topic.label});
 delete items[items.length-1].href;
 return items;
}
export function structureId(value){
 const id=String(value??'').trim().toLowerCase();
 if(!/^[a-z0-9-]{2,32}$/.test(id))throw Error('Kennung: 2–32 Zeichen (a–z, 0–9, -). / Slug: 2–32 characters (a–z, 0–9, -).');
 return id;
}
export function structurePosition(value){
 const position=Number(value);
 if(!Number.isInteger(position)||position<1||position>999)throw Error('Reihenfolge: 1–999. / Order: 1–999.');
 return position;
}
export function boundedText(value,min,max){
 const text=String(value??'').trim();
 if(text.length<min||text.length>max)throw Error('Text: '+min+'–'+max+' Zeichen / characters.');
 return text;
}
