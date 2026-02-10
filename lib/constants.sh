#!/usr/bin/env bash
# constants.sh — Global constants for the Chimera Linux installer
source "${LIB_DIR}/protection.sh"

readonly INSTALLER_VERSION="1.0.0"
readonly INSTALLER_NAME="Chimera Linux TUI Installer"

# Paths (use defaults, allow override from environment)
: "${MOUNTPOINT:=/media/root}"
: "${CHROOT_INSTALLER_DIR:=/tmp/chimera-installer}"
: "${LOG_FILE:=/tmp/chimera-installer.log}"
: "${CHECKPOINT_DIR:=/tmp/chimera-installer-checkpoints}"
: "${CONFIG_FILE:=/tmp/chimera-installer.conf}"

# Partition sizes (MiB)
readonly ESP_SIZE_MIB=512
readonly SWAP_DEFAULT_SIZE_MIB=4096

# Timeouts
readonly COUNTDOWN_DEFAULT=10
readonly DIALOG_TIMEOUT=0

# Exit codes for TUI screens
readonly TUI_NEXT=0
readonly TUI_BACK=1
readonly TUI_ABORT=2

# Checkpoint names
readonly -a CHECKPOINTS=(
    "preflight"
    "disks"
    "bootstrap"
    "chroot_setup"
    "apk_update"
    "kernel"
    "fstab"
    "system_config"
    "bootloader"
    "swap_setup"
    "networking"
    "desktop"
    "users"
    "extras"
    "finalize"
)

# Configuration variable names (for save/load)
readonly -a CONFIG_VARS=(
    TARGET_DISK
    PARTITION_SCHEME
    FILESYSTEM
    BTRFS_SUBVOLUMES
    LUKS_ENABLED
    LUKS_PARTITION
    SWAP_TYPE
    SWAP_SIZE_MIB
    HOSTNAME
    TIMEZONE
    KEYMAP
    KERNEL_TYPE
    BOOTLOADER_TYPE
    GPU_VENDOR
    GPU_DRIVER
    DESKTOP_EXTRAS
    ENABLE_FLATPAK
    ENABLE_PRINTING
    ENABLE_BLUETOOTH
    ROOT_PASSWORD_HASH
    USERNAME
    USER_PASSWORD_HASH
    USER_GROUPS
    ENABLE_SSH
    EXTRA_PACKAGES
    ESP_PARTITION
    ESP_REUSE
    ROOT_PARTITION
    SWAP_PARTITION
    BOOT_PARTITION
)
