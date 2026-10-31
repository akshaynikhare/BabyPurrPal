#!/usr/bin/env bash
# The one interruption at sprint end: macOS banner + full summary on stdout.
# Usage: poke.sh "<title>" "<summary line>" [more lines...]
set -euo pipefail
title="${1:?title}"; shift || true
if command -v osascript >/dev/null 2>&1; then
  osascript -e "display notification \"${1:-done}\" with title \"$title\"" >/dev/null 2>&1 || true
fi
echo "🔔 $title"
for line in "$@"; do echo "   $line"; done
