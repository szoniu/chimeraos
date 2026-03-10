#!/usr/bin/env bash
# tui/locale_config.sh — Language, timezone + keymap configuration
source "${LIB_DIR}/protection.sh"

screen_locale_config() {
    # System language / locale
    local locale
    locale=$(dialog_menu "System Language" \
        "en_US.UTF-8"  "English (US)" \
        "pl_PL.UTF-8"  "Polish" \
        "de_DE.UTF-8"  "German" \
        "fr_FR.UTF-8"  "French" \
        "en_GB.UTF-8"  "English (UK)" \
        "es_ES.UTF-8"  "Spanish" \
        "it_IT.UTF-8"  "Italian" \
        "pt_PT.UTF-8"  "Portuguese" \
        "ru_RU.UTF-8"  "Russian" \
        "cs_CZ.UTF-8"  "Czech" \
        "nl_NL.UTF-8"  "Dutch" \
        "sv_SE.UTF-8"  "Swedish" \
        "ja_JP.UTF-8"  "Japanese" \
        "zh_CN.UTF-8"  "Chinese (Simplified)" \
        "ko_KR.UTF-8"  "Korean") \
        || return "${TUI_BACK}"

    LOCALE="${locale}"
    export LOCALE

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

    einfo "Language: ${LOCALE}, Timezone: ${TIMEZONE}, Keymap: ${KEYMAP}"
    return "${TUI_NEXT}"
}
