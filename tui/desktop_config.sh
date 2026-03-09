#!/usr/bin/env bash
# tui/desktop_config.sh — KDE Plasma + apps + extras
source "${LIB_DIR}/protection.sh"

# _app_state — Return "on" if app is in DESKTOP_EXTRAS, "off" otherwise
_app_state() {
    local app="$1" default="$2"
    if [[ -z "${DESKTOP_EXTRAS:-}" ]]; then
        echo "${default}"
    elif echo "${DESKTOP_EXTRAS}" | tr -d '"' | grep -qw "${app}"; then
        echo "on"
    else
        echo "off"
    fi
}

screen_desktop_config() {
    dialog_msgbox "Desktop Environment" \
        "KDE Plasma 6 will be installed as your desktop environment.\n\n\
Includes:\n\
  * Plasma Desktop + Wayland\n\
  * SDDM display manager\n\
  * PipeWire audio (via Turnstile)\n\
  * Konsole terminal + Dolphin file manager\n\n\
You can select additional applications on the next screen." \
        || return "${TUI_BACK}"

    # KDE application selection (preserve preset values)
    local apps
    apps=$(dialog_checklist "KDE Applications" \
        "kate"        "Kate — advanced text editor"       "$(_app_state kate on)" \
        "firefox"     "Firefox — web browser"             "$(_app_state firefox on)" \
        "gwenview"    "Gwenview — image viewer"           "$(_app_state gwenview on)" \
        "okular"      "Okular — document viewer"          "$(_app_state okular on)" \
        "ark"         "Ark — archive manager"             "$(_app_state ark on)" \
        "spectacle"   "Spectacle — screenshot tool"       "$(_app_state spectacle on)" \
        "kcalc"       "KCalc — calculator"                "$(_app_state kcalc off)" \
        "elisa"       "Elisa — music player"              "$(_app_state elisa off)" \
        "vlc"         "VLC — media player"                "$(_app_state vlc off)" \
        "libreoffice" "LibreOffice — office suite"        "$(_app_state libreoffice off)" \
        "thunderbird" "Thunderbird — email client"        "$(_app_state thunderbird off)") \
        || return "${TUI_BACK}"

    DESKTOP_EXTRAS="${apps}"
    export DESKTOP_EXTRAS

    # Optional extras (preserve preset values)
    local _flatpak_state="off" _printing_state="off" _bluetooth_state="on"
    [[ "${ENABLE_FLATPAK:-no}" == "yes" ]] && _flatpak_state="on"
    [[ "${ENABLE_PRINTING:-no}" == "yes" ]] && _printing_state="on"
    [[ "${ENABLE_BLUETOOTH:-yes}" == "no" ]] && _bluetooth_state="off"

    local extras
    extras=$(dialog_checklist "Optional Features" \
        "flatpak"    "Flatpak — universal package manager" "${_flatpak_state}" \
        "printing"   "CUPS printing support"               "${_printing_state}" \
        "bluetooth"  "Bluetooth support"                   "${_bluetooth_state}") \
        || return "${TUI_BACK}"

    ENABLE_FLATPAK="no"
    ENABLE_PRINTING="no"
    ENABLE_BLUETOOTH="no"

    local cleaned
    cleaned=$(echo "${extras}" | tr -d '"')
    local item
    for item in ${cleaned}; do
        case "${item}" in
            flatpak)    ENABLE_FLATPAK="yes" ;;
            printing)   ENABLE_PRINTING="yes" ;;
            bluetooth)  ENABLE_BLUETOOTH="yes" ;;
        esac
    done

    export ENABLE_FLATPAK ENABLE_PRINTING ENABLE_BLUETOOTH

    einfo "Desktop extras: ${DESKTOP_EXTRAS}"
    return "${TUI_NEXT}"
}
