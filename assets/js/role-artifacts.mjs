const symbols={
 owner:'<g class="rune ring-a"><circle cx="16" cy="16" r="14" stroke-dasharray="5 4 1 5"/><path d="M16 1v4M31 16h-4M16 31v-4M1 16h4"/></g><circle class="rune ring-b" cx="16" cy="16" r="10" stroke-dasharray="2 5"/><path class="crown" d="m6 11 5 4 5-8 5 8 5-4-3 13H9Z"/><path class="arc arc-a" d="M16 8 5 3"/><path class="arc arc-b" d="M16 8V1"/><path class="arc arc-c" d="M16 8 27 3"/>',
 dayone:'<g class="orbit orbit-a"><circle cx="3" cy="16" r="1.3"/></g><g class="orbit orbit-b"><circle cx="27" cy="11" r="1"/></g><g class="orbit orbit-c"><circle cx="10" cy="28" r="1"/></g><path class="constellation" d="m3 16 24-5-17 17Z"/><path class="star" d="m16 5 3 8 8 3-8 3-3 8-3-8-8-3 8-3Z"/><ellipse class="focus-orbit" cx="16" cy="16" rx="15" ry="9"/>',
 admin:'<path class="conduit" d="M12 9 3 3M20 9l9-6M12 23l-9 6M20 23l9 6"/><path class="facet facet-a" d="m16 3 9 10-9 16-9-16Z"/><path class="facet facet-b" d="m16 3-2 12 2 14 9-16Z"/><path class="facet facet-c" d="m7 13 9 2 9-2-9 16Z"/><circle class="spark spark-a" cx="5" cy="23" r="1"/><circle class="spark spark-b" cx="27" cy="26" r="1"/>',
 moderator:'<path class="barrier barrier-a" d="M3 15A13 13 0 0 1 18 3"/><path class="barrier barrier-b" d="M29 17A13 13 0 0 1 14 29"/><path class="shield" d="m16 6 9 4v8c0 5-9 10-9 10S7 23 7 18v-8Z"/><path class="shield-wave" d="m11 21 5-2 5 2"/><circle class="impact" cx="24" cy="13" r="3"/>'
};
export function artifactMarkup(role){return Object.hasOwn(symbols,role)?'<svg viewBox="0 0 32 32" aria-hidden="true" focusable="false">'+symbols[role]+'</svg>':''}
export function effectsEnabled(stored,reduced){return stored!=='off'&&!reduced}
let phase=0;
export function createRankBadge(role,label,doc=document){
 const badge=doc.createElement('span');badge.className='rank rank-'+(Object.hasOwn(symbols,role)?role:'member');badge.dataset.phase=String(phase++%4);
 if(Object.hasOwn(symbols,role)){
  const symbol=doc.createElement('span');symbol.className='rank-art';symbol.setAttribute('aria-hidden','true');symbol.innerHTML=artifactMarkup(role);
  const energy=doc.createElement('span');energy.className='rank-energy';energy.setAttribute('aria-hidden','true');
  const core=doc.createElement('span');core.className='rank-core';core.setAttribute('aria-hidden','true');
  badge.append(core,energy,symbol);
 }
 const text=doc.createElement('span');text.className='rank-label';text.textContent=label;badge.append(text);return badge;
}
export function initRoleEffects(button){
 const root=document.documentElement,media=matchMedia('(prefers-reduced-motion: reduce)'),tracked=new Set();
 let stored;try{stored=localStorage.getItem('faf-role-effects')}catch{}
 const sync=()=>{root.dataset.roleEffects=effectsEnabled(stored,media.matches)?'on':'off';root.dataset.roleHidden=String(document.hidden);if(button){button.setAttribute('aria-pressed',String(stored!=='off'));button.title=root.lang==='en'?'Role effects (reduced motion takes priority)':'Rolleneffekte (reduzierte Bewegung hat Vorrang)';}};
 const observer=typeof IntersectionObserver==='function'?new IntersectionObserver(entries=>{for(const entry of entries)entry.target.classList.toggle('rank-visible',entry.isIntersecting)}):null;
 const collect=()=>{
  for(const badge of tracked)if(!badge.isConnected){observer?.unobserve(badge);tracked.delete(badge)}
  for(const badge of document.querySelectorAll('.rank'))if(!tracked.has(badge)){tracked.add(badge);if(observer)observer.observe(badge);else badge.classList.add('rank-visible')}
 };
 // Observe tree changes only: animation visibility classes never trigger this observer.
 new MutationObserver(collect).observe(document.body,{childList:true,subtree:true});
 new MutationObserver(sync).observe(root,{attributes:true,attributeFilter:['lang']});
 document.addEventListener('visibilitychange',sync);media.addEventListener('change',sync);
 if(button)button.onclick=()=>{stored=stored==='off'?'on':'off';try{localStorage.setItem('faf-role-effects',stored)}catch{}sync()};
 window.addEventListener('storage',event=>{if(event.key==='faf-role-effects'){stored=event.newValue;sync()}});
 sync();collect();
}
