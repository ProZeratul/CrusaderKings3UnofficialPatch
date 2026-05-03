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


def http_get(url: str) -> str:
    req = urllib.request.Request(url, headers={"User-Agent": UA})
    with urllib.request.urlopen(req, timeout=30) as resp:
        return resp.read().decode("utf-8", errors="replace")


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

        txt_m = re.search(
            r'<div class="commentthread_comment_text"[^>]*>(.*?)</div>',
            block, re.DOTALL,
        )
        raw = txt_m.group(1) if txt_m else ""
        raw = re.sub(r"<br\s*/?>", "\n", raw)
        raw = re.sub(r"<[^>]+>", "", raw)
        text = html.unescape(raw).strip()

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


def probe_suggestions_last_page() -> int:
    """Find the last page of the suggestions thread.

    Walks pages forward until one returns only the OP (length below threshold
    or only 1 timestamp). Returns the last non-empty page number.
    """
    last_full = 1
    for page in range(1, PAGE_CAP + 1):
        body = http_get(SUGGESTIONS_URL.format(page=page))
        ts_count = len(re.findall(r'data-timestamp="\d+"', body))
        if ts_count <= 1 and page > 1:
            return page - 1
        last_full = page
    return last_full


def fetch_suggestions(count_target: int, since_ts: int | None) -> tuple[list[dict], bool]:
    last_page = probe_suggestions_last_page()
    collected: list[dict] = []
    seen_ids: set[str] = set()
    pages_used = 0
    page = last_page
    while page >= 1 and pages_used < PAGE_CAP:
        pages_used += 1
        body = http_get(SUGGESTIONS_URL.format(page=page))
        items = parse_comment_blocks(body, page)
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
        page -= 1

    collected.sort(key=lambda x: x["ts"], reverse=True)
    cap_hit = pages_used >= PAGE_CAP and (
        (since_ts is not None and page >= 1) or
        (since_ts is None and len(collected) < count_target)
    )
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
