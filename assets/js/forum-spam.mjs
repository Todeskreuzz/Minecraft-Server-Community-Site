export const MIN_FILL_MS=3000;
export function honeypotTripped(value){return String(value??'').trim()!==''}
export function formTooFast(openedAt,now=Date.now(),minMs=MIN_FILL_MS){
 const opened=Number(openedAt);
 return !Number.isFinite(opened)||opened<=0||now-opened<minMs;
}
