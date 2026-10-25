"""Import a CurseForge export without executing any supplied files.

Only the manifest, mod list and text configuration are redistributed. An audit
lists every omitted file, so unsupported plugins are never silently discarded.
"""
import argparse
import hashlib
import html
import json
import re
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent

def import_pack(source):
    data_path=ROOT/'assets/data/modpack.json'
    previous=json.loads(data_path.read_text(encoding='utf-8')) if data_path.exists() else {}
    reviewed={(entry['projectId'],entry['fileId']):entry for entry in previous.get('entries',[])}
    with zipfile.ZipFile(source) as archive:
        manifest = json.loads(archive.read('manifest.json'))
        links = re.findall(r'<a href="(https://www\.curseforge\.com/minecraft/[^"<>]+)">([^<]+)</a>', archive.read('modlist.html').decode())
        if len(links) != len(manifest['files']):
            raise ValueError('Manifest and mod list must match; manual mapping required')
        loader = next(x['id'] for x in manifest['minecraft']['modLoaders'] if x.get('primary'))
        entries = []
        for item, (url, title) in zip(manifest['files'], links):
            title = html.unescape(title)
            match = re.fullmatch(r'(.*) \(by (.*)\)', title)
            category, slug = url.rsplit('/', 2)[-2:]
            kind = {'mc-mods': 'mod', 'shaders': 'shader', 'texture-packs': 'resourcepack'}[category]
            entries.append(dict(id=slug, name=match[1] if match else title, author=match[2] if match else '',
                kind=kind, projectId=item['projectID'], fileId=item['fileID'], required=item['required'],
                minecraft=manifest['minecraft']['version'], loader=loader if kind=='mod' else '',
                projectUrl=url, fileUrl=url+'/files/'+str(item['fileID']), environment='client' if kind!='mod' else 'unverified'))
            prior=reviewed.get((item['projectID'],item['fileID']),{})
            for field in ('version','releaseName','sha256','description_de','description_en','environment','metadataSource'):
                if field in prior: entries[-1][field]=prior[field]
        public = ROOT/'assets/downloads'
        public.mkdir(parents=True, exist_ok=True)
        clean_manifest = {**manifest, 'name':'Friends & Foes', 'author':'', 'version':'2026.10.25'}
        omitted = []
        with zipfile.ZipFile(public/'friends-and-foes.zip','w',zipfile.ZIP_DEFLATED) as output:
            output.writestr('manifest.json',json.dumps(clean_manifest,indent=2))
            output.writestr('modlist.html',archive.read('modlist.html'))
            for info in archive.infolist():
                name=info.filename
                if name in ('manifest.json','modlist.html') or info.is_dir():
                    continue
                path=Path(name)
                allowed=(name.startswith('overrides/config/') and '..' not in path.parts and
                    path.suffix.lower() in ('.json','.json5','.toml','.properties','.cfg','.txt') and
                    info.file_size<=2_000_000)
                if allowed:
                    output.writestr(name,archive.read(name))
                else:
                    omitted.append(name)
        data=dict(name='Friends & Foes',version='2026.10.25',minecraft=manifest['minecraft']['version'],loader=loader,
            entries=entries,omitted=omitted,
            note_de='Der Import enthält die 50 CurseForge-Einträge und Text-Konfigurationen. ColoredSigns.jar ist ein Bukkit-Plugin, kein Forge-Mod, und wird nicht mitverteilt. Cape-Caches und die Shader-Hinweisdatei bleiben lokal.',
            note_en='The import includes the 50 CurseForge entries and text configurations. ColoredSigns.jar is a Bukkit plugin, not a Forge mod, and is not redistributed. Cape caches and the shader hint file stay local.')
        (ROOT/'assets/data/modpack.json').write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
        config_path=ROOT/'assets/data/config.json'
        config=json.loads(config_path.read_text(encoding='utf-8'))
        config.update(minecraftVersion=data['minecraft'],forgeVersion=loader.removeprefix('forge-'),modCount=sum(e['kind']=='mod' for e in entries))
        config['modpack'].update(downloadUrl='assets/downloads/friends-and-foes.zip',version=data['version'],fileSize=str((public/'friends-and-foes.zip').stat().st_size))
        config_path.write_text(json.dumps(config,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
        print(json.dumps(dict(entries=len(entries),mods=config['modCount'],omitted=omitted,sha256=hashlib.sha256(Path(source).read_bytes()).hexdigest()),indent=2))

if __name__=='__main__':
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('export_zip')
    import_pack(parser.parse_args().export_zip)
