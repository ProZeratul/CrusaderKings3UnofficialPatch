#!/usr/bin/env bash
# Print the id (default) or body of the first comment on issue/PR <N> that contains <!-- <marker> -->
# and is authored by a login in .claude/trusted-authors. Prints nothing if there is none.
set -euo pipefail

usage="usage: marker-comment.sh <issue-or-pr> <marker> [id|body]"
N="${1:?$usage}"
MARKER="${2:?$usage}"
FIELD="${3:-id}"
REPO="ProZeratul/CrusaderKings3UnofficialPatch"

[[ "$N" =~ ^[0-9]+$ ]] || { echo "$usage" >&2; exit 2; }
[[ "$MARKER" =~ ^[a-z0-9-]+$ ]] || { echo "invalid marker: $MARKER" >&2; exit 2; }
case "$FIELD" in id|body) ;; *) echo "$usage" >&2; exit 2 ;; esac

# logins from "<role> <login>" lines, as a JSON array for the jq filter
logins=$(awk '!/^[[:space:]]*(#|$)/ { print $2 }' "$(dirname "$0")/../trusted-authors" \
  | grep -E '^[A-Za-z0-9-]+(\[bot\])?$' | jq -R . | jq -sc .)

id=$(gh api --paginate "repos/$REPO/issues/$N/comments" \
  --jq ".[] | select((.user.login as \$l | $logins | index(\$l)) and (.body | contains(\"<!-- $MARKER -->\"))) | .id" \
  | head -n1)

if [ -n "$id" ]; then
  if [ "$FIELD" = id ]; then
    echo "$id"
  else
    gh api "repos/$REPO/issues/comments/$id" --jq '.body'
  fi
fi
