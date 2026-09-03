# Claude Code token usage -> Honeycomb. Idempotent: recomputes totals from scratch each run.
$ErrorActionPreference = 'Stop'

$configPath = Join-Path $PSScriptRoot 'config.json'
$config = Get-Content $configPath -Raw | ConvertFrom-Json

$totals = @{ input = 0L; output = 0L; cache_write = 0L; cache_read = 0L; requests = 0L; sessions = 0 }
$projectsDir = Join-Path $env:USERPROFILE '.claude\projects'

if (Test-Path $projectsDir) {
    $files = Get-ChildItem $projectsDir -Recurse -Filter '*.jsonl'
    foreach ($f in $files) {
        $hadUsage = $false
        foreach ($line in [System.IO.File]::ReadLines($f.FullName)) {
            if ($line -notmatch '"usage"') { continue }
            try { $obj = $line | ConvertFrom-Json } catch { continue }
            $u = $obj.message.usage
            if ($null -eq $u) { continue }
            $hadUsage = $true
            $totals.requests++
            if ($u.input_tokens)                 { $totals.input       += [long]$u.input_tokens }
            if ($u.output_tokens)                { $totals.output      += [long]$u.output_tokens }
            if ($u.cache_creation_input_tokens)  { $totals.cache_write += [long]$u.cache_creation_input_tokens }
            if ($u.cache_read_input_tokens)      { $totals.cache_read  += [long]$u.cache_read_input_tokens }
        }
        if ($hadUsage) { $totals.sessions++ }
    }
}

$event = @{
    name                 = 'claude_code.token_usage'
    host                 = $env:COMPUTERNAME
    user                 = $env:USERNAME
    input_tokens         = $totals.input
    output_tokens        = $totals.output
    cache_write_tokens   = $totals.cache_write
    cache_read_tokens    = $totals.cache_read
    total_tokens         = $totals.input + $totals.output + $totals.cache_write + $totals.cache_read
    requests             = $totals.requests
    sessions_with_usage  = $totals.sessions
}

$uri = "https://api.honeycomb.io/1/events/$($config.dataset)"
Invoke-RestMethod -Uri $uri -Method Post `
    -Headers @{ 'X-Honeycomb-Team' = $config.apiKey } `
    -ContentType 'application/json' `
    -Body ($event | ConvertTo-Json) | Out-Null

Write-Host "Reported: $($event | ConvertTo-Json -Compress)"
