#!/usr/bin/env bash
# immudb_setup.sh
# Build immudb v1.10.0 locally and copy binaries to $HOME/bin
set -euo pipefail

# Requirements: git, make, go, clang (installed via universal-pm.sh)
BIN_DIR="$HOME/bin"
SRC_DIR="$HOME/immudb-src"
IMMUD_REPO="https://github.com/codenotary/immudb.git"
IMMUD_TAG="v1.10.0"

mkdir -p "$BIN_DIR"

# Load package manager helper if available
if [ -f "$HOME/.universal-pm.sh" ]; then
  # shellcheck source=/dev/null
  source "$HOME/.universal-pm.sh"
else
  echo "[!] ~/.universal-pm.sh not found; continuing without auto-install."
fi

echo "[*] Ensure build dependencies are installed (you may be prompted for sudo)."
if command -v sysinstall >/dev/null 2>&1; then
  sysinstall git make golang clang cmake
else
  echo "[!] sysinstall not available; ensure git, make, go, clang, cmake are installed."
fi

echo "[*] Verifying toolchain versions..."
git --version || true
make --version || true
go version || true
clang --version || true

# Clone or update source
if [ -d "$SRC_DIR" ]; then
  echo "[*] Updating immudb source in $SRC_DIR"
  git -C "$SRC_DIR" fetch --all --tags || true
  git -C "$SRC_DIR" checkout "$IMMUD_TAG" || git -C "$SRC_DIR" pull --ff-only || true
else
  echo "[*] Cloning immudb $IMMUD_TAG to $SRC_DIR"
  git clone --depth 1 --branch "$IMMUD_TAG" "$IMMUD_REPO" "$SRC_DIR"
fi

cd "$SRC_DIR"

# Build only if binaries missing or older
need_build=false
for b in immudb immuclient immuadmin; do
  if [ ! -x "$BIN_DIR/$b" ]; then
    need_build=true
    break
  fi
done

if [ "$need_build" = true ]; then
  echo "[*] Building immudb binaries..."
  make immudb immuclient immuadmin
  cp -f immudb immuclient immuadmin "$BIN_DIR/"
  chmod +x "$BIN_DIR"/immudb "$BIN_DIR"/immuclient "$BIN_DIR"/immuadmin
else
  echo "[*] Binaries already present in $BIN_DIR; skipping build."
fi

echo "[*] immudb version checks:"
"$BIN_DIR/immudb" version || true
"$BIN_DIR/immuclient" version || true
"$BIN_DIR/immuadmin" version || true
echo "[*] immudb build/install complete."
