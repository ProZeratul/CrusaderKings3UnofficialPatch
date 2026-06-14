#!/usr/bin/env python3
"""Fetch and parse Steam Workshop comments for the Unop mod.

Sources:
  main         JSON render endpoint, paginated by start/count, newest-first.
  suggestions  Discussion thread, paginated by ?ctp=N, oldest-first.

Output: JSON array on stdout, newest-first, each item:
  {"id": str, "ts": int, "date_utc": "YYYY-MM-DD HH:MM",
   "author": str, "text": str, "page": int}

Stop conditions:
  --count N        collect at least N posts (default 20)
  --since DATE     stop once a post older than DATE (YYYY-MM-DD UTC) is seen

Pagination is capped at 10 pages; a warning is printed to stderr if the cap
is hit before the scope is satisfied.
"""

from __future__ import annotations

import argparse
import datetime as dt
import html
import json
import re
import sys
import time
import urllib.request
import urllib.error

WORKSHOP_ID = "2871648329"
OWNER_STEAMID64 = "76561198047801064"
SUGGESTIONS_TOPIC_ID = "4697908845434539387"

MAIN_URL = (
    "https://steamcommunity.com/comment/PublishedFile_Public/render/"
    f"{OWNER_STEAMID64}/{WORKSHOP_ID}/?start={{start}}&count={{count}}"
)
SUGGESTIONS_URL = (
    "https://steamcommunity.com/workshop/filedetails/discussion/"
    f"{WORKSHOP_ID}/{SUGGESTIONS_TOPIC_ID}/?ctp={{page}}"
)

UA = "Mozilla/5.0 (compatible; unop-import-steam-comments/1.0)"
PAGE_CAP = 10
MAIN_PAGE_SIZE = 50
REQUEST_DELAY = 1.0  # seconds between requests, to stay under Steam's rate limit

_last_request = 0.0


def http_get(url: str) -> str:
    global _last_request
    wait = REQUEST_DELAY - (time.monotonic() - _last_request)
    if wait > 0:
        time.sleep(wait)
    req = urllib.request.Request(url, headers={"User-Agent": UA})
    try:
        with urllib.request.urlopen(req, timeout=30) as resp:
            return resp.read().decode("utf-8", errors="replace")
    finally:
        _last_request = time.monotonic()


def extract_comment_text(block: str) -> str:
    """Return a comment's plain text, preserving quoted replies.

    The comment_text div contains nested <div> blocks: Steam renders a quote as
    a <blockquote> wrapping a <div class="bb_quoteauthor">. A non-greedy match to
    the first </div> would stop inside that quote and drop the reply body after
    it, so find the matching close by counting <div> depth. Quotes are rendered
    as markdown blockquotes to keep them distinct from the reply.
    """
    m = re.search(r'<div class="commentthread_comment_text"[^>]*>', block)
    if not m:
        return ""
    inner = block[m.end():]
    depth = 1
    for tm in re.finditer(r"<(/?)div\b[^>]*>", inner):
        depth += -1 if tm.group(1) else 1
        if depth == 0:
            inner = inner[: tm.start()]
            break
    inner = re.sub(r"<blockquote[^>]*>", "\n> ", inner, flags=re.IGNORECASE)
    inner = re.sub(r"</blockquote>", "\n", inner, flags=re.IGNORECASE)
    inner = re.sub(r"<br\s*/?>", "\n", inner, flags=re.IGNORECASE)
    inner = re.sub(r"<[^>]+>", "", inner)
    text = html.unescape(inner)
    text = re.sub(r"[ \t]+\n", "\n", text)
    text = re.sub(r"\n{3,}", "\n\n", text)
    return text.strip()


def parse_comment_blocks(fragment: str, page: int) -> list[dict]:
    """Parse <div class="commentthread_comment ..." id="comment_NNN"> blocks."""
    starts = [
        m.start()
        for m in re.finditer(
            r'<div[^>]*class="commentthread_comment[^"]*"[^>]*id="comment_\d+"',
            fragment,
        )
    ]
    starts.append(len(fragment))
    out = []
    for i in range(len(starts) - 1):
        block = fragment[starts[i] : starts[i + 1]]

        idm = re.search(r'id="comment_(\d+)"', block)
        if not idm:
            continue
        cid = idm.group(1)

        am = re.search(
            r'commentthread_author_link[^>]*>\s*<bdi>(.*?)</bdi>',
            block, re.DOTALL,
        )
        author_raw = am.group(1) if am else ""
        author = html.unescape(re.sub(r"<[^>]+>.*$", "", author_raw, flags=re.DOTALL).strip()) or "?"

        tm = re.search(r'data-timestamp="(\d+)"', block)
        ts = int(tm.group(1)) if tm else 0
        date_utc = (
            dt.datetime.utcfromtimestamp(ts).strftime("%Y-%m-%d %H:%M")
            if ts else "?"
        )

        text = extract_comment_text(block)

        out.append({
            "id": cid, "ts": ts, "date_utc": date_utc,
            "author": author, "text": text, "page": page,
        })
    return out


def fetch_main(count_target: int, since_ts: int | None) -> tuple[list[dict], bool]:
    collected: list[dict] = []
    pages_used = 0
    for page in range(PAGE_CAP):
        pages_used += 1
        url = MAIN_URL.format(start=page * MAIN_PAGE_SIZE, count=MAIN_PAGE_SIZE)
        body = http_get(url)
        try:
            data = json.loads(body)
        except json.JSONDecodeError as e:
            raise RuntimeError(f"main: JSON decode failed on page {page}: {e}")
        frag = data.get("comments_html", "") or ""
        items = parse_comment_blocks(frag, page + 1)
        if not items:
            break
        collected.extend(items)

        oldest_on_page = min((it["ts"] for it in items), default=0)
        if since_ts is not None and oldest_on_page and oldest_on_page < since_ts:
            break
        if since_ts is None and len(collected) >= count_target:
            break

        total = data.get("total_count")
        if total and (page + 1) * MAIN_PAGE_SIZE >= total:
            break

    cap_hit = pages_used >= PAGE_CAP and (
        (since_ts is not None) or (len(collected) < count_target)
    )
    return collected, cap_hit


def suggestions_last_page(body: str) -> int | None:
    """Last page number, read from any page's "Showing A-B of N comments" summary.

    Avoids walking the thread forward to locate the end. Returns None if the
    summary can't be parsed.
    """
    m = re.search(r'forum_paging_summary.*?</div>', body, re.DOTALL)
    if not m:
        return None
    summary = re.sub(r"<[^>]+>", " ", m.group(0))
    mm = re.search(r"Showing\s+(\d+)\s*-\s*(\d+)\s+of\s+(\d+)", summary)
    if not mm:
        return None
    first, last, total = (int(g) for g in mm.groups())
    per_page = max(last - first + 1, 1)
    return -(-total // per_page)  # ceil


def fetch_suggestions(count_target: int, since_ts: int | None) -> tuple[list[dict], bool]:
    # Page 1 (oldest) tells us the page count and is reused if we walk that far back.
    bodies = {1: http_get(SUGGESTIONS_URL.format(page=1))}
    last_page = suggestions_last_page(bodies[1])
    if last_page is None:
        raise RuntimeError("suggestions: could not read comment count from paging summary")

    collected: list[dict] = []
    seen_ids: set[str] = set()
    cap_hit = False
    for page in range(last_page, 0, -1):
        if page not in bodies:
            if len(bodies) >= PAGE_CAP:
                cap_hit = True
                break
            bodies[page] = http_get(SUGGESTIONS_URL.format(page=page))
        items = parse_comment_blocks(bodies[page], page)
        items.sort(key=lambda x: x["ts"], reverse=True)

        new_items = [it for it in items if it["id"] not in seen_ids]
        for it in new_items:
            seen_ids.add(it["id"])
        collected.extend(new_items)

        oldest_seen = min((it["ts"] for it in new_items), default=0)
        if since_ts is not None and oldest_seen and oldest_seen < since_ts:
            break
        if since_ts is None and len(collected) >= count_target:
            break

    collected.sort(key=lambda x: x["ts"], reverse=True)
    return collected, cap_hit


def main() -> int:
    p = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    p.add_argument("--source", choices=("main", "suggestions"), default="main")
    p.add_argument("--count", type=int, default=20)
    p.add_argument("--since", help="YYYY-MM-DD (UTC); overrides --count")
    args = p.parse_args()

    since_ts: int | None = None
    if args.since:
        try:
            since_ts = int(
                dt.datetime.strptime(args.since, "%Y-%m-%d")
                .replace(tzinfo=dt.timezone.utc).timestamp()
            )
        except ValueError as e:
            print(f"error: bad --since: {e}", file=sys.stderr)
            return 2

    try:
        if args.source == "main":
            items, cap_hit = fetch_main(args.count, since_ts)
        else:
            items, cap_hit = fetch_suggestions(args.count, since_ts)
    except (urllib.error.URLError, urllib.error.HTTPError, RuntimeError) as e:
        print(f"error: fetch failed: {e}", file=sys.stderr)
        return 1

    if since_ts is not None:
        items = [it for it in items if it["ts"] >= since_ts]
    else:
        items = items[: args.count]

    if cap_hit:
        print(
            f"warning: page cap ({PAGE_CAP}) hit before scope was satisfied",
            file=sys.stderr,
        )

    json.dump(items, sys.stdout, ensure_ascii=False, indent=2)
    sys.stdout.write("\n")
    return 0


if __name__ == "__main__":
    sys.exit(main())
