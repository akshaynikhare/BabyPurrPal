#!/usr/bin/env bash
# Next free plan id: <CODE>-NNNN. Scans all stage folders; highest + 1. No counter file to corrupt.
set -euo pipefail
AP="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CODE=$(node -e 'console.log(require(process.argv[1]).code)' "$AP/config.json" 2>/dev/null || echo "AP")
max=0
for f in "$AP"/planned/*.md "$AP"/in-progress/*.md "$AP"/archived/*.md "$AP"/audit/*.md; do
  [ -e "$f" ] || continue
  n=$(basename "$f" | sed -nE "s/^${CODE}-([0-9]{4})-.*/\1/p")
  [ -n "$n" ] && [ "$((10#$n))" -gt "$max" ] && max=$((10#$n))
done
printf '%s-%04d\n' "$CODE" $((max + 1))
