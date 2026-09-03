# claude-token-metrics

A tiny Windows background tool that reports your total [Claude Code](https://claude.com/claude-code)
token usage to [Honeycomb](https://www.honeycomb.io/) every 10 minutes.

It runs as a hidden Scheduled Task (at logon + every 10 minutes), scans the local
Claude Code session transcripts under `%USERPROFILE%\.claude\projects\**\*.jsonl`,
sums all `message.usage` entries, and sends one event to the Honeycomb Events API.

The collector is **idempotent**: every run recomputes the totals from scratch and
reports them as absolute gauges. No local state, and running it twice in a row
changes nothing.

## Requirements

- Windows with PowerShell 5.1+ (no admin rights needed)
- Claude Code installed for the current user
- A Honeycomb ingest API key

## Install (no clone needed)

```powershell
$env:HONEYCOMB_API_KEY = 'hcaik_...'   # optional, prompted otherwise
iex (iwr https://raw.githubusercontent.com/volodya7292/claude-token-metrics/main/bootstrap.ps1).Content
```

This downloads the repo zip to `%LOCALAPPDATA%\claude-token-metrics`, writes
`config.json`, and registers two Scheduled Tasks: the 10-minute collector and an
hourly update check that pulls the latest `main` when its head commit changed
(`config.json` is preserved across updates).

### Alternative: from a clone

```powershell
git clone https://github.com/volodya7292/claude-token-metrics.git
cd claude-token-metrics
Copy-Item config.example.json config.json   # put your Honeycomb ingest key + dataset in it
powershell -ExecutionPolicy Bypass -File install.ps1
```

`install.ps1` registers (or replaces) the Scheduled Task `ClaudeTokenMetrics` and
starts it immediately. Re-running the installer is safe.

`config.json` is gitignored so your API key never ends up in the repo.

## Uninstall

```powershell
powershell -ExecutionPolicy Bypass -File uninstall.ps1
```

## Event fields

Each run sends one `claude_code.token_usage` event with the overall totals plus
one `claude_code.session_usage` event per session, carrying `session_id`,
`project`, and `title` (the session's first user prompt, truncated to 200
chars) alongside the same token fields.

The overall event (`name = claude_code.token_usage`) contains:

| Field | Meaning |
|---|---|
| `input_tokens` | total non-cached input tokens |
| `output_tokens` | total output tokens |
| `cache_write_tokens` | total prompt-cache write tokens |
| `cache_read_tokens` | total prompt-cache read tokens |
| `total_tokens` | sum of the four above |
| `requests` | number of API requests found |
| `sessions_with_usage` | session files that contained usage data |
| `host`, `user` | machine and user name |

## Querying in Honeycomb

The values are cumulative totals, so plot `MAX(total_tokens)` over time to see
growth, or `MAX(total_tokens) - MIN(total_tokens)` per time bucket for the rate.
Note that `cache_read_tokens` usually dominates by far; for cost estimates,
weight the four token categories with their respective per-model prices.

## Files

- `collect.ps1` — computes totals and posts the event
- `install.ps1` / `uninstall.ps1` — manage the Scheduled Task
- `config.example.json` — template for `config.json`
- `bootstrap.ps1` — clone-free installer (downloads the repo zip and runs `install.ps1`)
- `update.ps1` — hourly self-updater (replaces files when `main` has a new commit)
