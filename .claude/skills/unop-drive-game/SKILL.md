---
name: unop-drive-game
description: Launch CK3 with Unop and drive it via screenshots, clicks, keys, console commands, and run files to set up and verify fixes in-game
argument-hint: "[what to set up or verify]"
---

# Drive CK3 In-Game

Launch CK3, enable debug mode, set up a situation via console effects while paused, let a few days pass at speed 1, then inspect the result in screenshots and logs.

All interaction goes through [ck3.sh](ck3.sh) (macOS and Linux X11). It reads `CK3_BASE_DIR` and `CK3_USER_DIR` from `.env`.

## Prerequisites

- The game is configured for **windowed** mode at a large resolution (e.g. 2992x1870 on a 16" Retina Mac).
- The active playset contains only **Unop** and **Debug Toggle**. `launch` checks `dlc_load.json`, which the launcher writes on PLAY.
- Steam is running.
- The first direct `launch` may show one-time prompts that the user must answer: macOS asking to let `ck3.app` access Documents, and the Paradox user agreement in the main menu. Don't answer them yourself.
- macOS: the terminal app has **Accessibility** and **Screen Recording** permissions; `cliclick` is installed.
- Linux: an X11 session; `xdotool` and `imagemagick` are installed.

## Helper

Set `CK3_SHOT_DIR` to your scratchpad directory, then run `.claude/skills/unop-drive-game/ck3.sh <command>`:

| Command | Effect |
|---|---|
| `launch` | Check the playset in `dlc_load.json` and start the game binary directly, bypassing the launcher |
| `shot <name>` | Bring CK3 to front, capture its window; prints the path of a 1400px-wide copy to Read |
| `click <x> <y>` | Click at pixel coordinates **of the 1400px screenshot** |
| `key <key>...` | Press keys: `console`, `space`, `enter`, `esc`, `tab`, `up`, `down`, `f10`, `1`-`5` |
| `cmd <line>` | Type a console line and press Enter; refuses lines over 255 chars |
| `run <file>` | Copy an effect file to `run/claude_<timestamp>_<name>` (UTF-8 BOM) and execute it |
| `mark` | Remember the current length of `error.log` and `debug.log` |
| `new [error\|debug]` | Print log lines added since the last `mark` |

Every command activates the CK3 window first. Always take a `shot` and Read it before clicking, and again after, to confirm the result.

## Workflow

1. **Launch.** `launch`, then `shot` every ~20 s until the main menu appears (about a minute). Start or load a game from the menu, e.g. `Continue`.
2. **Enable debug mode.** `key f10` opens the Encyclopedia; click its **Toggle Debug** button (top center). Debug mode is on when the debug map-mode buttons (`Srlm`, `Ter`, `Bar`, ...) appear above the map-mode panel. Clicking it again turns debug mode off. Close the Encyclopedia with its ✕ (top right).
3. **Pause and set the speed.** `key 1` sets speed 1; `key space` toggles pause. Do all setup while paused.
4. **Set up.** `key console` opens/closes the console. Run effects with `cmd` or `run` (see below).
5. **Let time pass.** `key space`, wait, `key space`. Speed 1 runs at about **2 s per game day**; pausing overshoots by about a day. Check the date (bottom right) and the "Paused" banner in a `shot`.
6. **Inspect.** Read screenshots; check `new error` for errors and `new debug` for `debug_log` output. `mark` before the step you want to isolate.
7. **Quit.** `pkill -x ck3` (or Cmd+Q on macOS) doesn't exit but opens the **Exit Game** dialog. **Uncheck "Save the game as autosave_exit"** so the user's own `autosave_exit` isn't overwritten, then click **Exit to Desktop**.

## Console

- `effect <effects>` executes any script effects in the player's scope, so special commands are rarely needed. No `effect = { }` wrapper (removed in 1.18).
- **Console lines are limited to 255 chars**, including `effect `. A longer line is truncated silently and runs partially (the cut-off part logs `Unknown effect` in `error.log`), and the overflowing keystrokes reach the game as hotkeys (WASD pans the camera, space toggles pause).
- For anything longer, write an effect file and use `run <file>`. `root` is the player. Use a new file per run (the helper does this) rather than overwriting `run/run.txt`.
- Inspect state from effects with `debug_log = "..."` and `debug_log_scopes = yes` (output in `debug.log`); evaluate triggers with `if = { limit = { ... } debug_log = "yes" } else = { debug_log = "no" }`.
- Target other characters with `character:<id> = { ... }`. The id is the **historical** id (from history files, shown in debug tooltips); characters created or born after game start don't have one and can only be reached via a relation to `root` filtered by e.g. traits (`random_courtier = { limit = { has_trait = ... } ... }`), so prefer testing with historical characters.
- Typed text is appended to whatever is already in the console input; keep it empty.
- Useful commands: `play <id>`, `observe`, `event <event_id> [character_id]`, `set_date <y.m.d>`, `instant_*`/`insta*` toggles, `help [command]`. `tab` autocompletes. See [Console commands](https://ck3.paradoxwikis.com/Console_commands).

## Pitfalls

- **Don't touch the CK3 window while driving it.** Mouse movement over the window edge pans the map (edge scrolling); on macOS, Cmd+H hides the game until the next helper command.
- Hover tooltips (e.g. debug province IDs) stay where the last click left the cursor and may cover parts of the screen.
- macOS: the console key defaults to ISO `§`/`±` (key code 10); set `CK3_CONSOLE_KEYCODE=50` for ANSI keyboards. Linux: defaults to `grave`; override with `CK3_CONSOLE_KEY`.

## Platform Status

- macOS: tested with CK3 1.19.
- Linux X11: untested; verify each command on first use and update this skill.
