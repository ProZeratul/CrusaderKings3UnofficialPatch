#!/bin/bash

# Generate all potential PR links for a repository
# Usage: ./list-pr-links.sh [first] [last]

FIRST=${1:-1}
LAST=${2:-10}

REPO_BASE="https://github.com/ProZeratul/CrusaderKings3UnofficialPatch"

for ((i=$FIRST; i<=$LAST; i++)); do
    echo "$REPO_BASE/pull/$i"
    echo "$REPO_BASE/issues/$i"
done