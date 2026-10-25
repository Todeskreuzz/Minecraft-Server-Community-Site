$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Windows.Forms
if ([Windows.Forms.MessageBox]::Show('Remove the Friends & Foes website link? Your Minecraft and Prism files remain untouched.','Friends & Foes','YesNo') -ne 'Yes') { exit }
$key='HKCU:\Software\Classes\friendsandfoes'
$target=Join-Path ([Environment]::GetFolderPath('LocalApplicationData')) 'FriendsAndFoes'
if (Test-Path -LiteralPath $key) { Remove-Item -LiteralPath $key -Recurse }
foreach ($name in @('settings.json','Launch-FriendsAndFoes.ps1','Uninstall-FriendsAndFoes.ps1')) {
    $file=Join-Path $target $name
    if (Test-Path -LiteralPath $file) { Remove-Item -LiteralPath $file }
}
