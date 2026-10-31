#!/usr/bin/env bash
# Step 0 of every browser lane: what is actually available. Never installs anything.
set -uo pipefail
CACHE="$HOME/Library/Caches/ms-playwright"
[ -d "$HOME/.cache/ms-playwright" ] && CACHE="$HOME/.cache/ms-playwright"   # linux

chromium=$(ls -d "$CACHE"/chromium-* 2>/dev/null | tail -1)
pwver=$(npx --no-install playwright --version 2>/dev/null | awk '{print $2}')
chan="no"; [ -d "/Applications/Google Chrome.app" ] && chan="yes"
mcp="NO (.mcp.json absent)"; [ -f ".mcp.json" ] && grep -q playwright .mcp.json 2>/dev/null && mcp="YES (.mcp.json)"
mode="headed available"
if [ -n "${CI:-}" ] || [ -n "${CLAUDE_SESSION_ID:-}" ] || [ "${HEADED:-}" = "0" ]; then mode="headless forced (CI/agent session)"; fi

echo "[CHROMIUM] cached: ${chromium:-none} | playwright cli: ${pwver:-not installed} | channel:chrome $chan"
echo "[MCP]      claude-code: $mcp"
echo "[MODE]     $mode"
if [ -z "$chromium" ] && [ "$chan" = "no" ]; then
  echo "[VERDICT]  FAIL — no browser. Yours to run: cd e2e && npm i && npx playwright install chromium"
  exit 1
elif [ -z "$pwver" ]; then
  echo "[VERDICT]  PASS-WITH-NOTES — browser present, playwright cli not installed (cd e2e && npm i)"
else
  echo "[VERDICT]  PASS"
fi
