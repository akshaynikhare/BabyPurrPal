#!/usr/bin/env bash
# Keep ACTIONPLAN_SESSION_ID stable if CLAUDE_SESSION_ID is unavailable.
set -euo pipefail
export ACTIONPLAN_SESSION_ID="${ACTIONPLAN_SESSION_ID:-${CLAUDE_SESSION_ID:-$(hostname -s)-$PPID}}"
exec node "$(dirname "${BASH_SOURCE[0]}")/workflow.cjs" lock "$@"
