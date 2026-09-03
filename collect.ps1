# Claude Code token usage -> Honeycomb. Idempotent: recomputes totals from scratch each run.
# Sends one overall event plus one event per session (with the first user prompt as title).
$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$configPath = Join-Path $PSScriptRoot 'config.json'
$config = Get-Content $configPath -Raw | ConvertFrom-Json

$projectsDir = Join-Path $env:USERPROFILE '.claude\projects'
$sessions = @()

if (Test-Path $projectsDir) {
    foreach ($f in Get-ChildItem $projectsDir -Recurse -Filter '*.jsonl') {
        $s = @{ id = $f.BaseName; project = $f.Directory.Name; title = $null; modified = $f.LastWriteTimeUtc
                input = 0L; output = 0L; cache_write = 0L; cache_read = 0L; requests = 0L }
        foreach ($line in [System.IO.File]::ReadLines($f.FullName)) {
            if ((-not $s.title) -and $line -match '"type":"user"') {
                try {
                    $o = $line | ConvertFrom-Json
                    $c = $o.message.content
                    if ($c -is [string] -and $c -and $c -notmatch '^<' -and $o.isSidechain -ne $true) {
                        $s.title = $c.Substring(0, [Math]::Min(200, $c.Length))
                    }
                } catch {}
            }
            if ($line -notmatch '"usage"') { continue }
            try { $obj = $line | ConvertFrom-Json } catch { continue }
            $u = $obj.message.usage
            if ($null -eq $u) { continue }
            $s.requests++
            if ($u.input_tokens)                { $s.input       += [long]$u.input_tokens }
            if ($u.output_tokens)               { $s.output      += [long]$u.output_tokens }
            if ($u.cache_creation_input_tokens) { $s.cache_write += [long]$u.cache_creation_input_tokens }
            if ($u.cache_read_input_tokens)     { $s.cache_read  += [long]$u.cache_read_input_tokens }
        }
        if ($s.requests -gt 0) { $sessions += $s }
    }
}

function Total($sess, $prop) { [long](($sess | ForEach-Object { $_[$prop] } | Measure-Object -Sum).Sum) }

$events = @()
$events += @{ data = @{
    name                = 'claude_code.token_usage'
    host                = $env:COMPUTERNAME
    user                = $env:USERNAME
    input_tokens        = (Total $sessions 'input')
    output_tokens       = (Total $sessions 'output')
    cache_write_tokens  = (Total $sessions 'cache_write')
    cache_read_tokens   = (Total $sessions 'cache_read')
    total_tokens        = ((Total $sessions 'input') + (Total $sessions 'output') + (Total $sessions 'cache_write') + (Total $sessions 'cache_read'))
    requests            = (Total $sessions 'requests')
    sessions_with_usage = $sessions.Count
} }

$cutoff = (Get-Date).ToUniversalTime().AddDays(-7)
foreach ($s in $sessions | Where-Object { $_.modified -ge $cutoff }) {
    $events += @{ data = @{
        name               = 'claude_code.session_usage'
        host               = $env:COMPUTERNAME
        user               = $env:USERNAME
        session_id         = $s.id
        project            = $s.project
        title              = $s.title
        input_tokens       = $s.input
        output_tokens      = $s.output
        cache_write_tokens = $s.cache_write
        cache_read_tokens  = $s.cache_read
        total_tokens       = $s.input + $s.output + $s.cache_write + $s.cache_read
        requests           = $s.requests
    } }
}

$uri = "https://api.honeycomb.io/1/batch/$($config.dataset)"
$body = [System.Text.Encoding]::UTF8.GetBytes((ConvertTo-Json @($events) -Depth 5))
Invoke-RestMethod -Uri $uri -Method Post `
    -Headers @{ 'X-Honeycomb-Team' = $config.apiKey } `
    -ContentType 'application/json' -Body $body | Out-Null

Write-Host "Reported $($events.Count) events ($($events.Count - 1) of $($sessions.Count) sessions active in the last week)."
