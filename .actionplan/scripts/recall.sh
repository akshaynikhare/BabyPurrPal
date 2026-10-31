#!/usr/bin/env bash
# The ONLY sanctioned read path into DECISIONS/PATTERNS/FROZEN. Slices matching '## ' blocks.
# Usage: recall.sh <query>              literal substring search across all three registers
#        recall.sh --titles [--file F]  headings only (cheapest overview)
set -euo pipefail
AP="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
FILES=("$AP/DECISIONS.md" "$AP/PATTERNS.md" "$AP/FROZEN.md")

if [ "${1:-}" = "--titles" ]; then
  for f in "${FILES[@]}"; do
    [ -f "$f" ] && { echo "── $(basename "$f")"; grep '^## ' "$f" || true; }
  done
  exit 0
fi

[ $# -ge 1 ] || { echo "usage: recall.sh <query> | --titles" >&2; exit 2; }
q="$1"; hits=0
for f in "${FILES[@]}"; do
  [ -f "$f" ] || continue
  # Print each '## ' block whose heading or body contains the query (case-insensitive substring).
  out=$(awk -v q="$q" '
    /^## / { if (blk != "" && index(tolower(blk), tolower(q)) > 0) print blk "---"; blk = "" }
    { blk = blk $0 "\n" }
    END { if (blk != "" && index(tolower(blk), tolower(q)) > 0) print blk }
  ' "$f")
  if [ -n "$out" ]; then echo "── $(basename "$f")"; echo "$out"; hits=1; fi
done
[ "$hits" -eq 1 ] || echo "none"
