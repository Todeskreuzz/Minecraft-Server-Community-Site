$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Windows.Forms
try {
    $answer=[Windows.Forms.MessageBox]::Show('Install a Friends & Foes link for this Windows user? It will launch your selected Prism instance and the fixed community server. No administrator access is required.','Friends & Foes','YesNo')
    if ($answer -ne 'Yes') { exit }
    $origin='https://todeskreuzz.github.io/Minecraft-Server-Community-Site/'
    $config=Invoke-RestMethod -Uri ($origin+'assets/data/config.json')
    $server=[string]$config.server.address
    if ($server -notmatch '^(?=.{1,253}(:[0-9]{1,5})?$)[a-zA-Z0-9.-]+\.[a-zA-Z0-9.-]+(:[0-9]{1,5})?$') { throw 'The community server is not configured yet.' }
    if ($server -match ':([0-9]+)$' -and ([int]$Matches[1] -lt 1 -or [int]$Matches[1] -gt 65535)) { throw 'Invalid server port.' }
    $pick=New-Object Windows.Forms.OpenFileDialog
    $pick.Title='Select your installed Prism Launcher';$pick.Filter='Prism Launcher|prismlauncher.exe';$pick.CheckFileExists=$true
    if ($pick.ShowDialog() -ne 'OK') { exit }
    $prism=$pick.FileName
    $folder=New-Object Windows.Forms.FolderBrowserDialog
    $folder.Description='Select your imported Friends & Foes instance folder (inside Prism/instances). In Prism: right-click instance > Folder.'
    if ($folder.ShowDialog() -ne 'OK') { exit }
    $instanceFolder=Get-Item -LiteralPath $folder.SelectedPath
    if ($instanceFolder.Parent.Name -ine 'instances' -or -not (Test-Path -LiteralPath (Join-Path $instanceFolder.FullName 'instance.cfg'))) { throw 'Choose an imported Prism instance folder, inside its instances directory.' }
    $packFile=Join-Path $instanceFolder.FullName 'mmc-pack.json'
    if (-not (Test-Path -LiteralPath $packFile -PathType Leaf)) { throw 'Prism instance metadata is missing. Import the modpack first.' }
    $pack=Get-Content -LiteralPath $packFile -Raw | ConvertFrom-Json
    $minecraft=@($pack.components | Where-Object { $_.uid -eq 'net.minecraft' })
    $forge=@($pack.components | Where-Object { $_.uid -eq 'net.minecraftforge' })
    if ($minecraft.Count -ne 1 -or $minecraft[0].version -ne $config.minecraftVersion -or $forge.Count -ne 1 -or $forge[0].version -ne $config.forgeVersion) { throw 'This instance does not match the community Minecraft and Forge versions. Import the current modpack first.' }
    $target=Join-Path ([Environment]::GetFolderPath('LocalApplicationData')) 'FriendsAndFoes'
    New-Item -ItemType Directory -Path $target -Force | Out-Null
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'Launch-FriendsAndFoes.ps1') -Destination $target -Force
    Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'Uninstall-FriendsAndFoes.ps1') -Destination $target -Force
    @{server=$server;prism=$prism;root=$instanceFolder.Parent.Parent.FullName;instance=$instanceFolder.Name} | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $target 'settings.json') -Encoding UTF8
    $key='HKCU:\Software\Classes\friendsandfoes'
    New-Item -Path $key -Force | Out-Null
    Set-Item -Path $key -Value 'URL:Friends & Foes'
    New-ItemProperty -Path $key -Name 'URL Protocol' -Value '' -PropertyType String -Force | Out-Null
    New-Item -Path ($key+'\shell\open\command') -Force | Out-Null
    $powershell=Join-Path $PSHOME 'powershell.exe'
    $handler=Join-Path $target 'Launch-FriendsAndFoes.ps1'
    Set-Item -Path ($key+'\shell\open\command') -Value ('"'+$powershell+'" -NoProfile -File "'+$handler+'" -Uri "%1"')
    [Windows.Forms.MessageBox]::Show('Ready. The website can now open your Prism instance. For removal, run Uninstall-FriendsAndFoes.ps1 from the downloaded folder.','Friends & Foes') | Out-Null
} catch { [Windows.Forms.MessageBox]::Show($_.Exception.Message,'Friends & Foes') | Out-Null; exit 1 }
