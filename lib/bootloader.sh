#!/usr/bin/env bash
# bootloader.sh — GRUB or systemd-boot installation
source "${LIB_DIR}/protection.sh"

# bootloader_install — Install and configure bootloader
bootloader_install() {
    local boot_type="${BOOTLOADER_TYPE:-grub}"

    case "${boot_type}" in
        grub)
            _install_grub
            ;;
        systemd-boot)
            _install_systemd_boot
            ;;
    esac
}

# _install_grub — Install GRUB for x86_64 EFI
_install_grub() {
    einfo "Installing GRUB bootloader..."

    apk_install "Installing GRUB" grub-x86_64-efi

    # Install GRUB to ESP
    local efi_dir="/boot/efi"
    try "Installing GRUB to ${efi_dir}" \
        chroot_exec "grub-install --efi-directory=${efi_dir}"

    # Configure GRUB for LUKS if needed
    if [[ "${LUKS_ENABLED:-no}" == "yes" ]]; then
        local luks_uuid
        luks_uuid=$(get_uuid "${LUKS_PARTITION}")
        chroot_exec "cat >> /etc/default/grub << 'GRUBEOF'

# LUKS encryption support
GRUB_CMDLINE_LINUX=\"cryptdevice=UUID=${luks_uuid}:cryptroot root=/dev/mapper/cryptroot\"
GRUB_ENABLE_CRYPTODISK=y
GRUBEOF"
    fi

    # Enable os-prober for dual-boot
    if [[ "${WINDOWS_DETECTED:-0}" == "1" ]]; then
        apk_install_if_available "os-prober"
        chroot_exec "echo 'GRUB_DISABLE_OS_PROBER=false' >> /etc/default/grub" || true
    fi

    # Generate GRUB config
    try "Generating GRUB configuration" \
        chroot_exec "update-grub"

    einfo "GRUB installed"
}

# _install_systemd_boot — Install systemd-boot
_install_systemd_boot() {
    einfo "Installing systemd-boot bootloader..."

    apk_install "Installing systemd-boot" systemd-boot

    # Install bootloader
    try "Installing systemd-boot" \
        chroot_exec "bootctl install"

    # Generate boot entries
    try "Generating boot entries" \
        chroot_exec "gen-systemd-boot"

    # LUKS support via kernel cmdline
    if [[ "${LUKS_ENABLED:-no}" == "yes" ]]; then
        local luks_uuid
        luks_uuid=$(get_uuid "${LUKS_PARTITION}")
        ewarn "LUKS with systemd-boot: you may need to add kernel parameters manually"
        ewarn "cryptdevice=UUID=${luks_uuid}:cryptroot root=/dev/mapper/cryptroot"
    fi

    einfo "systemd-boot installed"
}
