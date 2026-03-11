#!/usr/bin/env bash
# tui/desktop_config.sh — Desktop environment selection + apps + extras
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
    # Desktop environment selection
    local de
    de=$(dialog_menu "Desktop Environment" \
        "kde"   "KDE Plasma 6 — feature-rich, customizable" \
        "gnome" "GNOME — clean, modern, Wayland-native") \
        || return "${TUI_BACK}"

    DESKTOP_ENV="${de}"
    export DESKTOP_ENV

    # DE-specific app selection
    case "${de}" in
        kde)   _select_kde_apps || return "${TUI_BACK}" ;;
        gnome) _select_gnome_apps || return "${TUI_BACK}" ;;
    esac

    # Optional extras (shared between DEs)
    _select_extras || return "${TUI_BACK}"

    einfo "Desktop: ${DESKTOP_ENV}, extras: ${DESKTOP_EXTRAS}"
    return "${TUI_NEXT}"
}

_select_kde_apps() {
    dialog_msgbox "KDE Plasma" \
        "KDE Plasma 6 will be installed.\n\n\
Includes:\n\
  * Plasma Desktop + Wayland\n\
  * SDDM display manager\n\
  * PipeWire audio (via Turnstile)\n\
  * Konsole terminal + Dolphin file manager\n\n\
You can select additional applications on the next screen." \
        || return 1

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
        || return 1

    DESKTOP_EXTRAS="${apps}"
    export DESKTOP_EXTRAS
}

_select_gnome_apps() {
    dialog_msgbox "GNOME" \
        "GNOME will be installed.\n\n\
Includes:\n\
  * GNOME Shell + Wayland\n\
  * GDM display manager\n\
  * PipeWire audio (via Turnstile)\n\
  * Nautilus file manager + GNOME Console\n\n\
Language packs are installed automatically by APK.\n\
You can select additional applications on the next screen." \
        || return 1

    local apps
    apps=$(dialog_checklist "GNOME Applications" \
        "firefox"          "Firefox — web browser"             "$(_app_state firefox on)" \
        "gnome-text-editor" "Text Editor"                      "$(_app_state gnome-text-editor on)" \
        "evince"           "Evince — document viewer"          "$(_app_state evince on)" \
        "loupe"            "Loupe — image viewer"              "$(_app_state loupe on)" \
        "gnome-calculator" "Calculator"                        "$(_app_state gnome-calculator on)" \
        "gnome-weather"    "Weather"                           "$(_app_state gnome-weather off)" \
        "gnome-clocks"     "Clocks"                            "$(_app_state gnome-clocks off)" \
        "vlc"              "VLC — media player"                "$(_app_state vlc off)" \
        "libreoffice"      "LibreOffice — office suite"        "$(_app_state libreoffice off)" \
        "thunderbird"      "Thunderbird — email client"        "$(_app_state thunderbird off)") \
        || return 1

    DESKTOP_EXTRAS="${apps}"
    export DESKTOP_EXTRAS
}

_select_extras() {
    local _flatpak_state="off" _printing_state="off" _bluetooth_state="on"
    [[ "${ENABLE_FLATPAK:-no}" == "yes" ]] && _flatpak_state="on"
    [[ "${ENABLE_PRINTING:-no}" == "yes" ]] && _printing_state="on"
    [[ "${ENABLE_BLUETOOTH:-yes}" == "no" ]] && _bluetooth_state="off"

    local extras
    extras=$(dialog_checklist "Optional Features" \
        "flatpak"    "Flatpak — universal package manager" "${_flatpak_state}" \
        "printing"   "CUPS printing support"               "${_printing_state}" \
        "bluetooth"  "Bluetooth support"                   "${_bluetooth_state}") \
        || return 1

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
}
