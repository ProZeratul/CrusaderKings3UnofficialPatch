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

root=$(git -C "$(dirname "$0")" rev-parse --show-toplevel)
cd "$root"
[ -f ~/.config/unop-app/app.env ] && [ -f ~/.config/unop-app/gitconfig ] || { echo "pipeline.sh: set up ~/.config/unop-app first" >&2; exit 1; }
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
