---
name: unop-drive-game
description: Launch CK3 with Unop and drive it via screenshots, clicks, keys, console commands, and run files to set up and verify fixes in-game
argument-hint: "[what to set up or verify]"
---

# Drive CK3 In-Game

Launch CK3 in debug mode, set up a situation via console effects while paused, let a few days pass at speed 1, then inspect the result in screenshots and logs.

All interaction goes through [ck3.sh](ck3.sh) (macOS and Linux X11; Linux clicks use [xclick.py](xclick.py)). It reads `CK3_BASE_DIR` and `CK3_USER_DIR` from `.env`.

## Prerequisites

- The game is configured for **windowed** mode at a large resolution (e.g. 2992x1870 on a 16" Retina Mac, 3200x1800 on a 4K Linux screen). The positions below are for a UI scale of 150%; in-game positions change with the UI scale.
- The active playset contains only **Unop** (and optionally **Debug Toggle**). `launch` checks `dlc_load.json`, which the launcher writes on PLAY.
- Steam is running.
- The first direct `launch` may show one-time prompts that the user must answer: macOS asking to let `ck3.app` access Documents, and the Paradox user agreement in the main menu. Don't answer them yourself.
- macOS: the terminal app has **Accessibility** and **Screen Recording** permissions; `cliclick` is installed.
- Linux: an X11 session; `xdotool`, `imagemagick` and `python3` are installed.

## Helper

Set `CK3_SHOT_DIR` to your scratchpad directory, then run `<base>/ck3.sh <command>`, where `<base>` is this skill's base directory as an absolute path.

| Command | Effect |
|---|---|
| `launch [--mod <dir>]` | Start the game binary directly, bypassing the launcher, and wait for the main menu. Refuses if CK3 is already running. `--mod` loads Unop from `<dir>` (e.g. a PR worktree) instead of the descriptor's path |
| `start <867\|1066\|1178>` | From the main menu: New Game, the bookmark, its first featured character (Rurik, Vratislav, Kiyomori), Start, and wait until loaded. Prints a crop of the bookmark's name and date and the selected character |
| `wait game [<s>]` | After `mark` and starting or loading a game by hand, wait until it's loaded (default timeout 300 s) |
| `exit` | Kill the game that `launch` started and restore the Unop descriptor's path. Refuses to kill a game it didn't start |
| `shot <name> [<x> <y> <w> <h>]` | Capture the CK3 window; prints the path of a 1400px-wide copy to Read, or of a full-resolution crop of the given region (1400px coordinates) |
| `click <x> <y>` | Click at pixel coordinates **of the 1400px screenshot** |
| `hover <x> <y>` | Move the pointer there without clicking, e.g. to show a tooltip |
| `key <key>...` | Press keys: `console`, `space`, `enter`, `esc`, `tab`, `up`, `down`, `f10`, `1`-`5` |
| `cmd <line>` | Type a console line and press Enter; refuses lines over 255 chars |
| `run <file>` | Copy an effect file to `run/claude_<timestamp>_<name>` (UTF-8 BOM) and execute it |
| `mark` | Remember the current length of `error.log` and `debug.log` |
| `new [error\|debug]` | Print log lines added since the last `mark` |

On macOS, every command activates the CK3 window first. On Linux, input is sent to the CK3 window directly, so it stays in the background and the user keeps focus and pointer.

Only one game runs at a time. If `launch` refuses because CK3 is running, the user or another agent is using it: stop, don't drive that game.

## Workflow

1. **Launch.** `launch` (about 15 s to the main menu). The MP checksum (bottom right of the main menu) tells different mod versions apart.
2. **Start a game.** `start <year>` (about 30 s), then switch to the character you need (see Console). Take a `shot`: a start event (e.g. 1178 Japan) may cover the screen; dismiss it before going on.
   - By hand: `mark`, start, `wait game`. The Character of the Week panel's **Start** also starts 1066, but its character changes weekly and it appears only once the menu has fully loaded.
   - **Continue** and **Load** stay greyed out until the history has loaded, which is slow while the window is in the background.
   - The loading screen can stay up a few seconds after `wait game` returns.
3. **Pause and set the speed.** `key 1` sets speed 1; `key space` toggles pause. Do all setup while paused. The game starts at a faster speed, so set speed 1 before letting time pass.
4. **Set up.** `key console` opens/closes the console. Take a `shot` to confirm it's open with an empty input before the first `cmd`. Run effects with `cmd` or `run` (see below).
5. **Let time pass.** `key space`, wait, `key space`. Speed 1 runs at about **2 s per game day**; pausing overshoots by about a day. Check the date (bottom right) and the "Paused" banner in a `shot`.
6. **Inspect.** Prefer logs over screenshots: `new error` for errors, `new debug` for `debug_log` output. `mark` before the step you want to isolate. `debug.log` is buffered: while the game is paused, new lines can take up to a minute to appear; run `cmd help` (thousands of output lines) to flush it. For text on screen, `shot` with a region crops just that part, which is cheaper and easier to read. Toasts disappear after a few seconds, so `shot` right after the command that sends one.
7. **Exit.** `exit` kills the game at once. Nothing is saved, so the user's `autosave_exit` is safe, but unflushed log lines are lost: read the logs (flush with `cmd help` if needed) before `exit`.

`launch` starts the game with `-debug_mode`, so the console works from the first game day. Debug mode stays on for the whole session.

Take a `shot` and Read it before clicking somewhere new, and after, to confirm the result. Positions don't change within a session, so a known button (e.g. **Start**, **≡**) can be clicked again without a new `shot`.

## Console

- `effect <effects>` executes any script effects in the player's scope, so special commands are rarely needed. No `effect = { }` wrapper (removed in 1.18).
- **Console lines are limited to 255 chars**, including `effect `. A longer line is truncated silently and runs partially (the cut-off part logs `Unknown effect` in `error.log`), and the overflowing keystrokes reach the game as hotkeys (WASD pans the camera, space toggles pause).
- For anything longer, write an effect file and use `run <file>`. `root` is the player. Use a new file per run (the helper does this) rather than overwriting `run/run.txt`.
- Inspect state from effects with `debug_log = "..."` and `debug_log_scopes = yes` (output in `debug.log`); evaluate triggers with `if = { limit = { ... } debug_log = "yes" } else = { debug_log = "no" }`.
- Target other characters with `character:<id> = { ... }`. The id is the **historical** id (from history files, shown in debug tooltips); characters created or born after game start don't have one and can only be reached via a relation to `root` filtered by e.g. traits (`random_courtier = { limit = { has_trait = ... } ... }`), or via `save_scope_as` within one run file, so prefer testing with historical characters.
- **Switch characters with `effect set_player_character = character:<id>`.** `play <id>` takes the game's internal id, which differs between runs, not the historical id. Switching to a landless character (e.g. a Japanese or Chinese emperor who holds only a special title) is an immediate Game Over; look at them from a landed character instead. If it happens, the console still works, but **Exit to Menu** and a new start are the reliable way out.
- **Open any window with `open_view_data`**, e.g. `effect open_view_data = { view = character data = character:<id> player = root }`. Other views: `title_view_window` (data: `title:<key>`), `holding_view`, `decision_detail`, `royal_court`, `my_realm`. This is cheaper than finding the window through the UI.
- `debug_log` writes to `debug.log`, not `game.log`. It resolves localization: `debug_log = <loc_key>` prints the text, and data functions work, e.g. `debug_log = "gov [THIS.Char.GetGovernment.GetName]"`. Reading state this way is cheaper than finding it in the UI.
- **Decisions and interactions from the console:** `execute_decision = <key>` takes a decision (its cost is still checked). `run_interaction = { interaction = <key> actor = root recipient = <character> execute_threshold = decline }` runs an interaction; `open_interaction_window = { interaction = <key> actor = root recipient = <character> target_title = <title> }` opens its window, e.g. for title interactions, which `run_interaction` can't target. Check validity with `is_character_interaction_valid = { recipient = <character> interaction = <key> }`.
- `trigger_event = { on_action = <key> }` respects `random_events`' `chance_to_happen`, so one call may fire nothing even with a raised weight; repeat it.
- `instabuild` plus `begin_create_holding = <type>` in an empty province builds a holding after one game day.
- Generic scopes may pick existing state: `random_character_war` can pick a war the bookmark character already fights. Narrow them, e.g. `random_character_war = { limit = { using_cb = depose_war } ... }`.
- Typed text is appended to whatever is already in the console input; keep it empty.
- Useful commands: `observe`, `event <event_id> [character_id]`, `set_date <y.m.d>`, `instant_*`/`insta*` toggles, `help [command]`. `tab` autocompletes. See [Console commands](https://ck3.paradoxwikis.com/Console_commands).

## Pitfalls

- **Chain helper commands with `&&` or `set -e`.** After a failed step, later clicks and keys land on the wrong screen.
- Esc closes the open window more reliably than its close button.
- **Don't touch the CK3 window while driving it.** Mouse movement over the window edge pans the map (edge scrolling); on macOS, Cmd+H hides the game until the next helper command.
- **A click that only shows a tooltip didn't register;** click again. The game renders slowly in the background.
- **Clicks chained across screen changes can be dropped.** After a click that changes the screen, check with a `shot` (or a crop) before relying on it.
- **Keys sent outside the console are hotkeys.** If a console line doesn't seem to have run, take a `shot`: the game may have unpaused, opened windows or panned the map.
- Hover tooltips (e.g. debug province IDs) stay where the last click left the cursor and may cover parts of the screen.
- macOS: the console key defaults to ISO `§`/`±` (key code 10); set `CK3_CONSOLE_KEYCODE=50` for ANSI keyboards. Linux: defaults to `grave`; override with `CK3_CONSOLE_KEY`.
- If a session ends without `exit` after `launch --mod`, the next `launch` restores the descriptor's path.

## Platform Status

- macOS: tested with CK3 1.19 (before `launch --mod`, `-debug_mode`, `start`, `wait` and `exit`).
- Linux X11: tested with CK3 1.20 (GNOME on X11).
