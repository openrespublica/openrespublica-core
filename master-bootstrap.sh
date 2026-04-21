#!/usr/bin/env bash
# master-bootstrap.sh — Run full first-run bootstrap or CI mode
# Usage:
#   ./master-bootstrap.sh          # interactive first-run (runs orp-env-bootstrap.sh if .env missing)
#   CI=true ./master-bootstrap.sh  # non-interactive CI mode (reads required env vars)
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="${LOG_FILE:-$HOME/universal-setup.log}"
ENV_FILE="$REPO_DIR/.env"

# Scripts (expected to be in repo root)
SCRIPTS=(
  "orp-env-bootstrap.sh"
  "orp-timezone-setup.sh"
  "immudb_setup.sh"
  "immudb-setup-operator.sh"
  "orp-pki-setup.sh"
  "python_prep.sh"
)

# Helper: log and echo
log() { printf '[%s] %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$*" | tee -a "$LOG_FILE"; }

# Check required scripts exist
for s in "${SCRIPTS[@]}"; do
  if [ ! -f "$REPO_DIR/$s" ]; then
    log "ERROR: Required script missing: $s"
    exit 1
  fi
done

# CI mode detection
CI_MODE="${CI:-false}"
if [ "$CI_MODE" = "true" ] || [ "$CI_MODE" = "1" ]; then
  CI_MODE=true
else
  CI_MODE=false
fi

log "MASTER BOOTSTRAP START (CI_MODE=$CI_MODE) — repo: $REPO_DIR"

# If CI mode, ensure required env vars are present and write .env non-interactively
if [ "$CI_MODE" = true ]; then
  log "CI mode: writing .env from environment variables"
  : "${LGU_NAME:?LGU_NAME must be set in CI mode}"
  : "${LGU_SIGNER_NAME:?LGU_SIGNER_NAME must be set in CI mode}"
  : "${OPERATOR_GPG_EMAIL:?OPERATOR_GPG_EMAIL must be set in CI mode}"
  : "${GITHUB_PORTAL_URL:?GITHUB_PORTAL_URL must be set in CI mode}"

  cat > "$ENV_FILE" <<EOF
# --- LGU Identity ---
LGU_NAME="${LGU_NAME}"
LGU_SIGNER_NAME="${LGU_SIGNER_NAME}"
LGU_TIMEZONE="${LGU_TIMEZONE:-Asia/Manila}"

# --- Operator ---
OPERATOR_GPG_EMAIL="${OPERATOR_GPG_EMAIL}"

# --- System Paths ---
GITHUB_REPO_PATH="${GITHUB_REPO_PATH:-$REPO_DIR}"
GITHUB_PORTAL_URL="${GITHUB_PORTAL_URL}"

# --- Flask ---
FLASK_PORT=${FLASK_PORT:-5000}

# --- immudb ---
IMMUDB_HOST="${IMMUDB_HOST:-127.0.0.1:3322}"
IMMUDB_USER="${IMMUDB_USER:-orp_operator}"
IMMUDB_DB="${IMMUDB_DB:-brgy_bunaodb}"

# NOTE: GNUPGHOME is intentionally absent and created at runtime.
EOF
  chmod 600 "$ENV_FILE"
  log ".env written (mode 600) from CI environment"
else
  # Interactive: run orp-env-bootstrap.sh only if .env missing
  if [ ! -f "$ENV_FILE" ]; then
    log ".env not found — launching interactive bootstrap: orp-env-bootstrap.sh"
    bash "$REPO_DIR/orp-env-bootstrap.sh" 2>&1 | tee -a "$LOG_FILE"
    log "Interactive .env bootstrap finished"
  else
    log ".env already present — skipping interactive bootstrap"
  fi
fi

# Run timezone setup
log "Running timezone setup: orp-timezone-setup.sh"
bash "$REPO_DIR/orp-timezone-setup.sh" 2>&1 | tee -a "$LOG_FILE"

# Build/install immudb
log "Running immudb build/install: immudb_setup.sh"
bash "$REPO_DIR/immudb_setup.sh" 2>&1 | tee -a "$LOG_FILE"

# Create immudb DB and operator user
log "Running immudb operator setup: immudb-setup-operator.sh"
bash "$REPO_DIR/immudb-setup-operator.sh" 2>&1 | tee -a "$LOG_FILE"

# PKI setup
log "Running PKI setup: orp-pki-setup.sh"
bash "$REPO_DIR/orp-pki-setup.sh" 2>&1 | tee -a "$LOG_FILE"

# Python venv and dependencies
log "Preparing Python environment: python_prep.sh"
bash "$REPO_DIR/python_prep.sh" 2>&1 | tee -a "$LOG_FILE"

# Final checks and summary
log "MASTER BOOTSTRAP COMPLETE"
cat <<EOF | tee -a "$LOG_FILE"
Summary:
 - Repo: $REPO_DIR
 - .env: $( [ -f "$ENV_FILE" ] && echo "present (mode $(stat -c '%a' "$ENV_FILE"))" || echo "missing" )
 - immudb data: $HOME/immudb-data
 - PKI dir: /home/orp/orp_engine/ssl (if created)
 - Python venv: $REPO_DIR/.venv

Next steps:
 1) Activate Python venv: source "$REPO_DIR/.venv/bin/activate"
 2) Start the engine: ./run_orp.sh
 3) If you created an operator password interactively, consider persisting it to ~/.identity/db_secrets.env (mode 600) if you want automatic vault login.

Logs: $LOG_FILE
EOF

exit 0
