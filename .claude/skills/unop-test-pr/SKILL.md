---
name: unop-test-pr
description: Run a PR's in-game test script on main and on the PR branch, post the observed results and a verdict, and append them to the shared file
argument-hint: "<PR> [<anchor>]"
---

# Test Unop PR In-Game

Run the PR's in-game test script twice, via the `unop-drive-game` skill: on `main`, where it should show the bug, and on the PR branch, where it should show the fix. Post the observations and a verdict on the PR, append a `## Test N` section to the shared file, and apply a verdict label to the anchor.

This skill runs **autonomously**, without asking for approval. Any human gates belong to the calling workflow, not here. It reports a summary at the end.

## Concepts

- **GitHub repo**: `ProZeratul/CrusaderKings3UnofficialPatch`. Use the `gh` CLI for all GitHub operations.
- **Anchor**: the issue or PR number carrying the labels and shared file — the issue a PR closes, or the PR itself if it closes none.
- **Shared file**: `tmp/issue-<anchor>.md` — the handover document. Other skills create it and append `## Fix N` and `## Review N` sections. This skill reads them and appends `## Test N`. May be absent.
- **Test script**: the PR comment marked `<!-- unop-test -->`, written following `../unop-fix-issue/testing.md`.
- **Base** and **head**: throwaway worktrees of `main` and of the PR branch, which the game loads Unop from.

## Arguments

- **PR number** (position $0, required): the GitHub PR to test (e.g. `723`).
- **Anchor number** (position $1): the issue or PR carrying the shared file and labels; defaults to the PR.
- **Identity** (position $2): the role this skill posts as, defaults to `tester`.

## Guidelines

- **Read the project's `CLAUDE.md`** and the `unop-drive-game` skill first.
- **Identify yourself.** Post as `<identity>`: begin each comment's first line with `**<identity>:**`. A comment containing `@<identity>` is addressed to you.
- **Test what the script tests.** The script is the spec. Don't change the code path it exercises or its expected result.
- **Fix mild inaccuracies yourself** before failing the test, and record each one as a deviation. Examples:
  - A console line over 255 chars: run it as an effect file.
  - `play <id>` with a historical id: use `effect set_player_character = character:<id>`.
  - A slightly wrong UI path: find the actual button or window.
  - A wrong id or title: verify against `history/` and use the right one.
  - An expectation that's hard to see: add a read-only check, e.g. a `debug_log` effect.
- **Don't bypass the fix.** Never replace the real path with `event <id>` when the fix is in a trigger, guard, `is_shown`/`is_valid`, or the on_action that fires the event.
- **Keep trying, within reason.** Try up to about three approaches per obstacle before giving up on it.
- **Save tokens.** Check results in logs where possible, e.g. with a `debug_log` effect file that tests the expected state, even if the script asks to look at a window. Take a `shot` only to navigate or to read on-screen text, crop it to the region you need, and reuse known button positions. Open windows with `open_view_data` instead of clicking through the UI.
- **Don't change the PR.** Temp edits go only into the throwaway worktrees; never commit or push them.

## Workflow

### 1. Load Context

- Read the shared file if present: the `## Analysis`, the latest `## Fix N` and `## Review N`, and every prior `## Test N`. Count the existing `## Test N` sections; this run is `## Test N+1`.
- Read the test script: `gh api repos/ProZeratul/CrusaderKings3UnofficialPatch/issues/<PR>/comments --jq '.[] | select(.body | contains("<!-- unop-test -->")) | .body'`. Also read the issue's repro comment (`<!-- unop-repro -->`) if the anchor is an issue.
- Read the diff (`gh pr diff <PR>`), to know which code the test must reach.

If there's no test script, skip to step 5 with verdict `Failed` and reason "no test script".

### 2. Prepare the Checkouts

```shell
B=$(gh pr view <PR> --json headRefName -q .headRefName)
git fetch origin main "$B"
BASE=${TMPDIR:-/tmp}/unop-test-<anchor>-base
HEAD=${TMPDIR:-/tmp}/unop-test-<anchor>-head
git worktree add --detach "$BASE" origin/main
git worktree add --detach "$HEAD" "origin/$B"
git merge-tree --write-tree origin/main "origin/$B" > /dev/null  # fails on a conflict
```

If the branch conflicts with `main`, don't test it: clean up (step 7) and report **needs rebase**, without posting or labelling anything.

Apply the script's **Temp edits** identically in both worktrees. If base has no Unop copy of the edited file, copy the vanilla file from `${CK3_BASE_DIR}` to the same path in base first.

### 3. Run the Script on Base, Then on Head

For each of base and head, following the `unop-drive-game` workflow:

1. `launch --mod "$BASE"` (or `"$HEAD"`). If it refuses because CK3 is already running, stop: clean up (step 7) and report **game busy**, without posting or labelling anything.
2. `start <year>` for the script's bookmark, dismiss any start event, then switch to the script's character.
3. Run the setup and actions. `mark` before the step that exercises the fix.
4. Record the observations: the exact on-screen text or values, the relevant `new debug` lines, and `new error` lines related to the changed files or events.
5. `exit`, after reading the logs.

Use the same steps, including any deviations, in both runs.

Watch for setup gaps: a temp edit that bypasses `is_valid` can also remove something the `effect` relies on, and a raised event weight still sits behind its block's `chance_to_happen`.

### 4. Judge

- **`Passed`**: head shows the expected result, and base shows the bug (or the vanilla behavior the script describes).
- **`Failed`**: either
  - **fix**: the setup verifiably reached the changed code on head, but head doesn't show the expected result; or
  - **script**: the script can't be made to reach the changed code even with fixes, or base already shows the expected result, so the test doesn't tell the versions apart.
- If base shows the bug differently from the shared file's analysis, say so in the result.
- **`Inconclusive`**: the test can't be automated (e.g. AI behavior over years, multiplayer, rare randomness without a temp edit), a prerequisite is missing (e.g. an unowned DLC), or the game crashed in a way unrelated to the fix.

### 5. Post the Result

Keep one current result comment on the PR, marked `<!-- unop-test-result -->`: edit it if it exists, post it otherwise, using the posting snippet in `../unop-fix-issue/testing.md`.

```markdown
<!-- unop-test-result -->
**<identity>:** In-game test <Passed | Failed (fix) | Failed (script) | Inconclusive>

**Base (`main`):** <what happened: exact text, values, log lines>
**Head (PR):** <same>

**Deviations from the script:** <each change and why; "none" if none>

**error.log:** <related errors, or "nothing related">

<On Failed: what the should be looked at. On Inconclusive: what blocked the test.>
```

### 6. Append to the Shared File and Apply the Label

Append to the shared file (create it with just this section if absent):

```markdown
## Test N

**Result:** Passed | Failed (fix) | Failed (script) | Inconclusive

**Base:** <one-line observation>

**Head:** <one-line observation>

**Deviations:** <list, or "none">
```

Set the verdict label on the **anchor**: one of `test:passed`, `test:failed`, `test:inconclusive`, removing the other two:

```shell
gh api --silent -X POST repos/ProZeratul/CrusaderKings3UnofficialPatch/issues/<anchor>/labels -f "labels[]=test:passed"
gh api --silent -X DELETE repos/ProZeratul/CrusaderKings3UnofficialPatch/issues/<anchor>/labels/test:failed
gh api --silent -X DELETE repos/ProZeratul/CrusaderKings3UnofficialPatch/issues/<anchor>/labels/test:inconclusive
```

A `DELETE` of a label the anchor doesn't have returns 404; ignore it.

### 7. Clean Up

- Make sure `exit` ran, so the game is gone and the Unop descriptor points back at its original path.
- Remove the worktrees: `git worktree remove --force "$BASE"` and `"$HEAD"`.
- Delete the effect files this run created in `${CK3_USER_DIR}/run/` (the paths `run` printed).

### 8. Report Summary

When done, report to the user:

- Verdict, with one line each for base and head.
- Deviations from the script.
- Recommended next step: on `Passed`, the PR is ready for human review; on `Failed`, the result comment should be addressed; on `Inconclusive`, what a human needs to test.
- Or **game busy**, if `launch` refused, or **needs rebase**, if the branch conflicts with `main`.

## Usage Examples

```bash
/unop-test-pr 723 603
```
