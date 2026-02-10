#!/usr/bin/env bash
# disk.sh — Two-phase disk operations (plan -> execute), LUKS, UUID persistence
source "${LIB_DIR}/protection.sh"

# Action queue for two-phase disk operations
declare -ga DISK_ACTIONS=()

# --- Phase 1: Planning ---

disk_plan_reset() {
    DISK_ACTIONS=()
}

disk_plan_add() {
    local desc="$1"
    shift
    DISK_ACTIONS+=("${desc}|||$*")
}

disk_plan_show() {
    local i
    einfo "Planned disk operations:"
    for (( i = 0; i < ${#DISK_ACTIONS[@]}; i++ )); do
        local desc="${DISK_ACTIONS[$i]%%|||*}"
        einfo "  $((i + 1)). ${desc}"
    done
}

# disk_plan_auto — Generate auto-partitioning plan
disk_plan_auto() {
    local disk="${TARGET_DISK}"
    local fs="${FILESYSTEM:-ext4}"
    local swap_type="${SWAP_TYPE:-zram}"
    local swap_size="${SWAP_SIZE_MIB:-${SWAP_DEFAULT_SIZE_MIB}}"

    disk_plan_reset

    disk_plan_add "Create GPT partition table on ${disk}" \
        parted -s "${disk}" mklabel gpt

    # ESP partition (512 MiB)
    disk_plan_add "Create ESP partition (${ESP_SIZE_MIB} MiB)" \
        parted -s "${disk}" mkpart "EFI System Partition" fat32 1MiB "$((ESP_SIZE_MIB + 1))MiB"
    disk_plan_add "Set ESP flag" \
        parted -s "${disk}" set 1 esp on

    local next_start="$((ESP_SIZE_MIB + 1))"

    # Optional swap partition
    if [[ "${swap_type}" == "partition" ]]; then
        local swap_end="$((next_start + swap_size))"
        disk_plan_add "Create swap partition (${swap_size} MiB)" \
            parted -s "${disk}" mkpart "Linux swap" linux-swap "${next_start}MiB" "${swap_end}MiB"
        next_start="${swap_end}"
    fi

    # Root partition (rest of disk)
    disk_plan_add "Create root partition (remaining space)" \
        parted -s "${disk}" mkpart "Linux filesystem" "${next_start}MiB" "100%"

    # Determine partition device names
    local part_prefix="${disk}"
    if [[ "${disk}" =~ [0-9]$ ]]; then
        part_prefix="${disk}p"
    fi

    local part_num=1
    ESP_PARTITION="${part_prefix}${part_num}"
    disk_plan_add "Format ESP as FAT32" \
        mkfs.vfat -F 32 -n EFI "${ESP_PARTITION}"
    (( part_num++ ))

    if [[ "${swap_type}" == "partition" ]]; then
        SWAP_PARTITION="${part_prefix}${part_num}"
        disk_plan_add "Format swap partition" \
            mkswap -L swap "${SWAP_PARTITION}"
        (( part_num++ ))
    fi

    ROOT_PARTITION="${part_prefix}${part_num}"

    # LUKS encryption
    if [[ "${LUKS_ENABLED:-no}" == "yes" ]]; then
        LUKS_PARTITION="${ROOT_PARTITION}"
        disk_plan_add "Setup LUKS encryption on ${ROOT_PARTITION}" \
            cryptsetup luksFormat --batch-mode "${ROOT_PARTITION}"
        disk_plan_add "Open LUKS partition" \
            cryptsetup luksOpen "${ROOT_PARTITION}" cryptroot
        ROOT_PARTITION="/dev/mapper/cryptroot"
    fi

    case "${fs}" in
        ext4)
            disk_plan_add "Format root as ext4" \
                mkfs.ext4 -L chimera "${ROOT_PARTITION}"
            ;;
        btrfs)
            disk_plan_add "Format root as btrfs" \
                mkfs.btrfs -f -L chimera "${ROOT_PARTITION}"
            ;;
        xfs)
            disk_plan_add "Format root as XFS" \
                mkfs.xfs -f -L chimera "${ROOT_PARTITION}"
            ;;
    esac

    export ESP_PARTITION ROOT_PARTITION SWAP_PARTITION LUKS_PARTITION

    einfo "Auto-partition plan generated for ${disk}"
}

# disk_plan_dualboot — Generate dual-boot partitioning plan
disk_plan_dualboot() {
    local disk="${TARGET_DISK}"
    local fs="${FILESYSTEM:-ext4}"

    disk_plan_reset

    einfo "Reusing existing ESP: ${ESP_PARTITION}"

    if [[ -z "${ROOT_PARTITION:-}" ]]; then
        disk_plan_add "Create root partition in free space" \
            parted -s "${disk}" mkpart "Linux filesystem" ext4 0% 100%

        local part_count
        part_count=$(lsblk -lno NAME "${disk}" 2>/dev/null | wc -l)
        local part_prefix="${disk}"
        [[ "${disk}" =~ [0-9]$ ]] && part_prefix="${disk}p"
        ROOT_PARTITION="${part_prefix}${part_count}"
    fi

    case "${fs}" in
        ext4)
            disk_plan_add "Format root as ext4" \
                mkfs.ext4 -L chimera "${ROOT_PARTITION}"
            ;;
        btrfs)
            disk_plan_add "Format root as btrfs" \
                mkfs.btrfs -f -L chimera "${ROOT_PARTITION}"
            ;;
        xfs)
            disk_plan_add "Format root as XFS" \
                mkfs.xfs -f -L chimera "${ROOT_PARTITION}"
            ;;
    esac

    export ROOT_PARTITION
    einfo "Dual-boot plan generated"
}

# --- Phase 2: Execution ---

disk_execute_plan() {
    if [[ ${#DISK_ACTIONS[@]} -eq 0 ]]; then
        case "${PARTITION_SCHEME:-auto}" in
            auto)      disk_plan_auto ;;
            dual-boot) disk_plan_dualboot ;;
            manual)
                einfo "Manual partitioning — no automated plan"
                return 0
                ;;
        esac
    fi

    disk_plan_show

    local i
    for (( i = 0; i < ${#DISK_ACTIONS[@]}; i++ )); do
        local entry="${DISK_ACTIONS[$i]}"
        local desc="${entry%%|||*}"
        local cmd="${entry#*|||}"

        einfo "[$((i + 1))/${#DISK_ACTIONS[@]}] ${desc}"
        try "${desc}" bash -c "${cmd}"
    done

    if [[ "${DRY_RUN}" != "1" ]]; then
        partprobe "${TARGET_DISK}" 2>/dev/null || true
        sleep 2
    fi

    einfo "All disk operations completed"
}

# --- Mount/unmount ---

mount_filesystems() {
    einfo "Mounting filesystems..."

    if [[ "${DRY_RUN}" == "1" ]]; then
        einfo "[DRY-RUN] Would mount filesystems"
        return 0
    fi

    mkdir -p "${MOUNTPOINT}"

    local fs="${FILESYSTEM:-ext4}"

    if [[ "${fs}" == "btrfs" ]]; then
        try "Mounting btrfs root" mount "${ROOT_PARTITION}" "${MOUNTPOINT}"

        if [[ -n "${BTRFS_SUBVOLUMES:-}" ]]; then
            local IFS=':'
            local -a parts
            read -ra parts <<< "${BTRFS_SUBVOLUMES}"
            local idx
            for (( idx = 0; idx < ${#parts[@]}; idx += 2 )); do
                local subvol="${parts[$idx]}"
                if ! btrfs subvolume list "${MOUNTPOINT}" 2>/dev/null | grep -q " ${subvol}$"; then
                    try "Creating btrfs subvolume ${subvol}" \
                        btrfs subvolume create "${MOUNTPOINT}/${subvol}"
                fi
            done
        fi

        umount "${MOUNTPOINT}"

        try "Mounting @ subvolume" \
            mount -o subvol=@,compress=zstd,noatime "${ROOT_PARTITION}" "${MOUNTPOINT}"

        if [[ -n "${BTRFS_SUBVOLUMES:-}" ]]; then
            local IFS=':'
            local -a parts
            read -ra parts <<< "${BTRFS_SUBVOLUMES}"
            local idx
            for (( idx = 0; idx < ${#parts[@]}; idx += 2 )); do
                local subvol="${parts[$idx]}"
                local mpoint="${parts[$((idx + 1))]}"
                [[ "${subvol}" == "@" ]] && continue
                mkdir -p "${MOUNTPOINT}${mpoint}"
                try "Mounting subvolume ${subvol} at ${mpoint}" \
                    mount -o "subvol=${subvol},compress=zstd,noatime" \
                    "${ROOT_PARTITION}" "${MOUNTPOINT}${mpoint}"
            done
        fi
    else
        try "Mounting root filesystem" mount "${ROOT_PARTITION}" "${MOUNTPOINT}"
    fi

    # CRITICAL: Chimera Linux requires correct permissions on root
    chmod 755 "${MOUNTPOINT}"

    # Mount boot and ESP
    # For GRUB: /boot on root, /boot/efi for ESP
    # For systemd-boot: /boot is ESP (special case)
    if [[ "${BOOTLOADER_TYPE:-grub}" == "systemd-boot" ]]; then
        mkdir -p "${MOUNTPOINT}/boot"
        try "Mounting ESP at /boot" mount "${ESP_PARTITION}" "${MOUNTPOINT}/boot"
    else
        mkdir -p "${MOUNTPOINT}/boot"
        mkdir -p "${MOUNTPOINT}/boot/efi"
        try "Mounting ESP at /boot/efi" mount "${ESP_PARTITION}" "${MOUNTPOINT}/boot/efi"
    fi

    # Activate swap if partition
    if [[ "${SWAP_TYPE:-}" == "partition" && -n "${SWAP_PARTITION:-}" ]]; then
        try "Activating swap" swapon "${SWAP_PARTITION}"
    fi

    einfo "Filesystems mounted at ${MOUNTPOINT}"
}

unmount_filesystems() {
    einfo "Unmounting filesystems..."

    if [[ "${DRY_RUN}" == "1" ]]; then
        einfo "[DRY-RUN] Would unmount filesystems"
        return 0
    fi

    # Deactivate swap
    if [[ "${SWAP_TYPE:-}" == "partition" && -n "${SWAP_PARTITION:-}" ]]; then
        swapoff "${SWAP_PARTITION}" 2>/dev/null || true
    fi

    # Unmount in reverse order
    local -a mounts
    readarray -t mounts < <(mount | grep "${MOUNTPOINT}" | awk '{print $3}' | sort -r)

    local mnt
    for mnt in "${mounts[@]}"; do
        umount -l "${mnt}" 2>/dev/null || true
    done

    # Close LUKS if active
    if [[ "${LUKS_ENABLED:-no}" == "yes" ]]; then
        cryptsetup luksClose cryptroot 2>/dev/null || true
    fi

    einfo "Filesystems unmounted"
}

# get_uuid — Get UUID of a partition
get_uuid() {
    local partition="$1"
    blkid -s UUID -o value "${partition}" 2>/dev/null
}

# get_partuuid — Get PARTUUID of a partition
get_partuuid() {
    local partition="$1"
    blkid -s PARTUUID -o value "${partition}" 2>/dev/null
}
