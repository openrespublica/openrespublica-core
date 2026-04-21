#!/usr/bin/env bash
# orp-env-bootstrap.sh — First-run dotenv setup
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="$SCRIPT_DIR/.env"

echo "=== ORP Environment Bootstrap ==="

# Prompt helpers
prompt() {
  local var="$1"; local msg="$2"; local example="$3"
  read -r -p "$msg (e.g. $example): " val
  printf -v "$var" '%s' "$val"
}

# Collect values
prompt LGU_NAME "Enter LGU Name" "Barangay Buñao"
prompt LGU_SIGNER_NAME "Enter LGU Signer Name (with salutation)" "HON. MARCO FERNANDEZ"
prompt OPERATOR_GPG_EMAIL "Enter Operator GPG Email" "marcofernandez0204@gmail.com"
prompt GITHUB_PORTAL_URL "Enter GitHub Portal URL" "https://openrespublica.github.io/verify.html"

# Hardcoded values
FLASK_PORT=5000
IMMUDB_HOST="127.0.0.1:3322"
IMMUDB_USER="orp_operator"
IMMUDB_DB="brgy_bunaodb"
GITHUB_REPO_PATH="$SCRIPT_DIR"

# Write .env
cat > "$ENV_FILE" <<EOF
# --- LGU Identity ---
LGU_NAME="$LGU_NAME"
LGU_SIGNER_NAME="$LGU_SIGNER_NAME"
LGU_TIMEZONE="Asia/Manila"

# --- Operator ---
OPERATOR_GPG_EMAIL="$OPERATOR_GPG_EMAIL"

# --- System Paths ---
GITHUB_REPO_PATH="$GITHUB_REPO_PATH"
GITHUB_PORTAL_URL="$GITHUB_PORTAL_URL"

# --- Flask ---
FLASK_PORT=$FLASK_PORT

# --- immudb ---
IMMUDB_HOST="$IMMUDB_HOST"
IMMUDB_USER="$IMMUDB_USER"
IMMUDB_DB="$IMMUDB_DB"

# NOTE: GNUPGHOME is intentionally absent.
EOF

chmod 600 "$ENV_FILE"
echo "[✔] .env created at $ENV_FILE with strict permissions"
