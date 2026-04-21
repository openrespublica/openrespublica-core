#!/usr/bin/env bash
# orp-timezone-setup.sh
# Enforce Philippine Standard Time (Asia/Manila) across Termux, WSL2, Fedora Proot, or Linux.
set -euo pipefail

TARGET_TZ="Asia/Manila"
LOG_FILE="$HOME/fedora-timezone.log"

# Detect environment
detect_env() {
  if [ -n "${WSL_DISTRO_NAME:-}" ]; then
    echo "wsl"
  elif command -v termux-info >/dev/null 2>&1; then
    echo "termux"
  elif [ -f "/etc/fedora-release" ]; then
    echo "fedora"
  elif [ -f "/etc/os-release" ]; then
    . /etc/os-release
    echo "$ID"
  else
    echo "unknown"
  fi
}

ENV_TYPE=$(detect_env)

echo "=== Timezone Setup ==="
echo "[*] Detected environment: $ENV_TYPE"

case "$ENV_TYPE" in
  fedora|centos|rhel|debian|ubuntu)
    echo "[*] Setting system timezone via /etc/localtime"
    sudo ln -sf "/usr/share/zoneinfo/$TARGET_TZ" /etc/localtime
    ;;
  termux)
    echo "[*] Termux detected — setting TZ environment variable only"
    echo "export TZ=\"$TARGET_TZ\"" >> "$HOME/.bashrc"
    ;;
  wsl)
    echo "[*] WSL detected — setting TZ environment variable only"
    echo "export TZ=\"$TARGET_TZ\"" >> "$HOME/.bashrc"
    ;;
  *)
    echo "[!] Unknown environment — falling back to TZ export"
    echo "export TZ=\"$TARGET_TZ\"" >> "$HOME/.bashrc"
    ;;
esac

export TZ="$TARGET_TZ"
current_time=$(date)
echo "Timezone set to: $current_time"

# Append to log file
echo "[$current_time] $ENV_TYPE login timezone enforced: $TARGET_TZ" >> "$LOG_FILE"
