#!/usr/bin/env node
/**
 * Offline UID allocation for Friends & Foes (Node 20+; no dependencies).
 * Internal UUID mapping lives in private/ (gitignored); public export only
 * includes opt-in name/UID/role. Execute allocations serially on one trusted PC.
 */
import fs from 'node:fs';
import path from 'node:path';
import process from 'node:process';
import {fileURLToPath} from 'node:url';

const ROOT=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..');
const PRIVATE_DIR=process.env.UID_PRIVATE_DIR?path.resolve(process.env.UID_PRIVATE_DIR):path.join(ROOT,'private');
const PRIVATE_FILE=path.join(PRIVATE_DIR,'uid-registry.json');
const PUBLIC_FILE=process.env.UID_PUBLIC_FILE?path.resolve(process.env.UID_PUBLIC_FILE):path.join(ROOT,'assets/data/members.json');
const ROLES=new Set(['owner','admin','mod','member']);
const UUID_RE=/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const USER_RE=/^[A-Za-z0-9_]{3,16}$/;

function usage(){console.log(`Friends & Foes UID Manager (Node 20+, no installation)

  node scripts/uid-manager.mjs add --uuid <Minecraft-UUID> --name <Minecraft-Name> --joined <ISO-UTC> [--role member|mod|admin|owner] [--public]
  node scripts/uid-manager.mjs import --file <players.csv>
  node scripts/uid-manager.mjs update --uuid <UUID> [--name <Name>] [--role <Role>] [--public | --private]
  node scripts/uid-manager.mjs export
  node scripts/uid-manager.mjs stats

  CSV columns: uuid,name,firstSeen,role,public
  'public' must be true only after the player explicitly consents.
  'firstSeen' is ISO UTC, e.g. 2026-10-24T18:00:00Z.
  Import old players chronologically BEFORE new ones; assigned UIDs never change.
  Internal UUID registry is NEVER meant to be committed to public GitHub.`)}
function parseArgs(tokens){const options={};for(let i=0;i<tokens.length;i++){const arg=tokens[i];if(!arg.startsWith('--'))throw Error('Unexpected argument: '+arg);const key=arg.slice(2);if(['public','private'].includes(key)){options[key]=true;continue}if(!tokens[i+1]||tokens[i+1].startsWith('--'))throw Error('Missing value after '+arg);options[key]=tokens[++i]}return options}
function validateId(uuid){if(!UUID_RE.test(uuid||''))throw Error('Invalid Minecraft UUID: '+uuid);return uuid.toLowerCase()}
function validateName(name){if(!USER_RE.test(name||''))throw Error('Minecraft names must be 3–16 ASCII letters, numbers or underscore: '+name);return name}
function validateRole(role='member'){if(!ROLES.has(role))throw Error('Role must be owner, admin, mod or member');return role}
function validateJoined(raw){const timestamp=Date.parse(raw||'');if(!Number.isFinite(timestamp)||!/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d{1,3})?Z$/.test(raw))throw Error('Use UTC ISO time for --joined / firstSeen, e.g. 2026-10-24T18:00:00Z');return new Date(timestamp).toISOString()}
function readRegistry(){if(!fs.existsSync(PRIVATE_FILE))return {nextUid:1,members:[]};const value=JSON.parse(fs.readFileSync(PRIVATE_FILE,'utf8'));if(!Number.isSafeInteger(value.nextUid)||!Array.isArray(value.members))throw Error('Invalid private registry');return value}
function writeAtomic(filename,value,mode=0o644){fs.mkdirSync(path.dirname(filename),{recursive:true});const temp=filename+'.'+process.pid+'.tmp';try{fs.writeFileSync(temp,JSON.stringify(value,null,2)+'\n',{encoding:'utf8',mode,flag:'wx'});fs.renameSync(temp,filename);fs.chmodSync(filename,mode)}finally{if(fs.existsSync(temp))fs.unlinkSync(temp)}}
function exportPublic(registry){const members=registry.members.filter(p=>p.public===true).map(({uid,name,role})=>({uid,name,role,public:true})).sort((a,b)=>a.uid-b.uid);writeAtomic(PUBLIC_FILE,{lastExportedAt:new Date().toISOString(),members});console.log(`Exported ${members.length} consented public profiles.`)}
function allocate(registry,entries){
  const seen=new Set(registry.members.map(m=>m.uuid));let added=0;
  const sorted=[...entries].sort((a,b)=>a.firstSeen.localeCompare(b.firstSeen));
  for(const candidate of sorted){
    const uuid=validateId(candidate.uuid);if(seen.has(uuid))throw Error('UUID already registered (or repeated in CSV): '+uuid);seen.add(uuid);
    validateName(candidate.name);validateRole(candidate.role);validateJoined(candidate.firstSeen);
  }
  let last=registry.members.length?registry.members[registry.members.length-1].firstSeen:null;
  for(const item of sorted){
    if(last && item.firstSeen<last)throw Error('Out-of-order first join. Import historical players before assigning newer UIDs; existing UIDs must not be renumbered. Earliest missing join: '+item.name);
    if(!Number.isSafeInteger(registry.nextUid)||registry.nextUid<1)throw Error('UID counter invalid');
    registry.members.push({uid:registry.nextUid++,uuid:validateId(item.uuid),name:item.name,firstSeen:item.firstSeen,role:item.role,public:item.public===true});
    last=item.firstSeen;added++;
  }
  return added
}
function parseCsv(source){
  // Minecraft usernames and ISO timestamps cannot contain a comma; CSV is intentionally limited.
  const rows=fs.readFileSync(source,'utf8').replace(/^\uFEFF/,'').split(/\r?\n/).filter(line=>line.trim()&&!line.trim().startsWith('#'));
  if(!rows.length||rows.shift().trim()!=='uuid,name,firstSeen,role,public')throw Error('CSV header must be exactly: uuid,name,firstSeen,role,public');
  return rows.map((line,index)=>{const parts=line.split(',').map(x=>x.trim());if(parts.length!==5)throw Error('Invalid CSV row '+(index+2));const [uuid,name,firstSeen,role,visibility]=parts;const flag=visibility.toLowerCase();if(!['true','false'].includes(flag))throw Error('public must be true or false in row '+(index+2));return {uuid,name,firstSeen:validateJoined(firstSeen),role:validateRole(role),public:flag==='true'}});
}
function main(){
  const [command,...args]=process.argv.slice(2);if(!command||['help','--help','-h'].includes(command)){usage();return}
  const opts=parseArgs(args);
  if(!['add','import','update','export','stats'].includes(command))throw Error('Unknown command: '+command);
  if(command==='stats'){const reg=readRegistry();console.log(JSON.stringify({registered:reg.members.length,nextUid:reg.nextUid,publicCount:reg.members.filter(x=>x.public).length},null,2));return}
  fs.mkdirSync(PRIVATE_DIR,{recursive:true,mode:0o700});
  const lockPath=path.join(PRIVATE_DIR,'.uid.lock');let lock;
  try{
    lock=fs.openSync(lockPath,'wx',0o600);const registry=readRegistry();
    if(command==='add'){
      const entry={uuid:validateId(opts.uuid),name:validateName(opts.name),firstSeen:validateJoined(opts.joined),role:validateRole(opts.role),public:opts.public===true};
      console.log('Assigned',allocate(registry,[entry]),'new UID.');
    } else if(command==='import'){
      if(!opts.file)throw Error('Missing --file <players.csv>');const entries=parseCsv(path.resolve(opts.file));console.log('Assigned',allocate(registry,entries),'new UIDs, sorted by first join time.');
    } else if(command==='update'){
      const uuid=validateId(opts.uuid);const member=registry.members.find(item=>item.uuid===uuid);if(!member)throw Error('UUID not registered');
      if(opts.name)member.name=validateName(opts.name);if(opts.role)member.role=validateRole(opts.role);if(opts.public&&opts.private)throw Error('Choose --public OR --private');
      if(opts.public)member.public=true;if(opts.private)member.public=false;console.log('Updated UID #'+String(member.uid).padStart(6,'0'));
    }
    if(command!=='export')writeAtomic(PRIVATE_FILE,registry,0o600);exportPublic(registry);
  } finally{if(lock!==undefined){fs.closeSync(lock);fs.unlinkSync(lockPath)}}
}
try{main()}catch(error){console.error('UID error:',error.message);process.exitCode=1}
