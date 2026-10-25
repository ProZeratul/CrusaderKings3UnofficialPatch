#!/usr/bin/env bash
# Drive a running CK3 window: screenshots, clicks, keys, console commands, run files, logs.
# Backends: macOS (screencapture, cliclick, osascript) and Linux X11 (xdotool, ImageMagick, xclick.py).
# Coordinates for `click` are pixels in the 1400px-wide screenshot produced by `shot`.
set -euo pipefail

ROOT=$(git -C "$(dirname "$0")" rev-parse --show-toplevel)
set -a; . "$ROOT/.env"; set +a
BIN="$CK3_BASE_DIR/../binaries"
SHOTS=${CK3_SHOT_DIR:-${TMPDIR:-/tmp}/ck3-shots}
SMALL=1400   # width of the downscaled screenshot that click coordinates refer to
MAXLINE=255  # console input limit; longer input overflows into game hotkeys
DEBUG_LOG="$CK3_USER_DIR/logs/debug.log"
MOD="$CK3_USER_DIR/mod/CrusaderKings3UnofficialPatch.mod"
MOD_ORIG="$CK3_USER_DIR/mod/.CrusaderKings3UnofficialPatch.mod.orig"  # saved by launch --mod
PIDFILE="$CK3_USER_DIR/.claude-ck3.pid"  # the game started by launch; exit kills only this one
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
  # crop <in> <out> <x> <y> <w> <h>, region in 1400px coordinates
  crop() {
    local f=$(( $(sips -g pixelWidth "$1" | awk '/pixelWidth/ {print $2}') ))
    sips -c $(($6 * f / SMALL)) $(($5 * f / SMALL)) --cropOffset $(($4 * f / SMALL)) $(($3 * f / SMALL)) "$1" --out "$2" > /dev/null
  }
  click_abs() { cliclick "c:$1,$2"; }
  hover_abs() { cliclick "m:$1,$2"; }
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
  launch_bin() { open -a "$BIN/ck3.app" --args -debug_mode; }
  running() { pgrep -x ck3 > /dev/null; }
  game_pid() { pgrep -x ck3 | head -1; }
  is_game() { [ "$(ps -p "$1" -o comm= 2>/dev/null | xargs basename 2>/dev/null)" = ck3 ]; }
elif [ "$OS" = Linux ]; then
  [ "${XDG_SESSION_TYPE:-x11}" = x11 ] || die "only X11 sessions are supported"
  # match the window class, not the title
  winid() {
    local w
    w=$(xdotool search --onlyvisible --class '^ck3$' | head -1)
    [ -n "$w" ] || die "CK3 window not found"
    echo "$w"
  }
  # input is sent to the window directly (synthetic events)
  activate() { WID=$(winid); }
  # origin 0 0: click coordinates are window-relative
  geometry() { xwininfo -id "$WID" | awk '/^ *Width/ {w=$NF} /^ *Height/ {h=$NF} END {print 0, 0, w, h}'; }
  capture() { import -window "$WID" -depth 8 -define png:compression-level=1 "$1"; }
  resize() { convert "$1" -resize "${SMALL}x" "$2"; }
  # crop <in> <out> <x> <y> <w> <h>, region in 1400px coordinates
  crop() {
    local f
    f=$(identify -format %w "$1")
    convert "$1" -crop "$(($5 * f / SMALL))x$(($6 * f / SMALL))+$(($3 * f / SMALL))+$(($4 * f / SMALL))" +repage "$2"
  }
  click_abs() { python3 -I "$(dirname "$0")/xclick.py" "$WID" "$1" "$2"; }
  hover_abs() { python3 -I "$(dirname "$0")/xclick.py" "$WID" "$1" "$2" hover; }
  keyname() {
    case $1 in
      console) echo "${CK3_CONSOLE_KEY:-grave}" ;; # key below Esc
      space) echo space ;; enter) echo Return ;; esc) echo Escape ;; tab) echo Tab ;;
      up) echo Up ;; down) echo Down ;; f10) echo F10 ;;
      1|2|3|4|5) echo "$1" ;;
      *) die "unknown key: $1" ;;
    esac
  }
  press() { xdotool key --window "$WID" "$(keyname "$1")"; }
  typetext() { xdotool type --window "$WID" --delay 12 -- "$1"; }
  # redirect the subshell too: an inherited stdout pipe would block callers like `launch | tail`
  launch_bin() { (cd "$BIN" && exec nohup ./ck3 -debug_mode) < /dev/null > /dev/null 2>&1 & }
  # the game renames its main thread, so match the command line, not the process name
  running() { pgrep -f '(^|/)ck3( |$)' > /dev/null; }
  game_pid() { pgrep -f '(^|/)ck3( |$)' | head -1; }
  is_game() { [ -r "/proc/$1/cmdline" ] && tr '\0' ' ' < "/proc/$1/cmdline" | grep -Eq '(^|/)ck3( |$)'; }
else
  die "unsupported OS: $OS"
fi

# --- helpers ---------------------------------------------------------------

# Point the Unop descriptor at another checkout (e.g. a PR worktree); the original is kept in $MOD_ORIG.
set_mod() {
  local dir
  dir=$(cd "$1" && pwd) || die "no such directory: $1"
  [ -f "$dir/descriptor.mod" ] || die "not a Unop checkout (no descriptor.mod): $dir"
  [ -f "$MOD_ORIG" ] || cp "$MOD" "$MOD_ORIG"
  sed "s|^path=.*|path=\"$dir\"|" "$MOD_ORIG" > "$MOD"
}

restore_mod() { if [ -f "$MOD_ORIG" ]; then cp "$MOD_ORIG" "$MOD"; rm "$MOD_ORIG"; fi; }

# Wait up to <timeout> s for a debug.log line containing <text>, logged at or after <HH:MM:SS>.
# Timestamps rather than line counts, since the game recreates the log on start.
wait_log() {
  local text=$1 since=$2 timeout=$3 i
  for ((i = 0; i < timeout; i++)); do
    awk -v t="$text" -v s="$since" 'index($0, t) && substr($0, 2, 8) >= s { f = 1 } END { exit !f }' \
      "$DEBUG_LOG" 2>/dev/null && return 0
    sleep 1
  done
  return 1
}

# --- commands --------------------------------------------------------------

cmd_launch() {
  local playset="$CK3_USER_DIR/dlc_load.json" mod="" start
  if [ "${1:-}" = --mod ]; then mod=${2:?launch --mod <dir>}; fi
  running && die "CK3 is already running (the user or another agent is using it)"
  grep -q CrusaderKings3UnofficialPatch "$playset" || die "Unop is not enabled; select the playset in the launcher first"
  restore_mod
  [ -z "$mod" ] || set_mod "$mod"
  echo "enabled mods: $(cat "$playset")"
  grep '^path=' "$MOD"
  start=$(date +%H:%M:%S)
  launch_bin
  # the frontend is up; history loads in the background (slowly while the window is unfocused),
  # which only Continue and Load wait for, not starting a new game
  wait_log "Setting idler 'Frontend'" "$start" 300 || die "main menu not ready after 300 s"
  game_pid > "$PIDFILE"
  sleep 2
  echo "main menu ready ($start -> $(date +%H:%M:%S)), debug mode on, pid $(cat "$PIDFILE")"
}

cmd_exit() {
  # kill the game that launch started (no exit dialog, no autosave), then restore the Unop descriptor
  local pid i
  pid=$(cat "$PIDFILE" 2>/dev/null) || pid=""
  if [ -n "$pid" ] && is_game "$pid"; then
    kill -9 "$pid"
    for ((i = 0; i < 30; i++)); do is_game "$pid" || break; sleep 1; done
    is_game "$pid" && die "pid $pid still running after kill"
  elif running; then
    die "CK3 is running but wasn't started by launch; not killing it"
  fi
  rm -f "$PIDFILE"
  restore_mod
  grep '^path=' "$MOD"
}

cmd_wait() {
  case ${1:-} in
    game)
      # needs a `mark` before starting or loading the game
      local i timeout=${2:-300}
      for ((i = 0; i < timeout; i++)); do
        cmd_new debug | grep "Setting idler 'In Game'" > /dev/null && { sleep 3; echo "in game"; return 0; }
        sleep 1
      done
      die "game not loaded after $timeout s; take a shot: if it shows the main menu, the clicks were lost" ;;
    *) die "wait game [<seconds>]" ;;
  esac
}

cmd_start() {
  # New Game -> bookmark tab -> first featured character -> Start, then wait until loaded.
  # Positions are in 1400px screenshot coordinates. Each click is sent twice: the frontend renders
  # slowly in the background and sometimes only registers the hover, and repeating is harmless.
  local tab char
  case ${1:-} in
    867) tab="515 16"; char="805 240" ;;   # Rurik Rurikid
    1066) tab="668 16"; char="760 262" ;;  # Duke Vratislav
    1178) tab="822 16"; char="655 652" ;;  # Taira Kiyomori
    *) die "start <867|1066|1178>" ;;
  esac
  cmd_mark
  cmd_click 327 303; sleep 3; cmd_click 327 303; sleep 3   # New Game
  cmd_click $tab; sleep 2; cmd_click $tab; sleep 3
  cmd_click $char; sleep 1; cmd_click $char; sleep 2
  # the bookmark's name and date and the selected character, to Read if in doubt
  cmd_shot start_bookmark 1090 35 290 345 > /dev/null
  echo "bookmark: $SHOTS/start_bookmark_crop.png"
  cmd_click 1235 704   # Start
  cmd_wait game 120    # loading takes 20-55 s
}

cmd_shot() {
  local name=${1:?shot <name> [<x> <y> <w> <h>]}
  activate
  capture "$SHOTS/$name.png"
  if [ $# -ge 5 ]; then
    # a region given in 1400px coordinates, at full resolution
    crop "$SHOTS/$name.png" "$SHOTS/${name}_crop.png" "$2" "$3" "$4" "$5"
    echo "$SHOTS/${name}_crop.png"
  else
    resize "$SHOTS/$name.png" "$SHOTS/${name}_small.png"
    echo "$SHOTS/${name}_small.png"
  fi
  rm -f "$SHOTS/$name.png"  # full-size captures are 6-16 MB each
}

cmd_click() {
  local sx=${1:?click <x> <y>} sy=${2:?click <x> <y>} X Y W H
  activate
  read -r X Y W H <<< "$(geometry)"
  click_abs $((X + sx * W / SMALL)) $((Y + sy * W / SMALL))
}

cmd_hover() {
  local sx=${1:?hover <x> <y>} sy=${2:?hover <x> <y>} X Y W H
  activate
  read -r X Y W H <<< "$(geometry)"
  hover_abs $((X + sx * W / SMALL)) $((Y + sy * W / SMALL))
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
  launch|start|wait|exit|shot|click|hover|key|cmd|run|mark|new) c=$1; shift; "cmd_$c" "$@" ;;
  *) sed -n '2,5p' "$0"; echo "usage: ck3.sh launch [--mod <dir>] | start <867|1066|1178> | wait game | exit | shot <name> [<x> <y> <w> <h>] | click <x> <y> | hover <x> <y> | key <key>... | cmd <line> | run <file> | mark | new [error|debug]"; exit 1 ;;
esac
