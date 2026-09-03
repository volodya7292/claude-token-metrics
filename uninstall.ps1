Unregister-ScheduledTask -TaskName 'ClaudeTokenMetrics' -Confirm:$false
Unregister-ScheduledTask -TaskName 'ClaudeTokenMetricsUpdate' -Confirm:$false -ErrorAction SilentlyContinue
Write-Host 'Uninstalled.'
