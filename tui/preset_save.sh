#!/usr/bin/env bash
# tui/preset_save.sh — Optional preset export
source "${LIB_DIR}/protection.sh"

screen_preset_save() {
    if ! dialog_yesno "Save Preset" \
        "Would you like to save your configuration as a preset?\n\n\
This allows you to reuse it on other machines.\n\
Hardware-specific values will be re-detected on import."; then
        return "${TUI_NEXT}"
    fi

    local file
    file=$(dialog_inputbox "Preset Path" \
        "Enter the path to save the preset:" \
        "${SCRIPT_DIR}/presets/custom-$(date +%Y%m%d).conf") || return "${TUI_BACK}"

    if [[ -z "${file}" ]]; then
        return "${TUI_NEXT}"
    fi

    preset_export "${file}"
    dialog_msgbox "Preset Saved" "Preset exported to:\n${file}"

    return "${TUI_NEXT}"
}
