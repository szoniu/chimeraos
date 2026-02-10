#!/usr/bin/env bash
# tui/user_config.sh — Root password, user, groups, SSH
source "${LIB_DIR}/protection.sh"

screen_user_config() {
    # Root password
    local root_pw1 root_pw2
    while true; do
        root_pw1=$(dialog_passwordbox "Root Password" \
            "Enter the root password:") || return "${TUI_BACK}"

        if [[ -z "${root_pw1}" ]]; then
            dialog_msgbox "Error" "Password cannot be empty."
            continue
        fi

        root_pw2=$(dialog_passwordbox "Root Password" \
            "Confirm the root password:") || return "${TUI_BACK}"

        if [[ "${root_pw1}" != "${root_pw2}" ]]; then
            dialog_msgbox "Error" "Passwords do not match. Please try again."
            continue
        fi

        break
    done

    ROOT_PASSWORD_HASH=$(generate_password_hash "${root_pw1}")
    export ROOT_PASSWORD_HASH

    # Username
    local username
    username=$(dialog_inputbox "Create User" \
        "Enter the username for your regular user account:" \
        "${USERNAME:-user}") || return "${TUI_BACK}"

    if [[ -z "${username}" ]]; then
        username="user"
    fi

    USERNAME="${username}"
    export USERNAME

    # User password
    local user_pw1 user_pw2
    while true; do
        user_pw1=$(dialog_passwordbox "User Password" \
            "Enter the password for ${USERNAME}:") || return "${TUI_BACK}"

        if [[ -z "${user_pw1}" ]]; then
            dialog_msgbox "Error" "Password cannot be empty."
            continue
        fi

        user_pw2=$(dialog_passwordbox "User Password" \
            "Confirm the password for ${USERNAME}:") || return "${TUI_BACK}"

        if [[ "${user_pw1}" != "${user_pw2}" ]]; then
            dialog_msgbox "Error" "Passwords do not match. Please try again."
            continue
        fi

        break
    done

    USER_PASSWORD_HASH=$(generate_password_hash "${user_pw1}")
    export USER_PASSWORD_HASH

    # Groups
    local groups
    groups=$(dialog_checklist "User Groups" \
        "wheel"   "Administrator (doas/sudo)" "on" \
        "audio"   "Audio devices"             "on" \
        "video"   "Video devices"             "on" \
        "input"   "Input devices"             "on" \
        "plugdev" "Removable devices"         "on" \
        "kvm"     "Virtual machines"          "off" \
        "docker"  "Docker containers"         "off") \
        || return "${TUI_BACK}"

    # Convert quoted list to comma-separated
    USER_GROUPS=$(echo "${groups}" | tr -d '"' | tr ' ' ',')
    export USER_GROUPS

    # SSH
    if dialog_yesno "SSH Server" \
        "Enable SSH server for remote access?"; then
        ENABLE_SSH="yes"
    else
        ENABLE_SSH="no"
    fi
    export ENABLE_SSH

    einfo "User: ${USERNAME}, Groups: ${USER_GROUPS}, SSH: ${ENABLE_SSH}"
    return "${TUI_NEXT}"
}
