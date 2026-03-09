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
        # Note: cryptsetup luksFormat reads passphrase from stdin interactively
        # --batch-mode only suppresses confirmation, not the passphrase prompt
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

    # Shrink existing partition if requested
    if [[ -n "${SHRINK_PARTITION:-}" ]]; then
        disk_plan_shrink
    fi

    if [[ -z "${ROOT_PARTITION:-}" ]]; then
        # Find free space for the new partition
        local free_start="" free_end=""

        if [[ "${DRY_RUN:-0}" == "1" ]]; then
            free_start="50%"
            free_end="100%"
        elif [[ -n "${SHRINK_PARTITION:-}" ]]; then
            # After shrink, free space starts at partition start + new size
            local shrink_part_num
            shrink_part_num=$(echo "${SHRINK_PARTITION}" | sed 's/.*[^0-9]\([0-9]*\)$/\1/')
            local part_line
            part_line=$(parted -s "${disk}" unit MiB print 2>/dev/null \
                | grep "^ *${shrink_part_num} " | head -1) || true
            local part_start_mib orig_end_mib
            part_start_mib=$(echo "${part_line}" | awk '{gsub(/MiB/,""); print int($2)}')
            orig_end_mib=$(echo "${part_line}" | awk '{gsub(/MiB/,""); print int($3)}')
            free_start="$(( part_start_mib + SHRINK_NEW_SIZE_MIB ))MiB"
            free_end="${orig_end_mib}MiB"
        else
            # Find largest existing free region
            local free_info
            free_info=$(parted -s "${disk}" unit MiB print free 2>/dev/null \
                | awk '/[Ff]ree [Ss]pace/ {gsub(/MiB/,""); s=int($3); if(s>m){m=s; a=$1; b=$2}} END{print a+0, b+0}')
            free_start="${free_info%% *}MiB"
            free_end="${free_info##* }MiB"
        fi

        if [[ -z "${free_start}" || "${free_start}" == "0MiB" ]]; then
            die "No free space found on ${disk} for Chimera partition"
        fi

        disk_plan_add "Create root partition in free space (${free_start} — ${free_end})" \
            parted -s "${disk}" mkpart "Linux filesystem" ext4 "${free_start}" "${free_end}"

        # Determine new partition's device name
        local part_prefix="${disk}"
        [[ "${disk}" =~ [0-9]$ ]] && part_prefix="${disk}p"
        local next_part_num
        next_part_num=$(( $(parted -s "${disk}" print 2>/dev/null | grep -c '^ *[0-9]') + 1 )) || true
        ROOT_PARTITION="${part_prefix}${next_part_num}"
    fi

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

    export ROOT_PARTITION LUKS_PARTITION
    einfo "Dual-boot plan generated"
}

# --- Shrink helpers ---

# disk_get_free_space_mib — Calculate free space on a disk in MiB
disk_get_free_space_mib() {
    local disk="$1"

    if [[ "${DRY_RUN:-0}" == "1" ]]; then
        echo "${_DRY_RUN_FREE_SPACE_MIB:-0}"
        return 0
    fi

    # Use parted to find free space
    local free_mib=0
    local line
    while IFS= read -r line; do
        # parted print free outputs lines like: "10.5GB  20.0GB  9500MB  Free Space"
        if echo "${line}" | grep -qi 'free space'; then
            local size_str
            size_str=$(echo "${line}" | awk '{print $(NF-1)}') || true
            local size_val
            size_val=$(echo "${size_str}" | sed 's/[^0-9.]//g') || true
            if [[ -n "${size_val}" ]]; then
                # Convert to MiB based on unit
                if echo "${size_str}" | grep -qi 'GB'; then
                    free_mib=$(( free_mib + ${size_val%%.*} * 1024 ))
                elif echo "${size_str}" | grep -qi 'MB'; then
                    free_mib=$(( free_mib + ${size_val%%.*} ))
                fi
            fi
        fi
    done < <(parted -s "${disk}" unit MiB print free 2>/dev/null || true)

    echo "${free_mib}"
}

# disk_get_partition_size_mib — Get partition size in MiB
disk_get_partition_size_mib() {
    local part="$1"

    if [[ "${DRY_RUN:-0}" == "1" ]]; then
        echo "${_DRY_RUN_PART_SIZE_MIB:-0}"
        return 0
    fi

    local bytes
    bytes=$(lsblk -bno SIZE "${part}" 2>/dev/null | head -1) || bytes=0
    echo $(( bytes / 1024 / 1024 ))
}

# disk_get_partition_used_mib — Get used space on partition in MiB
disk_get_partition_used_mib() {
    local part="$1" fstype="$2"

    if [[ "${DRY_RUN:-0}" == "1" ]]; then
        echo "${_DRY_RUN_PART_USED_MIB:-0}"
        return 0
    fi

    case "${fstype}" in
        ntfs)
            local info
            info=$(ntfsresize --info --force --no-action "${part}" 2>/dev/null) || { echo 0; return 0; }
            local bytes
            bytes=$(echo "${info}" | sed -n 's/.*resize at \([0-9]*\) bytes.*/\1/p' | head -1) || true
            if [[ -n "${bytes}" ]]; then
                echo $(( bytes / 1024 / 1024 ))
            else
                echo 0
            fi
            ;;
        ext4)
            local dump
            dump=$(dumpe2fs -h "${part}" 2>/dev/null) || { echo 0; return 0; }
            local block_count free_blocks block_size
            block_count=$(echo "${dump}" | sed -n 's/^Block count:[[:space:]]*//p' | head -1) || true
            free_blocks=$(echo "${dump}" | sed -n 's/^Free blocks:[[:space:]]*//p' | head -1) || true
            block_size=$(echo "${dump}" | sed -n 's/^Block size:[[:space:]]*//p' | head -1) || true
            if [[ -n "${block_count}" && -n "${free_blocks}" && -n "${block_size}" ]]; then
                echo $(( (block_count - free_blocks) * block_size / 1024 / 1024 ))
            else
                echo 0
            fi
            ;;
        btrfs)
            local tmpdir
            tmpdir=$(mktemp -d) || { echo 0; return 0; }
            if mount -o ro "${part}" "${tmpdir}" 2>/dev/null; then
                local used_bytes
                used_bytes=$(btrfs filesystem usage -b "${tmpdir}" 2>/dev/null \
                    | sed -n 's/^[[:space:]]*Used:[[:space:]]*//p' | head -1) || true
                umount "${tmpdir}" 2>/dev/null || true
                rmdir "${tmpdir}" 2>/dev/null || true
                if [[ -n "${used_bytes}" ]]; then
                    echo $(( used_bytes / 1024 / 1024 ))
                else
                    echo 0
                fi
            else
                rmdir "${tmpdir}" 2>/dev/null || true
                echo 0
            fi
            ;;
        *)
            echo 0
            ;;
    esac
}

# disk_can_shrink_fstype — Check if filesystem type can be shrunk
disk_can_shrink_fstype() {
    local fstype="$1"
    case "${fstype}" in
        ntfs|ext4|btrfs) return 0 ;;
        *) return 1 ;;
    esac
}

# disk_plan_shrink — Add shrink actions to DISK_ACTIONS[]
# Uses parted resizepart (Chimera uses parted, not sfdisk)
disk_plan_shrink() {
    local part="${SHRINK_PARTITION}"
    local fstype="${SHRINK_PARTITION_FSTYPE}"
    local new_size="${SHRINK_NEW_SIZE_MIB}"
    local disk="${TARGET_DISK}"

    # Determine partition number from device path
    local part_num
    part_num=$(echo "${part}" | sed 's/.*[^0-9]\([0-9]*\)$/\1/') || true

    if [[ -z "${part_num}" ]]; then
        eerror "Cannot determine partition number from ${part}"
        return 1
    fi

    einfo "Planning shrink: ${part} (${fstype}) → ${new_size} MiB"

    case "${fstype}" in
        ntfs)
            disk_plan_add "Shrink NTFS filesystem on ${part}" \
                ntfsresize --force --size "${new_size}M" "${part}"
            ;;
        ext4)
            disk_plan_add "Check ext4 filesystem on ${part}" \
                e2fsck -f -y "${part}"
            disk_plan_add "Shrink ext4 filesystem on ${part}" \
                resize2fs "${part}" "${new_size}M"
            ;;
        btrfs)
            disk_plan_add "Shrink btrfs filesystem on ${part}" \
                bash -c "mount ${part} /mnt/chimera-shrink-tmp && btrfs filesystem resize ${new_size}M /mnt/chimera-shrink-tmp && umount /mnt/chimera-shrink-tmp"
            ;;
    esac

    # Resize partition table entry using parted
    # parted resizepart expects END position, not size — calculate from partition start
    local part_start_mib=""
    if [[ "${DRY_RUN:-0}" == "1" ]]; then
        part_start_mib="${_DRY_RUN_PART_START_MIB:-1}"
    else
        part_start_mib=$(parted -s "${disk}" unit MiB print 2>/dev/null \
            | awk "/^ *${part_num} /{gsub(/MiB/,\"\"); print int(\$2)}")
    fi
    : "${part_start_mib:=0}"
    local part_end_mib=$(( part_start_mib + new_size ))

    disk_plan_add "Resize partition ${part_num} on ${disk}" \
        parted -s "${disk}" resizepart "${part_num}" "${part_end_mib}MiB"

    # Re-read partition table
    disk_plan_add "Re-read partition table on ${disk}" \
        partprobe "${disk}"
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

    # Cleanup stale mounts/swap before partitioning
    cleanup_target_disk

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

    # Unmount in reverse order (anchored match to avoid partial path collisions)
    local -a mounts
    readarray -t mounts < <(awk -v mp="${MOUNTPOINT}" '$3 == mp || $3 ~ "^"mp"/" {print $3}' /proc/mounts | sort -r)

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
