#!/usr/bin/env bash
# tui/desktop_config.sh — KDE Plasma + apps + extras
source "${LIB_DIR}/protection.sh"

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

    # KDE application selection
    local apps
    apps=$(dialog_checklist "KDE Applications" \
        "kate"        "Kate — advanced text editor"       "on" \
        "firefox"     "Firefox — web browser"             "on" \
        "gwenview"    "Gwenview — image viewer"           "on" \
        "okular"      "Okular — document viewer"          "on" \
        "ark"         "Ark — archive manager"             "on" \
        "spectacle"   "Spectacle — screenshot tool"       "on" \
        "kcalc"       "KCalc — calculator"                "off" \
        "elisa"       "Elisa — music player"              "off" \
        "vlc"         "VLC — media player"                "off" \
        "libreoffice" "LibreOffice — office suite"        "off" \
        "thunderbird" "Thunderbird — email client"        "off") \
        || return "${TUI_BACK}"

    DESKTOP_EXTRAS="${apps}"
    export DESKTOP_EXTRAS

    # Optional extras
    local extras
    extras=$(dialog_checklist "Optional Features" \
        "flatpak"    "Flatpak — universal package manager" "off" \
        "printing"   "CUPS printing support"               "off" \
        "bluetooth"  "Bluetooth support"                   "on") \
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
