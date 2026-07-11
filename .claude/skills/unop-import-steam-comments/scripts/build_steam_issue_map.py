#!/usr/bin/env python3
"""Build a map from post marker to issue number for `steam` GitHub issues.

Reads each `steam` issue's body and all its comments, extracts every
`<!-- steam-comment: <author> @ <date> -->` marker, and prints a JSON object
mapping each marker's inner text to its issue number:

    {"alice @ 2026-05-01 10:00": 500, "bob @ 2026-04-28 09:00": 494}

All open issues are included. Closed issues are added only with --since, limited
to those updated on or after it. Open issues win any key clash.

Requires the `gh` CLI, authenticated. Run from the repo root.
"""

import argparse
import json
import re
import subprocess
import sys

REPO = "ProZeratul/CrusaderKings3UnofficialPatch"
MARKER_RE = re.compile(r"<!--\s*steam-comment:\s*(.*?)\s*-->")


def gh_api_pages(path):
    """Yield items across all pages of a paginated gh REST array endpoint."""
    page = 1
    while True:
        sep = "&" if "?" in path else "?"
        url = f"{path}{sep}per_page=100&page={page}"
        out = subprocess.run(
            ["gh", "api", url],
            check=True,
            capture_output=True,
            text=True,
        ).stdout
        items = json.loads(out)
        if not items:
            return
        yield from items
        if len(items) < 100:
            return
        page += 1


def markers(text):
    return MARKER_RE.findall(text or "")


def build_map(state, since=None):
    path = f"repos/{REPO}/issues?state={state}&labels=steam"
    if since:
        path += f"&since={since}"
    mapping = {}
    for issue in gh_api_pages(path):
        # The issues endpoint also returns PRs; skip them.
        if "pull_request" in issue:
            continue
        number = issue["number"]
        for marker in markers(issue.get("body")):
            mapping[marker] = number
        # Only fetch comments when the issue actually has some.
        if issue.get("comments", 0):
            for comment in gh_api_pages(f"repos/{REPO}/issues/{number}/comments"):
                for marker in markers(comment.get("body")):
                    mapping[marker] = number
    return mapping


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--since",
        metavar="YYYY-MM-DD",
        help="include closed issues updated on or after this date",
    )
    args = parser.parse_args()

    since = args.since
    if since and len(since) == 10:
        since += "T00:00:00Z"

    # Closed first, then open, so an open issue wins any colliding marker key.
    mapping = build_map("closed", since) if since else {}
    mapping.update(build_map("open"))

    json.dump(mapping, sys.stdout, ensure_ascii=False)
    sys.stdout.write("\n")


if __name__ == "__main__":
    try:
        main()
    except subprocess.CalledProcessError as exc:
        sys.stderr.write(exc.stderr or f"gh failed: {exc}\n")
        sys.exit(1)
