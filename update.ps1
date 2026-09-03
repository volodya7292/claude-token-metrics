# Hourly self-update: if the latest commit on main differs from the installed one,
# re-download the repo zip and replace the installed files (config.json is kept).
$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$repo = 'volodya7292/claude-token-metrics'
$dest = $PSScriptRoot

$latest = (Invoke-RestMethod "https://api.github.com/repos/$repo/commits/main").sha
$shaFile = Join-Path $dest '.installed-sha'
$installed = if (Test-Path $shaFile) { (Get-Content $shaFile -Raw).Trim() } else { '' }

if ($latest -eq $installed) { Write-Host "Up to date ($latest)"; exit 0 }

Write-Host "Updating $installed -> $latest"
$zip = Join-Path $env:TEMP 'claude-token-metrics.zip'
Invoke-WebRequest "https://api.github.com/repos/$repo/zipball/main" -OutFile $zip
$tmp = Join-Path $env:TEMP "ctm-update-$([guid]::NewGuid())"
Expand-Archive $zip -DestinationPath $tmp
$src = Get-ChildItem $tmp -Directory | Select-Object -First 1
Get-ChildItem $src.FullName -Exclude 'config.json' | Copy-Item -Destination $dest -Recurse -Force
Remove-Item $zip, $tmp -Recurse -Force
Set-Content $shaFile $latest

# Re-register tasks in case install.ps1 changed
& powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $dest 'install.ps1')
Write-Host "Updated to $latest"
