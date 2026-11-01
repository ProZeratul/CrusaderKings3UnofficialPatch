#!/usr/bin/env bash
# Print the conversation on issue/PR <N> as one JSON object per line, oldest first:
#   {"kind", "id", "author", "role", "created", "body"} (+ "path", "line" for inline review comments)
# kind: body | comment | review | review-comment. role: the author's role in .claude/trusted-authors
# (maintainer, bot), or "untrusted". The JSON keeps each body separate, so a body can't pose as
# another comment or author, as it can in the plain text of `gh ... view --comments`.
# Anyone with write access can edit others' comments, so a comment last edited by someone other than
# its author gets the lower of the two roles, with "edited_by" naming the editor: e.g. a maintainer's
# comment edited by the bot, or the bot's edited by a maintainer, counts as the bot's.
# Any failed fetch fails the script, so it never prints a partial conversation.
set -euo pipefail

usage="usage: comments.sh <issue-or-pr>"
N="${1:?$usage}"
REPO="ProZeratul/CrusaderKings3UnofficialPatch"
[[ "$N" =~ ^[0-9]+$ ]] || { echo "$usage" >&2; exit 2; }

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

# {"<login>": "<role>"} from "<role> <login>" lines
roles=$(awk '!/^[[:space:]]*(#|$)/ { print $1 " " $2 }' "$(dirname "$0")/../trusted-authors" \
  | grep -E '^(maintainer|bot) [A-Za-z0-9-]+(\[bot\])?$' \
  | jq -R 'split(" ") | {(.[1]): .[0]}' | jq -sc 'add // {}')
item() { jq -c --argjson r "$roles" --arg kind "$1" \
  '{kind: $kind, id, node_id, author: .user.login, role: ($r[.user.login] // "untrusted"),
    created: (.created_at // .submitted_at), body: (.body // "")} + (if .path then {path, line} else {} end)'; }

# Fetch at the top level, not inside $(...), where bash ignores set -e.
issue=$(gh api "repos/$REPO/issues/$N")
item body <<< "$issue" > "$tmp/items"
gh api --paginate "repos/$REPO/issues/$N/comments" --jq '.[]' | item comment >> "$tmp/items"
if jq -e '.pull_request' <<< "$issue" > /dev/null; then
  gh api --paginate "repos/$REPO/pulls/$N/reviews" --jq '.[] | select(.body != "")' | item review >> "$tmp/items"
  gh api --paginate "repos/$REPO/pulls/$N/comments" --jq '.[]' | item review-comment >> "$tmp/items"
fi

# Add the last editor of each trusted item, from GraphQL (REST doesn't expose it), 100 ids per query.
query='query($ids: [ID!]!) { nodes(ids: $ids) { ... on Comment {
  id lastEditedAt author { __typename login } editor { __typename login } } } }'
jq -sc '[.[] | select(.role != "untrusted") | .node_id] as $a | range(0; $a | length; 100) | $a[.:. + 100]' \
  "$tmp/items" > "$tmp/batches"
: > "$tmp/nodes"
while read -r ids; do
  jq -n --arg q "$query" --argjson ids "$ids" '{query: $q, variables: {ids: $ids}}' \
    | gh api graphql --input - --jq '.data.nodes[]' >> "$tmp/nodes"
done < "$tmp/batches"
edits=$(jq -sc 'def name: if . == null then "unknown" elif .__typename == "Bot" then .login + "[bot]" else .login end;
                map(select(.lastEditedAt != null and (.editor | name) != (.author | name))
                    | {(.id): (.editor | name)}) | add // {}' "$tmp/nodes")

jq -sc --argjson r "$roles" --argjson e "$edits" '
  def rank: {untrusted: 0, bot: 1, maintainer: 2}[.];
  sort_by(.created)[]
  | if $e[.node_id] then .edited_by = $e[.node_id]
      | .role = ([.role, ($r[.edited_by] // "untrusted")] | min_by(rank)) else . end
  | del(.node_id)' "$tmp/items"
