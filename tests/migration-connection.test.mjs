import test from 'node:test';
import assert from 'node:assert/strict';
import {databaseUrl,redact} from '../scripts/deploy-database.mjs';
test('database password is encoded and destination is fixed to this project',()=>{
 const password='test:@/# ?%';const uri=databaseUrl(password);const parsed=new URL(uri);
 assert.equal(decodeURIComponent(parsed.password),password);
 assert.equal(parsed.hostname,'aws-1-eu-central-1.pooler.supabase.com');
 assert.equal(parsed.username,'postgres.iewltgawdodbmwcdgzxy');
 assert.equal(parsed.port,'5432');assert.equal(parsed.searchParams.get('sslmode'),'require');
 assert.throws(()=>databaseUrl(''),/SUPABASE_DB_PASSWORD/);
});
test('CLI output cannot expose the raw password or connection URI',()=>{
 const password='fake-secret:@/#';const uri=databaseUrl(password);
 const output=redact(`raw=${password} encoded=${encodeURIComponent(password)} url=${uri}`,password);
 assert.ok(!output.includes(password));assert.ok(!output.includes(encodeURIComponent(password)));assert.ok(!output.includes(uri));
});
