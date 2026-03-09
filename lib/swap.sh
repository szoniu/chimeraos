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

# swap_setup_zram — Configure zram swap via custom dinit service
swap_setup_zram() {
    einfo "Setting up zram swap..."

    local mem_kb
    mem_kb=$(awk '/MemTotal/{print $2}' /proc/meminfo 2>/dev/null) || mem_kb=0
    local zram_size_kb=$(( mem_kb / 2 ))
    local zram_size_mb=$(( zram_size_kb / 1024 ))
    [[ "${zram_size_mb}" -lt 256 ]] && zram_size_mb=256
    [[ "${zram_size_kb}" -lt 262144 ]] && zram_size_kb=262144

    # Try Chimera's built-in zram-device service first (dinit-chimera >= 2025)
    if chroot_exec "test -f /usr/lib/dinit.d/zram-device" 2>/dev/null; then
        chroot_exec "cat > /etc/dinit-zram.conf << ZRAMEOF
[zram0]
size=${zram_size_mb}M
algorithm=zstd
ZRAMEOF"
        try "Enabling zram swap" \
            chroot_exec "dinitctl -o enable zram-device@zram0" 2>/dev/null || true
    else
        # Fallback: create a standalone dinit service
        chroot_exec "mkdir -p /etc/dinit.d"
        chroot_exec "cat > /etc/dinit.d/zram-swap << DINITEOF
type = scripted
command = /bin/sh -c 'modprobe zram && echo zstd > /sys/block/zram0/comp_algorithm && echo ${zram_size_kb}K > /sys/block/zram0/disksize && mkswap /dev/zram0 && swapon -p 100 /dev/zram0'
stop-command = /bin/sh -c 'swapoff /dev/zram0 2>/dev/null; echo 1 > /sys/block/zram0/reset 2>/dev/null'
depends-on = boot.target
DINITEOF"
        try "Enabling zram swap" \
            chroot_exec "dinitctl -o enable zram-swap" 2>/dev/null || true
    fi

    einfo "zram configured (${zram_size_mb}M, zstd)"
}
