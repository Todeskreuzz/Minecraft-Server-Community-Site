param([Parameter(Mandatory=$true)][string]$Uri)
$ErrorActionPreference='Stop'
try {
    if ($args.Count -ne 0 -or $Uri -cnotmatch '^friendsandfoes://join/?$') { throw 'Unsupported launch request.' }
    $settings=Get-Content -LiteralPath (Join-Path $PSScriptRoot 'settings.json') -Raw | ConvertFrom-Json
    if ($settings.server -notmatch '^[a-zA-Z0-9.-]+(:[0-9]{1,5})?$' -or $settings.server -notmatch '\.') { throw 'Invalid fixed server address. Run setup again.' }
    if (-not (Test-Path -LiteralPath $settings.prism -PathType Leaf) -or [IO.Path]::GetFileName($settings.prism) -ine 'prismlauncher.exe') { throw 'Prism Launcher is missing. Run setup again.' }
    if (-not (Test-Path -LiteralPath (Join-Path (Join-Path $settings.root 'instances') (Join-Path $settings.instance 'instance.cfg')) -PathType Leaf)) { throw 'Your imported instance is missing. Run setup again.' }
    # Argument array: the URI cannot supply executable names, paths, or arguments.
    & $settings.prism '--dir' $settings.root '--launch' $settings.instance '--server' $settings.server
} catch {
    Add-Type -AssemblyName System.Windows.Forms
    [Windows.Forms.MessageBox]::Show($_.Exception.Message,'Friends & Foes') | Out-Null
    exit 1
}
