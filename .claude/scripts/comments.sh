#!/usr/bin/env bash
# Print the conversation on issue/PR <N> as one JSON object per line, oldest first:
#   {"kind", "id", "author", "role", "created", "body"} (+ "path", "line" for inline review comments)
# kind: body | comment | review | review-comment. role: the author's role in .claude/trusted-authors
# (maintainer, bot), or "untrusted". The JSON keeps each body separate, so a body can't pose as
# another comment or author, as it can in the plain text of `gh ... view --comments`.
set -euo pipefail

usage="usage: comments.sh <issue-or-pr>"
N="${1:?$usage}"
REPO="ProZeratul/CrusaderKings3UnofficialPatch"
[[ "$N" =~ ^[0-9]+$ ]] || { echo "$usage" >&2; exit 2; }

# {"<login>": "<role>"} from "<role> <login>" lines
roles=$(awk '!/^[[:space:]]*(#|$)/ { print $1 " " $2 }' "$(dirname "$0")/../trusted-authors" \
  | grep -E '^(maintainer|bot) [A-Za-z0-9-]+(\[bot\])?$' \
  | jq -R 'split(" ") | {(.[1]): .[0]}' | jq -sc 'add // {}')
item() { jq -c --argjson r "$roles" --arg kind "$1" \
  '{kind: $kind, id, author: .user.login, role: ($r[.user.login] // "untrusted"),
    created: (.created_at // .submitted_at), body: (.body // "")} + (if .path then {path, line} else {} end)'; }

issue=$(gh api "repos/$REPO/issues/$N")
{
  item body <<< "$issue"
  gh api --paginate "repos/$REPO/issues/$N/comments" --jq '.[]' | item comment
  if jq -e '.pull_request' <<< "$issue" > /dev/null; then
    gh api --paginate "repos/$REPO/pulls/$N/reviews" --jq '.[] | select(.body != "")' | item review
    gh api --paginate "repos/$REPO/pulls/$N/comments" --jq '.[]' | item review-comment
  fi
} | jq -sc 'sort_by(.created) | .[]'
