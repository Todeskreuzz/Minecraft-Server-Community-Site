import {SHRINK_ERROR,fitSteps,imageKind} from './forum-profile.mjs';
const TYPES=new Set(['image/png','image/jpeg','image/webp']);
const MAX_BYTES=8*1024*1024;
const MAX_PIXELS=40000000;
const TARGET=262144;
export async function compressImage(file,maxSide,isCurrent=()=>true){
 if(!file||file.size>MAX_BYTES)throw Error('Das Bild darf höchstens 8 MB groß sein.');
 if(!TYPES.has(file.type))throw Error('Nur PNG, JPEG oder WebP.');
 const header=new Uint8Array(await file.slice(0,16).arrayBuffer());
 if(!imageKind(header))throw Error('Nur PNG, JPEG oder WebP.');
 if(!isCurrent())throw Error('cancelled');
 const bitmap=await createImageBitmap(file);
 try{
  if(bitmap.width*bitmap.height>MAX_PIXELS)throw Error('Das Bild hat zu viele Pixel.');
  const fitted=Math.min(1,maxSide/Math.max(bitmap.width,bitmap.height));
  for(const step of fitSteps()){
   if(!isCurrent())throw Error('cancelled');
   const width=Math.max(1,Math.round(bitmap.width*fitted*step.scale));
   const height=Math.max(1,Math.round(bitmap.height*fitted*step.scale));
   const canvas=document.createElement('canvas');
   canvas.width=width;canvas.height=height;
   canvas.getContext('2d').drawImage(bitmap,0,0,width,height);
   const blob=await new Promise(resolve=>canvas.toBlob(resolve,'image/webp',step.quality));
   if(blob&&blob.size<=TARGET)return blob;
  }
  throw Error(SHRINK_ERROR);
 }finally{bitmap.close()}
}
