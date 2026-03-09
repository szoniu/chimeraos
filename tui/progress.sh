#!/usr/bin/env bash
# tui/progress.sh — Installation progress screen with resume detection
source "${LIB_DIR}/protection.sh"

# Phase definitions: "phase_name|description"
readonly -a INSTALL_PHASES=(
    "preflight|Preflight checks"
    "disks|Disk operations"
    "bootstrap|Bootstrap Chimera Linux"
    "chroot_setup|Chroot setup"
    "apk_update|Package update"
    "kernel|Kernel installation"
    "fstab|Filesystem table"
    "system_config|System configuration"
    "bootloader|Bootloader installation"
    "swap_setup|Swap configuration"
    "networking|Network configuration"
    "desktop|Desktop installation"
    "users|User configuration"
    "extras|Extra packages"
    "finalize|Finalization"
)

# _save_config_to_target — Persist config file to target disk for --resume recovery
_save_config_to_target() {
    if [[ -n "${MOUNTPOINT:-}" ]] && mountpoint -q "${MOUNTPOINT}" 2>/dev/null; then
        config_save "${MOUNTPOINT}/tmp/$(basename "${CONFIG_FILE}")"
    fi
}

# _detect_and_handle_resume — Check for previous progress and ask user
# Returns 0 if resuming, 1 if starting fresh
_detect_and_handle_resume() {
    local has_checkpoints=0

    # Check /tmp checkpoints
    if [[ -d "${CHECKPOINT_DIR}" ]] && ls "${CHECKPOINT_DIR}/"* &>/dev/null 2>&1; then
        has_checkpoints=1
    fi

    # Check target disk checkpoints
    local target_checkpoint_dir="${MOUNTPOINT}${CHECKPOINT_DIR_SUFFIX}"
    if [[ -d "${target_checkpoint_dir}" ]] && ls "${target_checkpoint_dir}/"* &>/dev/null 2>&1; then
        has_checkpoints=1
        # Adopt target checkpoints if they exist and /tmp ones don't
        if [[ ! -d "${CHECKPOINT_DIR}" ]] || ! ls "${CHECKPOINT_DIR}/"* &>/dev/null 2>&1; then
            CHECKPOINT_DIR="${target_checkpoint_dir}"
            export CHECKPOINT_DIR
        fi
    fi

    if [[ "${has_checkpoints}" -eq 0 ]]; then
        return 1  # no previous progress
    fi

    # List completed checkpoints for display
    local completed_list=""
    local cp_name
    for cp_name in "${CHECKPOINTS[@]}"; do
        if checkpoint_reached "${cp_name}"; then
            completed_list+="  - ${cp_name}\n"
        fi
    done

    if [[ "${NON_INTERACTIVE:-0}" == "1" ]]; then
        einfo "Non-interactive mode — resuming from previous progress"
        _validate_and_clean_checkpoints
        return 0
    fi

    if dialog_yesno "Resume Installation" \
        "Previous installation progress detected:\n\n${completed_list}\nResume from where it left off?\n\nChoose 'No' to start fresh (all progress will be lost)."; then
        _validate_and_clean_checkpoints
        return 0
    else
        checkpoint_clear
        return 1
    fi
}

# _validate_and_clean_checkpoints — Validate each checkpoint, remove invalid ones
_validate_and_clean_checkpoints() {
    local cp_name
    for cp_name in "${CHECKPOINTS[@]}"; do
        if checkpoint_reached "${cp_name}" && ! checkpoint_validate "${cp_name}"; then
            ewarn "Checkpoint '${cp_name}' failed validation — will re-run"
            rm -f "${CHECKPOINT_DIR}/${cp_name}"
        fi
    done
}

# screen_progress — Run installation with live log preview
screen_progress() {
    local total=${#INSTALL_PHASES[@]}
    local i=0

    # Check for previous progress and handle resume
    if ! _detect_and_handle_resume; then
        einfo "Starting fresh installation"
    else
        einfo "Resuming installation from previous progress"
    fi

    # Restore terminal echo (was disabled for gum TUI)
    stty echo </dev/tty 2>/dev/null || true
    _GUM_ECHO_OFF=0
    # Flush accumulated terminal responses from the wizard session
    sleep 0.3
    dd if=/dev/tty of=/dev/null bs=4096 count=100 iflag=nonblock 2>/dev/null || true
    while read -t 0.1 -rsn 1 _ </dev/tty 2>/dev/null; do :; done

    # Enable live output globally — commands output via tee (terminal + log)
    export LIVE_OUTPUT=1

    # Print initial header
    if [[ "${NON_INTERACTIVE:-0}" != "1" ]]; then
        printf '\033[H\033[2J' >/dev/tty 2>/dev/null
        _live_preview_header "1" "${total}" "Starting..." >/dev/tty 2>/dev/null || true
        echo "" >/dev/tty
    fi

    for entry in "${INSTALL_PHASES[@]}"; do
        local phase_name phase_desc
        IFS='|' read -r phase_name phase_desc <<< "${entry}"
        (( i++ )) || true

        if checkpoint_reached "${phase_name}"; then
            einfo "Phase ${phase_name} already completed (checkpoint)"

            # Re-mount filesystems if disks phase is skipped (needed after reboot/resume)
            if [[ "${phase_name}" == "disks" ]]; then
                mount_filesystems
                checkpoint_migrate_to_target
                _save_config_to_target
            fi

            # Re-setup chroot if skipped (pseudo-FS mounts needed for later phases)
            if [[ "${phase_name}" == "chroot_setup" ]]; then
                chroot_setup
            fi

            continue
        fi

        # Print phase separator with progress info
        if [[ "${NON_INTERACTIVE:-0}" != "1" ]]; then
            echo "" >/dev/tty
            _live_preview_header "${i}" "${total}" "${phase_desc}" >/dev/tty 2>/dev/null || true
            echo "" >/dev/tty
        fi

        _execute_phase "${phase_name}" "${phase_desc}"
    done

    unset LIVE_OUTPUT

    dialog_msgbox "Installation Complete" \
        "Chimera Linux has been successfully installed!\n\n\
You can now reboot into your new system.\n\
Remember to remove the installation media.\n\n\
Log file: ${LOG_FILE}"

    return "${TUI_NEXT}"
}

# _live_preview_header — Print progress header with bar
_live_preview_header() {
    local current="$1" total="$2" desc="$3"

    local bar_width=40
    local filled=$(( bar_width * current / total ))
    local empty=$(( bar_width - filled ))
    local bar=""
    local j
    for (( j = 0; j < filled; j++ )); do bar+="█"; done
    for (( j = 0; j < empty; j++ )); do bar+="░"; done

    local phase_info="Phase ${current}/${total}"

    echo "=== ${INSTALLER_NAME} v${INSTALLER_VERSION} ==="
    echo "[${bar}] ${phase_info}"
    echo "${desc}"
    printf '%.0s─' $(seq 1 "${DIALOG_WIDTH:-76}")
    echo
}

# _execute_phase — Execute a single installation phase
_execute_phase() {
    local phase_name="$1"
    local phase_desc="$2"

    einfo "=== Phase: ${phase_desc} ==="
    maybe_exec "before_${phase_name}"

    case "${phase_name}" in
        preflight)
            preflight_checks
            ;;
        disks)
            disk_execute_plan
            mount_filesystems
            checkpoint_migrate_to_target
            _save_config_to_target
            ;;
        bootstrap)
            bootstrap_install
            ;;
        chroot_setup)
            chroot_setup
            copy_installer_to_chroot
            ;;
        apk_update)
            apk_update
            ;;
        kernel)
            kernel_install
            ;;
        fstab)
            generate_fstab
            generate_crypttab
            ;;
        system_config)
            system_set_timezone
            system_set_hostname
            system_set_keymap
            ;;
        bootloader)
            bootloader_install
            ;;
        swap_setup)
            swap_setup
            ;;
        networking)
            install_networking
            ;;
        desktop)
            desktop_install
            ;;
        users)
            system_create_users
            ;;
        extras)
            install_extra_packages
            install_fingerprint_tools
            install_thunderbolt_tools
            install_sensor_tools
            install_wwan_tools
            ;;
        finalize)
            system_finalize
            ;;
    esac

    maybe_exec "after_${phase_name}"
    checkpoint_set "${phase_name}"
}
