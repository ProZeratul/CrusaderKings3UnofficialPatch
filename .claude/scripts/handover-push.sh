#!/usr/bin/env bash
# Upsert tmp/issue-<N>.md as the collapsed handover comment on issue <N>.
# Re-derives the comment id, so it pairs with handover-pull.sh without shared state.
set -euo pipefail

N="${1:?usage: handover-push.sh <issue-number>}"
REPO="ProZeratul/CrusaderKings3UnofficialPatch"
FILE="tmp/issue-$N.md"

id=$(gh api --paginate "repos/$REPO/issues/$N/comments" \
  --jq '.[] | select(.body | contains("<!-- unop-handover -->")) | .id' | head -n1)

body=$(mktemp)
trap 'rm -f "$body"' EXIT
{
  echo '<!-- unop-handover -->'
  echo '<details><summary>🤖 handover document</summary>'
  echo
  cat "$FILE"
  echo '</details>'
} > "$body"

if [ -n "$id" ]; then
  gh api -X PATCH "repos/$REPO/issues/comments/$id" -F body=@"$body"
else
  gh issue comment "$N" --repo "$REPO" --body-file "$body"
fi
