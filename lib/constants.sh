#!/usr/bin/env bash
# constants.sh — Global constants for the Chimera Linux installer
source "${LIB_DIR}/protection.sh"

readonly INSTALLER_VERSION="1.1.0"
readonly INSTALLER_NAME="Chimera Linux TUI Installer"

# Paths (use defaults, allow override from environment)
: "${MOUNTPOINT:=/media/root}"
: "${CHROOT_INSTALLER_DIR:=/tmp/chimera-installer}"
: "${LOG_FILE:=/tmp/chimera-installer.log}"
: "${CHECKPOINT_DIR:=/tmp/chimera-installer-checkpoints}"
: "${CHECKPOINT_DIR_SUFFIX:=/tmp/chimera-installer-checkpoints}"
: "${CONFIG_FILE:=/tmp/chimera-installer.conf}"

# Partition sizes (MiB)
readonly ESP_SIZE_MIB=512
readonly SWAP_DEFAULT_SIZE_MIB=4096
: "${CHIMERA_MIN_SIZE_MIB:=8192}"

# Gum TUI backend
: "${GUM_VERSION:=0.17.0}"
: "${GUM_CACHE_DIR:=/tmp/chimera-installer-gum}"

# GPT partition type GUIDs (for sfdisk)
readonly GPT_TYPE_EFI="C12A7328-F81F-11D2-BA4B-00A0C93EC93B"
readonly GPT_TYPE_LINUX="0FC63DAF-8483-4772-8E79-3D69D8477DE4"
readonly GPT_TYPE_SWAP="0657FD6D-A4AB-43C4-84E5-0933C84B4F4F"

# GPU vendor PCI IDs
readonly GPU_VENDOR_NVIDIA="10de"
readonly GPU_VENDOR_AMD="1002"
readonly GPU_VENDOR_INTEL="8086"

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
    DESKTOP_ENV
    TARGET_DISK
    PARTITION_SCHEME
    FILESYSTEM
    BTRFS_SUBVOLUMES
    LUKS_ENABLED
    LUKS_PARTITION
    SWAP_TYPE
    SWAP_SIZE_MIB
    HOSTNAME
    LOCALE
    TIMEZONE
    KEYMAP
    KERNEL_TYPE
    BOOTLOADER_TYPE
    GPU_VENDOR
    GPU_DEVICE_ID
    GPU_DEVICE_NAME
    GPU_DRIVER
    HYBRID_GPU
    IGPU_VENDOR
    IGPU_DEVICE_NAME
    DGPU_VENDOR
    DGPU_DEVICE_NAME
    DESKTOP_EXTRAS
    ENABLE_FLATPAK
    ENABLE_PRINTING
    ENABLE_BLUETOOTH
    BLUETOOTH_DETECTED
    FINGERPRINT_DETECTED
    ENABLE_FINGERPRINT
    THUNDERBOLT_DETECTED
    ENABLE_THUNDERBOLT
    SENSORS_DETECTED
    ENABLE_SENSORS
    WEBCAM_DETECTED
    WWAN_DETECTED
    ENABLE_WWAN
    ROOT_PASSWORD_HASH
    USERNAME
    USER_PASSWORD_HASH
    USER_GROUPS
    ENABLE_SSH
    ENABLE_HYPRLAND
    EXTRA_PACKAGES
    ESP_PARTITION
    ESP_REUSE
    ROOT_PARTITION
    SWAP_PARTITION
    WINDOWS_DETECTED
    LINUX_DETECTED
    DETECTED_OSES_SERIALIZED
    SHRINK_PARTITION
    SHRINK_PARTITION_FSTYPE
    SHRINK_NEW_SIZE_MIB
)
