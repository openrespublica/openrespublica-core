#!/bin/bash
# run_orp-gum.sh — Sovereign UI Edition
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./_orp_core.sh
source "$SCRIPT_DIR/_orp_core.sh"

ACCENT="#004a99"
GOLD="#FFD700"
WARN="#ff4d4d"
SUCCESS="#2ecc71"

# Override cleanup to add gum styling.
# orp_cleanup (from _orp_core.sh) handles the actual RAM wipe.
cleanup() {
    echo ""
    gum style --foreground "$WARN" " [!] Locking vault & wiping volatile memory..."
    orp_cleanup
    gum style --foreground "$SUCCESS" " [*] Session terminated securely."
}
trap cleanup EXIT INT TERM

# ── 1. Load environment ──────────────────────────────────────────
gum spin --spinner dot --title "Loading sovereign environment..." \
    -- bash -c "true"   # gum spin needs a command; real work runs below in THIS shell
orp_load_env

# ── 2. Forge session identity ────────────────────────────────────
# IMPORTANT: orp_forge_identity MUST run in THIS shell to export GNUPGHOME,
# SSH_AUTH_SOCK, ORP_IDENTITY_DIR, and KEY_ID.  Running it inside a gum spin
# subshell would silently discard all exports and also leak a stale GNUPGHOME
# directory in /dev/shm that the cleanup trap would never remove.
gum style --foreground "$GOLD" " [~] Forging ephemeral session keys for $LGU_SIGNER_NAME..."
orp_forge_identity
gum style --foreground "$SUCCESS" " [✔] Session identity forged. Key: $KEY_ID"

# ── 3. Start or attach to immudb vault ──────────────────────────
# Delegate entirely to orp_start_vault, which has a proper nc-based readiness
# loop.  The previous inline block used a blind `sleep 2` and also ran immudb
# inside a gum spin subshell, which meant IMMUDB_PID was written to a temp
# file and the vault was never confirmed ready before Flask connected.
if nc -z 127.0.0.1 3322 2>/dev/null; then
    gum style --foreground "$SUCCESS" " [✔] immudb vault detected on :3322."
    IMMUDB_PID=$(pgrep -f "immudb" | head -n1 || true)
    export IMMUDB_PID
else
    gum style --foreground "$GOLD" " [~] Igniting hardened immudb vault..."
    orp_start_vault
    gum style --foreground "$SUCCESS" " [✔] Vault ready on :3322. PID: $IMMUDB_PID"
fi

# ── 4. Configure git signing ─────────────────────────────────────
orp_configure_git

# ── 5. Restart Nginx mTLS gateway ───────────────────────────────
# orp_refresh_gateway runs nginx -t and systemctl restart — purely external
# commands, so running it in a subshell is safe.
gum spin --spinner line \
    --title "Synchronizing mTLS Gateway..." \
    -- bash -c "source '$SCRIPT_DIR/_orp_core.sh' && orp_load_env && orp_refresh_gateway"
gum style --foreground "$SUCCESS" " [✔] mTLS Gateway synchronized."

# ── 6. Display session info & confirm ───────────────────────────
clear
gum style \
    --border double \
    --margin "1" --padding "1 2" \
    --border-foreground "$ACCENT" --align center \
    "OPENRESPUBLICA" "INFORMATION TECHNOLOGY SOLUTIONS"

echo "$(gum style --foreground "$GOLD" --align center "★ ★ ★")"
gum style --bold " Sovereign node:  " "$LGU_NAME"
gum style        " Operator:        " "$LGU_SIGNER_NAME ($KEY_ID)"
echo ""
gum style --bold "📋 Session SSH key (Authentication):"
gum style --faint -- "$(cat "$ORP_IDENTITY_DIR/session.pub")"
echo ""
gum style --bold "🔐 Session GPG key (Commit Verification):"
gum style --faint -- "$(cat "$ORP_IDENTITY_DIR/session.gpg")"
echo ""

if gum confirm "Keys synced to GitHub Settings?"; then
    clear
    gum style --border normal --padding "1 2" \
        --border-foreground "$SUCCESS" \
        "VAULT UNLOCKED · ENGINE START"
    orp_launch_engine
else
    gum style --foreground "$WARN" "Launch aborted. Cleaning up..."
    exit 0
fi
