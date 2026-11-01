#!/usr/bin/env bash
# Upsert tmp/issue-<N>.md as the collapsed handover comment on issue <N>.
# Re-derives the comment id, so it pairs with handover-pull.sh without shared state.
set -euo pipefail

N="${1:?usage: handover-push.sh <issue-number>}"
[[ "$N" =~ ^[0-9]+$ ]] || { echo "usage: handover-push.sh <issue-number>" >&2; exit 2; }
FILE="tmp/issue-$N.md"

body=$(mktemp)
trap 'rm -f "$body"' EXIT
{
  echo '<!-- unop-handover -->'
  echo '<details><summary>🤖 handover document</summary>'
  echo
  cat "$FILE"
  echo '</details>'
} > "$body"

# edits only a handover comment by a trusted author (.claude/trusted-authors)
"$(dirname "$0")/marker-post.sh" "$N" unop-handover "$body"
