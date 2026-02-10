#!/usr/bin/env bash
# chroot.sh — chimera-chroot wrapper, bind mounts, cleanup
source "${LIB_DIR}/protection.sh"

# chroot_setup — Prepare chroot environment
# chimera-chroot handles bind mounts automatically, but we also support manual
chroot_setup() {
    einfo "Setting up chroot environment..."

    if [[ "${DRY_RUN}" == "1" ]]; then
        einfo "[DRY-RUN] Would set up chroot"
        return 0
    fi

    # If chimera-chroot is available, it handles pseudo-filesystems
    # For manual setup (when calling chroot directly):
    if ! command -v chimera-chroot &>/dev/null; then
        # Manual bind mounts
        if ! mountpoint -q "${MOUNTPOINT}/proc" 2>/dev/null; then
            try "Mounting /proc" mount --types proc /proc "${MOUNTPOINT}/proc"
        fi
        if ! mountpoint -q "${MOUNTPOINT}/sys" 2>/dev/null; then
            try "Mounting /sys" mount --rbind /sys "${MOUNTPOINT}/sys"
            mount --make-rslave "${MOUNTPOINT}/sys"
        fi
        if ! mountpoint -q "${MOUNTPOINT}/dev" 2>/dev/null; then
            try "Mounting /dev" mount --rbind /dev "${MOUNTPOINT}/dev"
            mount --make-rslave "${MOUNTPOINT}/dev"
        fi
        if ! mountpoint -q "${MOUNTPOINT}/run" 2>/dev/null; then
            try "Mounting /run" mount --bind /run "${MOUNTPOINT}/run"
            mount --make-slave "${MOUNTPOINT}/run"
        fi
    fi

    # Copy DNS configuration
    copy_dns_info

    einfo "Chroot environment ready"
}

# chroot_teardown — Clean up chroot bind mounts
chroot_teardown() {
    einfo "Tearing down chroot environment..."

    if [[ "${DRY_RUN}" == "1" ]]; then
        einfo "[DRY-RUN] Would tear down chroot"
        return 0
    fi

    local -a chroot_mounts=(
        "${MOUNTPOINT}/run"
        "${MOUNTPOINT}/dev/shm"
        "${MOUNTPOINT}/dev/pts"
        "${MOUNTPOINT}/dev"
        "${MOUNTPOINT}/sys"
        "${MOUNTPOINT}/proc"
    )

    local mnt
    for mnt in "${chroot_mounts[@]}"; do
        if mountpoint -q "${mnt}" 2>/dev/null; then
            umount -l "${mnt}" 2>/dev/null || true
        fi
    done

    einfo "Chroot teardown complete"
}

# chroot_exec — Execute a command inside the chroot
chroot_exec() {
    if [[ "${DRY_RUN}" == "1" ]]; then
        einfo "[DRY-RUN] Would chroot exec: $*"
        return 0
    fi

    if command -v chimera-chroot &>/dev/null; then
        # chimera-chroot auto-mounts pseudo-filesystems
        chimera-chroot "${MOUNTPOINT}" /bin/sh -c "$*"
    else
        chroot "${MOUNTPOINT}" /bin/sh -c "$*"
    fi
}

# copy_dns_info — Copy DNS resolver config to chroot
copy_dns_info() {
    einfo "Copying DNS configuration to chroot..."

    if [[ "${DRY_RUN}" == "1" ]]; then
        einfo "[DRY-RUN] Would copy DNS info"
        return 0
    fi

    if [[ -L "${MOUNTPOINT}/etc/resolv.conf" ]]; then
        rm "${MOUNTPOINT}/etc/resolv.conf"
    fi

    cp -L /etc/resolv.conf "${MOUNTPOINT}/etc/resolv.conf"
    einfo "DNS configuration copied"
}

# copy_installer_to_chroot — Copy installer for reference
copy_installer_to_chroot() {
    einfo "Copying installer to chroot..."

    if [[ "${DRY_RUN}" == "1" ]]; then
        einfo "[DRY-RUN] Would copy installer to chroot"
        return 0
    fi

    local dest="${MOUNTPOINT}${CHROOT_INSTALLER_DIR}"
    mkdir -p "${dest}"

    cp -a "${SCRIPT_DIR}/"* "${dest}/"
    cp "${CONFIG_FILE}" "${dest}/$(basename "${CONFIG_FILE}")"

    chmod +x "${dest}/install.sh" "${dest}/configure.sh"

    einfo "Installer copied to ${CHROOT_INSTALLER_DIR}"
}
