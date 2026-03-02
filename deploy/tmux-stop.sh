#!/usr/bin/env bash
# =============================================================================
# Zeta Voice — tmux Session Stop Script
# Usage: bash deploy/tmux-stop.sh
# =============================================================================

set -euo pipefail

SESSION="zeta-voice"

if tmux has-session -t "$SESSION" 2>/dev/null; then
    tmux kill-session -t "$SESSION"
    echo "✅  tmux session '$SESSION' stopped."
else
    echo "ℹ️  No tmux session '$SESSION' found — nothing to stop."
fi
