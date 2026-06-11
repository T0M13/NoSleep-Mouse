#!/usr/bin/env bash
# NoSleep Mouse - Linux  (console-only)
#
# Nudges real input on an interval so apps like Slack/Teams keep you "online".
#
#  >>> BEST-EFFORT / UNTESTED <<<
#  Written without a Linux box to test on. Please verify and report issues.
#
# Linux has no universal built-in way to inject input, so this needs ONE tool:
#   X11     -> xdotool
#   Wayland -> ydotool   (also needs the `ydotoold` daemon running + input perms)
# Install:
#   Debian/Ubuntu:  sudo apt install xdotool      # or: ydotool
#   Fedora:         sudo dnf install xdotool       # or: ydotool
#   Arch:           sudo pacman -S xdotool         # or: ydotool
#
# Run:   chmod +x nosleep.sh   (first time)
#        ./nosleep.sh [-i seconds] [-d pixels] [-r direction] [-m method]
# Stop:  Ctrl+C   (or:  pkill -f nosleep.sh)

set -u

INTERVAL=60          # seconds between nudges
DISTANCE=60          # pixels the cursor travels
DIR=random           # random | horizontal | vertical | circle
METHOD=mouse         # mouse | key   (key = invisible F15 press)

usage() {
  cat <<EOF
NoSleep Mouse (Linux)
Usage: ./nosleep.sh [-i seconds] [-d pixels] [-r direction] [-m method]
  -i  interval in seconds               (default $INTERVAL)
  -d  distance in pixels                (default $DISTANCE)
  -r  random|horizontal|vertical|circle (default $DIR)
  -m  mouse|key                         (default $METHOD)
  -h  show this help
Stop with Ctrl+C.
EOF
}

while getopts "i:d:r:m:h" opt; do
  case "$opt" in
    i) INTERVAL=$OPTARG ;;
    d) DISTANCE=$OPTARG ;;
    r) DIR=$OPTARG ;;
    m) METHOD=$OPTARG ;;
    h) usage; exit 0 ;;
    *) usage; exit 1 ;;
  esac
done

# --- pick a backend ---
BACKEND=""
if [ "${XDG_SESSION_TYPE:-}" = "wayland" ] || [ -n "${WAYLAND_DISPLAY:-}" ]; then
  command -v ydotool >/dev/null 2>&1 && BACKEND=ydotool
fi
[ -z "$BACKEND" ] && command -v xdotool >/dev/null 2>&1 && BACKEND=xdotool
[ -z "$BACKEND" ] && command -v ydotool >/dev/null 2>&1 && BACKEND=ydotool
if [ -z "$BACKEND" ]; then
  echo "ERROR: no input tool found. Install 'xdotool' (X11) or 'ydotool' (Wayland)." >&2
  echo "       e.g. sudo apt install xdotool" >&2
  exit 1
fi

move_rel() { # dx dy  (relative move)
  if [ "$BACKEND" = "xdotool" ]; then
    xdotool mousemove_relative -- "$1" "$2"
  else
    ydotool mousemove -x "$1" -y "$2"      # ydotool is relative by default
  fi
}

press_key() {
  if [ "$BACKEND" = "xdotool" ]; then
    xdotool key F15
  else
    ydotool key 185:1 185:0                # 185 = KEY_F15 (evdev)
  fi
}

nudge() {
  if [ "$METHOD" = "key" ]; then press_key; return; fi

  local tx ty
  case "$DIR" in
    horizontal) tx=$DISTANCE; ty=0 ;;
    vertical)   tx=0; ty=$DISTANCE ;;
    circle)
      # 8 points around a circle, deltas sum to ~0 (returns near start)
      # offset by -DISTANCE on x so point 0 and the final point are both (0,0)
      local pts=8 i a px py prevx=0 prevy=0
      for i in $(seq 0 $pts); do
        a=$(awk "BEGIN{print 2*3.141592653589793*$i/$pts}")
        px=$(awk "BEGIN{printf \"%d\", (cos($a)-1)*$DISTANCE}")
        py=$(awk "BEGIN{printf \"%d\", sin($a)*$DISTANCE}")
        move_rel $((px - prevx)) $((py - prevy))
        prevx=$px; prevy=$py
        sleep 0.02
      done
      return ;;
    *)  # random
      local ang; ang=$((RANDOM % 360))
      tx=$(awk "BEGIN{printf \"%d\", cos($ang*3.141592653589793/180)*$DISTANCE}")
      ty=$(awk "BEGIN{printf \"%d\", sin($ang*3.141592653589793/180)*$DISTANCE}") ;;
  esac

  # glide out then back to exactly where we started
  move_rel "$tx" "$ty"
  sleep 0.15
  move_rel "$((-tx))" "$((-ty))"
}

echo "NoSleep (Linux/$BACKEND) | method=$METHOD interval=${INTERVAL}s dir=$DIR dist=${DISTANCE}px"
echo "Running. Press Ctrl+C to stop."

count=0
while true; do
  nudge
  count=$((count + 1))
  echo "[$(date +%H:%M:%S)] nudge #$count"
  sleep "$INTERVAL"
done
