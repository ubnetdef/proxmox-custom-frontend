#!/bin/bash

set -e

### CONFIG ###
REPO="https://github.com/ubnetdef/proxmox-custom-frontend.git"
CUSTOM_DIR="/UBnetDef-Frontend"

PVE_MANAGER_DIR="/usr/share/pve-manager"
PWT_IMG_DIR="/usr/share/javascript/proxmox-widget-toolkit/images"

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

echo "========== Proxmox Custom Deployment =========="
echo "[*] Mode: $MODE"
echo "[*] Source: $SRC_DIR"

### 1️⃣ Fresh Clone Repo ###
echo "[*] Resetting frontend repo..."

if [ -d "$CUSTOM_DIR" ]; then
    echo "[*] Removing existing repo..."
    rm -rf "$CUSTOM_DIR"
fi

echo "[*] Cloning repo..."
git clone --depth 1 "$REPO" "$CUSTOM_DIR"

### 2️⃣ Validate Source ###
if [ ! -d "$SRC_DIR" ]; then
    echo "[!] Mode folder not found: $SRC_DIR"
    exit 1
fi

### 3️⃣ Deploy Frontend Overrides ###
echo "[*] Applying frontend overrides..."

RSYNC_OUTPUT=$(rsync -av --delete --exclude='.git' "$SRC_DIR/" "$PVE_MANAGER_DIR/")

### 4️⃣ Deploy PWT Logo ###
LOGO_CHANGED=0

if [ -f "$LOGO_SRC" ]; then
    echo "[*] Applying PWT logo..."
    cp "$LOGO_SRC" "$PWT_IMG_DIR/proxmox_logo.svg"
    LOGO_CHANGED=1
else
    echo "[!] No proxmox_logo.svg found in $SRC_DIR/images/"
fi

### 5️⃣ Optional Legacy Logo ###
if [ -f "$LEGACY_LOGO_SRC" ]; then
    echo "[*] Applying legacy logo..."
    cp "$LEGACY_LOGO_SRC" "$PVE_MANAGER_DIR/images/logo.svg"
fi

### 6️⃣ Restart Only If Needed ###
if echo "$RSYNC_OUTPUT" | grep -qv "sending incremental file list" || [ "$LOGO_CHANGED" -eq 1 ]; then
    echo "[*] Changes detected, restarting pveproxy..."
    systemctl restart pveproxy
else
    echo "[*] No changes detected, skipping restart"
fi

echo "========== DONE =========="