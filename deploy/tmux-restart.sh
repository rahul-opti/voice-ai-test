#!/usr/bin/env bash
# =============================================================================
# Zeta Voice — tmux Session Restart Script
# Usage: bash deploy/tmux-restart.sh
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "🔄  Restarting Zeta Voice tmux session..."
bash "$SCRIPT_DIR/tmux-stop.sh"
sleep 1
bash "$SCRIPT_DIR/tmux-start.sh"
