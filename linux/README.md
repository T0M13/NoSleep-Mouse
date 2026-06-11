# No Sleep — Mouse (Linux)

Console stay-online helper for Linux. Nudges real input on an interval so apps
like Slack/Teams keep you "online".

> ⚠️ **Best-effort / untested.** Written without a Linux box to test on. Please
> verify and report issues.

## Requirement: an input tool

Linux has no universal built-in way to inject input, so you need **one** of:

| Session | Tool | Install |
|---------|------|---------|
| **X11** | `xdotool` | `sudo apt install xdotool` · `sudo dnf install xdotool` · `sudo pacman -S xdotool` |
| **Wayland** | `ydotool` | `sudo apt install ydotool` (also run the `ydotoold` daemon; needs input-device perms) |

Not sure which you have? Run `echo $XDG_SESSION_TYPE`. The script auto-detects and
prefers `ydotool` on Wayland, `xdotool` on X11.

## Run

```bash
chmod +x nosleep.sh           # first time only
./nosleep.sh                                   # defaults: mouse, random, 60px, every 60s
./nosleep.sh -i 30 -r circle -d 150            # circle, 150px, every 30s
./nosleep.sh -m key                            # invisible F15 press
```

Stop with **Ctrl+C**, or from another shell: `pkill -f nosleep.sh`.

| Flag | Meaning |
|------|---------|
| `-i <sec>` | Interval in seconds (default 60) |
| `-d <px>` | Mouse travel distance (default 60) |
| `-r random\|horizontal\|vertical\|circle` | Movement pattern (default random) |
| `-m mouse\|key` | Visible mouse glide, or invisible F15 (default mouse) |
| `-h` | Help |

## Notes

- **Wayland is stricter:** `ydotool` needs its daemon (`ydotoold`) running and your
  user in the right input group, or it needs root. `xdotool` does **not** work on
  pure Wayland (only X11 / XWayland).
- Only works on this machine, while it's running; won't override a locked/sleeping
  session.
- The `key` method sends F15 (`xdotool key F15` / `ydotool key 185:1 185:0`).
