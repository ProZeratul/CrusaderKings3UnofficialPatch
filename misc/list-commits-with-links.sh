#!/bin/bash

# List commits with PR references from git log
# Usage: ./list-commits-with-links.sh [limit] [skip]

LIMIT=${1:-50} # Default to 50 commits, override with first argument
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

echo "SHA|Author|Subject|Body|PR Link"

# Process all commits
git log --oneline --no-merges -n "$LIMIT" --skip="$SKIP" | while read sha subject; do
    # Get commit details
    author=$(git log --format="%an" -n 1 "$sha")
    body=$(git log --format="%b" -n 1 "$sha")
    
    # Check if subject contains PR reference (#123)
    if [[ $subject =~ \(#([0-9]+)\) ]]; then
        # Extract PR number
        number="${BASH_REMATCH[1]}"
        
        # Generate clean subject and PR link
        clean_subject=$(echo "$subject" | sed 's/ (#[0-9]\+)$//')
        pr_link="${REPO_BASE}/pull/${number}"
        
        # Output with empty body, the PR description will be used
        echo "$sha|$author|$(sanitize "$clean_subject")|$(sanitize "$body")|$pr_link"
    elif [ -n "$body" ]; then
        # Output with full body and no links
        echo "$sha|$author|$(sanitize "$subject")|$(sanitize "$body")|"
    else
        # No body either, just output the subject
        echo "$sha|$author|$(sanitize "$subject")||"
    fi
done
