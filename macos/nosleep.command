#!/usr/bin/env bash
# NoSleep Mouse - macOS  (console-only; no install needed)
#
# Uses macOS's built-in `osascript` (JavaScript for Automation) to nudge real
# input on an interval so apps like Slack/Teams keep you "online".
#
#  >>> BEST-EFFORT / UNTESTED <<<
#  Written without a Mac to test on. It should work, but please verify and
#  report issues. See README.md in this folder.
#
# One-time setup: grant Accessibility permission to your terminal, or the
# synthetic input is silently ignored:
#   System Settings > Privacy & Security > Accessibility > add/enable Terminal
#
# Run:   chmod +x nosleep.command   (first time)
#        ./nosleep.command [-i seconds] [-d pixels] [-r direction] [-m method]
# or just double-click nosleep.command in Finder.
# Stop:  Ctrl+C   (or close the Terminal window)

set -u

INTERVAL=60          # seconds between nudges
DISTANCE=60          # pixels the cursor travels
DIR=random           # random | horizontal | vertical | circle
METHOD=mouse         # mouse | key   (key = invisible F15 press)

usage() {
  cat <<EOF
NoSleep Mouse (macOS)
Usage: ./nosleep.command [-i seconds] [-d pixels] [-r direction] [-m method]
  -i  interval in seconds            (default $INTERVAL)
  -d  distance in pixels             (default $DISTANCE)
  -r  random|horizontal|vertical|circle (default $DIR)
  -m  mouse|key                      (default $METHOD)
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

# JXA: move the cursor (visible glide, returns to start) or press F15.
# Values are inlined from the shell vars above.
read -r -d '' JS <<JSEOF || true
ObjC.import('CoreGraphics');
ObjC.import('Foundation');
var dist = $DISTANCE, dir = "$DIR", method = "$METHOD";
function nil(){ return \$(); }
function post(x,y){ var e = \$.CGEventCreateMouseEvent(nil(), 5, \$.CGPointMake(x,y), 0); \$.CGEventPost(0, e); }
function sleep(s){ \$.NSThread.sleepForTimeInterval(s); }
if (method === "key") {
  var d = \$.CGEventCreateKeyboardEvent(nil(), 113, true);  \$.CGEventPost(0, d);   // 113 = F15
  var u = \$.CGEventCreateKeyboardEvent(nil(), 113, false); \$.CGEventPost(0, u);
} else {
  var loc = \$.CGEventGetLocation(\$.CGEventCreate(nil()));
  var sx = loc.x, sy = loc.y, steps = 14;
  if (dir === "circle") {
    for (var i = 0; i <= steps; i++) { var a = 2*Math.PI*i/steps; post(sx+Math.cos(a)*dist, sy+Math.sin(a)*dist); sleep(0.01); }
  } else {
    var tx = dist, ty = 0;
    if (dir === "vertical") { tx = 0; ty = dist; }
    else if (dir === "random") { var a = Math.random()*2*Math.PI; tx = Math.cos(a)*dist; ty = Math.sin(a)*dist; }
    for (var i = 1; i <= steps; i++) { post(sx+tx*i/steps, sy+ty*i/steps); sleep(0.01); }
    for (var i = steps-1; i >= 0; i--) { post(sx+tx*i/steps, sy+ty*i/steps); sleep(0.01); }
  }
  post(sx, sy);
}
JSEOF

echo "NoSleep (macOS) | method=$METHOD interval=${INTERVAL}s dir=$DIR dist=${DISTANCE}px"
echo "Running. Press Ctrl+C to stop.  (Needs Accessibility permission for your terminal.)"

count=0
while true; do
  osascript -l JavaScript -e "$JS" >/dev/null 2>&1
  count=$((count + 1))
  echo "[$(date +%H:%M:%S)] nudge #$count"
  sleep "$INTERVAL"
done
