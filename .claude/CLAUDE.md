# Crusader Kings 3 Unofficial Patch (Unop)

Crusader Kings 3 Unofficial Patch (Unop) is a CK3 mod that fixes issues in the vanilla CK3 game.

GitHub: [ProZeratul/CrusaderKings3UnofficialPatch](https://github.com/ProZeratul/CrusaderKings3UnofficialPatch)

[@../README.md](../README.md)
[@../.env](../.env)
[@../ck3-tiger.conf](../ck3-tiger.conf)

## Concepts

- **ck3-tiger** (aka "tiger"): A CK3 code analysis tool, [amtep/tiger](https://github.com/amtep/tiger).
- **Vanilla**: The unmodified base game files, located under `${CK3_BASE_DIR}` (see `.env`).

## Context

### Basics

- The mod overrides vanilla files by placing modified copies in the same relative path. Only modified vanilla files are copied to the mod.
- Localization keys are added or changed by adding them to Unop-specific files in `localization/replace/english`. The mod contains only English localization keys.

### Directories

All relevant directories are in [@../.env](../.env):

- `CK3_BASE_DIR`: base game root directory
- `CK3_USER_DIR`: game user data directory (logs, settings, etc.)

### Game Docs

- `.info` files in the corresponding base game directory contain information on script syntax and scopes for files in that directory
- `${CK3_USER_DIR}/logs/*.log` files contain information on builtin effects, triggers, etc.:
  - `custom_localization.log`
  - `effects.log`
  - `event_scopes.log`
  - `event_targets.log`
  - `modifiers.log`
  - `on_actions.log`
  - `triggers.log`

### Tiger

- The `ck3-tiger` configuration is `ck3-tiger.conf`, and its output is saved to `ck3-tiger.out`.
- The Unop file that overrides a base game file is **always** a file with the same name (for script files).
- Unop localization `.yml` files are in `localization/replace/english`:
  - `unop_fixed_keys_l_english.yml`: fixed vanilla keys
  - `unop_new_keys_*_l_english.yml`: new Unop keys

## Guidelines

### General

- **Never** assume that vanilla code is correct.
- Avoid changes that can't be regarded as fixing issues but rather as additions or balance changes.
- **Always** do the minimal change required to fix an issue.
- **Always** adhere to the formatting of the original code in the place where the fix is introduced.
- Avoid accidental unrelated changes, e.g. to whitespace.
- When enclosing existing code in a scope, indent it properly.

### Style

- **Always** include a comment in the format `#Unop <description>` (preferred) or `#Unop: <description>` (acceptable) on the first changed line.
- **Always** comment out rather than delete unneeded vanilla code.
  - Include an `#Unop` comment on the first deleted line.
  - Comment out only the actually replaced/removed lines, not unchanged surrounding lines.

### Ignoring Tiger Errors

- Use the correct `ck3-tiger.conf` section when adding rules:
  - `# False positives`: false positives
  - `# Ignored`: ignored
- When adding a new rule to `ck3-tiger.conf`, group it with similar rules of the same type in that section.
  - If there are no such rules, add it at the end.

### Validation and Testing

- After making a new fix, ensure that tiger passes with no errors or warnings.
- **Always** run tiger by running `make tiger`.
- When adding new vanilla files, tiger may report new errors in these files that are unrelated to the original fix.
  - Fix or ignore them in the same PR so that tiger reports no errors or warnings in this case as well.
- If fixing an issue reported by an external party, ask the user to manually verify that the fix works.
- After introducing a new fix, ask the user to run the vanilla game + Unop in observer mode.
  - Then check the game's `logs/error.log` in the CK3 user data directory for any errors related to the fix.

### Opening PRs

- When opening PRs for fixes, prefer creating a GitHub issue first and linking the PR to it by mentioning it in the PR description, e.g. `Fixes #<id>`.
- If the issue was reported in Paradox forums or Reddit, don't open a GitHub issue and include the relevant link(s) in the PR description.
- Branch off `main`:

  ```shell
  git checkout main && git pull --ff-only
  git checkout -b <branch>
  ```

  - Branch name convention: `<git-user>-fix-<short-slug>` derived from the issue title (e.g. `pharaox-fix-court-positions`). Don't include the issue number.
- Changes under `.claude/` are allowed to be uncommitted while you work — they should stay out of any PR.
- Stage fix files **explicitly by path**. Never `git add -A` / `git add .` / `git commit -a` — they may sweep in dirty `.claude/` or other unrelated files.
- Commit message style: short imperative summary (e.g. `Fix travel_events.2012 option B showing wrong tooltip`).
- New vanilla files should be added without modifications in a separate commit, followed by a commit in the same PR with the actual changes. This makes these changes easier to identify and review.

### Investigating Issues

- Use the `unop-investigate-issue` skill.

### Reviewing PRs

- Use the `unop-review-pr` skill.
