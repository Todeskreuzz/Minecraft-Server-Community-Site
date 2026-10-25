"""Resolve the pinned CurseForge references for private server provisioning.

Downloads stay under private/. No downloaded code is executed by this script.
The source Maven repository is linked by CurseForge's own file pages.
"""
import concurrent.futures
import hashlib
import io
import json
import tomllib
import urllib.request
import zipfile
from pathlib import Path

ROOT=Path(__file__).resolve().parent.parent
DEST=ROOT/'private/server-import'
SERVER_IDS={'guideme','playeranimator','citadel','glitchcore','create','elytra-slot','biomes-o-plenty','caelus','monolib','inventory-sort','terrablender','gml','curios','applied-energistics-2','alexs-mobs','serene-seasons','craft-config','creativecore','cloth-config','placebo'}

def resolve(entry):
    project,file_id=entry['projectId'],entry['fileId']
    name=f"{entry['id']}-{project}-{file_id}.jar"
    path=DEST/'all-mods'/name
    source=f"https://www.cursemaven.com/curse/maven/{entry['id']}-{project}/{file_id}/{entry['id']}-{project}-{file_id}.jar"
    if not path.exists():
        with urllib.request.urlopen(source,timeout=90) as response:
            data=response.read(100_000_001)
        if len(data)>100_000_000: raise ValueError('Mod is too large')
        with zipfile.ZipFile(io.BytesIO(data)) as jar:
            language_provider=(entry['id']=='gml' and 'META-INF/services/net.minecraftforge.forgespi.language.IModLanguageProvider' in jar.namelist())
            if 'META-INF/mods.toml' not in jar.namelist() and not language_provider: raise ValueError('Not a Forge mod: '+entry['id'])
        path.write_bytes(data)
    data=path.read_bytes()
    with zipfile.ZipFile(io.BytesIO(data)) as jar:
        text=jar.read('META-INF/mods.toml').decode('utf-8-sig',errors='replace') if 'META-INF/mods.toml' in jar.namelist() else ''
        metadata=tomllib.loads(text) if text else {}
        versions=[{'id':mod['modId'],'version':mod.get('version','')} for mod in metadata.get('mods',[])]
        dependencies=metadata.get('dependencies',{})
        manifest=jar.read('META-INF/MANIFEST.MF').decode('utf-8-sig',errors='replace') if 'META-INF/MANIFEST.MF' in jar.namelist() else ''
        version=next((line.split(': ',1)[1].strip() for line in manifest.splitlines() if line.startswith('Implementation-Version: ')),None)
        for mod in versions:
            if mod['version']=='${file.jarVersion}':mod['version']=version or mod['version']
        if not versions and entry['id']=='gml':versions=[{'id':'gml','version':version}]
    return dict(id=entry['id'],projectId=project,fileId=file_id,file=name,source=source,sha256=hashlib.sha256(data).hexdigest(),size=len(data),server=entry['id'] in SERVER_IDS,mods=versions,dependencies=dependencies)

if __name__=='__main__':
    (DEST/'all-mods').mkdir(parents=True,exist_ok=True)
    pack=json.loads((ROOT/'assets/data/modpack.json').read_text(encoding='utf-8'))
    result=[]
    with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:
        futures={pool.submit(resolve,entry):entry for entry in pack['entries'] if entry['kind']=='mod'}
        for future in concurrent.futures.as_completed(futures):
            entry=futures[future]
            try:
                result.append(future.result());print('Verified '+entry['id'],flush=True)
            except Exception as error:
                print('FAILED '+entry['id']+': '+str(error),flush=True)
    result.sort(key=lambda entry:entry['id'])
    (DEST/'audit.json').write_text(json.dumps(result,indent=2)+'\n',encoding='utf-8')
    if len(result)!=39: raise SystemExit('Some pinned files could not be resolved; do not provision an incomplete server.')
    with zipfile.ZipFile(DEST/'friends-and-foes-server.zip','w',zipfile.ZIP_DEFLATED) as output:
        for entry in result:
            if entry['server']: output.write(DEST/'all-mods'/entry['file'],'mods/'+entry['file'])
        with zipfile.ZipFile(ROOT/'assets/downloads/friends-and-foes.zip') as client:
            for name in client.namelist():
                if name.startswith('overrides/config/'): output.writestr(name.removeprefix('overrides/'),client.read(name))
    print('Private server ZIP ready: '+str(DEST/'friends-and-foes-server.zip'),flush=True)
