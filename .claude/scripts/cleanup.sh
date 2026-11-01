#!/usr/bin/env bash
# Remove the agent worktrees and branches that agents left behind: worktrees with no changes
# outside .claude/ (and their fix branches if pushed), and worktree-agent-* branches no worktree uses.
# Keeps running agents' worktrees (Claude Code locks them), worktrees with other changes, and
# unpushed fix branches. Run it in the main checkout, outside pipeline sessions.
set -euo pipefail

cd "$(dirname "$0")/../.."

git worktree prune

for w in .claude/worktrees/agent-*; do
  [ -d "$w" ] || continue
  changes=$(git -C "$w" status --porcelain)
  if [ -n "$(grep -v '^.. \.claude/' <<< "$changes")" ]; then echo "kept $w: changes outside .claude/"; continue; fi
  b=$(git -C "$w" branch --show-current)
  git worktree remove --force "$w" 2>/dev/null || { echo "kept $w: locked, its agent still runs"; continue; }
  echo "removed $w"
  case "$b" in
    ''|worktree-agent-*) ;;
    *) if git merge-base --is-ancestor "$b" "origin/$b" 2>/dev/null; then git branch -D "$b"; else echo "kept branch $b: not pushed"; fi ;;
  esac
done

for b in $(git for-each-ref --format='%(refname:short)' 'refs/heads/worktree-agent-*'); do
  git branch -D "$b" 2>/dev/null || true   # refused while a worktree still uses it
done
