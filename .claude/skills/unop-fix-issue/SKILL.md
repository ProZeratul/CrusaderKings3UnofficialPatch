---
name: unop-fix-issue
description: Formulate and apply a fix for a confirmed Unop issue, commit and push
argument-hint: "<issue-number>"
---

# Fix Unop Issue

Formulate a fix approach for a confirmed Unop issue, apply it, run tiger, commit, and push. Read full context from a shared file and append a `## Fix N` section with the approach and changes.

This skill runs **autonomously**, without asking for approval. Any human gates belong to the calling workflow, not here. It reports a summary at the end.

## Concepts

- **GitHub repo**: `ProZeratul/CrusaderKings3UnofficialPatch`. Use the `gh` CLI for all GitHub operations.
- **Issue**: A bug report (or occasionally an enhancement request) opened against the Unop repo.
- **Shared file**: `tmp/issue-<N>.md` — the handover document. Other skills may create it with the `## Analysis` section and append `## Review N` sections. This skill reads both and appends `## Fix N`.

## Context

- Commands should be executed in the current working tree (the Unop repo root, or the worktree the session was launched in).

## Arguments

- **Issue number** (position $0, required): The GitHub issue number to fix (e.g. `419`).
- **Identity** (position $1): the role this skill posts as, defaults to `fixer`.

## Guidelines

- **Read the project's `CLAUDE.md`** first.
- **Identify yourself.** Post as `<identity>`): begin each comment's first line with `**<identity>:**`. A comment containing `@<identity>` is addressed to you.
- **Read the shared file** in full before formulating a fix — the `## Analysis` section and every prior `## Fix N` and `## Review N`.
- **Read the relevant parts of the actual Unop and vanilla files** before formulating the fix — don't rely on the investigation summary alone.
- **Decide the fix yourself.** Trust the shared file's `Findings` and *file-verified facts*, but treat any `Fix directions` recorded there as one unverified hypothesis, not a spec. Re-derive the approach from the facts and choose the altitude.
- **Don't hand-classify tiger warnings.** When `make tiger` reports new warnings, invoke the `tiger` skill to fix them properly.
- Consult `examples.md` for relevant past investigations when a situation it covers comes up.

## Workflow

### 1. Load Context

Read the shared file for the investigation findings, classification, and any prior fix/review cycles.

**Re-fix due to review.** If a `## Review N` section is present, read the most recent one and treat its `High` and `Medium` findings as the work list for this attempt — every one must be addressed before you consider the fix ready. `Low` findings are optional. Earlier `## Fix N` sections show what was already tried.

**Re-fix due to PR feedback.** If the fix has a linked PR and there is feedback after your last `**<identity>:**` comment (especially any addressing `@<identity>`), read its conversation and review comments — `gh pr view <PR> --comments`, plus inline comments via `gh api repos/ProZeratul/CrusaderKings3UnofficialPatch/pulls/<PR>/comments`. Take into account any **feedback from the maintainers** but **vet each against the code**; if you disagree, say so in the `## Fix N` rather than silently complying.

Re-read the relevant Unop and vanilla files to refresh the context before formulating the fix.

### 2. Formulate the Fix Approach

Work out *how* to fix the bug before writing any code.

- **Look for the simpler fix first.** Is there an existing trigger, variable, flag, or guard that already encodes the state? Avoid new state and new files unless the existing surface really can't express the fix. See `examples.md` (#420).
- **Find the right altitude.** Before patching individual items, ask whether one higher-level guard subsumes them. When the bug spans members of a group, fixing the group is usually simpler and more complete; if an analogous system already handles the condition, mirror its mechanism. See `examples.md` (#498).
- **Enumerate the pattern class, including sibling systems.** Identify the category (object group of family, analogous systems) and check every member — in other files too — for the same bug; fix all buggy ones in the same PR. See `examples.md` (#498).
- **Articulate the intent of any guard you propose to loosen.** State in one sentence why the original code added it — reading the whole feature for intent, including its localization and effects, not just the guard. A narrow predicate may be a *proxy* for a real condition; target that condition rather than widening the proxy. See `examples.md` (#440, #501).
- **Verify against the other guards in the same block.** Before removing or loosening a guard, simulate the post-change state against all other guards in the same `is_shown` / `is_valid` / `can_create`. If another guard still blocks the reporter's case, the fix doesn't work. See `examples.md` (#440).
- **Check all siblings, not just the ones with the matching pattern.** When a fix applies a guard to some items in a group, read every sibling item's conditions to determine whether it has the same exposure. A sibling whose conditions look unrelated may still be satisfiable by the invalid subject through a different path.
- **Find all call sites of the buggy code path.** Grep the symbol you're about to guard. Vanilla often runs the same logic in 2-3 places; missing a duplicate leaves the bug unfixed. See `examples.md` (#213).
- **Evaluate suggested fixes critically.** Both the reporter's diagnosis and any `Fix directions` in the shared file are candidates, not defaults — re-derive the approach from the verified facts. Watch for fixes that destroy state other systems still depend on. See `examples.md` (#213, #498).
- **Name the load-bearing assumption.** State the single behavioral assumption the fix rests on and corroborate it from files (a working precedent, a `.info`/log line); if it can't be confirmed, flag it for in-game testing. See `examples.md` (#498).
- **On a re-fix**, make sure the new approach resolves the review findings rather than working around them.

**Paradox Script Gotchas:**

- **`custom_description` is a tooltip wrapper, not a condition.** `custom_description = { text = X; <trigger> }` evaluates `<trigger>` and labels failures with `X`'s loc — the `text =` line is not a separate condition.

### 3. Apply the Fix

Following the project `CLAUDE.md` "General", "Style", and "Opening PRs" guidelines:

1. **Be on a fix branch.** If you're on the default branch (`main`), create one from a clean tree; otherwise you're already on the fix branch — use it.
   ```shell
   # First attempt, only when on main. Working tree should be clean apart from .claude/; if not, stop.
   git status --porcelain | grep -v '^.. \.claude/'
   git checkout main && git pull --ff-only
   git checkout -b <git-user>-fix-<short-slug>   # from the issue title, no issue number
   ```

2. **Apply the fix.** Minimal change; `#Unop` comment on the first changed line; comment out rather than delete unneeded vanilla code. When enclosing existing code in a scope, indent it properly. New vanilla files should be added without modifications in a separate commit.

3. **Validate**: run `make tiger` and ensure no new errors or warnings.
   - If new errors appear in newly-added vanilla files, fix or ignore them in the same PR.
   - **invoke the `tiger` skill to handle tiger error reports.

4. **Commit fix files scoped by path.** Stage explicitly (`git add -- <path>`, never `git add -A`) **and** commit with a pathspec: `git commit -m "<summary>" -- <path...>`. Before committing, run `git diff --cached --name-only` and confirm only the fix files are listed. Commit message: short imperative summary.

5. **Open or update the PR:**
   - **First fix attempt**: open a draft PR whose description contains a `Fixes #<N>` line and a **concise** description of the fix prefixed with `**<identity>:**`. The `Fixes #<N>` line auto-links the issue, which already contains the analysis comment and labels. This description **is** your first-fix comment — don't also post a separate PR comment.

     ```shell
     gh pr create --draft --title "<title>" --body "$(cat <<'EOF'
     Fixes #<N>

     **<identity>:** <short description of the fix>
     EOF
     )"
     ```

   - **Re-fix attempt**: push to the existing branch — the PR updates automatically. Then post a **concise** `**<identity>:**` PR comment explaining what changed (`gh pr comment <PR>`, resolving `<PR>` with `gh pr view --json number -q .number` on the checked-out branch); if the re-fix addressed PR feedback, reply to those comments directly.

### 4. Append to the Shared File

Append a `## Fix N` section to the shared file (N = 1 for the first attempt, 2 for the second, etc.):

```markdown
## Fix N

**Approach:** <one-sentence description>

**Addresses review:** <which Review findings this resolves; omit on the first attempt>

**Files changed:**
- `<path>` — <one-line note>

**Key assumption:** <the single behavioral assumption the fix depends on, and its corroboration — or "test in-game" if unconfirmed>

**Commit:** <commit message>

**PR:** <PR URL> | existing PR updated
```

### 5. Report Summary

When done, report to the user:

- Approach applied and why; on a re-fix, which review findings it resolved.
- Files changed, commit, PR link.
- Ask the user to manually verify the fix in-game and run in observer mode to check `error.log` for errors related to the fix.

## Reference

### Examples

`examples.md` contains past investigations, one section per issue. Read the relevant section when its situation comes up.

## Usage Examples

```bash
/unop-fix-issue 419
```
