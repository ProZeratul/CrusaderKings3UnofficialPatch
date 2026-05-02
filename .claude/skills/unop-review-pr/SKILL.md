---
name: unop-review-pr
description: Review a GitHub PR, propose inline review comments, and post a final summary
argument-hint: "<pr-number>"
---

# Review Unop GitHub PR

Review a pull request opened against the Unop GitHub repo. Compare changes against vanilla (or `main`), draft inline review comments for changed lines that raise concerns, and post a final summary comment.

## Concepts

- **GitHub repo**: `ProZeratul/CrusaderKings3UnofficialPatch`. Use the `gh` CLI for all GitHub operations.
- **PR**: A pull request opened against the Unop repo (typically a fix from a contributor, often linked to an issue with `Fixes #<id>`).
- **Fix**: A logically related group of changes that addresses one issue. A PR may contain multiple unrelated fixes.

## Context

- Commands should be executed in the Unop repo root.

## Arguments

**PR number** (position $0, required): The GitHub PR number to review (e.g. `433`).

## Guidelines

- **Always** read the project's `CLAUDE.md` first.
- **Always** fetch any links to GitHub issues or external links from the PR.
- **Always** compare changes against vanilla (or `main`) to understand what was modified and why.
  - If an Unop file exists for the changed path, read it instead of the vanilla one.
- **Always** review the actual changes, not the entire files (read more only when context requires).
- Prefer concrete and concise feedback; avoid praise.
- Don't consider project maintenance changes (e.g. updates to `.gitignore`) as fixes; only mention them if they raise concerns.
- **Always** ask the user for approval before posting reviews to GitHub.
- **Never** approve PRs unless explicitly instructed.

## Workflow

### 1. Fetch the PR

Read the PR header, body, comments, and diff:

```shell
gh pr view <N> --comments
gh pr diff <N>
```

Note linked issues (e.g. `Fixes #<id>`) and any external references — fetch their content for context.

### 2. Identify Distinct Fixes

Group related changes together into a single "fix". Count the distinct fixes in the PR. If multiple unrelated fixes are bundled, plan to review each one separately and ask the user to check each review before continuing to the next.

### 3. Review Each Fix

For each fix, in turn:

1. Read the relevant Unop and vanilla files (the actual changes; read more only if context requires).
2. Compare against vanilla / `main` to understand what was modified and why.
3. If particular changed lines raise a concern, draft an inline review comment for those specific lines. Keep it concrete and short.
4. **For multi-fix PRs**, present the per-fix review to the user and wait for their go-ahead before moving to the next fix.

### 4. Prepare the Final Summary

Write the **final summary** comment for the entire PR. Use the **Summary Template** in Reference, with one block per fix. Only include the `Fix N: Title` heading row if there are multiple fixes.

### 5. Get User Approval and Post

Wait for explicit user approval before posting any inline comments or the final summary to GitHub. Never approve the PR unless explicitly instructed.

```shell
# Post the summary as a top-level review comment
gh pr review <N> --comment --body "$(cat <<'EOF'
<summary markdown>
EOF
)"
```

For inline comments on specific lines (when `gh pr review` is insufficient), use the API directly — see **gh Snippets** in Reference.

### 6. Report Summary

When done, report:

- PR number and title.
- Number of distinct fixes reviewed.
- What was posted (inline comments + summary), or what's still waiting on user approval.
- Any open recommendations.

## Reference

### Summary Template

Use this template for the final summary comment. Repeat the block per fix. Omit the `Fix N: Title` heading line for single-fix PRs.

```markdown
### Fix N: Title

* **File(s):** `file1`, `file2`
* **Issue:** A description of the issue (1-3 sentences)
* **Fix:** A description of the fix (1-3 sentences)
* **Analysis:** Analysis of the fix quality (1-2 sentences)
* **Recommendations:** What could be improved (1-2 sentences, only if needed)

_-- Review by Claude Code_
```

### gh Snippets

```shell
# Read PR header + comments
gh pr view <N> --comments

# Read the diff
gh pr diff <N>

# Post summary as a top-level review comment (does not approve)
gh pr review <N> --comment --body "$(cat <<'EOF'
<summary markdown>
EOF
)"

# Post an inline comment on a specific line of the PR diff
gh api -X POST repos/ProZeratul/CrusaderKings3UnofficialPatch/pulls/<N>/comments \
  -f body="<comment>" \
  -f commit_id="<sha>" \
  -f path="<file>" \
  -F line=<lineno> \
  -f side=RIGHT
```

## Usage Examples

```bash
# Review PR 433
/unop-review-pr 433
```
