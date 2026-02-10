#!/usr/bin/env bash
# tui/kernel_select.sh — Kernel selection: LTS or stable
source "${LIB_DIR}/protection.sh"

screen_kernel_select() {
    local current="${KERNEL_TYPE:-lts}"
    local on_lts="off" on_stable="off"
    case "${current}" in
        lts)    on_lts="on" ;;
        stable) on_stable="on" ;;
    esac

    local choice
    choice=$(dialog_radiolist "Kernel Selection" \
        "lts"    "linux-lts — Long Term Support (recommended)" "${on_lts}" \
        "stable" "linux-stable — Latest stable release" "${on_stable}") \
        || return "${TUI_BACK}"

    if [[ -z "${choice}" ]]; then
        return "${TUI_BACK}"
    fi

    KERNEL_TYPE="${choice}"
    export KERNEL_TYPE

    einfo "Kernel: linux-${KERNEL_TYPE}"
    return "${TUI_NEXT}"
}
