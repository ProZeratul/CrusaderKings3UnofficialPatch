#!/usr/bin/env bash
# Print the id (default) or body of the first comment on issue/PR <N> that starts with <!-- <marker> -->
# and is by a trusted author (a role in .claude/trusted-authors, see comments.sh). Prints nothing if
# there is none. The marker must come first: trusted comments may quote untrusted text further down.
set -euo pipefail

usage="usage: marker-comment.sh <issue-or-pr> <marker> [id|body]"
N="${1:?$usage}"
MARKER="${2:?$usage}"
FIELD="${3:-id}"

[[ "$N" =~ ^[0-9]+$ ]] || { echo "$usage" >&2; exit 2; }
[[ "$MARKER" =~ ^[a-z0-9-]+$ ]] || { echo "invalid marker: $MARKER" >&2; exit 2; }
case "$FIELD" in id|body) ;; *) echo "$usage" >&2; exit 2 ;; esac

"$(dirname "$0")/comments.sh" "$N" | jq -rs --arg m "<!-- $MARKER -->" --arg f "$FIELD" \
  'map(select(.kind == "comment" and .role != "untrusted" and (.body | startswith($m)))) | first | .[$f] // empty'
