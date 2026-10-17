#!/usr/bin/env bash
# Drive a running CK3 window: screenshots, clicks, keys, console commands, run files, logs.
# Backends: macOS (screencapture, cliclick, osascript) and Linux X11 (xdotool, ImageMagick).
# Coordinates for `click` are pixels in the 1400px-wide screenshot produced by `shot`.
set -euo pipefail

ROOT=$(git -C "$(dirname "$0")" rev-parse --show-toplevel)
set -a; . "$ROOT/.env"; set +a
BIN="$CK3_BASE_DIR/../binaries"
SHOTS=${CK3_SHOT_DIR:-${TMPDIR:-/tmp}/ck3-shots}
SMALL=1400   # width of the downscaled screenshot that click coordinates refer to
MAXLINE=255  # console input limit; longer input overflows into game hotkeys
mkdir -p "$SHOTS"
OS=$(uname)

die() { echo "ck3.sh: $*" >&2; exit 2; }

# --- platform primitives ---------------------------------------------------

if [ "$OS" = Darwin ]; then
  activate() { open -a "$BIN/ck3.app"; sleep 1; }
  # window origin and size in points, title bar included (matches screencapture -R)
  geometry() {
    osascript -e 'tell application "System Events" to tell (first process whose name is "ck3") to get {position, size} of window 1' | tr -d ' ' | tr ',' ' '
  }
  capture() { read -r X Y W H <<< "$(geometry)"; screencapture -x -R"$X,$Y,$W,$H" "$1"; }
  resize() { sips -Z "$SMALL" "$1" --out "$2" > /dev/null; }
  click_abs() { cliclick "c:$1,$2"; }
  keycode() {
    case $1 in
      console) echo "${CK3_CONSOLE_KEYCODE:-10}" ;; # ISO §/± key; ANSI ` key is 50
      space) echo 49 ;; enter) echo 36 ;; esc) echo 53 ;; tab) echo 48 ;;
      up) echo 126 ;; down) echo 125 ;; f10) echo 109 ;;
      1) echo 18 ;; 2) echo 19 ;; 3) echo 20 ;; 4) echo 21 ;; 5) echo 23 ;;
      *) die "unknown key: $1" ;;
    esac
  }
  press() { osascript -e "tell application \"System Events\" to key code $(keycode "$1")"; }
  typetext() {
    osascript -e 'on run argv' -e 'tell application "System Events" to keystroke (item 1 of argv)' -e 'end run' -- "$1"
  }
  launch_bin() { open -a "$BIN/ck3.app"; }
elif [ "$OS" = Linux ]; then
  [ "${XDG_SESSION_TYPE:-x11}" = x11 ] || die "only X11 sessions are supported"
  winid() { xdotool search --name '^Crusader Kings III$' | head -1; }
  activate() { xdotool windowactivate --sync "$(winid)"; sleep 0.5; }
  # client-area origin and size in pixels (matches import -window and mousemove --window)
  geometry() {
    eval "$(xdotool getwindowgeometry --shell "$(winid)")"
    echo "$X $Y $WIDTH $HEIGHT"
  }
  capture() { import -window "$(winid)" "$1"; }
  resize() { convert "$1" -resize "${SMALL}x" "$2"; }
  click_abs() { xdotool mousemove "$1" "$2" click 1; }
  keyname() {
    case $1 in
      console) echo "${CK3_CONSOLE_KEY:-grave}" ;; # key below Esc
      space) echo space ;; enter) echo Return ;; esc) echo Escape ;; tab) echo Tab ;;
      up) echo Up ;; down) echo Down ;; f10) echo F10 ;;
      1|2|3|4|5) echo "$1" ;;
      *) die "unknown key: $1" ;;
    esac
  }
  press() { xdotool key "$(keyname "$1")"; }
  typetext() { xdotool type --delay 12 -- "$1"; }
  launch_bin() { (cd "$BIN" && nohup ./ck3 > /dev/null 2>&1 &); }
else
  die "unsupported OS: $OS"
fi

# --- commands --------------------------------------------------------------

cmd_launch() {
  local playset="$CK3_USER_DIR/dlc_load.json"
  echo "enabled mods: $(cat "$playset")"
  grep -q CrusaderKings3UnofficialPatch "$playset" || die "Unop is not enabled; select the playset in the launcher first"
  launch_bin
}

cmd_shot() {
  local name=${1:?shot <name>}
  activate
  capture "$SHOTS/$name.png"
  resize "$SHOTS/$name.png" "$SHOTS/${name}_small.png"
  echo "$SHOTS/${name}_small.png"
}

cmd_click() {
  local sx=${1:?click <x> <y>} sy=${2:?click <x> <y>} X Y W H
  activate
  read -r X Y W H <<< "$(geometry)"
  click_abs $((X + sx * W / SMALL)) $((Y + sy * W / SMALL))
}

cmd_key() { activate; for k in "$@"; do press "$k"; sleep 0.3; done; }

cmd_cmd() {
  local line=${1:?cmd <console line>}
  [ ${#line} -le $MAXLINE ] || die "line is ${#line} chars, limit is $MAXLINE; use a run file"
  activate; typetext "$line"; sleep 0.3; press enter
}

cmd_run() {
  local src=${1:?run <effect file>} name
  name="claude_$(date +%Y%m%d_%H%M%S)_$(basename "$src")"
  mkdir -p "$CK3_USER_DIR/run"
  { printf '\xef\xbb\xbf'; cat "$src"; } > "$CK3_USER_DIR/run/$name"
  echo "run/$name"
  cmd_cmd "run $name"
}

cmd_mark() {
  for l in error debug; do wc -l < "$CK3_USER_DIR/logs/$l.log" | tr -d ' '; done > "$SHOTS/.logmark"
}

cmd_new() {
  local log=${1:-error} idx n cur
  [ "$log" = error ] && idx=1 || idx=2
  n=$(sed -n "${idx}p" "$SHOTS/.logmark" 2>/dev/null || echo 0)
  cur=$(wc -l < "$CK3_USER_DIR/logs/$log.log")
  [ "$cur" -ge "$n" ] || n=0   # log was recreated by a game restart
  tail -n +$((n + 1)) "$CK3_USER_DIR/logs/$log.log"
}

case ${1:-} in
  launch|shot|click|key|cmd|run|mark|new) c=$1; shift; "cmd_$c" "$@" ;;
  *) sed -n '2,5p' "$0"; echo "usage: ck3.sh launch | shot <name> | click <x> <y> | key <key>... | cmd <line> | run <file> | mark | new [error|debug]"; exit 1 ;;
esac
