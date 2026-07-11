# Crusader Kings 3 Unofficial Patch (Unop)

Crusader Kings 3 Unofficial Patch (Unop) is a CK3 mod that fixes issues in the vanilla CK3 game.

GitHub: [ProZeratul/CrusaderKings3UnofficialPatch](https://github.com/ProZeratul/CrusaderKings3UnofficialPatch)

[@../README.md](../README.md)
[@../CONTRIBUTING.md](../CONTRIBUTING.md)
[@../.env](../.env)

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

- **Question vanilla.** Don't assume the base game code is correct. It's full of issues, that's why Unop exists.
- **Fix, don't add or rebalance.** Avoid changes that read as additions or balance tweaks rather than fixing an issue.
- **Prefer the minimal change.** Do the minimal change required to fix the issue.
- **Match local formatting.** Follow the formatting of the surrounding code where the fix goes, and indent properly when wrapping existing code in a scope.
- **Avoid incidental edits.** Avoid unrelated changes, e.g. to whitespace.

### Style

- **Mark every change.** Put a `#Unop <description>` (preferred) or `#Unop: <description>` (acceptable) comment on the first changed line.
- **Comment out, don't delete.** Comment out unneeded vanilla code rather than removing it, with an `#Unop` comment on the first deleted line. Comment out only the replaced/removed lines, not unchanged surrounding ones.

### Ignoring Tiger Errors

- **Use the right section.** In `ck3-tiger.conf`, put genuine false positives under `# False positives` and deliberate ignores under `# Ignored`.
- **Group with similar rules.** Place a new rule next to similar ones of the same type; if there are none, append it at the end.

### Validation and Testing

- **Run tiger.** After a fix, run `make tiger`; it must report no errors or warnings.
- **Clean up new tiger errors.** New vanilla files may surface unrelated tiger errors; fix or ignore them in the same PR so tiger stays clean.
- **Ask for in-game verification.** For an externally-reported issue, ask the user to confirm the fix works.
- **Check error.log.** Ask the user to run vanilla + Unop in observer mode, then check `${CK3_USER_DIR}/logs/error.log` for errors related to the fix.

### Opening PRs

- **Link the issue.** Prefer opening a GitHub issue first and linking the PR with `Fixes #<id>` in its description.
- **Use appropriate branch names.** Branch off `main` as `<git-user>-fix-<short-slug>` from the issue title (e.g. `pharaox-fix-court-positions`). Don't include the issue number.
- **Keep `.claude/` out.** Changes under `.claude/` may stay uncommitted while you work; don't add them to a fix PR.
- **Stage by path.** Stage fix files explicitly by path; avoid `git add -A` / `git add .` / `git commit -a`, which can sweep in dirty `.claude/` or unrelated files.
- **Use imperative commit messages.** Use short imperative summary (e.g. `Fix travel_events.2012 option B showing wrong tooltip`).
- **Add vanilla files in a separate commit.** Add new vanilla files unmodified in their own commit, then the actual changes in a follow-up commit, so the diff is easy to review.
