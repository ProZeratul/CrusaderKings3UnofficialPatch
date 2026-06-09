#!/usr/bin/env bash
# Pull the handover comment for issue <N> into tmp/issue-<N>.md.
# If the issue has no handover comment yet (a first analysis), does nothing.
set -euo pipefail

N="${1:?usage: handover-pull.sh <issue-number>}"
REPO="ProZeratul/CrusaderKings3UnofficialPatch"
FILE="tmp/issue-$N.md"

id=$(gh api --paginate "repos/$REPO/issues/$N/comments" \
  --jq '.[] | select(.body | contains("<!-- unop-handover -->")) | .id' | head -n1)

if [ -n "$id" ]; then
  # strip the marker line, the <details><summary> opener, and the closing </details>
  gh api "repos/$REPO/issues/comments/$id" --jq '.body' \
    | sed '1,/<\/summary>/d; /^<\/details>$/d' \
    | sed '1{/^$/d}' \
    > "$FILE"
fi
