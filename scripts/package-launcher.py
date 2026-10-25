"""Package reviewed launcher scripts without executing or registering them."""
from pathlib import Path
import hashlib
import os
import subprocess
import zipfile
root=Path(__file__).resolve().parent.parent
source=root/'assets/launcher/FriendsAndFoes.cs'
binary=root/'private/FriendsAndFoes.exe'
compiler=Path(os.environ.get('WINDIR','C:/Windows'))/'Microsoft.NET/Framework64/v4.0.30319/csc.exe'
if not compiler.is_file():raise SystemExit('Build this native Windows helper on Windows with the included .NET Framework compiler.')
subprocess.run([str(compiler),'/nologo','/codepage:65001','/target:winexe','/reference:System.Web.Extensions.dll','/reference:System.Windows.Forms.dll','/out:'+str(binary),str(source)],check=True)
subprocess.run([str(binary),'--self-test'],check=True)
with zipfile.ZipFile(root/'assets/downloads/Setup-FriendsAndFoes.zip','w',zipfile.ZIP_DEFLATED) as archive:
    archive.write(binary,'Setup-FriendsAndFoes.exe')
    archive.write(source,source.name)
    archive.writestr('SOURCE.sha256',hashlib.sha256(source.read_bytes()).hexdigest()+'\n')
    archive.writestr('Uninstall.cmd','@echo off\r\n"%LOCALAPPDATA%\\FriendsAndFoes\\FriendsAndFoes.exe" --uninstall\r\n')
    archive.writestr('README.txt','DE: ZIP entpacken. Prism installieren und das Friends-&-Foes-Modpack importieren. Den enthaltenen Quellcode kannst du vorab lesen. Starte Setup-FriendsAndFoes.exe bewusst selbst und wähle Prism sowie den importierten Instanzordner. Danach funktioniert der Direktstart auf der Website. Kein Administratorzugriff und keine Änderungen an Sicherheits- oder PowerShell-Richtlinien. Wenn Windows die nicht signierte Anwendung blockiert, verwende die manuelle Verbindung; die Website umgeht keine Schutzabfrage. Entfernen: Uninstall.cmd.\r\n\r\nEN: Extract the ZIP. Install Prism and import the Friends & Foes modpack. Review the included source, then deliberately run Setup-FriendsAndFoes.exe and choose Prism and the imported instance folder. No administrator access or security-policy changes. If Windows blocks this unsigned application, use the manual Minecraft connection. Removal: Uninstall.cmd.\r\n')
