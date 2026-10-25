"""Package reviewed launcher scripts without executing or registering them."""
from pathlib import Path
import zipfile
root=Path(__file__).resolve().parent.parent
with zipfile.ZipFile(root/'assets/downloads/Setup-FriendsAndFoes.zip','w',zipfile.ZIP_DEFLATED) as archive:
    for source in sorted((root/'assets/launcher').glob('*.ps1')):
        archive.write(source,source.name)
    archive.writestr('Setup.cmd','@echo off\r\npowershell.exe -NoProfile -File "%~dp0Install-FriendsAndFoes.ps1"\r\npause\r\n')
    archive.writestr('README.txt','Extract the ZIP first. Review the scripts, then run Setup.cmd intentionally. Install Prism and import the Friends & Foes instance beforehand. No administrator access, antivirus changes or PowerShell execution-policy changes are performed. If Windows blocks unsigned scripts, use the manual Minecraft connection instead. To remove the link, run Uninstall-FriendsAndFoes.ps1.\r\n')
