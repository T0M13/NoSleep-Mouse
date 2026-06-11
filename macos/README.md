# No Sleep — Mouse (macOS)

Console stay-online helper for macOS. Uses the **built-in `osascript`** (JavaScript
for Automation) to nudge real input — **no install needed.**

> ⚠️ **Best-effort / untested.** This was written without a Mac to test on. It
> should work, but please verify and report issues.

## One-time setup: Accessibility permission

macOS blocks synthetic input unless the app running it has Accessibility access.
Grant it once:

**System Settings → Privacy & Security → Accessibility →** enable (or add with `+`)
your terminal app (Terminal, iTerm, etc.).

Without this, the script runs but the cursor won't move / the key won't register.

## Run

```bash
chmod +x nosleep.command      # first time only
./nosleep.command                              # defaults: mouse, random, 60px, every 60s
./nosleep.command -i 30 -r circle -d 150       # circle, 150px, every 30s
./nosleep.command -m key                       # invisible F15 press
```

Or just **double-click `nosleep.command`** in Finder (opens in Terminal).

Stop with **Ctrl+C** or by closing the Terminal window.

| Flag | Meaning |
|------|---------|
| `-i <sec>` | Interval in seconds (default 60) |
| `-d <px>` | Mouse travel distance (default 60) |
| `-r random\|horizontal\|vertical\|circle` | Movement pattern (default random) |
| `-m mouse\|key` | Visible mouse glide, or invisible F15 (default mouse) |
| `-h` | Help |

## How it works

Each interval it runs a small JXA snippet that posts `CGEvent` mouse-move events
(animated glide that returns to where your cursor started) or an F15 keypress.
Real events reset the system idle timer, which is what keeps Slack/Teams "active".

## Limits

- Only works on this Mac, while it's running.
- Won't override the **lock screen** or sleep.
- Slack in a browser tab is less reliable than the desktop app (browser presence
  leans on tab focus, not just OS idle).
