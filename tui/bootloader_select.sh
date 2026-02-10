#!/usr/bin/env bash
# tui/bootloader_select.sh — GRUB vs systemd-boot selection
source "${LIB_DIR}/protection.sh"

screen_bootloader_select() {
    local current="${BOOTLOADER_TYPE:-grub}"
    local on_grub="off" on_sdboot="off"
    case "${current}" in
        grub)         on_grub="on" ;;
        systemd-boot) on_sdboot="on" ;;
    esac

    local choice
    choice=$(dialog_radiolist "Bootloader" \
        "grub"         "GRUB — full-featured, dual-boot support" "${on_grub}" \
        "systemd-boot" "systemd-boot — lightweight, EFI only" "${on_sdboot}") \
        || return "${TUI_BACK}"

    if [[ -z "${choice}" ]]; then
        return "${TUI_BACK}"
    fi

    BOOTLOADER_TYPE="${choice}"
    export BOOTLOADER_TYPE

    # Warn about systemd-boot limitations with LUKS
    if [[ "${BOOTLOADER_TYPE}" == "systemd-boot" && "${LUKS_ENABLED:-no}" == "yes" ]]; then
        dialog_msgbox "Note" \
            "systemd-boot with LUKS may require manual kernel parameter configuration.\n\n\
GRUB has better LUKS support out of the box.\n\n\
You can switch to GRUB by going back."
    fi

    einfo "Bootloader: ${BOOTLOADER_TYPE}"
    return "${TUI_NEXT}"
}
