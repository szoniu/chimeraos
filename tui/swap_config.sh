#!/usr/bin/env bash
# tui/swap_config.sh — Swap configuration: zram / partition / none
source "${LIB_DIR}/protection.sh"

screen_swap_config() {
    # Pre-select "partition" if SWAP_PARTITION already set (e.g. manual mode)
    local current="${SWAP_TYPE:-zram}"
    if [[ -n "${SWAP_PARTITION:-}" && "${current}" == "zram" ]]; then
        current="partition"
    fi
    local on_zram="off" on_partition="off" on_none="off"
    case "${current}" in
        zram)      on_zram="on" ;;
        partition)  on_partition="on" ;;
        none)      on_none="on" ;;
    esac

    local choice
    choice=$(dialog_radiolist "Swap Configuration" \
        "zram"      "zram — compressed RAM swap (recommended)" "${on_zram}" \
        "partition"  "Dedicated swap partition" "${on_partition}" \
        "none"      "No swap" "${on_none}") \
        || return "${TUI_BACK}"

    if [[ -z "${choice}" ]]; then
        return "${TUI_BACK}"
    fi

    SWAP_TYPE="${choice}"
    export SWAP_TYPE

    if [[ "${SWAP_TYPE}" == "partition" ]]; then
        local size
        size=$(dialog_inputbox "Swap Size" \
            "Enter swap partition size in MiB:" \
            "${SWAP_SIZE_MIB:-${SWAP_DEFAULT_SIZE_MIB}}") || return "${TUI_BACK}"

        SWAP_SIZE_MIB="${size}"
        export SWAP_SIZE_MIB
    fi

    einfo "Swap: ${SWAP_TYPE}"
    return "${TUI_NEXT}"
}
