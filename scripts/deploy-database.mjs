import {spawnSync} from 'node:child_process';
import {pathToFileURL} from 'node:url';

export function databaseUrl(password){
 if(typeof password!=='string'||!password)throw Error('Missing GitHub Actions secret: SUPABASE_DB_PASSWORD');
 // Host/user verified in this project's Supabase Connect > Session pooler dialog.
 return 'postgresql://postgres.iewltgawdodbmwcdgzxy:'+encodeURIComponent(password)+'@aws-1-eu-central-1.pooler.supabase.com:5432/postgres?sslmode=require';
}
export function redact(output,password){
 for(const value of [databaseUrl(password),encodeURIComponent(password),password].sort((a,b)=>b.length-a.length))output=output.split(value).join('***');
 return output;
}
function main(){
 const password=process.env.SUPABASE_DB_PASSWORD;
 const uri=databaseUrl(password);
 if(process.env.GITHUB_ACTIONS==='true')console.log('::add-mask::'+encodeURIComponent(password));
 // No Management API token and no ability to fetch API-key secrets.
 const result=spawnSync('supabase',['db','push','--db-url',uri,'--yes'],{encoding:'utf8',maxBuffer:4*1024*1024});
 process.stdout.write(redact(result.stdout||'',password));
 process.stderr.write(redact(result.stderr||'',password));
 if(result.error)throw Error(redact(result.error.message,password));
 process.exitCode=result.status??1;
}
if(process.argv[1]&&import.meta.url===pathToFileURL(process.argv[1]).href){try{main()}catch(error){console.error(error.message);process.exitCode=1}}
