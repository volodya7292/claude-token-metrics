# Installs the collector as a Scheduled Task: runs at logon and every 10 minutes.
# Run:  powershell -ExecutionPolicy Bypass -File install.ps1
$ErrorActionPreference = 'Stop'
$taskName = 'ClaudeTokenMetrics'
$script = Join-Path $PSScriptRoot 'collect.ps1'

if (-not (Test-Path (Join-Path $PSScriptRoot 'config.json'))) {
    Copy-Item (Join-Path $PSScriptRoot 'config.example.json') (Join-Path $PSScriptRoot 'config.json')
    Write-Warning 'config.json created from example - fill in your Honeycomb API key first!'
}

$action = New-ScheduledTaskAction -Execute 'powershell.exe' `
    -Argument "-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$script`""

$trigger = New-ScheduledTaskTrigger -AtLogOn -User $env:USERNAME
$trigger.Repetition = (New-ScheduledTaskTrigger -Once -At (Get-Date) `
    -RepetitionInterval (New-TimeSpan -Minutes 10)).Repetition

$settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries -ExecutionTimeLimit (New-TimeSpan -Minutes 5)

# Idempotent install: replace existing task if present
Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue
Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Settings $settings | Out-Null
Start-ScheduledTask -TaskName $taskName
Write-Host "Installed and started task '$taskName' (at logon + every 10 min)."
