# Installs claude-token-metrics without cloning the repo.
# Needs a GitHub token with repo read access (private repo) in $env:GITHUB_TOKEN.
# Honeycomb settings come from $env:HONEYCOMB_API_KEY / $env:HONEYCOMB_DATASET or are prompted.
$ErrorActionPreference = 'Stop'

$repo = 'volodya7292/claude-token-metrics'
$dest = Join-Path $env:LOCALAPPDATA 'claude-token-metrics'

if (-not $env:GITHUB_TOKEN) { throw 'Set $env:GITHUB_TOKEN first (private repo).' }

$zip = Join-Path $env:TEMP 'claude-token-metrics.zip'
Invoke-WebRequest "https://api.github.com/repos/$repo/zipball/main" `
    -Headers @{ Authorization = "Bearer $env:GITHUB_TOKEN" } -OutFile $zip

$tmp = Join-Path $env:TEMP "ctm-extract-$([guid]::NewGuid())"
Expand-Archive $zip -DestinationPath $tmp
$src = Get-ChildItem $tmp -Directory | Select-Object -First 1

New-Item -ItemType Directory -Force $dest | Out-Null
Copy-Item (Join-Path $src.FullName '*') $dest -Force
Remove-Item $zip, $tmp -Recurse -Force

$apiKey  = if ($env:HONEYCOMB_API_KEY) { $env:HONEYCOMB_API_KEY } else { Read-Host 'Honeycomb ingest API key' }
$dataset = if ($env:HONEYCOMB_DATASET) { $env:HONEYCOMB_DATASET } else { 'claude-code-usage' }
@{ apiKey = $apiKey; dataset = $dataset } | ConvertTo-Json | Set-Content (Join-Path $dest 'config.json')

& powershell -NoProfile -ExecutionPolicy Bypass -File (Join-Path $dest 'install.ps1')
Write-Host "Installed to $dest"
