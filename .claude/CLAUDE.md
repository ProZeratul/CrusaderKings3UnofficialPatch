# Crusader Kings 3 Unofficial Patch (Unop)

Crusader Kings 3 Unofficial Patch (Unop) is a CK3 mod that fixes issues in the vanilla CK3 game.

GitHub: [ProZeratul/CrusaderKings3UnofficialPatch](https://github.com/ProZeratul/CrusaderKings3UnofficialPatch)

[@../README.md](../README.md)
[@../.env](../.env)
[@../ck3-tiger.conf](../ck3-tiger.conf)

## Concepts

- **ck3-tiger** (aka "tiger"): A CK3 code analysis tool, [amtep/tiger](https://github.com/amtep/tiger).

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
- Always do the minimal change required to fix an issue.
- Always adhere to the formatting of the original code in the place where the fix is introduced.
- Avoid accidental unrelated changes, e.g. to whitespace.
- When enclosing existing code in a scope, indent it properly.

### Style

- All changes introduced by Unop should include a comment in the format `#Unop <description>` (preferred) or `#Unop: <description>` (acceptable).
- Unneeded vanilla code should be commented out rather than deleted, with an `#Unop` comment on the first deleted line.

### Ignoring Tiger Errors

- Unop `ck3-tiger.conf` contains 2 different sections, use the correct one when adding rules:
  - `# False positives`: false positives
  - `# Ignored`: ignored
- When adding a new rule to `ck3-tiger.conf`, group it with similar rules of the same type in that section.
  - If there are no such rules, add it at the end.

### Validation and Testing

- After making a new fix, ensure that tiger passes with no errors or warnings.
- Always run tiger by running `make tiger`.
- When adding new vanilla files, tiger may report new errors in these files that are unrelated to the original fix. Fix or ignore them in the same PR so that tiger reports no errors or warnings in this case as well.
- If fixing an issue reported by an external party, ask the human to manually verify that the fix works.
- After introducing a new fix, ask the human to run the vanilla game + Unop in observer mode; then check the game's `logs/error.log` in the CK3 user data directory for any errors related to the fix.

### Opening PRs

- When opening PRs for fixes, prefer creating a GitHub issue first and linking the PR to it by mentioning it in the PR description, e.g. `Fixes #<id>`.
- If the issue was reported in Paradox forums or Reddit, don't open a GitHub issue and include the relevant link(s) in the PR description.
- New vanilla files should be added without modifications in a separate commit, followed by a commit in the same PR with the actual changes. This makes these changes easier to identify and review.

### PR Review

- If the PR contains links to GitHub issues or external links (e.g. to issue reports in Paradox forums), fetch them to get more info about what was fixed.
- Always compare Unop changes against vanilla (or `main`) to understand what was modified and why.
- PRs that add new vanilla files may contain multiple commits, some adding the vanilla files, others making actual changes. Make sure to only review the actual changes, not the entire files.
- If particular changed lines raise a concern, propose a review comment for these lines.
- If the PR contains multiple unrelated fixes, review each one separately, asking the human to check each review before continuing with the next one. At the end, prepare one summary comment for all fixes.
- Prefer concrete and concise feedback; avoid praise.
- Group related changes together into a single fix.
- Don't consider project maintenance changes (e.g. updates to `.gitignore`) as fixes; only mention them if they raise concerns.
- Both keeping and removing redundant vanilla code is ok, don't insist on either as far as the Unop fix works.
- When posting review comments on GitHub, always include a signature line: `-- Review by Claude Code`
- The final summary comment should follow the template below for each fix; only include a title if there are multiple fixes.

  ```markdown
  ### Fix N: Title

  * **File(s):** `file1`, `file2`
  * **Issue:** A description of the issue (1-3 sentences)
  * **Fix:** A description of the fix (1-3 sentences)
  * **Analysis:** Analysis of the fix quality (1-2 sentences)
  * **Recommendations:** What could be improved (1-2 sentences, only if needed)

  _-- Review by Claude Code_
  ```

- Always ask the human for approval before posting reviews to GitHub. Don't approve PRs unless explicitly instructed.
