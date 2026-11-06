#!/usr/bin/env bash
# Keep one current <marker> comment on issue/PR <N>: edit the trusted one if there is one
# (see marker-get.sh), post a new one otherwise. <file> holds the comment and must start
# with the line <!-- <marker> -->.
set -euo pipefail

usage="usage: marker-post.sh <issue-or-pr> <marker> <file>"
N="${1:?$usage}"
MARKER="${2:?$usage}"
FILE="${3:?$usage}"
REPO="ProZeratul/CrusaderKings3UnofficialPatch"

[[ "$N" =~ ^[0-9]+$ ]] || { echo "$usage" >&2; exit 2; }
[[ "$MARKER" =~ ^[a-z0-9-]+$ ]] || { echo "invalid marker: $MARKER" >&2; exit 2; }
[ -f "$FILE" ] || { echo "no such file: $FILE" >&2; exit 2; }
[ "$(head -n 1 "$FILE")" = "<!-- $MARKER -->" ] || { echo "$FILE must start with <!-- $MARKER -->" >&2; exit 2; }

id=$("$(dirname "$0")/marker-get.sh" "$N" "$MARKER")
if [ -n "$id" ]; then
  gh api --silent -X PATCH "repos/$REPO/issues/comments/$id" -F body=@"$FILE"
else
  gh api --silent -X POST "repos/$REPO/issues/$N/comments" -F body=@"$FILE"
fi
