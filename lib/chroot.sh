#!/usr/bin/env bash
# chroot.sh — Manual bind mounts + plain chroot (no chimera-chroot)
# chimera-chroot auto-unmounts pseudo-FS on each call, which causes
# mount state loss during multi-step installation. Use manual mounts instead.
source "${LIB_DIR}/protection.sh"

# chroot_setup — Prepare chroot environment with persistent bind mounts
chroot_setup() {
    einfo "Setting up chroot environment..."

    if [[ "${DRY_RUN}" == "1" ]]; then
        einfo "[DRY-RUN] Would set up chroot"
        return 0
    fi

    if ! mountpoint -q "${MOUNTPOINT}" 2>/dev/null; then
        ewarn "Filesystem not mounted at ${MOUNTPOINT} — skipping chroot setup"
        return 0
    fi

    # Clean up stale mounts from a previous session (crash + resume)
    chroot_teardown 2>/dev/null || true

    # Ensure mount directories exist
    mkdir -p "${MOUNTPOINT}"/{proc,sys,dev,run}

    # Bind mount pseudo-filesystems
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

    # Unmount all pseudo-FS mounts under MOUNTPOINT in reverse order
    local -a mounts
    readarray -t mounts < <(awk -v mp="${MOUNTPOINT}" '$2 ~ "^"mp"/(proc|sys|dev|run)" {print $2}' /proc/mounts 2>/dev/null | sort -r)

    local mnt
    for mnt in "${mounts[@]}"; do
        [[ -z "${mnt}" ]] && continue
        umount -l "${mnt}" 2>/dev/null || true
    done

    einfo "Chroot teardown complete"
}

# chroot_exec — Execute a command inside the chroot
chroot_exec() {
    if [[ "${DRY_RUN}" == "1" ]]; then
        einfo "[DRY-RUN] Would chroot exec: $*"
        return 0
    fi

    # Pass LIVE_OUTPUT so try() inside chroot shows output on terminal via tee
    local env_prefix=""
    [[ "${LIVE_OUTPUT:-0}" == "1" ]] && env_prefix="LIVE_OUTPUT=1 "

    chroot "${MOUNTPOINT}" /bin/sh -c "${env_prefix}$*"
}

# copy_dns_info — Copy DNS resolver config to chroot
copy_dns_info() {
    einfo "Copying DNS configuration to chroot..."

    if [[ "${DRY_RUN}" == "1" ]]; then
        einfo "[DRY-RUN] Would copy DNS info"
        return 0
    fi

    if ! mountpoint -q "${MOUNTPOINT}" 2>/dev/null; then
        ewarn "Target ${MOUNTPOINT} is not mounted — skipping DNS copy"
        return 0
    fi

    mkdir -p "${MOUNTPOINT}/etc"

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
