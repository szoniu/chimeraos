#!/usr/bin/env bash
# tests/test_disk.sh — Test disk plan generation
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Setup mock environment
export _CHIMERA_INSTALLER=1
export LIB_DIR="${SCRIPT_DIR}/lib"
export DATA_DIR="${SCRIPT_DIR}/data"
export LOG_FILE="/tmp/chimera-test-disk.log"
export DRY_RUN=1
: > "${LOG_FILE}"

source "${LIB_DIR}/constants.sh"
source "${LIB_DIR}/logging.sh"
source "${LIB_DIR}/utils.sh"
source "${LIB_DIR}/disk.sh"

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

assert_contains() {
    local desc="$1" needle="$2" haystack="$3"
    if [[ "${haystack}" == *"${needle}"* ]]; then
        echo "  PASS: ${desc}"
        (( PASS++ )) || true
    else
        echo "  FAIL: ${desc} — '${needle}' not found in output"
        (( FAIL++ )) || true
    fi
}

echo "=== Test: Auto-partition plan (sda, ext4, zram) ==="
TARGET_DISK="/dev/sda"
FILESYSTEM="ext4"
SWAP_TYPE="zram"
LUKS_ENABLED="no"
export TARGET_DISK FILESYSTEM SWAP_TYPE LUKS_ENABLED

disk_plan_auto
assert_eq "Action count (ext4+zram)" "3" "${#DISK_ACTIONS[@]}"
assert_eq "ESP partition" "/dev/sda1" "${ESP_PARTITION}"
assert_eq "Root partition" "/dev/sda2" "${ROOT_PARTITION}"

echo ""
echo "=== Test: Auto-partition plan (nvme, btrfs, swap partition) ==="
TARGET_DISK="/dev/nvme0n1"
FILESYSTEM="btrfs"
SWAP_TYPE="partition"
SWAP_SIZE_MIB="4096"
LUKS_ENABLED="no"
export TARGET_DISK FILESYSTEM SWAP_TYPE SWAP_SIZE_MIB LUKS_ENABLED

disk_plan_auto
assert_eq "ESP partition (nvme)" "/dev/nvme0n1p1" "${ESP_PARTITION}"
assert_eq "Swap partition (nvme)" "/dev/nvme0n1p2" "${SWAP_PARTITION}"
assert_eq "Root partition (nvme)" "/dev/nvme0n1p3" "${ROOT_PARTITION}"

echo ""
echo "=== Test: Auto-partition plan with LUKS ==="
TARGET_DISK="/dev/sda"
FILESYSTEM="ext4"
SWAP_TYPE="zram"
LUKS_ENABLED="yes"
export TARGET_DISK FILESYSTEM SWAP_TYPE LUKS_ENABLED

disk_plan_auto
assert_eq "LUKS partition" "/dev/sda2" "${LUKS_PARTITION}"
assert_eq "Root partition (LUKS)" "/dev/mapper/cryptroot" "${ROOT_PARTITION}"

plan_text=""
for action in "${DISK_ACTIONS[@]}"; do
    plan_text+="${action%%|||*}\n"
done
assert_contains "Plan has LUKS setup" "LUKS encryption" "${plan_text}"

# Cleanup
rm -f "${LOG_FILE}"

echo ""
echo "=== Results ==="
echo "Passed: ${PASS}"
echo "Failed: ${FAIL}"

[[ ${FAIL} -eq 0 ]] && exit 0 || exit 1
