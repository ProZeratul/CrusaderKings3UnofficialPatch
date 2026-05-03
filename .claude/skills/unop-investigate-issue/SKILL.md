---
name: unop-investigate-issue
description: Investigate a GitHub issue, classify it, and either request more info or open a fix PR
argument-hint: "<issue-number>"
---

# Investigate Unop GitHub Issue

Investigate a reported issue in the Unop GitHub repo, classify it against vanilla and mod files, label it accordingly, and follow up with either a fix PR, a request for more information, or an explanation that it's invalid.

## Concepts

- **GitHub repo**: `ProZeratul/CrusaderKings3UnofficialPatch`. Use the `gh` CLI for all GitHub operations.
- **Issue**: A bug report (or occasionally an enhancement request) opened against the Unop repo.

## Context

- Commands should be executed in the Unop repo root.

## Arguments

**Issue number** (position $0, required): The GitHub issue number to investigate (e.g. `419`).

## Guidelines

- **Always** read the project's `CLAUDE.md` first.
- **Always** read the issue body **and all comments** before forming a hypothesis. Earlier comments often contain repro details, partial diagnoses, or maintainer responses that change the picture.
- **Always** investigate against the actual files. Read both the vanilla file and the Unop override (if any) in their entirety — don't just grep.
- An issue tagged as `vanilla` is still a real bug to be fixed in Unop — don't dismiss it as "not our code".
- **Never** assume that the reporter is correct either. They may have misidentified the file, the cause, or the scope.
- **Always** present your classification and findings to the user **before** posting anything to GitHub or opening a PR.
- If in doubt how to classify or how to fix, **stop and ask the user**.
- **Never** apply the `duplicate` or `wontfix` labels — flag candidates and let the user decide.
- **Never** close issues. Closure is a maintainer action.

## Workflow

### 1. Fetch the Issue

Read the issue and all its comments:

```shell
gh issue view <N> --comments
```

Note any existing labels — they may already encode prior triage. Note any linked PRs.

**Identify how many distinct bugs the issue contains.** A title may name one symptom while later comments describe others. If the issue covers more than one distinct bug, list them in the findings, ask the user which to pursue (or all), and decide per-bug whether to file separate tracking issues or address them in the same PR. Don't silently work only the title bug.

### 2. Identify the Affected Files

From the issue, extract:

- File paths the reporter mentions (e.g. `events/activities/hold_court_activity/hold_court_events_general/...txt`).
- Object names (event IDs, trigger names, modifier keys, localization keys).
- Game version mentioned (if any).
- Reproduction steps and expected vs. actual behavior.

If the reporter only describes a symptom (e.g. "string missing localization in X tooltip"), search the vanilla and Unop trees to locate the responsible file(s):

```shell
# Search vanilla (read-only)
grep -rn "<key or symbol>" "${CK3_BASE_DIR}/<area>/" 2>/dev/null

# Search Unop override
grep -rn "<key or symbol>" .
```

If the relevant file cannot be located confidently, classify as **question** and ask the reporter for the file path.

### 3. Investigate

For each candidate file:

1. **Read the Unop override if it exists.** Unop overrides vanilla — so what the game runs is the Unop copy. Read it in full.
2. **Read the vanilla file** to compare and confirm whether Unop has already touched the relevant code.
3. **Check the relevant `.info` file** in the vanilla directory and the `${CK3_USER_DIR}/logs/*.log` files (`triggers.log`, `effects.log`, `event_scopes.log`, etc.) to verify scopes, effect signatures, and trigger names.
4. **Trace the actual code path** the reporter describes — don't reason from the title alone.

Specifically look for:

- Does the bug reproduce in the current vanilla file? → leans **vanilla**.
- Did Unop modify this code path? Look for `#Unop` markers and compare against the vanilla file. If yes, did Unop's change introduce the regression? → leans **mod**.
- Does the reporter's claim match the file contents? If not, the issue may be **invalid**, OR the reporter is on a stale version, OR another mod is interfering.

**Verify the bug still reproduces.** Check if vanilla has since added a guard upstream that prevents reaching the buggy state. See [`examples.md`](examples.md) (#420).

### 4. Classify

Decide on three label dimensions:

#### Origin (exactly one)

- **`vanilla`** — the buggy code is in the base game and is not (or not adequately) patched by Unop.
- **`mod`** — Unop itself is the cause: an Unop override is wrong, regresses behavior, or was orphaned by a vanilla update.

#### Area (one or several)

- **`common`** — anything under `common/` (traits, modifiers, scripted_effects, decisions, etc.).
- **`events`** — anything under `events/`.
- **`gui`** — anything under `gui/`.
- **`localization`** — missing or wrong loc keys, only loc files need to change.
- **`history`** — anything under `history/` (titles, characters, provinces, wars, etc.).
- **`gfx`** — anything under `gfx/` (assets, portrait modifiers, model data, etc.).

If the affected area doesn't fit any of these (e.g. `map_data/`), **stop and ask the user** whether to add a new label before continuing.

#### Status (exactly one)

- **`confirmed`** — reproduced against the files; the bug is real and a fix is feasible. Proceed to step 5 (Fix).
- **`question`** — need more from the reporter to proceed: missing repro steps, file path, screenshot, save, mod list, game version, or `error.log` excerpt. Proceed to step 8 (Question).
- **`invalid`** — analysis shows it isn't actually a bug, or it's already fixed, or it's out of Unop's scope (e.g. a balance change, a third-party mod conflict, a reporter on a stale version). Proceed to step 9 (Invalid).

Also flag (but don't apply):

- **`duplicate`** — if you find an existing open or closed issue covering the same thing. Mention the number in the comment and let the user apply the label.
- **`wontfix`** — if the fix appears to be risky or low value. Never decide this autonomously; ask the user.

### 5. Formulate a Fix Approach

Work out *how* you'd fix the bug before writing the comment — the fix shape often reveals investigation gaps.

- **Look for the simpler fix first.** Is there an existing trigger, variable, flag, or guard that already encodes the state? Avoid new state and new files unless the existing surface really can't express the fix. See [`examples.md`](examples.md) (#420).
- **Articulate the intent of any guard you propose to loosen.** State in one sentence why the original code added it. If you can't, keep investigating or ask the user. Look in nearby comments, the trigger's tooltip loc, related decisions. See [`examples.md`](examples.md) (#440).
- **Verify against the other guards in the same block.** Before removing/loosening a guard, simulate the post-removal state against the other guards in the same `is_shown` / `is_valid` / `can_create`. If another guard still blocks the reporter's case, your fix doesn't work. See [`examples.md`](examples.md) (#440).
simpler ones, so the user can redirect early.
- **Propose the approach at a high level before drafting the diff.** Surface alternatives considered and why you rejected 

**Paradox Script Gotchas:**

- **`custom_description` is a tooltip wrapper, not a condition.** `custom_description = { text = X; <trigger> }` evaluates `<trigger>` and labels failures with `X`'s loc — the `text =` line is not a separate condition.
- **`trigger_localization` entries are tooltip labels, not scripted triggers.** Names referenced in a `text =` field may live in `common/trigger_localization/` rather than `common/scripted_triggers/`. Grep both before concluding "trigger not found".

### 6. Present Findings to the User

Before touching GitHub, present:

- The proposed labels (origin, area, status, any flagged candidates).
- A short findings summary (3–8 bullets): what was reported, what files you checked, what you found, why you classified it this way.
- The exact comment you intend to post on the issue.
- If `confirmed`: the fix approach from step 5 (which file, what change, why; alternatives considered).
- If `question`: the specific list of questions to ask.
- If `invalid`: the explanation and what you want the reporter to confirm.

**Wait for user approval** before posting anything or making code changes.

### 7. Resolve — Fix

After approval:

1. **Post the findings comment** on the issue, use the **Comment Template** in Reference.

2. **Apply labels**: the chosen status (`confirmed`), origin, and area.

3. **Create a feature branch from `main`** following the project `CLAUDE.md` "Opening PRs" guidelines (branching, naming, `.claude/` allowed-dirty rule). Before branching, check there are no uncommitted mod files:

   ```shell
   # Should print nothing. If it prints anything, stop and ask the user.
   git status --porcelain | grep -v '^.. \.claude/'
   ```

4. **Prepare the fix** following the project `CLAUDE.md` "General", "Style", and "Opening PRs" guidelines (minimal change, `#Unop` comment, comment-out vs. delete, separate commit for newly-added vanilla files).

5. **Validate**: run `make tiger` and ensure no new errors or warnings.
   - If new errors appear in newly-added vanilla files, fix or ignore them in the same PR.
   - Use the `tiger` skill if loaded.

6. **Commit and open the PR as a draft** following the project `CLAUDE.md` "Opening PRs" guidelines (explicit `git add`, commit message style). After staging, committing, and pushing per CLAUDE.md, include `Fixes #<N>` in the PR body so GitHub auto-links the issue:

   ```shell
   gh pr create --draft --title "<title>" --body "$(cat <<'EOF'
   Fixes #<N>

   <short description of the fix>
   EOF
   )"
   ```

7. **Ask the user** to manually verify the fix in-game (and to run observer mode to check `error.log` if appropriate).

### 8. Resolve — Question

After approval:

1. **Post the question comment** on the issue. Keep it focused: ask for the specific missing pieces only (don't dump a generic template). Common asks:
   - Game version and exact Unop version.
   - Confirmation that the issue reproduces with **only** vanilla + Unop.
   - Reproduction steps, save file, screenshot, and/or `error.log` excerpt.
   - The specific file path or event/object ID, if the symptom is generic.
2. **Apply labels**: `question`, plus origin and area if you can determine them confidently from what's already there.
3. Do **not** open a PR.

### 9. Resolve — Invalid

After approval:

1. **Post the explanation comment** on the issue. Be specific:
   - State exactly what you checked (file paths, line numbers).
   - State why the report doesn't hold (e.g. "Unop does not modify `<file>` at all").
   - Offer the most likely benign explanation (stale version, another mod, misread tooltip).
   - Ask the reporter to confirm whether the issue still reproduces with only vanilla + Unop.
2. **Apply labels**: `invalid`, plus origin and area if applicable.
3. Do **not** close the issue — the reporter or maintainer will close it after confirming.

### 10. Report Summary

When done, report:

- Issue number and title.
- Classification applied (status / origin / area).
- Action taken (PR opened with link, question posted, invalid explanation posted).
- Anything the user needs to do next (manual verification, decide on `duplicate`/`wontfix`, add a new area label).

## Reference

### Comment Template

Use this template for the comment posted on the issue. Pick the resolution-specific section based on the chosen status, and replace the rest. Keep all sections short and concrete.

```markdown
## Investigation

**Files checked:**
- `<path>` (Unop) — <one-line note>
- `<path>` (vanilla) — <one-line note>

**Findings:**
- <bullet>
- <bullet>

**Classification:** `<status>` / `<origin>` / `<area>`

<!-- For confirmed: -->
## Fix in Progress

A fix is being prepared. PR will follow shortly.

<!-- For question: -->
## Information Needed

To proceed, could you please provide:
- <specific ask 1>
- <specific ask 2>

<!-- For invalid: -->
## Not a Bug

This doesn't appear to be a bug:

- <reason>
- <reason>

Could you confirm whether this still reproduces with only **vanilla + Unop** (no other mods, latest version)?
```

### Examples

Short retrospectives of past investigations live in [`examples.md`](examples.md), one section per issue and tagged with the lesson(s) each teaches. Read the relevant section when its situation comes up.

### gh Snippets

```shell
# Read issue + comments
gh issue view <N> --comments

# Post a comment (use a heredoc for multi-line bodies)
gh issue comment <N> --body "$(cat <<'EOF'
<comment markdown>
EOF
)"

# Add / remove labels
gh issue edit <N> --add-label "confirmed,vanilla,events"
gh issue edit <N> --remove-label "question"

# Search for possible duplicates (open + closed)
gh search issues "<keywords>" --repo ProZeratul/CrusaderKings3UnofficialPatch --state all
```

## Usage Examples

```bash
# Investigate issue 419
/unop-investigate-issue 419
```
