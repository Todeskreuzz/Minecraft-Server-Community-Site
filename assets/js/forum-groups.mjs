export const teamColors=['black','dark_blue','dark_green','dark_aqua','dark_red','dark_purple','gold','gray','dark_gray','blue','green','aqua','red','light_purple','yellow','white'];
export function groupTag(value){
 const tag=String(value||'').trim().toUpperCase();
 if(!/^[A-Z0-9]{2,6}$/.test(tag))throw Error('Invalid tag');
 return tag;
}
export function minecraftName(value){
 const name=String(value||'').trim();
 if(!name)return '';
 if(!/^[A-Za-z0-9_]{3,16}$/.test(name))throw Error('Invalid Minecraft name');
 return name;
}
export function safeCommandToken(value){
 const token=String(value||'');
 if(!/^[A-Za-z0-9_]{2,16}$/.test(token))throw Error('Unsafe token');
 return token;
}
