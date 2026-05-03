---
name: unop-import-steam-comments
description: Scan recent Steam comments for bug reports and open GitHub issues for them
argument-hint: "[count|--since YYYY-MM-DD] [main|suggestions] [--yes]"
---

# Import Unop Steam Comments as GitHub Issues

Scan recent comments on the Unop Steam Workshop page (or its "Fix suggestions" discussion), filter to bug reports, group multi-post threads, deduplicate against existing issues, and open a GitHub issue for each new bug — autonomously, with a single user approval before posting.

## Concepts

- **Steam page (main)**: <https://steamcommunity.com/sharedfiles/filedetails/?id=2871648329> — the mod's Workshop page comment stream.
- **Steam page (suggestions)**: <https://steamcommunity.com/workshop/filedetails/discussion/2871648329/4697908845434539387/> — the dedicated "Fix suggestions" discussion thread.
- **Maintainer**: Steam users `Kazarion` and `pharaox`, identify by author username. Maintainer posts are not bug reports themselves but may anchor a thread.
- **Thread**: One bug report's worth of posts. Steam shows posts flat (no nesting), so a thread is inferred from chronology and content — typically a user's bug post, followed by a maintainer reply asking for details, followed by the same user's clarification.
- **Marker**: A machine-greppable HTML comment placed in each filed issue's body, of the form `<!-- steam-comment: <author> @ <YYYY-MM-DD HH:MM> -->`. Used to detect duplicates on subsequent runs.
- **GitHub repo**: `ProZeratul/CrusaderKings3UnofficialPatch`. Use the `gh` CLI for all GitHub operations.

## Context

- Commands should be executed in the Unop repo root.
- Steam exposes two fetch surfaces, both read-only:
  - **Main page**: a JSON "render" endpoint returns paginated comments — see **Fetch URLs** in Reference.
  - **Suggestions thread**: a normal HTML page paginated by `?ctp=N` — see **Fetch URLs** in Reference.
- `WebFetch` summarizes by default, so prompts must explicitly demand verbatim, structured output. For the JSON endpoint, `curl` via `Bash` is more reliable.
- The `steam` label already exists on the repo.

## Arguments

Both arguments are optional and order-independent.

- **Scope** (one of):
  - `<count>`: integer, scan the most recent N posts. Default: `20`.
  - `--since YYYY-MM-DD`: scan posts on or after this date. Overrides `<count>`.
- **Source** (one of): `main` (default) or `suggestions`.
- **Approval** (flag): `--yes` skips the candidate-list approval step and files all `bug` candidates directly. Default is **on** (i.e. ask for approval).

Examples: `30`, `main 30`, `suggestions`, `--since 2026-04-01 suggestions`, `50 --yes`.

## Guidelines

- **Always** read the project's `CLAUDE.md` first.
- **Always** present the candidate list to the user **before** filing any issue, unless `--yes` is given. One batch approval is enough — don't prompt per issue.
- **Only** file `bug` candidates. Skip everything else (thanks, install help, compatibility questions, feature/balance requests, off-topic).
- **Never** file an issue without the marker comment in the body. The marker is what prevents duplicates on the next run.
- **Never** edit, delete, or close existing issues from this skill — only create new ones.
- **Never** assign labels other than `steam`. Triage labels (`confirmed`, `vanilla`, `mod`, area labels) are assigned by other skills.
- **Never** modify the Steam page — Steam is read-only here.
- If a candidate's classification is genuinely ambiguous, list it under "Uncertain" in the presentation and let the user decide. With `--yes`, exclude uncertain candidates.
- Quote the Steam comment text **verbatim**. Do not paraphrase, translate, or "fix" the user's wording.
- If a comment links to an image, fetch it, confirm relevance, and attach to the issue — see **Fetching Images** in Reference. If an image-only follow-up can't be fetched or isn't relevant, mark the candidate Uncertain.
- If a maintainer reply links to a GitHub issue, skip the candidate — already tracked.
- If a maintainer reply attributes the report to a stale mod version (e.g. "wait for the update", "don't use the mod before it's updated") and that update has since shipped, mark the candidate Uncertain — the bug may already be fixed.

## Workflow

### 1. Parse Arguments

Parse the args per the **Arguments** section. Resolve scope, source, and approval flag.

### 2. Fetch Comments

Run the bundled fetch script — it handles both sources, pagination, the 10-page cap, suggestions newest-on-last-page walk, and emits structured JSON. Prefer this over inline parsing.

```shell
.claude/skills/unop-import-steam-comments/scripts/fetch_steam_comments.py \
  --source <main|suggestions> [--count N | --since YYYY-MM-DD]
```

Output is a JSON array on stdout, newest-first; each item has `id`, `ts`, `date_utc` (`YYYY-MM-DD HH:MM`, UTC), `author`, `text`, `page`. A page-cap warning is printed to stderr if the cap is hit.

**Fallback**: if the script fails (non-zero exit, malformed JSON, missing fields, or output that looks structurally wrong — e.g. authors with leftover HTML tags, empty `text` for clearly non-empty comments), fall back to manual parsing: `curl` the endpoints in **Fetching URLs** (Reference) and parse the `commentthread_comment` blocks directly with a small `python3` heredoc using the per-comment fields documented there. Note the failure and the workaround used; surface this in the final report (step 8) so the script can be fixed afterwards.

### 3. Group into Threads

Steam posts are flat. Reconstruct threads by walking the posts in chronological order and applying:

1. A non-maintainer post starts a new candidate thread.
2. A maintainer post attaches to the most recent candidate thread **only if** it plausibly replies to it (mentions the user or topic).
3. A subsequent post by the **same** non-maintainer user attaches to their most recent thread if its content continues the same topic (answers a maintainer question, adds repro details, etc.).

The thread's marker is built from the **first** non-maintainer post (the OP): `<!-- steam-comment: <OP author> @ <OP date> -->`.

If a maintainer post stands alone with no preceding user post in scope, drop it — it's the maintainer's release note or unrelated reply.

### 4. Classify Each Thread

For each thread, classify as one of: `bug`, `feature`, `thanks`, `question`, `help`, `other`.

Bug indicators (lean `bug`): error log excerpts, "broken", "doesn't work", "wrong tooltip", "missing localization", specific event/decision/trait IDs paired with a complaint, "stuck on", "CTD/crash", "infinite loop", reports of unintended NPC behavior tied to a specific mechanic.

Skip indicators:

- `feature`: "could you add", "please make", "I wish", balance tuning requests.
- `thanks`: "thanks", "great mod", "love it" with no bug content.
- `question`: "is this compatible with", "how do I", "does this work with X mod".
- `help`: install issues, load order issues, launcher problems.
- `other`: off-topic, spam, untranslatable.

Keep only `bug`. List ambiguous ones under "Uncertain" in the presentation.

### 5. Deduplicate Against GitHub

For each `bug` candidate, search for an existing issue with the marker:

```shell
gh search issues "steam-comment: <OP author> @ <OP date>" \
  --repo ProZeratul/CrusaderKings3UnofficialPatch --json number,title,url
```

Quote the marker text exactly when searching. Drop candidates that match. Here "match" means the marker substring appears in an existing issue's body. If the search returns hits but none truly contain the marker, treat as no match.

### 6. Present Candidates and (Optionally) Wait for Approval

Show the user a single concise summary:

```
Found N bug candidates from <source>, scope <scope>:

1. <OP author> @ <OP date> — <one-line summary>
   Title: "<proposed issue title>"
   Posts in thread: <count>

2. ...

Uncertain (excluded by default):
- <OP author> @ <OP date> — <one-line summary> (reason: <why uncertain>)

Skipped as duplicates of existing issues:
- <OP author> @ <OP date> → #<issue-number>

Skipped as not-bug:
- <count> total (<count by category>)
```

- If `--yes` was **not** given: ask "File the N bug candidates as new issues?" and wait for explicit approval. 
- If `--yes` was given: skip the prompt and proceed to step 7. Still show the summary first. Uncertain candidates are excluded.

### 7. File Issues

For each approved candidate, create the issue with the **Issue Template** in Reference. Apply the `steam` label. Title format: short imperative summary derived from the bug content.

```shell
gh issue create \
  --repo ProZeratul/CrusaderKings3UnofficialPatch \
  --label steam \
  --title "<title>" \
  --body "$(cat <<'EOF'
<body per template>
EOF
)"
```

### 8. Report Summary

When done, report:

- Source and scope used.
- Counts: candidates found / filed / skipped-duplicate / skipped-not-bug / uncertain.
- A list of newly filed issues with their numbers and URLs.
- A ready-to-post Steam acknowledgement in BBCode — see **Steam Message Template** in Reference.
- Suggested follow-up: "Run `/unop-investigate-issue <N>` on each to triage."
- **If the fetch script failed** and manual parsing was used: state which step failed, what the symptom was, and that `scripts/fetch_steam_comments.py` likely needs an update.

## Reference

### Issue Template

```markdown
**Reported on Steam by `<OP author>` on `<OP date>`** (<link>).

> <verbatim OP comment text, blockquoted; preserve line breaks>

<!-- For multi-post threads, append clarifications: -->
**Follow-up by `<author>` on `<date>`:**

> <verbatim follow-up text>

**Follow-up by `<author>` on `<date>`:**

> <verbatim follow-up text>

<!-- steam-comment: <OP author> @ <OP date> -->
```

The marker comment **must** be the last line of the body and **must** match the format exactly — it's the dedup key for future runs.

### Steam Message Template

Steam BBCode acknowledgement to post on the Steam page:

```
@<user1>, @<user2>, ... Thanks for the reports! We've opened the following GitHub issues to track them:
- [url=<issue-url>]#<N> <issue-title>[/url]
- ...
```

One bullet per filed issue (a reporter with multiple issues gets multiple bullets). Steam caps comments at 1000 characters, so split into separate self-contained comments of **at most 4 issues each**, each with its own header listing only the reporters in that batch.

### Fetching URLs

**Main** (JSON, paginated by offset):

```
GET https://steamcommunity.com/comment/PublishedFile_Public/render/76561198047801064/2871648329/?start=<offset>&count=<n>
```

Newest-first. Response JSON has `total_count` and `comments_html` (HTML fragment of `<div class="commentthread_comment ...">` blocks). `76561198047801064` is the mod owner's SteamID64; `2871648329` is the Workshop ID.

**Suggestions** (HTML, paginated by `?ctp=N`, 1-based):

```
GET https://steamcommunity.com/workshop/filedetails/discussion/2871648329/4697908845434539387/?ctp=<page>
```

Same `commentthread_comment` block structure as the main page.

**Per-comment fields** in each block:

- Author: text inside `<bdi>` under `class="commentthread_author_link"`.
- Timestamp: `data-timestamp="<unix-seconds>"` on `<span class="commentthread_comment_timestamp">` — authoritative; the visible date string is locale-formatted.
- Text: inside `<div class="commentthread_comment_text">`; preserve `<br>` as newlines and unescape HTML entities.

### Fetching Images

`WebFetch` cannot reach `imgur.com`. Use `curl` instead:

1. Fetch the album/post page: `curl -sS -L -A "Mozilla/5.0" "<imgur-url>" -o /tmp/album.html`.
2. Extract image URLs: `grep -oE 'i\.imgur\.com/[A-Za-z0-9]+\.(jpg|jpeg|png|gif)' /tmp/album.html | sort -u`. The `og:image` meta tag is also reliable for single-image albums.
3. Download each image to a temp file: `curl -sS -L -A "Mozilla/5.0" "https://<image-url>" -o /tmp/img.jpeg`.
4. Use the `Read` tool on the temp file to view the image.
5. Attach the original imgur URL in the issue body (don't try to re-host).

The album hash and image hash differ — guessing `i.imgur.com/<album-hash>.jpg` returns a 503-byte placeholder, not the image.

### Marker Format

```
<!-- steam-comment: <author> @ <YYYY-MM-DD HH:MM> -->
```

- `<author>`: Steam username verbatim, **without** any `[developer]` tag.
- Date in 24-hour ISO-ish form, single space between date and time.
- Build the marker from the **OP** of the thread, never from a maintainer's reply.

### gh Snippets

```shell
# Dedup search
gh search issues "steam-comment: <author> @ <date>" \
  --repo ProZeratul/CrusaderKings3UnofficialPatch --json number,title,url

# File an issue
gh issue create --repo ProZeratul/CrusaderKings3UnofficialPatch \
  --label steam --title "<title>" --body "$(cat <<'EOF'
<body>
EOF
)"
```

## Usage Examples

```bash
# Scan the 20 most recent main-page comments (default)
/unop-import-steam-comments

# Scan the 50 most recent comments on the main page
/unop-import-steam-comments 50

# Scan the suggestions thread, last 30 posts
/unop-import-steam-comments 30 suggestions

# Scan everything since a specific date on the suggestions thread
/unop-import-steam-comments --since 2026-03-01 suggestions
```
