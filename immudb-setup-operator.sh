#!/usr/bin/env bash
# immudb-setup-operator-db.sh
# Start immudb (if needed), login as superadmin, create DB and operator user, test immuclient.
set -euo pipefail

BIN_DIR="${BIN_DIR:-$HOME/bin}"
IMMUD_BIN="$BIN_DIR/immudb"
IMMUADMIN="$BIN_DIR/immuadmin"
IMMUCLIENT="$BIN_DIR/immuclient"
DATA_DIR="${DATA_DIR:-$HOME/immudb-data}"
LOG_FILE="$DATA_DIR/immudb.log"

mkdir -p "$DATA_DIR"

# Check binaries
for cmd in "$IMMUD_BIN" "$IMMUADMIN" "$IMMUCLIENT"; do
  if [ ! -x "$cmd" ]; then
    echo "ERROR: required binary not found or not executable: $cmd"
    echo "Place immudb, immuadmin, immuclient in $BIN_DIR and re-run."
    exit 1
  fi
done

# Start immudb if not running
if ! pgrep -x immudb >/dev/null 2>&1; then
  echo "[*] immudb server not running, starting it..."
  nohup "$IMMUD_BIN" --dir "$DATA_DIR" > "$LOG_FILE" 2>&1 &
  sleep 4
fi

# Wait until immudb responds (timeout ~15s)
echo "[*] Waiting for immudb to accept connections..."
TRIES=0
until "$IMMUCLIENT" status >/dev/null 2>&1 || [ $TRIES -ge 15 ]; do
  sleep 1
  TRIES=$((TRIES + 1))
done

if ! "$IMMUCLIENT" status >/dev/null 2>&1; then
  echo "ERROR: immudb did not start or is not responding. Check $LOG_FILE"
  exit 2
fi

# Superadmin login (interactive)
echo "🔑 Login as superadmin (user: immudb)"
if ! "$IMMUADMIN" login immudb; then
  echo "ERROR: superadmin login failed"
  exit 3
fi

# Database creation (prompt with default)
read -r -p "Enter new database name [brgy_bunaodb]: " IMMUDBDB
IMMUDBDB="${IMMUDBDB:-brgy_bunaodb}"

if "$IMMUADMIN" database list | awk '{print $1}' | grep -qw "^$IMMUDBDB$"; then
  echo "[*] Database '$IMMUDBDB' already exists, skipping create."
else
  echo "[*] Creating database '$IMMUDBDB'..."
  "$IMMUADMIN" database create "$IMMUDBDB"
fi

# User creation (prompt with default)
read -r -p "Enter new username [orp_operator]: " IMMUDBUSER
IMMUDBUSER="${IMMUDBUSER:-orp_operator}"
read -r -p "Enter role (read, readwrite, admin) [readwrite]: " IMMUDBROLE
IMMUDBROLE="${IMMUDBROLE:-readwrite}"

if "$IMMUADMIN" user list | awk '{print $1}' | grep -qw "^$IMMUDBUSER$"; then
  echo "[*] User '$IMMUDBUSER' already exists. Skipping creation."
else
  echo "[*] Creating user '$IMMUDBUSER' with role '$IMMUDBROLE' on database '$IMMUDBDB'..."
  "$IMMUADMIN" user create "$IMMUDBUSER" "$IMMUDBROLE" "$IMMUDBDB"
fi

# Verify user exists
echo "[*] Verifying user..."
"$IMMUADMIN" user list | grep -E "^$IMMUDBUSER\b" || echo "⚠️ User not found in list"

# Test immuclient login and sample set/get/delete
echo "🔑 Testing immuclient login as $IMMUDBUSER on $IMMUDBDB"
if "$IMMUCLIENT" login "$IMMUDBUSER" --database "$IMMUDBDB"; then
  echo "[*] immuclient logged in as $IMMUDBUSER"
  "$IMMUCLIENT" set __orp_test_key "ok" >/dev/null 2>&1 || true
  "$IMMUCLIENT" get __orp_test_key || true
  "$IMMUCLIENT" delete __orp_test_key >/dev/null 2>&1 || true
  echo "[*] immuclient test complete"
else
  echo "⚠️ immuclient login failed for $IMMUDBUSER"
fi

echo "✅ immudb operator DB setup finished."
