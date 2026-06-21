module.exports = {
  // ─── Repository ────────────────────────────────────────────────────────────
  REPO:       "https://github.com/ubnetdef/proxmox-custom-frontend.git",
  CUSTOM_DIR: "/UBnetDef-Frontend",

  // ─── Required package versions (pinned to prevent API-breakage) ────────────
  PVE_VERSION: "9.2.0",
  PDS_VERSION: "1.1.4",
  PBS_VERSION: "4.2.0",

  // ─── Proxmox Virtual Environment (PVE) paths ───────────────────────────────
  PVE_MANAGER_DIR: "/usr/share/pve-manager",
  PVE_PWT_IMG_DIR: "/usr/share/javascript/proxmox-widget-toolkit/images",
  PVE_PWT_LIB_DIR: "/usr/share/javascript/proxmox-widget-toolkit",

  // ─── Proxmox Datacenter Server (PDS) paths ─────────────────────────────────
  PDS_MANAGER_DIR: "/usr/share/javascript/proxmox-datacenter-manager",
  PDS_PWT_IMG_DIR: "/usr/share/javascript/proxmox-datacenter-manager/images",
  PDS_PWT_LIB_DIR: "/usr/share/javascript/proxmox-datacenter-manager/js",

  // ─── Proxmox Backup Server (PBS) paths ─────────────────────────────────────
  PBS_MANAGER_DIR: "/usr/share/javascript/proxmox-backup/",
  PBS_PWT_IMG_DIR: "/usr/share/javascript/proxmox-widget-toolkit/images",
  PBS_PWT_LIB_DIR: "/usr/share/javascript/promox-widget-toolkit",
};