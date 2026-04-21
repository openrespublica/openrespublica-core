#!/bin/bash
# run_orp.sh — Plain terminal launcher for ORP Engine
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./_orp_core.sh
source "$SCRIPT_DIR/_orp_core.sh"

trap orp_cleanup EXIT INT TERM

orp_load_env
orp_forge_identity
orp_start_vault
orp_configure_git
orp_refresh_gateway

clear
cat <<EOF
======================================================
          ORP SESSION CHECK-IN COMPLETE
======================================================
Identity:   $LGU_SIGNER_NAME
GPG ID:     $KEY_ID
SSH Socket: $SSH_AUTH_SOCK
======================================================

--- BEGIN SSH PUBLIC KEY ---
$(cat "$ORP_IDENTITY_DIR/session.pub")
--- END SSH PUBLIC KEY ---

--- BEGIN GPG PUBLIC KEY ---
$(cat "$ORP_IDENTITY_DIR/session.gpg")
--- END GPG PUBLIC KEY ---

======================================================
[!] ACTION: Paste the SSH key to GitHub Settings now.
[!] Then press ENTER to start the Flask engine.
======================================================
EOF

# Copy keys to clipboard AFTER printing them
cat "$ORP_IDENTITY_DIR/session.pub" | termux-clipboard-set
termux-toast "SSH public key copied to clipboard"

cat "$ORP_IDENTITY_DIR/session.gpg" | termux-clipboard-set
termux-toast "GPG public key copied to clipboard"

read -rp "Press [ENTER] after pasting keys to GitHub... "
# Copy keys to clipboard if Termux tools available
if command -v termux-clipboard-set >/dev/null 2>&1; then
  cat "$ORP_IDENTITY_DIR/session.pub" | termux-clipboard-set
  termux-toast "SSH public key copied to clipboard"
  cat "$ORP_IDENTITY_DIR/session.gpg" | termux-clipboard-set
  termux-toast "GPG public key copied to clipboard"
else
  echo "[*] Clipboard integration not available; copy keys manually."
fi

orp_launch_engine
