# Installs the collector as Scheduled Tasks: collector (every 10 min) + hourly self-update.
# Run:  powershell -ExecutionPolicy Bypass -File install.ps1
$ErrorActionPreference = 'Stop'
$taskName = 'ClaudeTokenMetrics'
$script = Join-Path $PSScriptRoot 'collect.ps1'

if (-not (Test-Path (Join-Path $PSScriptRoot 'config.json'))) {
    Copy-Item (Join-Path $PSScriptRoot 'config.example.json') (Join-Path $PSScriptRoot 'config.json')
    Write-Warning 'config.json created from example - fill in your Honeycomb API key first!'
}

$settings = New-ScheduledTaskSettingsSet -StartWhenAvailable -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries -ExecutionTimeLimit (New-TimeSpan -Minutes 5)

function Register-RepeatingTask($name, $file, $interval) {
    $action = New-ScheduledTaskAction -Execute 'powershell.exe' `
        -Argument "-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$file`""
    $trigger = New-ScheduledTaskTrigger -AtLogOn -User $env:USERNAME
    $trigger.Repetition = (New-ScheduledTaskTrigger -Once -At (Get-Date) `
        -RepetitionInterval $interval).Repetition
    # Idempotent: replace existing task if present
    Unregister-ScheduledTask -TaskName $name -Confirm:$false -ErrorAction SilentlyContinue
    Register-ScheduledTask -TaskName $name -Action $action -Trigger $trigger -Settings $settings | Out-Null
}

Register-RepeatingTask $taskName $script (New-TimeSpan -Minutes 10)
Start-ScheduledTask -TaskName $taskName
Write-Host "Installed and started task '$taskName' (at logon + every 10 min)."

Register-RepeatingTask 'ClaudeTokenMetricsUpdate' (Join-Path $PSScriptRoot 'update.ps1') (New-TimeSpan -Hours 1)
Write-Host "Installed task 'ClaudeTokenMetricsUpdate' (hourly update check)."
