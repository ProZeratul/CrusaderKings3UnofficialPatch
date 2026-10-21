# In-Game Testing

How to write the bug **repro** and the fix **test script**. The maintainers know the console and debug tools. The value is the right *sequence*: which character, which actions, which exact commands, in what order. Don't explain the tools.

Test scripts are run as written, on `main` and on the PR branch, so every step must be executable and every expected result checkable.

## Scope

- **One spot-check, about 10 minutes.** For a fix that touches several places, test the most representative one and list the rest under `Not covered`.
- **Exercise the changed code.** The test must run through the code path the fix changed, and show a visible difference from vanilla.

## Choosing the Setup

In order of preference:

1. **A historical character at a bookmark** (867, 1066, 1178) who already meets the conditions. Give the name, character ID and main title.
2. **Any convenient character plus console commands** that create the missing state (`effect ...`).
3. **Firing the event directly** (`event <id>`). This skips the event's `trigger`, so never use it when the fix is in a trigger, guard, `is_shown`/`is_valid`, or the on_action that fires the event. Go through the real path in that case.

## Testing Hard-to-Reach States

AI behavior over time, game start, and rare random outcomes are still testable. Say how:

- **Observer mode**, plus the log or `error.log` line to check.
- **Temporary `debug_log`** (e.g. `debug_log = "..."` or `debug_log_scopes = yes`) at a named spot in a named file, plus the `game.log` line that proves the fix.
- **Temporary code tweaks** that make a random outcome likely, e.g. raising a `weight`, `chance` or `random` value. Give the file, the block and the new value, and tell the tester to revert it after.

## Common Mistakes

- **`play <id>` doesn't take historical IDs.** Switch characters with `effect set_player_character = character:<id>`.
- **Playing a landless character is Game Over.** Don't make the tester play someone who holds only a special title (e.g. a Japanese or Chinese emperor). Play a landed character and look at the other one, e.g. their liege.
- **Generic scopes pick existing state.** `random_character_war`, `random_courtier` etc. may pick something the bookmark character already has, e.g. William's Norman Conquest in 1066. Narrow them (`limit = { using_cb = depose_war }`), or pick a character with no such state.
- **`debug_log` writes to `debug.log`**, not `game.log`.
- **Observer mode is rarely needed.** Game-start effects run whoever is played; any character works.
- **Console lines over 255 chars** are truncated and run partially. Give longer setups as an effect file (a fenced block run with `run <file>`), not as one console line.
- **Characters created by the setup have no ID.** Keep the creation and every later use in one effect file via `save_scope_as`, or reach them through a relation to the player.
- **Transient or visual-only feedback.** Toasts disappear in seconds, and screen checks are slow for the tester. Prefer an expectation that can be checked in a log: a `debug_log` line from an effect that tests the trait, title, variable or government, or `error.log` content.
- **Expectations that need interpretation.** State the exact text, value or log line, not "works correctly".
- **Missing prerequisites.** Name the DLC, game rule or bookmark the setup depends on.

## Verification

Check all commands or IDs used:

- Character IDs, titles and their holders at the chosen bookmark, against `history/characters/` and `history/titles/`.
- Effects and triggers in console commands, against `${CK3_USER_DIR}/logs/effects.log` and `triggers.log`, including the scope they run in.
- Event IDs, decision and interaction keys, and loc keys, against the files.

## Templates

**Repro** (issue comment):

```markdown
<!-- unop-repro -->
**<identity>:** In-game repro

**Setup:** <bookmark>, play <name> (`<char id>`, <title>).

**Actions:**

1. <action>
2. Console: `effect <...>`
3. <action that triggers the bug>

**Observed:** <buggy behavior>.
**Expected:** <correct behavior>.
```

**Test script** (PR comment):

```markdown
<!-- unop-test -->
**<identity>:** In-game test

**Setup:** <bookmark>, play <name> (`<char id>`, <title>). 

**Temp edits**: <file, block → change; revert after; if needed>

**Actions:**
1. <action>
2. Console: `effect <...>`
3. <action that triggers the fixed code>

**Expected:** <what you see with Unop, optionally vs. buggy behavior>.

**error.log:** <what to look for; if needed>.

**Not covered:** <other changed spots; omit if none>
```

## Posting

Keep one current comment per marker: edit it if it exists, post it otherwise. `<N>` is the issue (repro) or the PR (test script). `<file>` holds the comment, starting with the marker line.

```shell
id=$(gh api --paginate repos/ProZeratul/CrusaderKings3UnofficialPatch/issues/<N>/comments \
  --jq '.[] | select(.body | contains("<!-- <marker> -->")) | .id' | head -n1)
if [ -n "$id" ]; then
  gh api --silent -X PATCH repos/ProZeratul/CrusaderKings3UnofficialPatch/issues/comments/$id -F body=@<file>
else
  gh api --silent -X POST repos/ProZeratul/CrusaderKings3UnofficialPatch/issues/<N>/comments -F body=@<file>
fi
```
