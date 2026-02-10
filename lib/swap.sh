#!/usr/bin/env bash
# swap.sh — zram, swap partition/file configuration
source "${LIB_DIR}/protection.sh"

# swap_setup — Configure swap based on SWAP_TYPE
swap_setup() {
    local swap_type="${SWAP_TYPE:-zram}"

    case "${swap_type}" in
        zram)
            swap_setup_zram
            ;;
        partition)
            einfo "Swap partition configured during disk setup"
            ;;
        none)
            einfo "No swap configured"
            ;;
    esac
}

# swap_setup_zram — Install and configure zram
swap_setup_zram() {
    einfo "Setting up zram swap..."

    # Chimera Linux uses dinit, so configure zram via a service or module
    apk_install_if_available "zram-init"

    # Configure zram via kernel module parameters
    chroot_exec "mkdir -p /etc/modprobe.d"
    chroot_exec "cat > /etc/modprobe.d/zram.conf << 'ZRAMEOF'
options zram num_devices=1
ZRAMEOF"

    # Create a dinit service for zram swap
    chroot_exec "cat > /etc/dinit.d/zram-swap << 'DINITEOF'
type = scripted
command = /bin/sh -c 'modprobe zram && echo zstd > /sys/block/zram0/comp_algorithm && echo \$(( \$(awk \"/MemTotal/{print \\\$2}\" /proc/meminfo) / 2 ))K > /sys/block/zram0/disksize && mkswap /dev/zram0 && swapon -p 100 /dev/zram0'
stop-command = /bin/sh -c 'swapoff /dev/zram0 2>/dev/null; echo 1 > /sys/block/zram0/reset 2>/dev/null'
depends-on = boot.target
DINITEOF"

    try "Enabling zram-swap" \
        chroot_exec "dinitctl -o enable zram-swap" 2>/dev/null || true

    einfo "zram configured"
}
