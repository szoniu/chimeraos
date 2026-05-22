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

    # Ensure ESP is mounted (chimera-chroot cleanup or resume may have lost it)
    local efi_dir="/boot/efi"
    if [[ -n "${ESP_PARTITION:-}" ]] && ! mountpoint -q "${MOUNTPOINT}${efi_dir}" 2>/dev/null; then
        einfo "Re-mounting ESP at ${efi_dir}..."
        mkdir -p "${MOUNTPOINT}${efi_dir}"
        try "Mounting ESP" mount "${ESP_PARTITION}" "${MOUNTPOINT}${efi_dir}"
    fi

    # UMPC portrait-panel quirk: fbcon for early console + panel_orientation
    # for KMS-aware compositors (KWin, Mutter). Without this the first boot
    # (GRUB -> console -> SDDM/GDM -> Plasma/GNOME) shows the image rotated
    # because the panel is mounted physically rotated relative to the casing.
    local default_params="quiet"
    if [[ "${UMPC_DETECTED:-0}" == "1" ]] && [[ -n "${UMPC_PANEL_ORIENTATION:-}" ]]; then
        default_params="${default_params} fbcon=rotate:${UMPC_FBCON_ROTATE} video=${UMPC_VIDEO_CONNECTOR}:panel_orientation=${UMPC_PANEL_ORIENTATION}"
        einfo "UMPC panel rotation applied to GRUB_CMDLINE_LINUX_DEFAULT"
    fi

    # Configure /etc/default/grub BEFORE grub-install (LUKS requires CRYPTODISK=y at install time)
    chroot_exec "mkdir -p /etc/default"
    chroot_exec "cat > /etc/default/grub << 'GRUBEOF'
GRUB_DEFAULT=0
GRUB_TIMEOUT=5
GRUB_TIMEOUT_STYLE=menu
GRUB_DISTRIBUTOR=\"Chimera\"
GRUB_CMDLINE_LINUX_DEFAULT=\"${default_params}\"
GRUBEOF"

    if [[ "${LUKS_ENABLED:-no}" == "yes" ]]; then
        chroot_exec "cat >> /etc/default/grub << 'GRUBEOF'

# LUKS encryption support
GRUB_CMDLINE_LINUX=\"root=/dev/mapper/cryptroot\"
GRUB_ENABLE_CRYPTODISK=y
GRUBEOF"
    fi

    if [[ "${PARTITION_SCHEME:-}" == "dual-boot" ]]; then
        apk_install_if_available os-prober
        chroot_exec "echo 'GRUB_DISABLE_OS_PROBER=false' >> /etc/default/grub" || true
    fi

    # Install GRUB to ESP with unique bootloader-id (avoid overwriting other OS entries)
    try "Installing GRUB to ${efi_dir}" \
        chroot_exec "grub-install --efi-directory=${efi_dir} --bootloader-id=chimera"

    # Regenerate initramfs with LUKS support if needed (crypttab written in fstab phase)
    if [[ "${LUKS_ENABLED:-no}" == "yes" ]]; then
        try "Regenerating initramfs with LUKS support" \
            chroot_exec "update-initramfs -c -k all"
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

    # Ensure ESP is mounted at /boot (systemd-boot uses /boot, not /boot/efi)
    if [[ -n "${ESP_PARTITION:-}" ]] && ! mountpoint -q "${MOUNTPOINT}/boot" 2>/dev/null; then
        einfo "Re-mounting ESP at /boot..."
        mkdir -p "${MOUNTPOINT}/boot"
        try "Mounting ESP" mount "${ESP_PARTITION}" "${MOUNTPOINT}/boot"
    fi

    # Install bootloader
    try "Installing systemd-boot" \
        chroot_exec "bootctl install"

    # UMPC portrait-panel quirk: fbcon for early console + panel_orientation
    # for KMS-aware compositors. Drop a cmdline fragment so gen-systemd-boot
    # picks it up when it generates the entry options.
    if [[ "${UMPC_DETECTED:-0}" == "1" ]] && [[ -n "${UMPC_PANEL_ORIENTATION:-}" ]]; then
        local umpc_cmdline="fbcon=rotate:${UMPC_FBCON_ROTATE} video=${UMPC_VIDEO_CONNECTOR}:panel_orientation=${UMPC_PANEL_ORIENTATION}"
        chroot_exec "mkdir -p /etc/cmdline.d"
        chroot_exec "printf '%s\n' '${umpc_cmdline}' > /etc/cmdline.d/10-umpc-rotation.conf"
        einfo "UMPC panel rotation written to /etc/cmdline.d/10-umpc-rotation.conf"
    fi

    # Generate boot entries
    try "Generating boot entries" \
        chroot_exec "gen-systemd-boot"

    # Belt-and-suspenders: ensure the rotation params are present in the
    # generated entry options (in case gen-systemd-boot ignores /etc/cmdline.d).
    if [[ "${UMPC_DETECTED:-0}" == "1" ]] && [[ -n "${UMPC_PANEL_ORIENTATION:-}" ]]; then
        local umpc_params="fbcon=rotate:${UMPC_FBCON_ROTATE} video=${UMPC_VIDEO_CONNECTOR}:panel_orientation=${UMPC_PANEL_ORIENTATION}"
        chroot_exec "for f in /boot/loader/entries/*.conf; do [ -f \"\$f\" ] || continue; grep -q 'panel_orientation=' \"\$f\" && continue; if grep -q '^options ' \"\$f\"; then sed -i \"s|^options .*|& ${umpc_params}|\" \"\$f\"; else printf 'options %s\n' '${umpc_params}' >> \"\$f\"; fi; done" || true
        einfo "UMPC panel rotation applied to systemd-boot entry options"
    fi

    # LUKS support: regenerate initramfs with crypttab, regenerate boot entries
    if [[ "${LUKS_ENABLED:-no}" == "yes" ]]; then
        try "Regenerating initramfs with LUKS support" \
            chroot_exec "update-initramfs -c -k all"
        try "Regenerating boot entries with LUKS" \
            chroot_exec "gen-systemd-boot"
    fi

    einfo "systemd-boot installed"
}
