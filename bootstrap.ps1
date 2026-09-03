# Installs claude-token-metrics without cloning the repo.
# Honeycomb settings come from $env:HONEYCOMB_API_KEY / $env:HONEYCOMB_DATASET or are prompted.
$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$repo = 'volodya7292/claude-token-metrics'
$dest = Join-Path $env:LOCALAPPDATA 'claude-token-metrics'

$zip = Join-Path $env:TEMP 'claude-token-metrics.zip'
Invoke-WebRequest "https://api.github.com/repos/$repo/zipball/main" -OutFile $zip
$tmp = Join-Path $env:TEMP "ctm-extract-$([guid]::NewGuid())"
Expand-Archive $zip -DestinationPath $tmp
$src = Get-ChildItem $tmp -Directory | Select-Object -First 1

New-Item -ItemType Directory -Force $dest | Out-Null
Copy-Item (Join-Path $src.FullName '*') $dest -Force
Remove-Item $zip, $tmp -Recurse -Force

$apiKey  = if ($env:HONEYCOMB_API_KEY) { $env:HONEYCOMB_API_KEY } else { Read-Host 'Honeycomb ingest API key' }
$dataset = if ($env:HONEYCOMB_DATASET) { $env:HONEYCOMB_DATASET } else { 'claude-code-usage' }
@{ apiKey = $apiKey; dataset = $dataset } | ConvertTo-Json | Set-Content (Join-Path $dest 'config.json')

# Record installed commit for the self-updater
$sha = (Invoke-RestMethod "https://api.github.com/repos/$repo/commits/main").sha
Set-Content (Join-Path $dest '.installed-sha') $sha

& powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $dest 'install.ps1')
Write-Host "Installed to $dest"
