export const SHRINK_ERROR='Das Bild lässt sich nicht ausreichend verkleinern. Bitte ein kleineres Bild wählen.';
export const mediaSlots={avatar:256,banner:1500,background:1600};
export const presets=[
 {id:'',de:'Kein Motiv',en:'No motif'},
 {id:'grove',de:'Hain',en:'Grove'},
 {id:'deepslate',de:'Tiefenschiefer',en:'Deepslate'},
 {id:'campfire',de:'Lagerfeuer',en:'Campfire'},
 {id:'nether',de:'Nether',en:'Nether'},
 {id:'end',de:'Ende',en:'The End'}
];
const presetIds=new Set(presets.map(preset=>preset.id));
export function padUid(uid){
 const value=Number(uid);
 if(!Number.isSafeInteger(value)||value<1)throw Error('Invalid UID');
 return String(value).padStart(2,'0');
}
export function profilePath(uid){return '#u/'+padUid(uid)}
export function parseProfileHash(hash){
 const parts=String(hash||'').replace(/^#/,'').split('/').filter(Boolean);
 if(parts[0]!=='u'||!/^\d{1,9}$/.test(parts[1]||''))return null;
 const uid=Number(parts[1]);
 return Number.isSafeInteger(uid)&&uid>=1?uid:null;
}
export function presetOk(id){return presetIds.has(id)}
export function publicMediaUrl(base,path){
 if(!base||!path)return '';
 return String(base).replace(/\/$/,'')+'/storage/v1/object/public/profile-media/'+String(path).split('/').map(encodeURIComponent).join('/');
}
export function previewLabel(bytes){
 const kb=Math.max(1,Math.round(Number(bytes)/1024));
 return kb+' KB · Metadaten entfernt';
}
export function imageKind(bytes){
 const u=bytes instanceof Uint8Array?bytes:new Uint8Array(bytes||[]);
 if(u.length>=8&&u[0]===0x89&&u[1]===0x50&&u[2]===0x4e&&u[3]===0x47&&u[4]===0x0d&&u[5]===0x0a&&u[6]===0x1a&&u[7]===0x0a)return 'png';
 if(u.length>=3&&u[0]===0xff&&u[1]===0xd8&&u[2]===0xff)return 'jpeg';
 if(u.length>=12&&u[0]===0x52&&u[1]===0x49&&u[2]===0x46&&u[3]===0x46&&u[8]===0x57&&u[9]===0x45&&u[10]===0x42&&u[11]===0x50)return 'webp';
 return '';
}
export function webpHeaderHex(bytes){
 const u=bytes instanceof Uint8Array?bytes:new Uint8Array(bytes||[]);
 if(imageKind(u)!=='webp')throw Error('Invalid image');
 let hex='\\x';
 for(let i=0;i<12;i++)hex+=u[i].toString(16).padStart(2,'0');
 return hex;
}
export function fitSteps(){
 const steps=[];
 let quality=0.84,scale=1;
 for(let round=0;round<7;round++){
  steps.push({quality,scale});
  quality=Math.max(0.4,Number((quality-0.07).toFixed(2)));
  scale*=0.78;
 }
 return steps;
}
