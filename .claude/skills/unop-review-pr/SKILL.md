---
name: unop-review-pr
description: Adversarially review a PR's diff against main with inline comments and a verdict, appending to the shared file if one exists
argument-hint: "<PR> [<anchor>]"
---

# Review Unop PR

Adversarially review the change in a PR. Read the shared file if present, review the approach and the diff against `main`, and rate each finding by severity. Append a `## Review N` section to the shared file, post inline comments and a verdict review on the PR, and apply a verdict label to the anchor.

This skill runs **autonomously**, without asking for approval. Any human gates belong to the calling workflow, not here. It reports a summary at the end.

## Concepts

- **GitHub repo**: `ProZeratul/CrusaderKings3UnofficialPatch`. Use the `gh` CLI for all GitHub operations.
- **Anchor**: the issue or PR number carrying the labels and shared file — the issue a PR closes, or the PR itself if it closes none.
- **Shared file**: `tmp/issue-<anchor>.md` — the handover document. Other skills may create it with the `## Analysis` section and append `## Fix N` sections. This skill reads both and appends `## Review N`. May be absent.

## Context

- Commands should be executed in the current working tree (the Unop repo root, or the worktree the session was launched in).

## Arguments

- **PR number** (position $0, required): the GitHub PR to review (e.g. `517`).
- **Anchor number** (position $1): the issue or PR carrying the shared file and labels; defaults to the PR.
- **Identity** (position $2): the role this skill posts as, defaults to `reviewer`.

## Guidelines

- **Read the project's `CLAUDE.md`** first.
- **Identify yourself.** Post as `<identity>`: begin each comment's first line with `**<identity>:**`. A comment containing `@<identity>` is addressed to you.
- **Read the shared file in full if present** — the `## Analysis` section and every prior `## Fix N` and `## Review N`.
  - If there is none, derive the change's intent from the PR description, diff, and any linked issue.
- **Read the relevant parts of the Unop and vanilla files** before reviewing — don't limit yourself to the diff.
- **Be adversarial.** Your job is to find problems with the fix, not to validate it. Default to skepticism.
- **Don't invent problems.** Only report findings grounded in the actual code and game mechanics.
- Consult `examples.md` for relevant past investigations when a situation it covers comes up.

## Workflow

### 1. Load Context

Read the shared file for the investigation, the fix approach, and prior fix/review cycles.

Count the existing `## Fix N` sections — this review is `## Review N` for the same N. Review only the latest fix; earlier `## Fix N` / `## Review N` sections are history for context. If the shared file is absent, this is `## Review 1`: start it from the PR's intent in place of `## Analysis`.

**Re-review due to PR feedback.** If the PR carries comments after your last `**<identity>:**` comment (especially any addressing `@<identity>`), read its conversation and review comments — `gh pr view <PR> --comments`, plus inline comments via `gh api repos/ProZeratul/CrusaderKings3UnofficialPatch/pulls/<PR>/comments`. Take any **feedback from the maintainers** into account but **vet each against the code**; fold valid points into your `## Review N` findings, and note any you disagree with rather than silently deferring.

### 2. Check Out the PR and Get the Diff

Check out the PR branch so you can read PR-side files in full, then get its diff with `gh pr diff`. Read the relevant parts of the affected Unop and vanilla files for context beyond the diff:

```shell
gh pr checkout <PR>
gh pr diff <PR>
```

### 3. Review

A PR may bundle several distinct changes; apply the checks below to each on its own merits. The output stays a single findings list and one verdict — don't split it into per-change sections.

1. **Review the Approach**

Before the line-level review, judge the approach itself — as stated in the latest `## Fix N` and as realized in the diff:

- **Root cause vs. symptom.** Does the approach target the root cause identified in `## Analysis`, or does it patch over a symptom while the underlying bug remains?
- **Simplicity.** Is this the simplest viable fix? Flag new state, new files, or new triggers added where an existing trigger, variable, flag, or guard would have expressed the fix. See `examples.md` (#420).
- **Altitude.** Could one higher-level change replace the N changes? If the fix patches each member of a group, is the group itself the right level? If an analogous system handles the same condition, does the fix mirror that verified mechanism or invent a parallel one? See `examples.md` (#498).
- **Pattern class / sibling systems.** Did the fix enumerate the whole category? Check analogous systems — other files sharing the mechanic — for the same bug; a reproducing sibling left untouched is a finding. See `examples.md` (#498).
- **Load-bearing assumption.** Is the single behavioral assumption the fix depends on corroborated (a precedent, a doc/log line) or merely asserted? An unverified core assumption is a finding even if prior cycles repeated it. See `examples.md` (#498).
- **Guard intent.** If the approach loosens or adds a guard, is the stated intent sound and aligned with the design intent in the whole feature — comments, localization, and effects? Watch for a widened proxy that re-admits the cases it was guarding. See `examples.md` (#440, #501).
- **Reporter's fix.** If the approach follows the reporter's suggestion, was that suggestion evaluated critically rather than taken as default? See `examples.md` (#213).
- **Re-fix.** If a prior `## Review N` exists, does this approach genuinely resolve its `High`/`Medium` findings, or merely work around them?

2. **Review the Implementation**

For each changed file, check:

- **Missed call sites.** Grep the guarded symbol across the codebase. Vanilla often runs the same logic in 2-3 places; one missed duplicate means the bug survives. See `examples.md` (#213).
- **Guard interactions.** Are there other guards in the same `is_shown` / `is_valid` / `can_create` block that would still block the reporter's case even after this fix? See `examples.md` (#440).
- **Side effects.** Does the fix destroy state that other events, effects, or on_actions still depend on? See `examples.md` (#213).
- **`#Unop` comments.** Are they present on the first changed line? Are they accurate and concise?
- **Tiger is clean.** Re-run `make tiger` yourself — don't trust the fix's claim that it passes. Any error or warning the fix introduced or left unaddressed is a finding. Don't invoke the `tiger` skill or fix anything; that's for the next fix cycle.
- **Tiger suppressions.** If the fix added entries to `ck3-tiger.conf` (`# False positives` / `# Ignored`), challenge each one: warnings should be fixed, not suppressed, unless tiger is proven wrong. A warning suppressed that should have been fixed is a finding.
- **Vanilla file commits.** If a new vanilla file was added, was it added in a separate commit without modifications?

### 4. Rate Findings

Assign each finding a severity:

- **`High`** — the fix is wrong or incomplete: the original bug survives, a regression is introduced, another system is broken, or the approach is fundamentally misdirected.
- **`Medium`** — a significant concern with a plausible failure mode: likely-missed call site, suspicious guard interaction, untested edge case, or a needlessly complex approach.
- **`Low`** — style, clarity, or minor correctness issue that doesn't affect whether the fix works.

Severity tracks the **shipped fix** (the diff and its in-game behavior), not the handover prose. A change you've judged correct and on-purpose is not a Medium because the `## Fix N` narrative omitted it, understated its scope, or gave a wrong rationale. An under-described change is at most a `Low` finding pointing testers at it; it never drives the verdict.

The verdict is **`Needs work`** if there is any `High` or `Medium` finding, otherwise **`Looks good`**.

### 5. Append to the Shared File

Append a `## Review N` section to the shared file:

```markdown
## Review N

**Verdict:** Looks good | Needs work

**Findings:**

| Severity | Description |
|---|---|
| High | ... |
| Medium | ... |
| Low | ... |
```

Omit the findings table if there are no findings.

### 6. Post the Review and Apply the Verdict Label

Get the PR head commit:

```shell
SHA=$(gh pr view <PR> --json headRefOid -q .headRefOid)
```

**Prefer inline comments.** For each changed line that raises a concern, write a line-level comment — adding a ` ```suggestion ` block proposing the exact change where you can. Submit them together with the verdict as **one review** with event `COMMENT`, so you neither approve nor block. Build the payload as a JSON file, then post it:

```shell
# tmp/review.json:
# {
#   "commit_id": "<SHA>",
#   "event": "COMMENT",
#   "body": "**<identity>:** <Looks good | Needs work> — <gist>\n\n- <one line per High/Medium finding>",
#   "comments": [
#     { "path": "<file>", "line": <new-file line in the diff>, "side": "RIGHT", "body": "<note; optionally a ```suggestion block>" }
#   ]
# }
gh api -X POST repos/ProZeratul/CrusaderKings3UnofficialPatch/pulls/<PR>/reviews --input tmp/review.json
```

Comment only on lines present in the diff, using new-file numbers with `side: RIGHT`. Omit `comments` if you have no line-level notes.

Apply your verdict label to the **anchor** via the label API — set `review:looks-good` or `review:needs-work`, removing the other:

```shell
gh api --silent -X POST repos/ProZeratul/CrusaderKings3UnofficialPatch/issues/<anchor>/labels -f "labels[]=review:needs-work"
gh api --silent -X DELETE repos/ProZeratul/CrusaderKings3UnofficialPatch/issues/<anchor>/labels/review:looks-good
```

### 7. Report Summary

When done, report to the user:

- Verdict (`Looks good` or `Needs work`).
- Summary of `High` and `Medium` findings; `Low` findings briefly.
- Recommended next step: if `Needs work`, the fix needs another pass; if `Looks good`, the PR is ready for human review.

## Reference

### Examples

`examples.md` contains past investigations, one section per issue. Read the relevant section when its situation comes up.

## Usage Examples

```bash
/unop-review-pr 517
```
