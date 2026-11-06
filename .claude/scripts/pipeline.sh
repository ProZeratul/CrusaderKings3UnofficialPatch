#!/usr/bin/env bash
# Launch Unop pipeline sessions with .claude/pipeline-settings.json (auto mode, strict sandbox),
# acting on GitHub as the GitHub App configured in ~/.config/unop-app (see .claude/agents/README.md).
#
#   pipeline.sh dispatch              run the dispatcher here; then type: /loop 20m dispatch
#   pipeline.sh run <agent> <prompt>  start one agent in the background,
#                                     e.g. pipeline.sh run unop-analyzer "Process issue 712"
#   pipeline.sh view                  open an agent view; sessions dispatched from it use the pipeline settings
set -euo pipefail

usage() { sed -n '2,8s/^# \{0,1\}//p' "$0" >&2; exit 2; }

die() { echo "pipeline.sh: $*" >&2; exit 1; }

root=$(cd "$(dirname "$0")/../.." && pwd -P)
cd "$root"

[ -f ~/.config/unop-app/app.env ] && [ -f ~/.config/unop-app/gitconfig ] || die "set up ~/.config/unop-app first"

# The hooks run the token script from this fixed path, outside the sandbox.
[ "$(readlink -f ~/.config/unop-app/app-token.py)" = "$root/.claude/scripts/app-token.py" ] \
  || die "link ~/.config/unop-app/app-token.py to $root/.claude/scripts/app-token.py first"

# A main checkout has no .git/commondir; one would redirect git to another repo and its config.
[ -d .git ] && [ ! -e .git/commondir ] \
  || die "$root/.git is not a plain git directory or has a commondir file"

git worktree prune

git fetch -q origin main || echo "pipeline.sh: warning: can't fetch origin/main" >&2
git diff --quiet HEAD origin/main -- .claude \
  || echo "pipeline.sh: warning: .claude/ differs from origin/main; agents may leave their worktrees behind" >&2

opts=(--permission-mode auto --settings "$root/.claude/pipeline-settings.json")

case "${1:-}" in
  dispatch)
    exec claude --agent unop-dispatcher "${opts[@]}"
    ;;
  run)
    agent=${2:-}; prompt=${3:-}
    [[ "$agent" == unop-* && -f ".claude/agents/$agent.md" && -n "$prompt" ]] || usage
    exec claude --bg --agent "$agent" "${opts[@]}" "$prompt"
    ;;
  view)
    exec claude agents "${opts[@]}"
    ;;
  *)
    usage
    ;;
esac
