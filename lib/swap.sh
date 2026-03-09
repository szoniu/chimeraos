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

# swap_setup_zram — Configure zram using Chimera's built-in dinit-zram framework
swap_setup_zram() {
    einfo "Setting up zram swap..."

    # Chimera has built-in zram support via dinit-chimera (zram-device@zramN service)
    # Config: /etc/dinit-zram.conf with [zram0] section
    # size goes to /sys/block/zram0/disksize — needs value in bytes/K/M/G
    local mem_kb
    mem_kb=$(awk '/MemTotal/{print $2}' /proc/meminfo 2>/dev/null) || mem_kb=0
    local zram_size_mb=$(( mem_kb / 2 / 1024 ))
    [[ "${zram_size_mb}" -lt 256 ]] && zram_size_mb=256

    chroot_exec "cat > /etc/dinit-zram.conf << ZRAMEOF
[zram0]
size=${zram_size_mb}M
algorithm=zstd
ZRAMEOF"

    # Enable the zram device service
    try "Enabling zram swap" \
        chroot_exec "dinitctl -o enable zram-device@zram0" 2>/dev/null || true

    einfo "zram configured (${zram_size_mb}M, zstd)"
}
