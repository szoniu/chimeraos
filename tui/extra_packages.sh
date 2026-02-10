#!/usr/bin/env bash
# tui/extra_packages.sh — Additional packages
source "${LIB_DIR}/protection.sh"

screen_extra_packages() {
    local packages
    packages=$(dialog_inputbox "Extra Packages" \
        "Enter additional apk packages to install (space-separated):\n\n\
Examples: vim git htop tmux neofetch curl wget\n\n\
Leave blank to skip." \
        "${EXTRA_PACKAGES:-}") || return "${TUI_BACK}"

    EXTRA_PACKAGES="${packages}"
    export EXTRA_PACKAGES

    if [[ -n "${EXTRA_PACKAGES}" ]]; then
        einfo "Extra packages: ${EXTRA_PACKAGES}"
    fi

    return "${TUI_NEXT}"
}
