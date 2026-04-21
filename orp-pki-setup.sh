#!/usr/bin/env bash
# orp-pki-setup.sh
# Create a Sovereign Root CA, server cert, operator client cert, and PKCS#12 bundle.
set -euo pipefail

PKI_DIR="${PKI_DIR:-/home/orp/orp_engine/ssl}"
mkdir -p "$PKI_DIR"
cd "$PKI_DIR"

echo "=== Sovereign PKI Setup ==="
echo "[*] Working directory: $PKI_DIR"

# Tracking files
touch index.txt
echo 1000 > crlnumber

# Root CA
echo "[*] Generating Root CA (sovereign_root.key / sovereign_root.crt)"
openssl genrsa -out sovereign_root.key 4096
openssl req -x509 -new -nodes -key sovereign_root.key -sha256 -days 3650 \
  -out sovereign_root.crt \
  -subj "/C=PH/ST=Negros Oriental/L=Dumaguete/O=ORP Sovereign/CN=ORP Root CA"

# Server cert
echo "[*] Generating server key and CSR"
openssl genrsa -out orp_server.key 2048
openssl req -new -key orp_server.key -out orp_server.csr \
  -subj "/C=PH/ST=Negros Oriental/L=Dumaguete/O=ORP Engine/CN=localhost"

echo "[*] Signing server CSR with Root CA"
openssl x509 -req -in orp_server.csr -CA sovereign_root.crt -CAkey sovereign_root.key \
  -CAcreateserial -out orp_server.crt -days 365 -sha256

# Operator client cert
echo "[*] Generating operator client key and CSR"
openssl genrsa -out operator_01.key 2048
read -r -p "Operator common name (CN) [Marco-Admin]: " OP_CN
OP_CN="${OP_CN:-Marco-Admin}"
openssl req -new -key operator_01.key -out operator_01.csr \
  -subj "/C=PH/ST=Negros Oriental/O=ORP Operators/CN=${OP_CN}"

echo "[*] Signing operator CSR with Root CA"
openssl x509 -req -in operator_01.csr -CA sovereign_root.crt -CAkey sovereign_root.key \
  -CAcreateserial -out operator_01.crt -days 365 -sha256

# PKCS#12 export
echo "[*] Create PKCS#12 bundle for operator (operator01.p12)"
read -s -r -p "Enter export password for operator01.p12 (leave empty for interactive prompt later): " EXPORTPASS
echo
if [ -z "$EXPORTPASS" ]; then
  openssl pkcs12 -export -out operator01.p12 -inkey operator_01.key -in operator_01.crt -certfile sovereign_root.crt
else
  openssl pkcs12 -export -out operator01.p12 -inkey operator_01.key -in operator_01.crt -certfile sovereign_root.crt -passout pass:"$EXPORTPASS"
fi

# Ownership and permissions
echo "[*] Setting secure permissions"
# Private keys: owner read/write only
chmod 600 "$PKI_DIR"/*.key || true
# Certs: owner read, group/world read
chmod 644 "$PKI_DIR"/*.crt || true

# Attempt to set group to nginx or www-data if present
if getent group nginx >/dev/null 2>&1; then
  chgrp nginx "$PKI_DIR"/*.crt "$PKI_DIR"/*.key || true
elif getent group www-data >/dev/null 2>&1; then
  chgrp www-data "$PKI_DIR"/*.crt "$PKI_DIR"/*.key || true
fi

# SELinux handling (Fedora)
if command -v getenforce >/dev/null 2>&1 && [ "$(getenforce 2>/dev/null || echo Disabled)" = "Enforcing" ]; then
  if command -v semanage >/dev/null 2>&1; then
    echo "[*] Setting SELinux file context for PKI directory"
    semanage fcontext -a -t cert_t "${PKI_DIR}(/.*)?" || true
    restorecon -Rv "$PKI_DIR" || true
  else
    echo "[!] semanage not found; install policycoreutils-python-utils to set SELinux context if needed."
  fi
fi

# Verify chain
echo "[*] Verifying certificate chain"
openssl verify -CAfile sovereign_root.crt operator_01.crt || true
openssl verify -CAfile sovereign_root.crt orp_server.crt || true

# Nginx test (best-effort)
echo "[*] Testing nginx config (if nginx present)"
if command -v nginx >/dev/null 2>&1; then
  if nginx -t >/dev/null 2>&1; then
    echo "[*] nginx config OK; reloading (best-effort)"
    if command -v systemctl >/dev/null 2>&1 && systemctl is-active --quiet nginx; then
      sudo systemctl reload nginx || sudo systemctl restart nginx || true
    else
      nginx -s reload || true
    fi
  else
    echo "⚠️ nginx -t failed; check /etc/nginx/nginx.conf"
  fi
else
  echo "[*] nginx not installed or not in PATH; skip reload."
fi

# Quick mTLS test (curl)
echo "[*] Quick mTLS test with curl (best-effort)"
if command -v curl >/dev/null 2>&1; then
  if [ -f operator01.p12 ]; then
    echo "[*] Running curl with PKCS#12 (may prompt for password)"
    curl -vk --cert-type P12 --cert operator01.p12 https://localhost:9443/ || true
  fi
fi

echo "=== PKI setup complete ==="
echo "Files in: $PKI_DIR"
ls -l "$PKI_DIR"
echo "=== PKI setup complete ==="
echo "Root CA: $PKI_DIR/sovereign_root.crt"
echo "Server cert: $PKI_DIR/orp_server.crt"
echo "Operator cert: $PKI_DIR/operator_01.crt"
echo "PKCS#12 bundle: $PKI_DIR/operator01.p12"
echo "[*] Next step: configure your nginx server block to use orp_server.crt and orp_server.key, and enable mTLS with operator01.p12 for client auth."
