import {padUid,profilePath} from './forum-profile.mjs';

// Name is supplied by the existing protected name resolver, never a new public lookup.
export function paintProfileShortcut(link,profile,name,label){
 link.replaceChildren();link.hidden=!profile?.uid;
 if(link.hidden){link.removeAttribute('href');return}
 link.href=profilePath(profile.uid);
 const span=(text,className)=>{const el=link.ownerDocument.createElement('span');el.textContent=text;el.className=className;return el};
 link.replaceChildren(span(name,'account-name'),span('#'+padUid(profile.uid),'uid-badge'),span(label,'profile-shortcut-label'));
}
