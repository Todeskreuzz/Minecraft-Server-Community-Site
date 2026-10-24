#!/usr/bin/env node
/** Lightweight structural checks, zero dependencies. */
import fs from 'node:fs';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
const root=path.resolve(path.dirname(fileURLToPath(import.meta.url)),'..');
const required=['index.html','assets/css/style.css','assets/js/app.js','assets/data/config.json','assets/data/team.json','assets/data/members.json','assets/data/news.json','assets/data/rules.json','assets/img/mark.svg','assets/img/favicon.svg','.nojekyll','README.md','CODEX-ANLEITUNG.md'];
let errors=[];
for(const file of ['assets/css/forum.css','assets/js/forum.mjs','assets/js/forum-api.mjs','assets/data/supabase.json','supabase/setup.sql','supabase/permission-tests.sql'])if(!fs.existsSync(path.join(root,file)))errors.push('Missing forum file: '+file);
for(const file of required)if(!fs.existsSync(path.join(root,file)))errors.push('Missing file: '+file);
function read(file){try{return JSON.parse(fs.readFileSync(path.join(root,'assets/data',file),'utf8'))}catch(error){errors.push('Invalid JSON in '+file+': '+error.message);return {}}}
const config=read('config.json'),team=read('team.json'),members=read('members.json'),news=read('news.json'),rules=read('rules.json');
if(config.minecraftVersion!=='1.20.1')errors.push('Minecraft version differs from request');
if(config.forgeVersion!=='47.4.10')errors.push('Forge version differs from request');
for(const [name,data,key] of [['team.json',team,'team'],['members.json',members,'members'],['news.json',news,'news'],['rules.json',rules,'rules']])if(!Array.isArray(data[key]))errors.push(name+' must contain array '+key);
const uids=new Set();for(const m of members.members||[]){if(!Number.isSafeInteger(m.uid)||m.uid<1||uids.has(m.uid))errors.push('Invalid / duplicate public UID '+m.uid);uids.add(m.uid);if(m.public!==true)errors.push('Unapproved member exposed in public members.json')}
for(const m of team.team||[])if(m.visible!==true)errors.push('Hidden team member should not be present in public team.json');
if(errors.length){errors.forEach(e=>console.error('ERROR:',e));process.exitCode=1}else console.log('PASS — files, JSON, versions, published UID uniqueness, public team visibility.');
