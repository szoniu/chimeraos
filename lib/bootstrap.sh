#!/usr/bin/env bash
# bootstrap.sh — chimera-bootstrap and apk operations
source "${LIB_DIR}/protection.sh"

# bootstrap_install — Install base Chimera Linux system
bootstrap_install() {
    einfo "Installing Chimera Linux base system..."

    if [[ "${DRY_RUN}" == "1" ]]; then
        einfo "[DRY-RUN] Would run chimera-bootstrap ${MOUNTPOINT}"
        return 0
    fi

    # chimera-bootstrap requires an empty directory
    # If retrying after a failed attempt, clean up first
    if [[ -d "${MOUNTPOINT}" ]] && [[ -n "$(ls -A "${MOUNTPOINT}" 2>/dev/null)" ]]; then
        ewarn "Target directory ${MOUNTPOINT} is not empty — cleaning up"

        # Unmount any nested mounts (ESP, btrfs subvols) before cleaning
        local -a nested_mounts
        readarray -t nested_mounts < <(awk -v mp="${MOUNTPOINT}" '$2 ~ "^"mp"/" {print $2}' /proc/mounts 2>/dev/null | sort -r)
        local m
        for m in "${nested_mounts[@]}"; do
            [[ -z "${m}" ]] && continue
            umount -l "${m}" 2>/dev/null || true
        done

        # Remove contents but keep the mount point itself
        find "${MOUNTPOINT}" -mindepth 1 -maxdepth 1 -exec rm -rf {} + 2>/dev/null || true
    fi

    # chimera-bootstrap installs base-full by default
    # -l flag = local (from live ISO, offline)
    # without -l = network install (downloads latest)
    if has_network; then
        try "Bootstrap Chimera Linux (network)" \
            chimera-bootstrap "${MOUNTPOINT}"
    else
        try "Bootstrap Chimera Linux (local/offline)" \
            chimera-bootstrap -l "${MOUNTPOINT}"
    fi

    einfo "Base system installed to ${MOUNTPOINT}"
}

# apk_update — Update package database and upgrade
apk_update() {
    einfo "Updating package database..."

    try "Updating apk index" \
        chroot_exec "apk update"

    try "Upgrading packages" \
        chroot_exec "apk upgrade --available"

    einfo "Packages up to date"
}

# apk_install — Install packages via apk inside chroot
# Usage: apk_install "description" pkg1 pkg2 ...
apk_install() {
    local desc="$1"
    shift
    local -a pkgs=("$@")

    if [[ ${#pkgs[@]} -eq 0 ]]; then
        return 0
    fi

    try "${desc}" \
        chroot_exec "apk add ${pkgs[*]}"
}

# apk_install_if_available — Install package only if it exists in repo
apk_install_if_available() {
    local pkg="$1"

    if chroot_exec "apk search -e ${pkg}" >> "${LOG_FILE}" 2>&1; then
        try "Installing ${pkg}" chroot_exec "apk add ${pkg}"
    else
        ewarn "Package ${pkg} not found in repositories, skipping"
    fi
}

# enable_user_repo — Enable the user repository
enable_user_repo() {
    einfo "Enabling user repository..."
    try "Enabling chimera-repo-user" \
        chroot_exec "apk add chimera-repo-user"
    try "Updating repos" \
        chroot_exec "apk update"
}

# --- Peripheral install functions ---

# install_fingerprint_tools — Install fingerprint reader support
install_fingerprint_tools() {
    if [[ "${ENABLE_FINGERPRINT:-no}" != "yes" ]]; then
        return 0
    fi
    einfo "Installing fingerprint reader support..."
    apk_install "Installing fprintd" fprintd libfprint
    einfo "Fingerprint support installed"
}

# install_thunderbolt_tools — Install Thunderbolt device manager
install_thunderbolt_tools() {
    if [[ "${ENABLE_THUNDERBOLT:-no}" != "yes" ]]; then
        return 0
    fi
    einfo "Installing Thunderbolt support..."
    apk_install "Installing bolt" bolt
    einfo "Thunderbolt support installed"
}

# install_sensor_tools — Install IIO sensor proxy
install_sensor_tools() {
    if [[ "${ENABLE_SENSORS:-no}" != "yes" ]]; then
        return 0
    fi
    einfo "Installing IIO sensor support..."
    apk_install "Installing iio-sensor-proxy" iio-sensor-proxy
    einfo "IIO sensor support installed"
}

# install_wwan_tools — Install WWAN/LTE modem support
install_wwan_tools() {
    if [[ "${ENABLE_WWAN:-no}" != "yes" ]]; then
        return 0
    fi
    einfo "Installing WWAN/LTE support..."
    apk_install "Installing ModemManager" modemmanager libmbim libqmi
    einfo "WWAN/LTE support installed"
}
