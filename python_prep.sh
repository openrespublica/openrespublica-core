#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VENV_DIR="$REPO_DIR/.venv"
REQ_FILE="$REPO_DIR/requirements.txt"

echo "=== Python environment setup ==="
if [ ! -f "$REQ_FILE" ]; then
  echo "ERROR: requirements.txt not found at $REQ_FILE"
  exit 1
fi

python3 -m venv "$VENV_DIR"
# shellcheck disable=SC1090
source "$VENV_DIR/bin/activate"
pip install --upgrade pip
pip install -r "$REQ_FILE"

echo "[✔] Virtualenv created at $VENV_DIR"
echo "To activate: source $VENV_DIR/bin/activate"
