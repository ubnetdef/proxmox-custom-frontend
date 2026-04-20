#!/bin/bash
set -e

### CONFIG ###
REPO="https://github.com/ubnetdef/proxmox-custom-frontend.git"
CUSTOM_DIR="/UBnetDef-Frontend"

PVE_MANAGER_DIR="/usr/share/pve-manager"
PWT_IMG_DIR="/usr/share/javascript/proxmox-widget-toolkit/images"
PWT_LIB_DIR="/usr/share/javascript/proxmox-widget-toolkit"

REQUIRED_VERSION="9.1.5"

### PRE-CHECK: Enforce Proxmox Version ###
echo "========== Pre-Check: Proxmox Version =========="

CURRENT_VERSION=$(dpkg-query -W -f='${Version}' pve-manager 2>/dev/null || echo "none")

echo "[*] Current pve-manager version: $CURRENT_VERSION"
echo "[*] Required version: $REQUIRED_VERSION"

if [ "$CURRENT_VERSION" != "$REQUIRED_VERSION" ]; then
    echo "[*] Installing required version..."

    apt update
    apt install -y --allow-downgrades pve-manager=$REQUIRED_VERSION

    echo "[*] Version enforced successfully"
else
    echo "[*] Correct version already installed"
fi

echo "[*] Applying package holds..."

apt-mark hold pve-manager
apt-mark hold proxmox-ve

echo "========== Pre-Check Complete =========="

### MODE INPUT ###
MODE="$1"

if [ -z "$MODE" ]; then
    echo "Usage: $0 [dev|instructor|prod]"
    exit 1
fi

MODE=$(echo "$MODE" | tr '[:upper:]' '[:lower:]')

case "$MODE" in
    dev)
        MODE_DIR="pve-manager[DEVELOPMENT-MODE]"
        ;;
    instructor)
        MODE_DIR="pve-manager[INSTRUCTOR-MODE]"
        ;;
    prod|production)
        MODE_DIR="pve-manager[PRODUCTION-MODE]"
        ;;
    *)
        echo "Invalid mode: $MODE"
        echo "Valid options: dev | instructor | prod"
        exit 1
        ;;
esac

SRC_DIR="$CUSTOM_DIR/$MODE_DIR"
LOGO_SRC="$SRC_DIR/images/proxmox_logo.svg"
LEGACY_LOGO_SRC="$SRC_DIR/images/logo.svg"
LIB_SRC="$SRC_DIR/proxmoxlib.js"

echo "========== Proxmox Custom Deployment =========="
echo "[*] Mode: $MODE"
echo "[*] Source: $SRC_DIR"

### 1️⃣ Clone or update repo ###
if [ ! -d "$CUSTOM_DIR/.git" ]; then
    echo "[*] Cloning repo..."
    rm /UBnetDef-Frontend/ -rf
    git clone --depth 1 "$REPO" "$CUSTOM_DIR"
else
    echo "[*] Updating repo..."
    git -C "$CUSTOM_DIR" pull
fi

### 2️⃣ Validate source ###
if [ ! -d "$SRC_DIR" ]; then
    echo "[!] Mode folder not found: $SRC_DIR"
    exit 1
fi

### 3️⃣ Deploy frontend via rsync (mirror mode) ###
echo "[*] Applying frontend overrides..."
RSYNC_OUTPUT=$(rsync -av --exclude='.git' "$SRC_DIR/" "$PVE_MANAGER_DIR/")

### 4️⃣ Deploy proxmoxlib.js ###
LIB_CHANGED=0
if [ -f "$LIB_SRC" ]; then
    echo "[*] Applying proxmoxlib.js..."
    cp "$LIB_SRC" "$PWT_LIB_DIR/proxmoxlib.js"
    LIB_CHANGED=1
else
    echo "[!] No proxmoxlib.js found in $SRC_DIR/"
fi

### 5️⃣ Deploy PWT logo ###
LOGO_CHANGED=0
if [ -f "$LOGO_SRC" ]; then
    echo "[*] Applying PWT logo..."
    cp "$LOGO_SRC" "$PWT_IMG_DIR/proxmox_logo.svg"
    LOGO_CHANGED=1
else
    echo "[!] No proxmox_logo.svg found in $SRC_DIR/images/"
fi

### 6️⃣ Optional legacy logo ###
if [ -f "$LEGACY_LOGO_SRC" ]; then
    echo "[*] Applying legacy logo..."
    cp "$LEGACY_LOGO_SRC" "$PVE_MANAGER_DIR/images/logo.svg"
fi

### 7️⃣ Restart pveproxy only if changes happened ###
if echo "$RSYNC_OUTPUT" | grep -qv "sending incremental file list" || [ "$LOGO_CHANGED" -eq 1 ]; then
    echo "[*] Changes detected, restarting pveproxy..."
    systemctl restart pveproxy
else
    echo "[*] No changes detected, skipping restart"
fi

echo "========== DONE =========="