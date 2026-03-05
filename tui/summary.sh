#!/usr/bin/env bash
# tui/summary.sh — Full summary + confirmation + countdown for Chimera Linux
source "${LIB_DIR}/protection.sh"

screen_summary() {
    # Validate configuration before showing summary
    local validation_errors
    validation_errors=$(validate_config) || {
        dialog_msgbox "Configuration Errors" \
            "Fix these issues before proceeding:\n\n${validation_errors}"
        return "${TUI_BACK}"
    }

    local summary=""
    summary+="=== Installation Summary ===\n\n"
    summary+="Target disk:  ${TARGET_DISK:-?}\n"
    summary+="Partitioning: ${PARTITION_SCHEME:-auto}\n"
    summary+="Filesystem:   ${FILESYSTEM:-ext4}\n"
    [[ "${FILESYSTEM}" == "btrfs" ]] && summary+="Subvolumes:   ${BTRFS_SUBVOLUMES:-default}\n"
    [[ "${LUKS_ENABLED:-no}" == "yes" ]] && summary+="Encryption:   LUKS enabled\n"
    summary+="Swap:         ${SWAP_TYPE:-zram}"
    [[ -n "${SWAP_SIZE_MIB:-}" ]] && summary+=" (${SWAP_SIZE_MIB} MiB)"
    summary+="\n"
    summary+="\n"
    summary+="Hostname:     ${HOSTNAME:-chimera}\n"
    summary+="Timezone:     ${TIMEZONE:-UTC}\n"
    summary+="Keymap:       ${KEYMAP:-us}\n"
    summary+="\n"
    summary+="Bootloader:   ${BOOTLOADER_TYPE:-grub}\n"
    summary+="Kernel:       linux-${KERNEL_TYPE:-lts}\n"
    if [[ "${HYBRID_GPU:-no}" == "yes" ]]; then
        summary+="GPU:          ${IGPU_VENDOR:-?} + ${DGPU_DEVICE_NAME:-?} (hybrid, open-source)\n"
    else
        summary+="GPU:          ${GPU_VENDOR:-unknown} (${GPU_DRIVER:-mesa}, open-source)\n"
    fi
    [[ "${ASUS_ROG_DETECTED:-0}" == "1" ]] && summary+="ASUS ROG:     detected\n"
    [[ "${ENABLE_ASUSCTL:-no}" == "yes" ]] && summary+="ROG tools:    asusctl enabled\n"
    [[ "${ENABLE_FINGERPRINT:-no}" == "yes" ]] && summary+="Fingerprint:  fprintd enabled\n"
    [[ "${ENABLE_THUNDERBOLT:-no}" == "yes" ]] && summary+="Thunderbolt:  bolt enabled\n"
    [[ "${ENABLE_SENSORS:-no}" == "yes" ]] && summary+="IIO sensors:  iio-sensor-proxy enabled\n"
    [[ "${ENABLE_WWAN:-no}" == "yes" ]] && summary+="WWAN LTE:     ModemManager enabled\n"
    summary+="\n"
    summary+="Username:     ${USERNAME:-user}\n"
    summary+="SSH:          ${ENABLE_SSH:-no}\n"
    summary+="Desktop:      KDE Plasma + SDDM + PipeWire\n"
    [[ -n "${DESKTOP_EXTRAS:-}" ]] && summary+="KDE apps:     ${DESKTOP_EXTRAS}\n"
    [[ "${ENABLE_FLATPAK:-no}" == "yes" ]] && summary+="Flatpak:      yes\n"
    [[ "${ENABLE_PRINTING:-no}" == "yes" ]] && summary+="Printing:     yes\n"
    [[ "${ENABLE_BLUETOOTH:-no}" == "yes" ]] && summary+="Bluetooth:    yes\n"
    [[ -n "${EXTRA_PACKAGES:-}" ]] && summary+="Extra pkgs:   ${EXTRA_PACKAGES}\n"

    if [[ -n "${SHRINK_PARTITION:-}" ]]; then
        summary+="Shrink:       ${SHRINK_PARTITION} (${SHRINK_PARTITION_FSTYPE:-?}) -> ${SHRINK_NEW_SIZE_MIB:-?} MiB\n"
    fi

    if [[ "${ESP_REUSE:-no}" == "yes" ]]; then
        summary+="\nDual-boot:    YES (reusing ESP ${ESP_PARTITION:-?})\n"
    fi

    # Show detected operating systems
    if [[ ${#DETECTED_OSES[@]} -gt 0 ]]; then
        summary+="\nDetected OSes:\n"
        local p
        for p in "${!DETECTED_OSES[@]}"; do
            summary+="  ${p}: ${DETECTED_OSES[${p}]}\n"
        done
    fi

    dialog_msgbox "Installation Summary" "${summary}" || return "${TUI_BACK}"

    # Destructive warning
    if [[ "${PARTITION_SCHEME:-auto}" == "auto" ]]; then
        local warning=""
        warning+="!!! WARNING: DATA DESTRUCTION !!!\n\n"
        warning+="The following disk will be COMPLETELY ERASED:\n\n"
        warning+="  ${TARGET_DISK:-?}\n\n"
        warning+="ALL existing data on this disk will be permanently lost.\n"
        warning+="This action CANNOT be undone.\n\n"
        warning+="Type 'YES' in the next dialog to confirm."

        dialog_msgbox "WARNING" "${warning}" || return "${TUI_BACK}"

        local confirmation
        confirmation=$(dialog_inputbox "Confirm Installation" \
            "Type YES (all caps) to confirm and begin installation:" \
            "") || return "${TUI_BACK}"

        if [[ "${confirmation}" != "YES" ]]; then
            dialog_msgbox "Cancelled" "Installation cancelled. You typed: '${confirmation}'"
            return "${TUI_BACK}"
        fi
    elif [[ "${PARTITION_SCHEME:-auto}" == "dual-boot" ]]; then
        local warning=""
        warning+="!!! DUAL-BOOT INSTALLATION !!!\n\n"

        # What WILL be formatted
        warning+="WILL BE FORMATTED (data destroyed):\n"
        if [[ -n "${ROOT_PARTITION:-}" ]]; then
            warning+="  ${ROOT_PARTITION} -> ${FILESYSTEM:-ext4}\n"
        else
            warning+="  (new partition will be created) -> ${FILESYSTEM:-ext4}\n"
        fi
        if [[ -n "${SHRINK_PARTITION:-}" ]]; then
            warning+="WILL BE SHRUNK (data preserved):\n"
            warning+="  ${SHRINK_PARTITION} (${SHRINK_PARTITION_FSTYPE:-?}) -> ${SHRINK_NEW_SIZE_MIB:-?} MiB\n"
        fi
        warning+="\n"

        # What will SURVIVE
        warning+="WILL BE PRESERVED:\n"
        warning+="  ${ESP_PARTITION:-?}: EFI System Partition\n"
        local p
        for p in "${!DETECTED_OSES[@]}"; do
            [[ "${p}" == "${ROOT_PARTITION:-}" ]] && continue
            warning+="  ${p}: ${DETECTED_OSES[${p}]}\n"
        done

        warning+="\nType 'YES' in the next dialog to confirm."

        dialog_msgbox "WARNING" "${warning}" || return "${TUI_BACK}"

        local confirmation
        confirmation=$(dialog_inputbox "Confirm Dual-Boot Installation" \
            "Type YES (all caps) to confirm and begin installation:" \
            "") || return "${TUI_BACK}"

        if [[ "${confirmation}" != "YES" ]]; then
            dialog_msgbox "Cancelled" "Installation cancelled. You typed: '${confirmation}'"
            return "${TUI_BACK}"
        fi
    else
        dialog_yesno "Confirm Installation" \
            "Ready to begin installation. Continue?" \
            || return "${TUI_BACK}"
    fi

    # Countdown
    einfo "Installation starting in ${COUNTDOWN_DEFAULT} seconds..."
    (
        local i
        for (( i = COUNTDOWN_DEFAULT; i > 0; i-- )); do
            echo "$(( (COUNTDOWN_DEFAULT - i) * 100 / COUNTDOWN_DEFAULT ))"
            sleep 1
        done
        echo "100"
    ) | dialog_gauge "Starting Installation" \
        "Installation will begin in ${COUNTDOWN_DEFAULT} seconds...\nPress Ctrl+C to abort."

    return "${TUI_NEXT}"
}
