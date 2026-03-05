#!/usr/bin/env bash
# tui/extra_packages.sh — Checklist with conditional hardware items + free-form input
source "${LIB_DIR}/protection.sh"

screen_extra_packages() {
    local -a items=()

    # --- Always-visible items ---
    items+=("fastfetch"   "System info tool"          "off")
    items+=("btop"        "Resource monitor"           "off")
    items+=("htop"        "Process viewer"             "off")
    items+=("kitty"       "GPU-accelerated terminal"   "off")
    items+=("vim"         "Vi improved text editor"    "off")
    items+=("git"         "Version control system"     "off")
    items+=("tmux"        "Terminal multiplexer"       "off")
    items+=("v4l-utils"   "Video4Linux utilities"      "off")

    # --- Conditional items (hardware-detected) ---
    if [[ "${FINGERPRINT_DETECTED:-0}" == "1" ]]; then
        items+=("fprintd"  "Fingerprint authentication" "off")
    fi
    if [[ "${THUNDERBOLT_DETECTED:-0}" == "1" ]]; then
        items+=("bolt"     "Thunderbolt device manager"  "off")
    fi
    if [[ "${SENSORS_DETECTED:-0}" == "1" ]]; then
        items+=("iio-sensor-proxy" "IIO sensor support (2-in-1)" "off")
    fi
    if [[ "${WWAN_DETECTED:-0}" == "1" ]]; then
        items+=("ModemManager" "WWAN/LTE modem support"  "off")
    fi

    local selected
    selected=$(dialog_checklist "Extra Packages" "${items[@]}") \
        || return "${TUI_BACK}"

    # Process selected items — set ENABLE_* flags
    ENABLE_FINGERPRINT="no"
    ENABLE_THUNDERBOLT="no"
    ENABLE_SENSORS="no"
    ENABLE_WWAN="no"

    local pkg
    for pkg in ${selected}; do
        case "${pkg}" in
            fprintd)           ENABLE_FINGERPRINT="yes" ;;
            bolt)              ENABLE_THUNDERBOLT="yes" ;;
            iio-sensor-proxy)  ENABLE_SENSORS="yes" ;;
            ModemManager)      ENABLE_WWAN="yes" ;;
        esac
    done
    export ENABLE_FINGERPRINT ENABLE_THUNDERBOLT ENABLE_SENSORS ENABLE_WWAN

    # Build EXTRA_PACKAGES from non-special items
    local -a extra_pkgs=()
    for pkg in ${selected}; do
        case "${pkg}" in
            fprintd|bolt|iio-sensor-proxy|ModemManager) ;;
            *) extra_pkgs+=("${pkg}") ;;
        esac
    done

    # Free-form input for additional packages
    local more_pkgs
    more_pkgs=$(dialog_inputbox "Additional Packages" \
        "Enter any additional apk packages (space-separated):\n\nLeave blank to skip." \
        "") || true

    if [[ -n "${more_pkgs}" ]]; then
        local p
        for p in ${more_pkgs}; do
            extra_pkgs+=("${p}")
        done
    fi

    EXTRA_PACKAGES="${extra_pkgs[*]:-}"
    export EXTRA_PACKAGES

    if [[ -n "${EXTRA_PACKAGES}" ]]; then
        einfo "Extra packages: ${EXTRA_PACKAGES}"
    fi

    return "${TUI_NEXT}"
}
