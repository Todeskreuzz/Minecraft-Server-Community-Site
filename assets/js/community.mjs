export function readOnlySession(storage){storage.removeItem('faf-session');storage.setItem('faf-anonymous','1');return null}
export function filterMods(mods,query){const q=String(query).trim().toLocaleLowerCase();return mods.filter(mod=>[mod.name,mod.author,mod.id].join(' ').toLocaleLowerCase().includes(q))}
export function modPath(id){if(!/^[a-z0-9-]+$/.test(id))throw Error('Invalid mod identifier');return '#mod/'+id}
export function stepNumber(value){return Number.isFinite(Number(value))?Math.max(0,Math.min(3,Math.trunc(Number(value)))):0}
export function launchUri(address){
 const match=/^([a-z0-9](?:[a-z0-9.-]*[a-z0-9])?\.[a-z]{2,}|(?:\d{1,3}\.){3}\d{1,3})(?::(\d{1,5}))?$/i.exec(String(address||''));
 if(!match||(match[2]&&(Number(match[2])<1||Number(match[2])>65535)))return '';
 return 'friendsandfoes://join';
}
