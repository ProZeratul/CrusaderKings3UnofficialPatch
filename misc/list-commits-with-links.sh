#!/bin/bash

# Script to extract commits with PR/Issue references from git log
# Usage: ./list-commits-with-links.sh [limit] [skip]

LIMIT=${1:-50}  # Default to 50 commits, override with first argument
SKIP=${2:-0}

REPO_BASE="https://github.com/ProZeratul/CrusaderKings3UnofficialPatch"

# Check if we're in a git repository
if ! git rev-parse --git-dir > /dev/null 2>&1; then
    echo "Error: Not in a git repository!"
    exit 1
fi

# Sanitize text for CSV (escape quotes, remove newlines, remove pipes)
sanitize() {
    echo "$1" | sed 's/"/\\"/g' | tr '\n' ' ' | tr '|' ';' | sed 's/  */ /g' | sed 's/^ *//;s/ *$//'
}

echo "SHA|Author|Title|Body|PR_Link|Issue_Link"

# Get all commits (both with and without PR/Issue references)
git log --oneline --no-merges -n "$LIMIT" --skip="$SKIP" | while read sha title; do
    # Get commit details
    author=$(git log --format="%an" -n 1 "$sha")
    subject=$(git log --format="%s" -n 1 "$sha")
    body=$(git log --format="%b" -n 1 "$sha")
    
    # Check if title contains PR/Issue reference (#123)
    if [[ $subject =~ \(#([0-9]+)\) ]]; then
        # Commit has PR/Issue reference
        number="${BASH_REMATCH[1]}"
        
        # Generate title and links
        clean_title=$(echo "$subject" | sed 's/ (#[0-9]\+)$//')
        pr_link="${REPO_BASE}/pull/${number}"
        issue_link="${REPO_BASE}/issues/${number}"
        
        # Output with empty body (we'll get description from PR)
        echo "$sha|$author|$(sanitize "$clean_title")||$pr_link|$issue_link"
    elif [ -n "$body" ]; then
        # Output with full body and no links
        echo "$sha|$author|$(sanitize "$subject")|$(sanitize "$body")||"
    else
        # No body either, just output the title
        echo "$sha|$author|$(sanitize "$subject")|||"
    fi
done
