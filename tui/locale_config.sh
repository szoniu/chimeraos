#!/usr/bin/env bash
# tui/locale_config.sh — Timezone + keymap configuration
source "${LIB_DIR}/protection.sh"

screen_locale_config() {
    # Timezone
    local tz
    tz=$(dialog_inputbox "Timezone" \
        "Enter your timezone (e.g., Europe/Warsaw, America/New_York):\n\n\
Common timezones:\n\
  Europe/Warsaw, Europe/Berlin, Europe/London\n\
  America/New_York, America/Chicago, America/Los_Angeles\n\
  Asia/Tokyo, Australia/Sydney" \
        "${TIMEZONE:-Europe/Warsaw}") || return "${TUI_BACK}"

    if [[ -z "${tz}" ]]; then
        tz="UTC"
    fi

    TIMEZONE="${tz}"
    export TIMEZONE

    # Keymap
    local keymap
    keymap=$(dialog_menu "Console Keymap" \
        "us"    "US English" \
        "pl"    "Polish" \
        "de"    "German" \
        "fr"    "French" \
        "uk"    "UK English" \
        "es"    "Spanish" \
        "it"    "Italian" \
        "pt"    "Portuguese" \
        "ru"    "Russian" \
        "cz"    "Czech") \
        || return "${TUI_BACK}"

    KEYMAP="${keymap}"
    export KEYMAP

    einfo "Timezone: ${TIMEZONE}, Keymap: ${KEYMAP}"
    return "${TUI_NEXT}"
}
