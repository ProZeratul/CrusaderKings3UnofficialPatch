---
name: unop-analyze-issue
description: Analyze a GitHub issue, classify it, post a comment, and write findings to a file
argument-hint: "<issue-number>"
---

# Analyze Unop GitHub Issue

Analyze a reported issue in the Unop GitHub repo against vanilla and mod files, classify it on several dimensions, write findings to a shared file, and post a concise comment and labels on the issue.

This skill runs **autonomously**, without asking for approval. Any human gates belong to the calling workflow, not here. It reports a summary at the end.

## Concepts

- **GitHub repo**: `ProZeratul/CrusaderKings3UnofficialPatch`. Use the `gh` CLI for all GitHub operations.
- **Issue**: A bug report (or occasionally an enhancement request) opened against the Unop repo.
- **Shared file**: `tmp/issue-<N>.md` — the handover document. This skill creates it with the `## Analysis` section. Other skills may append to it later.

## Context

- Commands should be executed in the current working tree (the Unop repo root, or the worktree the session was launched in).

## Arguments

- **Issue number** (position $0, required): The GitHub issue number to analyze (e.g. `419`).
- **Identity** (position $1): the role this skill posts as, defaults to `analyzer`.

## Guidelines

- **Read the project's `CLAUDE.md`** first.
- **Identify yourself.** Post as `<identity>`: begin each comment's first line with `**<identity>:**`. A comment containing `@<identity>` is addressed to you.
- **Read the issue body and all comments** before forming a hypothesis. Earlier comments often contain repro details, partial diagnoses, or maintainer responses that change the picture.
- **Analyze against the actual files.** Read the relevant parts of both the vanilla file and the Unop override (if any) — don't reason from grep matches alone.
- An issue tagged as `vanilla` is still a real bug to be fixed in Unop — don't dismiss it as "not our code".
- **Don't assume that the reporter is correct.** They may have misidentified the file, the cause, or the scope.
- **Diagnose, don't prescribe.** Your job is the root cause and the solution *space*, not the chosen remedy. Any fix direction you record is soft input: one or more hypotheses with trade-offs, never a single verdict.
- **Run autonomously.** Make the best classification you can, post the comment, and apply labels without pausing for approval. Encode any uncertainty in the `confidence` field rather than stopping to ask.
- **Don't apply the `duplicate` or `wontfix` labels** — note candidates in the findings and comment instead.
- **Don't close issues.** Closure is a maintainer action.

## Workflow

### 1. Fetch the Issue

Read the issue and all its comments:

```shell
gh issue view <N> --comments
```

Note any existing labels — they may already encode prior triage. Note any linked PRs.

**Identify how many distinct bugs the issue contains.** A title may name one symptom while later comments describe others. If the issue covers more than one distinct bug, record each in the findings and classify the issue by the primary bug, noting the others. Don't silently work only the title bug.

**Re-analysis.** If the issue already carries a `**<identity>:**` comment from you, you have analyzed this before. Consult the shared file if it exists. Read your prior comment, then read **all** comments posted *after* it (especially any addressing `@<identity>`). Make sure to take into account any **feedback from the maintainers**. Re-analyze from the files, **treat your prior conclusion skeptically**, and correct it.

### 2. Identify the Affected Files

From the issue, extract:

- File paths the reporter mentions.
- Object names (event IDs, trigger names, modifier keys, localization keys).
- Game version mentioned (if any).
- Reproduction steps and expected vs. actual behavior.

If the reporter only describes a symptom, search the vanilla and Unop trees to locate the responsible file(s):

```shell
grep -rn "<key or symbol>" "${CK3_BASE_DIR}/<area>/" 2>/dev/null
grep -rn "<key or symbol>" .
```

If the relevant file cannot be located confidently, classify as **question** and ask the reporter for the file path.

### 3. Investigate

For each candidate file:

1. **Read the Unop override if it exists.** Unop overrides vanilla — what the game runs is the Unop copy. Read its relevant parts in full.
2. **Read the vanilla file** to compare and confirm whether Unop has already touched the relevant code.
3. **Check the relevant `.info` file** in the vanilla directory and the `${CK3_USER_DIR}/logs/*.log` files (`triggers.log`, `effects.log`, `event_scopes.log`, etc.) to verify scopes, signatures, and names.
4. **Trace the actual code path** the reporter describes — don't reason from the title alone.

**Guidelines:**

* **Recover design intent from the whole feature**, including its localization and effects, not just guard predicates. A narrow guard may be a proxy for a real condition; two independent guards agreeing on the same restriction signal intent.
* **Map the pattern class.** Identify the category the buggy object belongs to — the object group or family, event chain, or set of analogous systems. Enumerate its members and check each for the same bug. Where a comparable member does **not** exhibit the bug, work out *how* it avoids it — that comparison usually reveals the right altitude for the fix.
* **Verify against the decisive evidence.** Reading a condition isn't checking it — confirm the actual mechanism, which may live upstream (e.g. how the object is created) rather than in its own definition. A contradiction is a lead to trace, not something to wave away.

Specifically look for:

- Does the bug reproduce in the current vanilla file? → leans **vanilla**.
- Did Unop modify this code path? Look for `#Unop` markers and compare against the vanilla file. If yes, did Unop's changes introduce the regression? → leans **mod**.
- Does the reporter's claim match the file contents? If not, the issue may be **invalid**, OR the reporter is on a stale version, OR another mod is interfering.

### 4. Classify

Decide on three label dimensions plus a confidence level.

#### Origin (exactly one)

- **`vanilla`** — the buggy code is in the base game and is not (or not adequately) patched by Unop.
- **`mod`** — Unop itself is the cause: an Unop override is wrong or was made obsolete by a vanilla update.

#### Area (one or several)

- **`common`** — anything under `common/`.
- **`events`** — anything under `events/`.
- **`gui`** — anything under `gui/`.
- **`localization`** — missing or wrong loc keys, only loc files need to change.
- **`history`** — anything under `history/`.
- **`gfx`** — anything under `gfx/`.

If the affected area doesn't fit any of these (e.g. `map_data/`), don't invent a label — note in the findings and summary that a new area label may be needed, and apply only the labels that do exist.

#### Status (exactly one)

- **`confirmed`** — the bug is verified against the files and a script fix is feasible.
- **`question`** — need more from the reporter to proceed, including when the bug can't be verified from script and needs an in-game repro.
- **`invalid`** — analysis shows it isn't a bug, it's already fixed, or it's not fixable in script.

Two independent axes decide the status:

| Real bug? | Fixable in script? | status |
|---|---|---|
| yes | yes | `confirmed` |
| yes | no (engine-hardcoded) | `invalid` (out of scope) |
| no (intended / already fixed) | — | `invalid` |
| can't tell from files | — | `question` |

An `invalid` (out of scope) conclusion is door-closing, so it must clear the same bar as proposing a fix.

Also flag (but don't apply):

- **`duplicate`** — if you find an existing open or closed issue covering the same thing. Mention the number in the findings and comment.
- **`wontfix`** — if the fix appears risky or low value. Never decide this autonomously; flag it for the maintainer.

#### Confidence (exactly one)

How sure you are of the classification, whatever it is:

- **`high`** — the classification is unambiguous. For `confirmed`: the bug reproduces in the current files with a clear root cause and no plausible alternative. For `invalid`: the files plainly contradict the report or it's clearly out of scope. For `question`: the missing information is clearly identified and genuinely required to proceed.
- **`medium`** — likely but not certain: multiple possible causes, a possible duplicate, or the reporter's claim only partially matches the files.
- **`low`** — uncertain: the reporter may be on a stale version, another mod may be interfering, or missing information could change the picture.

### 5. Write to the Shared File

Create the shared file, or re-write it if this is a re-analysis. The findings here are the detailed record, the GitHub comment in step 6 is the concise version. 

```markdown
---
issue: <N>
title: "<issue title>"
status: confirmed|question|invalid
origin: vanilla|mod
area: [events, common, ...]
confidence: high|medium|low
---

## Analysis

**Reported:** <what the reporter claims, 1-2 sentences>

**Files checked:**
- `<path>` (Unop) — <note on what's relevant here>
- `<path>` (vanilla) — <note>

**Findings:** <verified facts — evidence that can be relied on>
- <bullet: the code path traced, what the relevant lines do>
- <root cause, with the specific trigger/effect/guard and why it misbehaves>
- <reachability: does it still reproduce in current vanilla?>
- <any duplicate / wontfix / multi-bug / new-area-label notes>

**Pattern class:** <the category this bug belongs to and its members; for each, whether the bug applies; and how comparable members that avoid it do so>

**Fix directions:** <optional and soft — one or more hypotheses with trade-offs, never a single prescribed remedy; omit this if you are not confident.>

**Classification:** `<status>` / `<origin>` / `<area>` — confidence `<confidence>`
```

### 6. Post a Comment and Apply Labels

Post a **concise** comment on the issue and apply the labels. Use the matching template from Reference.

- **confirmed**: post the "Confirmed" comment; apply `confirmed`, origin, area, and `confidence:<level>`.
- **question**: post the "Question" comment; apply `question` and `confidence:<level>`, plus origin and area if confidently known.
- **invalid**: post the "Invalid" comment; apply `invalid` and `confidence:<level>`, plus origin and area if applicable. Do not close the issue.

Apply only your own labels (status, origin, area, confidence). On a re-analysis, remove any stale labels you are replacing.

```shell
gh issue comment <N> --body "$(cat <<'EOF'
<comment markdown>
EOF
)"
gh issue edit <N> --add-label "confirmed,vanilla,common,confidence:high"
```

If this is a re-analysis, post a **very concise** follow-up comment stating what changed compared to the previous one.

### 7. Report Summary

When done, report to the user:

- Issue number and title.
- Classification applied (status / origin / area / confidence).
- Action taken: comment posted, labels applied, and findings written to the shared file.
- Anything that may need a human decision: `duplicate`/`wontfix` candidates, a missing area label, or multiple distinct bugs.

## Reference

### Comment Templates

Keep the posted comment **concise** — the details are in the shared file. Keep it to the diagnosis, don't prescribe a fix in it.

**Confirmed:**

```markdown
**<identity>:** Confirmed.

- <root cause in 1-2 lines>

**Classification:** `confirmed` / `<origin>` / `<area>` — confidence `<confidence>`
```

**Question:**

```markdown
**<identity>:** Information needed.

To proceed, could you please provide:
- <specific ask 1>
- <specific ask 2>
```

**Invalid:**

```markdown
**<identity>:** Not a bug (or out of scope).

- <reason, citing what was checked>

Could you confirm whether it still reproduces with only vanilla + Unop?
```

### gh Snippets

```shell
# Search for possible duplicates (open + closed)
gh search issues "<keywords>" --repo ProZeratul/CrusaderKings3UnofficialPatch --state all
```

## Usage Examples

```bash
/unop-analyze-issue 419
```
