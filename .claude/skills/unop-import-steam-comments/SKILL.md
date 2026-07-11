---
name: unop-import-steam-comments
description: Scan recent Steam comments for bug reports and open or update GitHub issues for them
argument-hint: "[count|--since YYYY-MM-DD] [main|suggestions] [identity]"
---

# Import Unop Steam Comments as GitHub Issues

Scan recent comments on the Unop Steam Workshop page or its "Fix suggestions" discussion, filter to bug reports, split and assemble them into threads, reconcile against existing issues, and open a GitHub issue for each new bug, or append newly-appeared follow-up posts as comments on an issue that already exists.

This skill runs **autonomously**, without asking for approval. Any human gates belong to the calling workflow, not here. It reports a summary at the end.

## Concepts

- **Steam page (main)**: <https://steamcommunity.com/sharedfiles/filedetails/?id=2871648329>, the mod's Workshop page comment stream.
- **Steam page (suggestions)**: <https://steamcommunity.com/workshop/filedetails/discussion/2871648329/4697908845434539387/>, the dedicated "Fix suggestions" discussion thread.
- **Maintainer**: Steam users `Kazarion` and `pharaox`, identify by author username. Maintainer comments are not bug reports themselves but may anchor a thread.
- **Comment**: a single Steam comment, with one author and timestamp. Unqualified, "comment" always means this; a GitHub issue comment is always qualified, as a *follow-up comment* or *issue comment*.
- **Post**: a logical part of a comment about one distinct bug. A comment contains one or more posts. Posts are the unit the rest of the workflow handles.
- **Thread**: one bug report's worth of posts. Steam shows comments flat, so a thread is inferred from chronology and content: typically a user's bug report, a maintainer reply asking for details, then the same user's clarification.
- **Marker**: A machine-greppable HTML comment placed on each filed post, of the form `<!-- steam-comment: <author> @ <YYYY-MM-DD HH:MM> -->`. The OP's marker lives in the issue body; each follow-up post's marker lives in its own issue comment. Markers are the per-post dedup key across runs. See **Marker Format**.
- **Result file**: `tmp/steam-import-<source>-<YYYY-MM-DD-HHMM>.md`, written at the end of each run. Records which issues were created and updated, the outcome of every scanned post, and the Steam acknowledgements. See **Result File**.
- **GitHub repo**: `ProZeratul/CrusaderKings3UnofficialPatch`. Use the `gh` CLI for all GitHub operations.

## Context

- Commands should be executed in the Unop repo root.
- Steam exposes two fetch surfaces, both read-only:
  - **Main page**: a JSON render endpoint returns paginated comments. See **Fetching URLs**.
  - **Suggestions thread**: a normal HTML page paginated by `?ctp=N`. See **Fetching URLs**.
- `WebFetch` summarizes by default, so prompts must explicitly demand verbatim, structured output. For the JSON endpoint, `curl` via `Bash` is more reliable.

## Arguments

All arguments are optional and order-independent.

- **Scope**, one of:
  - `<count>`: integer, scan the most recent N comments. Default `20`.
  - `--since YYYY-MM-DD`: scan comments on or after this date. Overrides `<count>`.
- **Source**, one of: `main` (default) or `suggestions`.
- **Identity**: the role this skill posts as on follow-up comments. Default `steam-importer`.

Examples: `30`, `main 30`, `suggestions`, `--since 2026-04-01 suggestions`, `50 steam-importer`.

## Guidelines

- **Read the project's `CLAUDE.md`** first.
- **Identify yourself.** Begin each follow-up comment's first line with `**<identity>:**`.
- **File every bug report, and default to filing when unsure.** Open an issue for every thread that is a bug report; if you genuinely can't tell whether a thread is one, open it anyway. Only skip threads that are confidently not bugs, or that show positive evidence of being handled already.
- **Apply only the `steam` label.** The skill is standalone: it imports and deduplicates, nothing more. Never assign any other label.
- **Add the post marker** to every issue and follow-up comment. The marker is what prevents duplicates on the next run.
- **Don't close existing issues, change their labels, or edit their bodies.** You may only create new issues and append follow-up comments to issues that already carry a matching marker.
- **Don't modify the Steam page.** Steam is read-only here.
- **Quote the Steam text verbatim.** Do not paraphrase, translate, or "fix" the user's wording.
- If a single comment reports multiple distinct bugs, **file one issue per bug**, don't bundle them.
  - Title and quote each issue to its single bug; don't repeat the full comment.
  - Give each split its own marker, suffixed ` #<n>` numbered `1`, `2`, `3` in the order the bugs appear in the comment, so every split is uniquely keyed. See **Marker Format**.
- If a comment links to an image, fetch it, confirm relevance, and attach it to the issue. See **Fetching Images**. If an image-only follow-up can't be fetched or isn't relevant, don't file an issue.
- **Skip on positive evidence it's handled:** a maintainer reply links to a GitHub issue, or attributes the report to a stale mod version that has since shipped.
- **Take the fetch result at face value.** Trust what the fetch returns, including an empty result; don't widen the scope to second-guess it.
- **Give up on rate limits.** If a Steam or GitHub call hits a rate limit, stop and report it; don't retry or work around it.

## Workflow

### 1. Parse Arguments

Resolve scope, source, and identity per the **Arguments** section.

### 2. Fetch Comments

Run the bundled fetch script. It handles both sources, pagination, the 10-page cap, the suggestions newest-on-last-page walk, and emits structured JSON. Prefer it over inline parsing.

```shell
.claude/skills/unop-import-steam-comments/scripts/fetch_steam_comments.py \
  --source <main|suggestions> [--count N | --since YYYY-MM-DD]
```

Output is a JSON array on stdout, newest-first; each item has `id`, `ts`, `date_utc` (`YYYY-MM-DD HH:MM`, UTC), `author`, `text`, `page`. A page-cap warning is printed to stderr if the cap is hit.

**Fallback**: if the script fails or its output looks structurally wrong, `curl` the endpoints in **Fetching URLs** and parse the `commentthread_comment` blocks with a small `python3` heredoc using the per-comment fields documented there. Note the failure in the final report so the script can be fixed afterwards.

### 3. Split Comments into Posts

A single comment may cover more than one distinct bug: it may report several new bugs, or contain follow-ups to several existing issues, often citing each as `#N`. Split each comment into one post per distinct bug. Every post inherits the comment's author and timestamp; when a comment yields more than one post they share one `<author> @ <date>` and stay unique through the ` #<n>` marker suffix; see **Marker Format**.

### 4. Group into Threads

Steam comments are flat. Reconstruct threads by walking the posts in chronological order:

1. A non-maintainer post starts a new candidate thread.
2. A maintainer post attaches to the most recent candidate thread only if it plausibly replies to it.
3. A later post by the same non-maintainer user attaches to their most recent thread if its content continues the same topic.

The thread's OP is the first non-maintainer post. Each post carries its own marker built from its comment's author and date.

If a maintainer post stands alone with no preceding user post in scope, drop it; it's a release note or unrelated reply.

### 5. Classify Each Thread

Decide one of two outcomes per thread:

- **Bug**: file it, or append follow-ups. Default here when in doubt.
- **Not a bug**: skip.

**Bug** indicators: error log excerpts, "broken", "doesn't work", "wrong tooltip", "missing localization", specific object IDs paired with a complaint, "stuck on", "CTD/crash", reports of unintended behavior tied to a specific mechanic.

**Not a bug** indicators:

- `feature`: "could you add", "please make", "I wish", balance tuning requests.
- `thanks`: "thanks", "great mod", "love it" with no bug content.
- `question`: "is this compatible with", "how do I", "does this work with X mod".
- `help`: install issues, load order issues, launcher problems.
- `other`: off-topic, spam, untranslatable.

Anything that could be a bug but you can't confirm counts as **Bug**; file it, don't drop it. Only the edge cases mentioned in **Guidelines** should be skipped despite looking like bugs.

### 6. Reconcile Against GitHub

Build the marker map once per run, passing the oldest comment date in scope:

```shell
.claude/skills/unop-import-steam-comments/scripts/build_steam_issue_map.py --since <oldest comment date>
```

It maps each marker's inner text, `<author> @ <date>`, to its issue number. See **Building the Issue Map**.

Find each bug thread's issue:

- A post that cites an existing issue `#N` belongs to that issue.
- Otherwise match by the map: a post is already filed when a key starts with its `<author> @ <date>`; comments in the same minute and multi-bug splits add a ` #<n>` suffix. Match a thread by **any** of its posts, not only the OP, since the OP is often older than the scan window while a later filed post still falls inside it.

Then:

- **No issue found**: the thread is new. Create an issue, step 7a.
- **Issue N found**: append every post not yet on it as a follow-up comment, step 7b. Don't reopen a closed issue. If all its posts are already there, do nothing.

### 7. File Issues and Post Follow-up Comments

#### 7a. Create a new issue

Create the issue with the **Issue Template**. Its title is a short imperative summary of the bug. Apply the `steam` label.

```shell
gh issue create --repo ProZeratul/CrusaderKings3UnofficialPatch \
  --label steam \
  --title "<title>" --body "$(cat <<'EOF'
<body per Issue Template>
EOF
)"
```

Then post each follow-up post in the thread as its own follow-up comment, step 7b.

#### 7b. Append follow-up comments

For each follow-up post, in chronological order, post one follow-up comment with the **Follow-up Comment Template**: verbatim text, the author/date header, and the post's own marker.

```shell
gh issue comment <N> --repo ProZeratul/CrusaderKings3UnofficialPatch --body "$(cat <<'EOF'
**<identity>:** Follow-up by `<author>` on `<date>`:

> <verbatim follow-up text>

<!-- steam-comment: <author> @ <date> -->
EOF
)"
```

Leave the issue's labels unchanged.

### 8. Write the Result File and Report

Write `tmp/steam-import-<source>-<YYYY-MM-DD-HHMM>.md`, creating `tmp/` if needed. Format in **Result File**.

Then report to the user:

- Source, scope, and identity.
- Counts: threads found, issues created, issues updated with follow-ups, threads skipped.
- The created issues with numbers and URLs, and the issues that received follow-up comments.
- The result file path, and the acknowledgement BBCode inline.
- If the fetch script needed the manual-parsing fallback, say so; it likely needs an update.

## Reference

### Issue Template

The issue body holds only the OP post and the OP marker. Follow-up posts go in separate comments.

```markdown
**Reported on Steam by `<OP author>` on `<OP date>`** (<link>).

> <verbatim OP post text, blockquoted; preserve line breaks>

<!-- steam-comment: <OP author> @ <OP date> -->
```

The marker must be the last line of the body and must match the format exactly.

### Follow-up Comment Template

One comment per follow-up post, each carrying its own marker:

```markdown
**<identity>:** Follow-up by `<author>` on `<date>`:

> <verbatim follow-up text>

<!-- steam-comment: <author> @ <date> -->
```

### Result File

A markdown file, `tmp/steam-import-<source>-<YYYY-MM-DD-HHMM>.md`. The frontmatter records the run and the issue numbers created and updated. The body maps every scanned post to its outcome. A final section holds the Steam acknowledgements as `bbcode` blocks for a human to post.

````markdown
---
source: main
scope: "--since 2026-05-25"
created: [531, 532]
updated: [512]
---

## Posts

- `alice @ 2026-05-01 10:00` - created 531
- `dave @ 2026-05-09 08:00` - created 532
- `bob @ 2026-05-10 09:00` - updated 512
- `carol @ 2026-05-11 12:00` - skipped, thanks

## Acknowledgements

```bbcode
@alice, @dave Thanks for the reports! We've opened the following GitHub issues to track them:
- [url=<url>]#531 <title>[/url]
- [url=<url>]#532 <title>[/url]
```
````

One bullet per scanned post, marker first, then `created N`, `updated N`, or `skipped, <reason>`. One `bbcode` block per Steam acknowledgement comment: only created issues are acknowledged, at most 4 issues per block to stay under Steam's 1000-character cap, each block headed with only that block's reporters.

### Fetching URLs

**Main**, JSON, paginated by offset:

```
GET https://steamcommunity.com/comment/PublishedFile_Public/render/76561198047801064/2871648329/?start=<offset>&count=<n>
```

Newest-first. Response JSON has `total_count` and `comments_html`, an HTML fragment of `<div class="commentthread_comment ...">` blocks. `76561198047801064` is the mod owner's SteamID64; `2871648329` is the Workshop ID.

**Suggestions**, HTML, paginated by `?ctp=N`, 1-based:

```
GET https://steamcommunity.com/workshop/filedetails/discussion/2871648329/4697908845434539387/?ctp=<page>
```

Same `commentthread_comment` block structure as the main page.

**Per-comment fields** in each block:

- Author: text inside `<bdi>` under `class="commentthread_author_link"`.
- Timestamp: `data-timestamp="<unix-seconds>"` on `<span class="commentthread_comment_timestamp">`, authoritative; the visible date string is locale-formatted.
- Text: inside `<div class="commentthread_comment_text">`; preserve `<br>` as newlines and unescape HTML entities.

### Fetching Images

`WebFetch` cannot reach `imgur.com`. Use `curl` instead:

1. Fetch the album/post page: `curl -sS -L -A "Mozilla/5.0" "<imgur-url>" -o /tmp/album.html`.
2. Extract image URLs: `grep -oE 'i\.imgur\.com/[A-Za-z0-9]+\.(jpg|jpeg|png|gif)' /tmp/album.html | sort -u`. The `og:image` meta tag is also reliable for single-image albums.
3. Download each image: `curl -sS -L -A "Mozilla/5.0" "https://<image-url>" -o /tmp/img.jpeg`.
4. Use the `Read` tool on the temp file to view the image.
5. Attach the original imgur URL in the issue body; don't try to re-host.

The album hash and image hash differ. Guessing `i.imgur.com/<album-hash>.jpg` returns a 503-byte placeholder, not the image.

### Marker Format

```
<!-- steam-comment: <author> @ <YYYY-MM-DD HH:MM> -->
```

- `<author>`: Steam username verbatim, without any `[developer]` tag.
- Date in 24-hour ISO-ish form, single space between date and time.
- One marker per post: the OP's marker in the issue body, each follow-up's marker in its own comment.
- When one `<author> @ <date>` would otherwise map to more than one issue, append ` #<n>` to each marker to keep them unique, numbered `1`, `2`, `3`: in chronological order for multiple comments in the same minute, or in order of appearance for multiple posts split from a single comment. When looking a post up in the issue map, treat a key that starts with `<author> @ <date>` as a match.

### Building the Issue Map

`scripts/build_steam_issue_map.py [--since YYYY-MM-DD]` reads each `steam` issue's body and all its comments, extracts every `<!-- steam-comment: ... -->` marker, and prints a JSON object mapping each marker's inner text to the issue number:

```shell
.claude/skills/unop-import-steam-comments/scripts/build_steam_issue_map.py --since 2026-05-25
```

```json
{ "alice @ 2026-05-01 10:00": 500, "alice @ 2026-05-03 14:00": 500, "bob @ 2026-05-10 09:00": 512 }
```

All open `steam` issues are included, plus closed ones updated on or after `--since`. Compose a post's key as `<author> @ <date>`; a key starting with it means that post is already filed in the mapped issue. The script targets `ProZeratul/CrusaderKings3UnofficialPatch` and uses `gh`; run it from the repo root.

### gh Snippets

```shell
# Create an issue
gh issue create --repo ProZeratul/CrusaderKings3UnofficialPatch \
  --label steam --title "<title>" --body "$(cat <<'EOF'
<body>
EOF
)"

# Append a follow-up comment
gh issue comment <N> --repo ProZeratul/CrusaderKings3UnofficialPatch --body "$(cat <<'EOF'
<comment>
EOF
)"
```

## Usage Examples

```bash
# Scan the 20 most recent main-page comments (default)
/unop-import-steam-comments

# Scan the 50 most recent comments on the main page
/unop-import-steam-comments 50

# Scan the suggestions thread, last 30 comments
/unop-import-steam-comments 30 suggestions

# Scan everything since a specific date on the suggestions thread
/unop-import-steam-comments --since 2026-03-01 suggestions
```
