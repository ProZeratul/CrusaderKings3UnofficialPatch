#!/bin/bash

# Script to extract PR/Issue links from git log
# Usage: ./list-commits-links.sh [limit] [skip]

LIMIT=${1:-50}  # Default to 50 commits, override with first argument
SKIP=${2:-0}

REPO_BASE="https://github.com/ProZeratul/CrusaderKings3UnofficialPatch"

# Check if we're in a git repository
if ! git rev-parse --git-dir > /dev/null 2>&1; then
    echo "Error: Not in a git repository!"
    exit 1
fi

# Generate clean URL list for fetching (only for commits with PR/Issue references)
git log --oneline --no-merges -n "$LIMIT" --skip="$SKIP" | while read sha title; do
    subject=$(git log --format="%s" -n 1 "$sha")
    if [[ $subject =~ \(#([0-9]+)\) ]]; then
        number="${BASH_REMATCH[1]}"
        echo "${REPO_BASE}/pull/${number}"
        echo "${REPO_BASE}/issues/${number}"
    fi
done