#!/usr/bin/env bash
# =============================================================================
# Zeta Voice — tmux Session Start Script
# Usage: bash deploy/tmux-start.sh
#
# Creates a tmux session named "zeta-voice" with 3 windows:
#   0: zeta-app   → Main voice AI app  (port 8000)
#   1: zeta-admin → Admin app          (port 8001)
#   2: logs       → Live log tail
# =============================================================================

set -euo pipefail

APP_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SESSION="zeta-voice"
VENV="$APP_DIR/.venv/bin"
ENV_FILE="$APP_DIR/.env"

# ── Guard: don't start if already running ────────────────────────────────────
if tmux has-session -t "$SESSION" 2>/dev/null; then
    echo "⚠️  tmux session '$SESSION' is already running."
    echo "   Attach with:  tmux attach -t $SESSION"
    echo "   To restart:   bash deploy/tmux-stop.sh && bash deploy/tmux-start.sh"
    exit 0
fi

# ── Source .env so subprocesses inherit the variables ────────────────────────
set -a; source "$ENV_FILE"; set +a

echo "🚀  Starting Zeta Voice services in tmux session: $SESSION"

# ── Window 0: Main app ───────────────────────────────────────────────────────
tmux new-session -d -s "$SESSION" -n "zeta-app" -x 220 -y 50
tmux send-keys -t "$SESSION:zeta-app" \
    "cd $APP_DIR && source .env 2>/dev/null; $VENV/uvicorn zeta_voice.main:app --host 0.0.0.0 --port 8000 --workers 1 --log-level info 2>&1 | tee logs/app.log" \
    Enter

# ── Window 1: Admin app ──────────────────────────────────────────────────────
tmux new-window -t "$SESSION" -n "zeta-admin"
tmux send-keys -t "$SESSION:zeta-admin" \
    "cd $APP_DIR && source .env 2>/dev/null; $VENV/uvicorn zeta_voice.main:admin_app --host 0.0.0.0 --port 8001 --workers 1 --log-level info 2>&1 | tee logs/admin.log" \
    Enter

# ── Window 2: Live logs ───────────────────────────────────────────────────────
tmux new-window -t "$SESSION" -n "logs"
tmux send-keys -t "$SESSION:logs" \
    "cd $APP_DIR && tail -f logs/app.log logs/admin.log" \
    Enter

# ── Focus the main app window ────────────────────────────────────────────────
tmux select-window -t "$SESSION:zeta-app"

echo ""
echo "✅  Services started."
echo ""
echo "   Attach:           tmux attach -t $SESSION"
echo "   Switch windows:   Ctrl+b  then  0 / 1 / 2"
echo "   Detach:           Ctrl+b  then  d"
echo "   Stop all:         bash deploy/tmux-stop.sh"
echo ""
echo "   App URL:          http://0.0.0.0:8000"
echo "   Admin URL:        http://0.0.0.0:8001"
