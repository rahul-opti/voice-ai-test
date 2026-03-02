#!/usr/bin/env bash
# =============================================================================
# Zeta Voice — EC2 Deployment Script
# Usage: sudo bash deploy/deploy.sh
# Run from /opt/zeta-voice after cloning the repo there.
# =============================================================================

set -euo pipefail

APP_DIR="/opt/zeta-voice"
PYTHON_VERSION="3.12"

echo "════════════════════════════════════════════════════"
echo "  Zeta Voice — Deployment"
echo "════════════════════════════════════════════════════"

# ── 1. Pull latest code ───────────────────────────────────────────────────────
echo "[1/6] Pulling latest code..."
cd "$APP_DIR"
git pull origin main

# ── 2. Install / update Python dependencies ───────────────────────────────────
echo "[2/6] Installing Python dependencies..."
if [ ! -f ".venv/bin/activate" ]; then
    uv venv --python "$PYTHON_VERSION" .venv
fi
uv pip install --python .venv/bin/python -e .

# ── 3. Download NLP model (idempotent) ────────────────────────────────────────
echo "[3/6] Ensuring spaCy model is present..."
.venv/bin/python -m spacy download en_core_web_lg --quiet || true

# ── 4. Download Transformer model (idempotent) ────────────────────────────────
echo "[4/6] Ensuring question-classifier model is cached..."
MODEL_DIR="$APP_DIR/src/zeta_voice/question_classification/model"
mkdir -p "$MODEL_DIR"
.venv/bin/python - <<'PY'
from transformers import AutoModelForSequenceClassification, AutoTokenizer
import os
MODEL_ID = "shahrukhx01/question-vs-statement-classifier"
MODEL_DIR = "src/zeta_voice/question_classification/model"
AutoTokenizer.from_pretrained(MODEL_ID, cache_dir=MODEL_DIR)
AutoModelForSequenceClassification.from_pretrained(MODEL_ID, cache_dir=MODEL_DIR)
print("Model ready.")
PY

# ── 5. Ensure runtime directories exist ───────────────────────────────────────
echo "[5/6] Creating runtime directories..."
mkdir -p "$APP_DIR/data/dynamic_recordings"
mkdir -p "$APP_DIR/data/static_recordings"
mkdir -p "$APP_DIR/logs"

# ── 6. Restart tmux session ───────────────────────────────────────────────────
echo "[6/6] Restarting tmux session..."
bash "$APP_DIR/deploy/tmux-restart.sh"

echo ""
echo "✅  Deployment complete!"
echo "   zeta-app   → http://0.0.0.0:8000"
echo "   zeta-admin → http://0.0.0.0:8001"
echo ""
echo "   Attach:  tmux attach -t zeta-voice"
