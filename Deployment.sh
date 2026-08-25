#!/bin/bash
set -e

# Load configuration from Configuration.js (requires node in PATH)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/Configuration.js"

if [ ! -f "$CONFIG_FILE" ]; then
  echo "[!] Configuration.js not found at: $CONFIG_FILE"
  exit 1
fi

if ! command -v node >/dev/null 2>&1; then
    echo "[*] Node.js not found. Installing..."

    apt-get update
    apt-get full-upgrade -y
    apt autoremove -y

    if ! apt-get install -y nodejs npm; then
        echo "[!] Failed to install Node.js."
        exit 1
    fi

    if ! command -v node >/dev/null 2>&1; then
        echo "[!] Node.js installation completed, but 'node' is still unavailable."
        exit 1
    fi
fi

# Helper: pull a single key out of the config module
cfg() { node -e "const c=require('$CONFIG_FILE'); process.stdout.write(String(c.$1));"; }

REPO=$(cfg REPO)
CUSTOM_DIR=$(cfg CUSTOM_DIR)

PVE_VERSION=$(cfg PVE_VERSION)
PDS_VERSION=$(cfg PDS_VERSION)
PBS_VERSION=$(cfg PBS_VERSION)

PVE_MANAGER_DIR=$(cfg PVE_MANAGER_DIR)
PVE_PWT_IMG_DIR=$(cfg PVE_PWT_IMG_DIR)
PVE_PWT_LIB_DIR=$(cfg PVE_PWT_LIB_DIR)

PDS_MANAGER_DIR=$(cfg PDS_MANAGER_DIR)
PDS_PWT_IMG_DIR=$(cfg PDS_PWT_IMG_DIR)
PDS_PWT_LIB_DIR=$(cfg PDS_PWT_LIB_DIR)

PBS_MANAGER_DIR=$(cfg PBS_MANAGER_DIR)
PBS_PWT_IMG_DIR=$(cfg PBS_PWT_IMG_DIR)
PBS_PWT_LIB_DIR=$(cfg PBS_PWT_LIB_DIR)

# Service and mode passthrough parameters
SERVICE="$1"
MODE="$2"

if [ -z "$SERVICE" ] || [ -z "$MODE" ]; then
  echo "Usage: $0 <service> <mode>"
  echo "  service : pve | pds | pbs"
  echo "  mode    : default | modded"
  exit 1
fi

SERVICE=$(echo "$SERVICE" | tr '[:upper:]' '[:lower:]')
MODE=$(echo "$MODE"    | tr '[:upper:]' '[:lower:]')

# Resolve service-specific variables
case "$SERVICE" in
  pve)
    SERVICE_LABEL="Proxmox Virtual Environment"
    REQUIRED_VERSION="$PVE_VERSION"
    PKG_NAME="pve-manager"
    MANAGER_DIR="$PVE_MANAGER_DIR"
    PWT_IMG_DIR="$PVE_PWT_IMG_DIR"
    PWT_LIB_DIR="$PVE_PWT_LIB_DIR"
    FOLDER_PREFIX="pve"
    ;;
  pds)
    SERVICE_LABEL="Proxmox Datacenter Server"
    REQUIRED_VERSION="$PDS_VERSION"
    PKG_NAME="pds-manager"
    MANAGER_DIR="$PDS_MANAGER_DIR"
    PWT_IMG_DIR="$PDS_PWT_IMG_DIR"
    PWT_LIB_DIR="$PDS_PWT_LIB_DIR"
    FOLDER_PREFIX="pds"
    ;;
  pbs)
    SERVICE_LABEL="Proxmox Backup Server"
    REQUIRED_VERSION="$PBS_VERSION"
    PKG_NAME="proxmox-backup-server"
    MANAGER_DIR="$PBS_MANAGER_DIR"
    PWT_IMG_DIR="$PBS_PWT_IMG_DIR"
    PWT_LIB_DIR="$PBS_PWT_LIB_DIR"
    FOLDER_PREFIX="pbs"
    ;;
  *)
    echo "[!] Invalid service: $SERVICE"
    echo "    Valid options: pve | pds | pbs"
    exit 1
    ;;
esac

# Resolve mode-specific folder suffix
case "$MODE" in
  default)  MODE_LABEL="DEFAULT" ; CONFIG_TYPE="DefaultConfiguration" ;;
  modded)   MODE_LABEL="MODDED"  ; CONFIG_TYPE="ModdedConfiguration"  ;;
  *)
    echo "[!] Invalid mode: $MODE"
    echo "    Valid options: default | modded"
    exit 1
    ;;
esac
# Final derived variables
SRC_DIR="$CUSTOM_DIR/${FOLDER_PREFIX}-${CONFIG_TYPE}"

LOGO_SRC="$SRC_DIR/images/proxmox_logo.svg"
LEGACY_LOGO_SRC="$SRC_DIR/images/logo.svg"
LIB_SRC="$SRC_DIR/js/proxmoxlib.js"

# Start pre-checks

echo "========== Pre-Check: $SERVICE_LABEL Version =========="
CURRENT_VERSION=$(dpkg-query -W -f='${Version}' "$PKG_NAME" 2>/dev/null || echo "none")
echo "[*] Package          : $PKG_NAME"
echo "[*] Current version  : $CURRENT_VERSION"
echo "[*] Required version : $REQUIRED_VERSION"

if [ "$CURRENT_VERSION" != "$REQUIRED_VERSION" ]; then
  echo "[*] Installing required version..."
  apt update
  apt install -y --allow-downgrades --allow-change-held-packages "${PKG_NAME}=${REQUIRED_VERSION}"
  echo "[*] Version enforced successfully"
else
  echo "[*] Correct version already installed"
fi

echo "[*] Applying package holds..."
apt-mark hold "$PKG_NAME"
apt-mark hold proxmox-ve
echo "========== Pre-Check Complete =========="
sleep 2

# Start Deployment

echo ""
echo "========== $SERVICE_LABEL Custom Deployment =========="
echo "[*] Service : $SERVICE_LABEL"
echo "[*] Mode    : $MODE_LABEL"
echo "[*] Source  : $SRC_DIR"
echo "[*] Target  : $MANAGER_DIR"
sleep 2

# 1. Clone or update repo 
if [ ! -d "$CUSTOM_DIR/.git" ]; then
  echo "[*] Downloading required files..."
  sleep 1
  rm -rf "$CUSTOM_DIR"
  git clone --depth 1 "$REPO" "$CUSTOM_DIR"
else
  echo "[*] Updating required files..."
  sleep 1
  git -C "$CUSTOM_DIR" pull
fi
sleep 1
# 2. Validate source folder
if [ ! -d "$SRC_DIR" ]; then
  echo "[!] Source folder not found: $SRC_DIR"
  exit 1
fi

# 3. Deploy frontend via rsync (mirror)
echo "[*] Applying custom frontend..."
sleep 1
RSYNC_OUTPUT=$(rsync -av --exclude='.git' "$SRC_DIR/" "$MANAGER_DIR/")
sleep 1

# 4. Deploy proxmoxlib.js
LIB_CHANGED=0
if [ -f "$LIB_SRC" ]; then
  echo "[*] Applying custom WebUI layout..."
  sleep 1
  cp "$LIB_SRC" "$PWT_LIB_DIR/proxmoxlib.js"
  LIB_CHANGED=1
else
  echo "[!] No proxmoxlib.js found in $SRC_DIR/js/"
fi
sleep 1

# 5. Deploy PWT logo
LOGO_CHANGED=0
if [ -f "$LOGO_SRC" ]; then
  sleep 1
  echo "[*] Applying custom branding... (task 1/2)"
  cp "$LOGO_SRC" "$PWT_IMG_DIR/proxmox_logo.svg"
  LOGO_CHANGED=1
else
  echo "[!] No proxmox_logo.svg found in $SRC_DIR/images/"
fi
sleep 1

# 6. Optional legacy logo 
if [ -f "$LEGACY_LOGO_SRC" ]; then
  sleep 1
  echo "[*] Applying custom branding... (task 2/2)"
  cp "$LEGACY_LOGO_SRC" "$MANAGER_DIR/images/logo.svg"
fi
sleep 1

# 7. Restart proxy only when something changed
if echo "$RSYNC_OUTPUT" | grep -qv "sending incremental file list" \
   || [ "$LOGO_CHANGED" -eq 1 ] \
   || [ "$LIB_CHANGED"  -eq 1 ]; then
  echo "[*] Changes detected, restarting pveproxy..."
  sleep 1
  systemctl restart pveproxy
  echo "Operation has completed successfully (Refresh your browser to see changes)"
else
  echo "[*] No major changes detected"
  sleep 1
  echo "Operation has completed successfully"
fi
sleep 1
echo "========== DONE =========="