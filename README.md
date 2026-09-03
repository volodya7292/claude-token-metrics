# claude-token-metrics

Background collector (Windows Scheduled Task) that every 10 minutes sums the
total Claude Code token usage of the current user from
`%USERPROFILE%\.claude\projects\**\*.jsonl` and sends one event to Honeycomb.

Idempotent: each run recomputes the totals from scratch and reports them as
absolute gauges - running it twice changes nothing.

## Install

```powershell
Copy-Item config.example.json config.json   # then put your Honeycomb ingest key in it
powershell -ExecutionPolicy Bypass -File install.ps1
```

Re-running `install.ps1` replaces the existing task. Remove with `uninstall.ps1`.

## Metrics (per event)

`input_tokens`, `output_tokens`, `cache_write_tokens`, `cache_read_tokens`,
`total_tokens`, `requests`, `sessions_with_usage`, plus `host`/`user`.
In Honeycomb, query `MAX(total_tokens)` over time to see growth.
