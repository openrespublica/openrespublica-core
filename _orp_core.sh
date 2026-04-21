#!/bin/bash
# _orp_core.sh — Shared core for ORP Engine boot sequence
# Source this file; do not execute directly.
# Ensure identity anchor permissions
[ -d "$HOME/.identity" ] || mkdir -p "$HOME/.identity"
chmod 700 "$HOME/.identity"
[ -f "$HOME/.identity/db_secrets.env" ] && chmod 600 "$HOME/.identity/db_secrets.env"

# ── 1. Environment ───────────────────────────────────────────────
orp_load_env() {
    # Resolve the repo root relative to THIS file, not CWD.
    # This makes it safe to launch the engine from any working directory.
    local core_dir
    core_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

    if [ -f "$core_dir/.env" ]; then
        set -a; source "$core_dir/.env"; set +a
    else
        orp_die "CRITICAL: .env file missing. Expected: $core_dir/.env"
    fi

    if [ -f "$HOME/.identity/db_secrets.env" ]; then
        set -a; source "$HOME/.identity/db_secrets.env"; set +a
    else
        orp_die "CRITICAL: RAM secrets not found at ~/.identity/db_secrets.env"
    fi
}

orp_die() {
    printf '\nERROR: %s\n' "$*" >&2
    exit 1
}

# ── 2. Cleanup trap ──────────────────────────────────────────────
orp_cleanup() {
    printf '\n[!] Shutting down ORP Engine...\n'
    if [ -n "${IMMUDB_PID:-}" ] && kill -0 "$IMMUDB_PID" 2>/dev/null; then
        kill "$IMMUDB_PID" 2>/dev/null || true
    fi
    if [ -n "${GNUPGHOME:-}" ] && [ -d "$GNUPGHOME" ]; then
        printf '[*] Wiping ephemeral RAM disk...\n'
        gpgconf --kill all 2>/dev/null || true
        rm -rf "$GNUPGHOME"
    fi
    [ -d "/dev/shm/orp_identity" ] && rm -rf "/dev/shm/orp_identity"
    printf '[*] Session terminated securely.\n'
}

# ── 3. RAM disk + GPG identity ───────────────────────────────────
orp_forge_identity() {
    export GNUPGHOME
    GNUPGHOME=$(mktemp -d -p /dev/shm .orp-gpg-XXXXXX)
    chmod 700 "$GNUPGHOME"

    cat > "$GNUPGHOME/gpg-agent.conf" <<'EOF'
enable-ssh-support
allow-loopback-pinentry
default-cache-ttl 86400
EOF

    gpg-connect-agent reloadagent /bye > /dev/null 2>&1
    export SSH_AUTH_SOCK
    SSH_AUTH_SOCK=$(gpgconf --list-dirs agent-ssh-socket)

    # Note: LGU_SIGNER_NAME and OPERATOR_GPG_EMAIL must already be exported
    # by orp_load_env before calling this function.
    cat > "$GNUPGHOME/gpg-gen-spec" <<EOF
Key-Type: EDDSA
Key-Curve: ed25519
Key-Usage: auth,sign
Name-Real: $LGU_SIGNER_NAME
Name-Email: $OPERATOR_GPG_EMAIL
Expire-Date: 1d
%no-protection
%commit
EOF

    gpg --batch --generate-key "$GNUPGHOME/gpg-gen-spec" > /dev/null 2>&1

    # Poll for the key to appear in the keyring instead of a blind sleep.
    local i=0
    local KEYGRIP=""
    while [ -z "$KEYGRIP" ]; do
        sleep 0.5
        i=$((i + 1))
        [ $i -ge 20 ] && orp_die "GPG key generation timed out after 10s."
        KEYGRIP=$(gpg --with-keygrip -K "$OPERATOR_GPG_EMAIL" 2>/dev/null \
            | grep "Keygrip" | head -n1 | awk '{print $3}')
    done

    echo "$KEYGRIP 0" > "$GNUPGHOME/sshcontrol"
    gpg-connect-agent updatestartuptty /bye > /dev/null 2>&1

    export ORP_IDENTITY_DIR="/dev/shm/orp_identity"
    mkdir -p "$ORP_IDENTITY_DIR"
    gpg --export-ssh-key "$OPERATOR_GPG_EMAIL" > "$ORP_IDENTITY_DIR/session.pub"
    gpg --export --armor   "$OPERATOR_GPG_EMAIL" > "$ORP_IDENTITY_DIR/session.gpg"

    KEY_ID=$(gpg --list-secret-keys --with-colons "$OPERATOR_GPG_EMAIL" \
        | awk -F: '/^sec/{print $5; exit}')
    export KEY_ID
}

# ── 4. immudb vault ──────────────────────────────────────────────
orp_start_vault() {
    printf '[*] Checking for immudb vault on :3322...\n'
    if nc -z 127.0.0.1 3322 2>/dev/null; then
        printf '[!] Vault already running. Connecting.\n'
        IMMUDB_PID=$(pgrep -f "immudb" | head -n1 || true)
    else
        printf '[*] Starting hardened immudb instance...\n'
        # Use $HOME explicitly — tilde inside quotes does not always expand.
        "$HOME/bin/immudb" \
            --dir "$HOME/.orp_vault/data" \
            --address 127.0.0.1 \
            --port 3322 \
            --pidfile "$HOME/.orp_vault/immudb.pid" \
            --auth=true \
            --maintenance=false \
            >> "$HOME/.orp_vault/immudb.log" 2>&1 &
        IMMUDB_PID=$!

        # Poll until the port is open, with a 10-second timeout.
        local i=0
        while ! nc -z 127.0.0.1 3322 2>/dev/null; do
            sleep 0.5; i=$((i + 1))
            [ $i -ge 20 ] && orp_die "immudb failed to start after 10s."
        done
        printf '[*] Vault ready.\n'
    fi
    export IMMUDB_PID
}

# ── 5. Git config ────────────────────────────────────────────────
# NOTE: This intentionally changes CWD to GITHUB_REPO_PATH.
# orp_launch_engine relies on the CWD being the repo root
# so that `exec ./.venv/bin/python3 main.py` resolves correctly.
orp_configure_git() {
    cd "$GITHUB_REPO_PATH" || orp_die "Cannot cd to GITHUB_REPO_PATH: $GITHUB_REPO_PATH"
    git config --local user.name        "$LGU_SIGNER_NAME"
    git config --local user.email       "$OPERATOR_GPG_EMAIL"
    git config --local user.signingkey  "$KEY_ID"
    git config --local commit.gpgsign   true
}

# ── 6. Engine launch ─────────────────────────────────────────────
orp_launch_engine() {
    # Re-derive the agent socket in case it drifted after a gpg-agent restart.
    export SSH_AUTH_SOCK
    SSH_AUTH_SOCK=$(gpgconf --list-dirs agent-ssh-socket)
    export GNUPGHOME

    printf '[*] Launching ORP Engine...\n'
    # exec replaces the shell so the cleanup trap fires only on Python exit,
    # not on a normal shell exit beforehand.
    exec ./.venv/bin/python3 main.py
}

# ── 7. Network Gateway (Nginx) ───────────────────────────────────
orp_refresh_gateway() {
    printf '[*] Verifying Nginx mTLS Gateway...\n'

    # 1. Check syntax first
    if ! nginx -t > /dev/null 2>&1; then
        nginx -t  # Show the actual error to the user
        orp_die "Nginx config is broken. Please fix /etc/nginx/nginx.conf or /etc/nginx/conf.d/"
    fi

    # 2. Check if Nginx is running WITHOUT systemctl
    if ! pgrep -x "nginx" >/dev/null 2>&1; then
        printf '[*] Gateway is cold. Starting Nginx natively...\n'
        # Start Nginx directly in the background
        nginx
    else
        printf '[*] Gateway is hot. Reloading mTLS config natively...\n'
        # Send the reload signal directly to the master process
        nginx -s reload
    fi

    # 3. Final health check
    sleep 1 # Give it a second to bind to ports
    if ! pgrep -x "nginx" >/dev/null 2>&1; then
        orp_die "Gateway failed to ignite."
    fi
    printf '[✔] Gateway is fully operational.\n'
}
