export const VIDEO_MAX_SOURCE=100*1024*1024;
export const VIDEO_MAX_OUTPUT=8*1024*1024;
export const VIDEO_MAX_SECONDS=60;
export const IMAGE_MAX_OUTPUT=256*1024;
export const VIDEO_LINK_HINT='Dieses Video lässt sich hier nicht verkleinern. Bitte einen YouTube-, Streamable- oder Medal-Link einfügen.';

export function storagePublicUrl(base,bucket,path){
 if(!base||!bucket||!path)return '';
 return String(base).replace(/\/$/,'')+'/storage/v1/object/public/'+bucket+'/'+String(path).split('/').map(encodeURIComponent).join('/');
}
export function embedsIn(text){
 const found=[];
 const source=String(text||'');
 const patterns=[
  [/https?:\/\/(?:www\.)?(?:youtube\.com\/watch\?v=|youtu\.be\/|youtube\.com\/embed\/)([A-Za-z0-9_-]{6,})/g,'youtube',id=>'https://www.youtube-nocookie.com/embed/'+id],
  [/https?:\/\/(?:www\.)?streamable\.com\/(?:e\/)?([A-Za-z0-9]+)/g,'streamable',id=>'https://streamable.com/e/'+id],
  [/https?:\/\/(?:www\.)?medal\.tv\/(?:games\/[^/\s]+\/)?clips\/([A-Za-z0-9_-]+)/g,'medal',id=>'https://medal.tv/clip/'+id]
 ];
 for(const [pattern,host,src] of patterns){
  for(const match of source.matchAll(pattern)){
   if(found.some(item=>item.host===host&&item.id===match[1]))continue;
   found.push({host,id:match[1],src:src(match[1])});
  }
 }
 return found;
}

export function mediaKindFromHeader(bytes){
 const u=bytes instanceof Uint8Array?bytes:new Uint8Array(bytes||[]);
 if(u.length>=12&&u[0]===0x52&&u[1]===0x49&&u[2]===0x46&&u[3]===0x46&&u[8]===0x57&&u[9]===0x45&&u[10]===0x42&&u[11]===0x50)return 'image';
 if(u.length>=4&&u[0]===0x1a&&u[1]===0x45&&u[2]===0xdf&&u[3]===0xa3)return 'video';
 if(u.length>=12&&u[4]===0x66&&u[5]===0x74&&u[6]===0x79&&u[7]===0x70)return 'video';
 return '';
}

export function assertVideoCandidate(file){
 if(!file)throw Error('Invalid video');
 if(file.size>VIDEO_MAX_SOURCE)throw Error(VIDEO_LINK_HINT);
 if(!['video/mp4','video/webm','video/quicktime'].includes(file.type||''))throw Error(VIDEO_LINK_HINT);
}
