#!/usr/bin/env bash
# tests/test_config.sh — Test config save/load round-trip
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Setup mock environment
export _CHIMERA_INSTALLER=1
export LIB_DIR="${SCRIPT_DIR}/lib"
export DATA_DIR="${SCRIPT_DIR}/data"
export LOG_FILE="/tmp/chimera-test-config.log"
: > "${LOG_FILE}"

source "${LIB_DIR}/constants.sh"
source "${LIB_DIR}/logging.sh"
source "${LIB_DIR}/config.sh"

PASS=0
FAIL=0

assert_eq() {
    local desc="$1" expected="$2" actual="$3"
    if [[ "${expected}" == "${actual}" ]]; then
        echo "  PASS: ${desc}"
        (( PASS++ )) || true
    else
        echo "  FAIL: ${desc} — expected '${expected}', got '${actual}'"
        (( FAIL++ )) || true
    fi
}

echo "=== Test: Config Round-Trip ==="

# Set some config values
FILESYSTEM="btrfs"
HOSTNAME="test-host"
TIMEZONE="Europe/Warsaw"
KEYMAP="pl"
BTRFS_SUBVOLUMES="@:/:@home:/home:@var-log:/var/log"
SWAP_TYPE="zram"
KERNEL_TYPE="lts"
BOOTLOADER_TYPE="grub"
LUKS_ENABLED="yes"
EXTRA_PACKAGES="vim git htop"
export FILESYSTEM HOSTNAME TIMEZONE KEYMAP BTRFS_SUBVOLUMES SWAP_TYPE
export KERNEL_TYPE BOOTLOADER_TYPE LUKS_ENABLED EXTRA_PACKAGES

# Save
TMPFILE="/tmp/chimera-test-config-$$.conf"
config_save "${TMPFILE}"

# Clear values
unset FILESYSTEM HOSTNAME TIMEZONE KEYMAP BTRFS_SUBVOLUMES SWAP_TYPE
unset KERNEL_TYPE BOOTLOADER_TYPE LUKS_ENABLED EXTRA_PACKAGES

# Load
config_load "${TMPFILE}"

# Verify
assert_eq "FILESYSTEM" "btrfs" "${FILESYSTEM:-}"
assert_eq "HOSTNAME" "test-host" "${HOSTNAME:-}"
assert_eq "TIMEZONE" "Europe/Warsaw" "${TIMEZONE:-}"
assert_eq "KEYMAP" "pl" "${KEYMAP:-}"
assert_eq "BTRFS_SUBVOLUMES" "@:/:@home:/home:@var-log:/var/log" "${BTRFS_SUBVOLUMES:-}"
assert_eq "SWAP_TYPE" "zram" "${SWAP_TYPE:-}"
assert_eq "KERNEL_TYPE" "lts" "${KERNEL_TYPE:-}"
assert_eq "BOOTLOADER_TYPE" "grub" "${BOOTLOADER_TYPE:-}"
assert_eq "LUKS_ENABLED" "yes" "${LUKS_ENABLED:-}"
assert_eq "EXTRA_PACKAGES" "vim git htop" "${EXTRA_PACKAGES:-}"

# Test config_set / config_get
echo ""
echo "=== Test: config_set / config_get ==="
config_set "HOSTNAME" "new-host"
assert_eq "config_set HOSTNAME" "new-host" "$(config_get HOSTNAME)"

config_set "EXTRA_PACKAGES" "pkg with spaces"
assert_eq "Spaces in value" "pkg with spaces" "$(config_get EXTRA_PACKAGES)"

config_set "BTRFS_SUBVOLUMES" '@:/:@home:/home'
assert_eq "Special chars (@/:)" "@:/:@home:/home" "$(config_get BTRFS_SUBVOLUMES)"

# Test round-trip with special characters
TMPFILE2="/tmp/chimera-test-config-special-$$.conf"
config_save "${TMPFILE2}"
unset HOSTNAME EXTRA_PACKAGES BTRFS_SUBVOLUMES
config_load "${TMPFILE2}"
assert_eq "Round-trip HOSTNAME" "new-host" "${HOSTNAME:-}"
assert_eq "Round-trip EXTRA_PACKAGES" "pkg with spaces" "${EXTRA_PACKAGES:-}"
assert_eq "Round-trip BTRFS_SUBVOLUMES" "@:/:@home:/home" "${BTRFS_SUBVOLUMES:-}"

# Cleanup
rm -f "${TMPFILE}" "${TMPFILE2}" "${LOG_FILE}"

echo ""
echo "=== Results ==="
echo "Passed: ${PASS}"
echo "Failed: ${FAIL}"

[[ ${FAIL} -eq 0 ]] && exit 0 || exit 1
