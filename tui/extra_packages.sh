#!/usr/bin/env bash
# tui/extra_packages.sh — Checklist with conditional hardware items + free-form input
source "${LIB_DIR}/protection.sh"

_extra_pkg_state() {
    local pkg="$1" default="$2"
    # Check EXTRA_PACKAGES and ENABLE_* flags from preset
    if [[ -n "${EXTRA_PACKAGES:-}" ]] && echo " ${EXTRA_PACKAGES} " | grep -qw "${pkg}"; then
        echo "on"
        return
    fi
    case "${pkg}" in
        hyprland-ecosystem) [[ "${ENABLE_HYPRLAND:-no}" == "yes" ]] && echo "on" && return ;;
        fprintd)           [[ "${ENABLE_FINGERPRINT:-no}" == "yes" ]] && echo "on" && return ;;
        bolt)              [[ "${ENABLE_THUNDERBOLT:-no}" == "yes" ]] && echo "on" && return ;;
        iio-sensor-proxy)  [[ "${ENABLE_SENSORS:-no}" == "yes" ]] && echo "on" && return ;;
        ModemManager)      [[ "${ENABLE_WWAN:-no}" == "yes" ]] && echo "on" && return ;;
    esac
    echo "${default}"
}

screen_extra_packages() {
    local -a items=()

    # --- Always-visible items ---
    items+=("fastfetch"   "System info tool"          "$(_extra_pkg_state fastfetch off)")
    items+=("btop"        "Resource monitor"           "$(_extra_pkg_state btop off)")
    items+=("htop"        "Process viewer"             "$(_extra_pkg_state htop off)")
    items+=("kitty"       "GPU-accelerated terminal"   "$(_extra_pkg_state kitty off)")
    items+=("vim"         "Vi improved text editor"    "$(_extra_pkg_state vim off)")
    items+=("git"         "Version control system"     "$(_extra_pkg_state git off)")
    items+=("tmux"        "Terminal multiplexer"       "$(_extra_pkg_state tmux off)")
    items+=("v4l-utils"   "Video4Linux utilities"      "$(_extra_pkg_state v4l-utils off)")

    # --- Hyprland ecosystem ---
    items+=("hyprland-ecosystem" "Hyprland + ekosystem (waybar, wofi, mako...)" "$(_extra_pkg_state hyprland-ecosystem off)")

    # --- Conditional items (hardware-detected) ---
    if [[ "${FINGERPRINT_DETECTED:-0}" == "1" ]]; then
        items+=("fprintd"  "Fingerprint authentication" "$(_extra_pkg_state fprintd off)")
    fi
    if [[ "${THUNDERBOLT_DETECTED:-0}" == "1" ]]; then
        items+=("bolt"     "Thunderbolt device manager"  "$(_extra_pkg_state bolt off)")
    fi
    if [[ "${SENSORS_DETECTED:-0}" == "1" ]]; then
        items+=("iio-sensor-proxy" "IIO sensor support (2-in-1)" "$(_extra_pkg_state iio-sensor-proxy off)")
    fi
    if [[ "${WWAN_DETECTED:-0}" == "1" ]]; then
        items+=("ModemManager" "WWAN/LTE modem support"  "$(_extra_pkg_state ModemManager off)")
    fi

    local selected
    selected=$(dialog_checklist "Extra Packages" "${items[@]}") \
        || return "${TUI_BACK}"

    # Process selected items — set ENABLE_* flags
    ENABLE_HYPRLAND="no"
    ENABLE_FINGERPRINT="no"
    ENABLE_THUNDERBOLT="no"
    ENABLE_SENSORS="no"
    ENABLE_WWAN="no"

    local pkg
    for pkg in ${selected}; do
        case "${pkg}" in
            hyprland-ecosystem) ENABLE_HYPRLAND="yes" ;;
            fprintd)           ENABLE_FINGERPRINT="yes" ;;
            bolt)              ENABLE_THUNDERBOLT="yes" ;;
            iio-sensor-proxy)  ENABLE_SENSORS="yes" ;;
            ModemManager)      ENABLE_WWAN="yes" ;;
        esac
    done
    export ENABLE_HYPRLAND ENABLE_FINGERPRINT ENABLE_THUNDERBOLT ENABLE_SENSORS ENABLE_WWAN

    # Build EXTRA_PACKAGES from non-special items
    local -a extra_pkgs=()
    for pkg in ${selected}; do
        case "${pkg}" in
            hyprland-ecosystem|fprintd|bolt|iio-sensor-proxy|ModemManager) ;;
            *) extra_pkgs+=("${pkg}") ;;
        esac
    done

    # Collect any preset EXTRA_PACKAGES not in the checklist above
    local _known_pkgs="fastfetch btop htop kitty vim git tmux v4l-utils hyprland-ecosystem fprintd bolt iio-sensor-proxy ModemManager"
    local _preset_extra=""
    local _ep
    for _ep in ${EXTRA_PACKAGES:-}; do
        echo " ${_known_pkgs} " | grep -qw "${_ep}" || _preset_extra+="${_ep} "
    done

    # Free-form input for additional packages
    local more_pkgs
    more_pkgs=$(dialog_inputbox "Additional Packages" \
        "Enter any additional apk packages (space-separated):\n\nLeave blank to skip." \
        "${_preset_extra}") || true

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
