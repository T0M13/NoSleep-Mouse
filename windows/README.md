# No Sleep — Mouse (Windows)

Stay-online helper for Windows. **Two ways to run:** a styled web dashboard, or
straight from the console with flags. No installs, no admin — PowerShell and the
Win32 calls it uses both ship with Windows.

## Option A — Web UI (easiest)

1. Double-click **`Start.bat`**.
2. Your browser opens the **No Sleep** dashboard. Flip the switch on, pick an
   interval / direction / distance. It runs quietly in the background.
3. Stop it any of these ways: **close the browser tab** (the background service
   shuts itself down a few seconds later), click **quit** in the dashboard, or run
   **`Stop.bat`**. Use `-KeepAlive` if you want it to keep running after the tab is
   closed.

## Option B — Console / CLI

Run `server.ps1` with flags. Two console modes:

```powershell
# Headless console mode — no web server, just the nudge loop + live log:
powershell -ExecutionPolicy Bypass -File server.ps1 -Console -Interval 30 -Dir circle -Distance 150
powershell -ExecutionPolicy Bypass -File server.ps1 -Console -Method key      # invisible F15
powershell -ExecutionPolicy Bypass -File server.ps1 -Console -Interval 60 -Off # set up but start paused

# Web-server mode, but skip the browser popup and preset values:
powershell -ExecutionPolicy Bypass -File server.ps1 -NoBrowser -On -Interval 45
```

| Flag | Meaning |
|------|---------|
| `-Console` | Headless loop, no web server. Implies "on" unless `-Off`. Ctrl+C to stop. |
| `-Interval <sec>` | Seconds between nudges (5–86400) |
| `-Distance <px>` | Mouse travel distance (1–2000) |
| `-Method mouse\|key` | Visible mouse glide, or invisible F15 keypress |
| `-Dir random\|horizontal\|vertical\|circle` | Mouse movement pattern |
| `-On` / `-Off` | Start enabled / paused |
| `-NoBrowser` | Web mode without auto-opening the browser |
| `-KeepAlive` | Web mode: keep running even after the browser/UI is closed |
| `-Port <n>` | Web server port (default 8787) |

> By default the web service **stops itself when the UI is closed** (it watches for
> the dashboard's heartbeat and exits ~6s after it goes quiet). Pass `-KeepAlive`
> to disable that. `-Console` mode ignores this entirely.

A running web instance can also be driven over its local API, e.g.:

```powershell
Invoke-RestMethod http://localhost:8787/api/config -Method POST -ContentType application/json -Body '{"enabled":true,"intervalSec":30,"moveDir":"circle","moveDistance":150}'
Invoke-RestMethod http://localhost:8787/api/status
Invoke-RestMethod http://localhost:8787/api/quit -Method POST
```

## Settings

- **Interval** — 30s / 1min / 5min or custom (web), or `-Interval` (CLI).
- **Method** — **Mouse** (visible animated glide that returns exactly to where it
  started) or **Key (F15)** (completely invisible).
- **Movement** (mouse) — direction `random` / `horizontal` / `vertical` / `circle`
  and distance in pixels.
- **Active hours** (web UI) — optionally only run between two times; overnight
  ranges like 22:00–06:00 work too.

Settings are saved to `config.json` next to the script and restored next launch.

## Troubleshooting

**It "opens and instantly closes" / the web UI won't load.**
`Start.bat` runs hidden, so you never see the error. Run one of these instead — the
window **stays open** so you can read what happened:

- **`Run-Console.bat`** — visible console mode (no web server, just the jiggler +
  a live log). Best for confirming the core works on this machine.
- **`Debug-WebUI.bat`** — visible web-UI mode with `-KeepAlive`, so it won't
  auto-close while you inspect it. If the UI works here but not from `Start.bat`,
  the auto-close (below) was the cause.

Common causes:
- **Port already in use** — another copy is running, or something else holds
  port 8787. Run `Stop.bat`, or start with `-Port 8788`.
- **Auto-close while using it** — the UI sends a heartbeat; if it goes silent the
  service stops on purpose. Browsers throttle **background tabs**, so leaving the
  dashboard tab in the background used to stop it. The timeout is now generous
  (~90s); use `-KeepAlive` (or `Debug-WebUI.bat`) to disable auto-close entirely.

## Notes

- **First run:** Windows SmartScreen may warn because the scripts aren't
  code-signed → *More info → Run anyway*. Everything stays local; the server only
  listens on `localhost`.
- Keeps you *active* — it doesn't bypass the **lock screen** (`Win+L`).
- Default port is `8787`; change with `-Port` or `$Port` in `server.ps1`.

## Files

| File | What it is |
|------|------------|
| `Start.bat` | Double-click to launch (hidden) + open the UI |
| `Run-Console.bat` | Visible console mode (live log) — for troubleshooting |
| `Debug-WebUI.bat` | Visible web-UI mode (`-KeepAlive`) — for troubleshooting |
| `Stop.bat` | Stops the helper |
| `server.ps1` | The web server + console loop + input nudger |
| `web/` | The dashboard (HTML/CSS/JS, Teko font) |
| `config.json` | Saved settings (created on first change) |
