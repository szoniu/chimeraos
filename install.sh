#!/usr/bin/env bash
# install.sh — Main entry point for the Chimera Linux TUI Installer
#
# Usage:
#   ./install.sh              — Run full installation (TUI wizard + install)
#   ./install.sh --configure  — Run only the TUI wizard (generate config)
#   ./install.sh --install    — Run only the installation (using existing config)
#   ./install.sh --resume     — Resume interrupted installation (scan disks)
#   ./install.sh --dry-run    — Run wizard + simulate installation
#
set -euo pipefail
shopt -s inherit_errexit

# Mark as the Chimera installer (used by protection.sh)
export _CHIMERA_INSTALLER=1

# Determine script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export SCRIPT_DIR
export LIB_DIR="${SCRIPT_DIR}/lib"
export TUI_DIR="${SCRIPT_DIR}/tui"
export DATA_DIR="${SCRIPT_DIR}/data"

# --- Source library modules ---
source "${LIB_DIR}/constants.sh"
source "${LIB_DIR}/logging.sh"
source "${LIB_DIR}/utils.sh"
source "${LIB_DIR}/dialog.sh"
source "${LIB_DIR}/config.sh"
source "${LIB_DIR}/hardware.sh"
source "${LIB_DIR}/disk.sh"
source "${LIB_DIR}/bootstrap.sh"
source "${LIB_DIR}/chroot.sh"
source "${LIB_DIR}/system.sh"
source "${LIB_DIR}/bootloader.sh"
source "${LIB_DIR}/desktop.sh"
source "${LIB_DIR}/swap.sh"
source "${LIB_DIR}/hooks.sh"
source "${LIB_DIR}/preset.sh"

# --- Source TUI screens ---
source "${TUI_DIR}/welcome.sh"
source "${TUI_DIR}/preset_load.sh"
source "${TUI_DIR}/hw_detect.sh"
source "${TUI_DIR}/disk_select.sh"
source "${TUI_DIR}/filesystem_select.sh"
source "${TUI_DIR}/swap_config.sh"
source "${TUI_DIR}/network_config.sh"
source "${TUI_DIR}/locale_config.sh"
source "${TUI_DIR}/bootloader_select.sh"
source "${TUI_DIR}/kernel_select.sh"
source "${TUI_DIR}/gpu_config.sh"
source "${TUI_DIR}/desktop_config.sh"
source "${TUI_DIR}/user_config.sh"
source "${TUI_DIR}/extra_packages.sh"
source "${TUI_DIR}/preset_save.sh"
source "${TUI_DIR}/summary.sh"
source "${TUI_DIR}/progress.sh"

# --- Source data files ---
source "${DATA_DIR}/gpu_database.sh"

# --- Cleanup trap ---
cleanup() {
    local rc=$?

    # Restore terminal echo (gum backend disables it)
    stty echo 2>/dev/null || true

    # Restore stderr if it was redirected to log file (fd 4 saved by screen_progress)
    if { true >&4; } 2>/dev/null; then
        exec 2>&4
        exec 4>&-
    fi

    if mountpoint -q "${MOUNTPOINT}/proc" 2>/dev/null; then
        ewarn "Cleaning up chroot mount points..."
        chroot_teardown || true
    fi

    # Unmount filesystems and close LUKS on failure
    if [[ ${rc} -ne 0 ]]; then
        if mountpoint -q "${MOUNTPOINT}" 2>/dev/null; then
            ewarn "Cleaning up filesystems..."
            unmount_filesystems || true
        elif [[ "${LUKS_ENABLED:-no}" == "yes" ]]; then
            cryptsetup luksClose cryptroot 2>/dev/null || true
        fi
        eerror "Installer exited with code ${rc}"
        eerror "Log file: ${LOG_FILE}"
    fi
    return ${rc}
}
trap cleanup EXIT
trap 'trap - EXIT; cleanup; exit 130' INT
trap 'trap - EXIT; cleanup; exit 143' TERM

# --- Parse arguments ---
MODE="full"
DRY_RUN=0
FORCE=0
NON_INTERACTIVE=0
export DRY_RUN FORCE NON_INTERACTIVE

usage() {
    cat <<'EOF'
Chimera Linux TUI Installer

Usage:
  install.sh [OPTIONS] [COMMAND]

Commands:
  (default)       Run full installation (wizard + install)
  --configure     Run only the TUI configuration wizard
  --install       Run only the installation phase (requires config)
  --resume        Resume interrupted installation (scan disks for checkpoints)

Options:
  --config FILE   Use specified config file
  --dry-run       Simulate installation without destructive operations
  --force         Continue past failed prerequisite checks
  --non-interactive  Abort on any error (no recovery menu)
  --help          Show this help message
EOF
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        --configure)
            MODE="configure"
            shift
            ;;
        --install)
            MODE="install"
            shift
            ;;
        --resume)
            MODE="resume"
            shift
            ;;
        --config)
            CONFIG_FILE="$2"
            shift 2
            ;;
        --dry-run)
            DRY_RUN=1
            shift
            ;;
        --force)
            FORCE=1
            shift
            ;;
        --non-interactive)
            NON_INTERACTIVE=1
            shift
            ;;
        --help|-h)
            usage
            exit 0
            ;;
        *)
            eerror "Unknown argument: $1"
            usage
            exit 1
            ;;
    esac
done

# --- Main functions ---

run_configuration_wizard() {
    init_dialog

    register_wizard_screens \
        screen_welcome \
        screen_preset_load \
        screen_hw_detect \
        screen_disk_select \
        screen_filesystem_select \
        screen_swap_config \
        screen_network_config \
        screen_locale_config \
        screen_bootloader_select \
        screen_kernel_select \
        screen_gpu_config \
        screen_desktop_config \
        screen_user_config \
        screen_extra_packages \
        screen_preset_save \
        screen_summary

    run_wizard

    config_save "${CONFIG_FILE}"
    einfo "Configuration complete. Saved to ${CONFIG_FILE}"
}

run_post_install() {
    einfo "=== Post-installation ==="

    chroot_teardown
    unmount_filesystems

    dialog_msgbox "Installation Complete" \
        "Chimera Linux has been successfully installed!\n\n\
You can now reboot into your new system.\n\n\
Remember to remove the installation media.\n\n\
Log file saved to: ${LOG_FILE}"

    if dialog_yesno "Reboot" "Would you like to reboot now?"; then
        einfo "Rebooting..."
        if [[ "${DRY_RUN}" != "1" ]]; then
            reboot
        else
            einfo "[DRY-RUN] Would reboot now"
        fi
    else
        einfo "You can reboot manually when ready."
        einfo "Log file: ${LOG_FILE}"
    fi
}

preflight_checks() {
    einfo "Running preflight checks..."

    if [[ "${DRY_RUN}" != "1" ]]; then
        is_root || die "Must run as root"
        is_efi || die "UEFI boot mode required"
        ensure_dns
        has_network || die "Network connectivity required"
    fi

    ensure_dependencies

    # Sync clock if possible
    if command -v chronyd &>/dev/null && [[ "${DRY_RUN}" != "1" ]]; then
        try "Syncing system clock" chronyd -q || true
    elif command -v ntpd &>/dev/null && [[ "${DRY_RUN}" != "1" ]]; then
        try "Syncing system clock" ntpd -q -g || true
    fi

    einfo "Preflight checks passed"
}

# --- Entry point ---
main() {
    init_logging

    einfo "========================================="
    einfo "${INSTALLER_NAME} v${INSTALLER_VERSION}"
    einfo "========================================="
    einfo "Mode: ${MODE}"
    [[ "${DRY_RUN}" == "1" ]] && ewarn "DRY-RUN mode enabled"

    case "${MODE}" in
        full)
            run_configuration_wizard
            screen_progress
            run_post_install
            ;;
        configure)
            run_configuration_wizard
            ;;
        install)
            config_load "${CONFIG_FILE}"
            init_dialog
            screen_progress
            run_post_install
            ;;
        resume)
            local resume_rc=0
            try_resume_from_disk || resume_rc=$?

            case ${resume_rc} in
                0)
                    # Config + checkpoints recovered
                    config_load "${CONFIG_FILE}"
                    init_dialog

                    local completed_list=""
                    local cp_name
                    for cp_name in "${CHECKPOINTS[@]}"; do
                        if checkpoint_reached "${cp_name}"; then
                            completed_list+="  - ${cp_name}\n"
                        fi
                    done
                    dialog_msgbox "Resume: Data Recovered" \
                        "Found previous installation on ${RESUME_FOUND_PARTITION}.\n\nRecovered config and checkpoints:\n\n${completed_list}\nResuming installation..."

                    screen_progress
                    run_post_install
                    ;;
                1)
                    # Only checkpoints, no config — try inference
                    init_dialog

                    local infer_rc=0
                    infer_config_from_partition "${RESUME_FOUND_PARTITION}" "${RESUME_FOUND_FSTYPE}" || infer_rc=$?

                    if [[ ${infer_rc} -eq 0 ]]; then
                        config_save "${CONFIG_FILE}"

                        local inferred_summary=""
                        inferred_summary+="Partition: ${ROOT_PARTITION:-?}\n"
                        inferred_summary+="Disk: ${TARGET_DISK:-?}\n"
                        inferred_summary+="Filesystem: ${FILESYSTEM:-?}\n"
                        inferred_summary+="ESP: ${ESP_PARTITION:-?}\n"
                        [[ -n "${HOSTNAME:-}" ]] && inferred_summary+="Hostname: ${HOSTNAME}\n"
                        [[ -n "${TIMEZONE:-}" ]] && inferred_summary+="Timezone: ${TIMEZONE}\n"
                        [[ -n "${BOOTLOADER_TYPE:-}" ]] && inferred_summary+="Bootloader: ${BOOTLOADER_TYPE}\n"

                        local completed_list=""
                        local cp_name
                        for cp_name in "${CHECKPOINTS[@]}"; do
                            if checkpoint_reached "${cp_name}"; then
                                completed_list+="  - ${cp_name}\n"
                            fi
                        done

                        dialog_msgbox "Resume: Config Inferred" \
                            "Found checkpoints on ${RESUME_FOUND_PARTITION} (no config file).\n\nInferred configuration:\n${inferred_summary}\nCompleted phases:\n${completed_list}\nResuming installation..."

                        screen_progress
                        run_post_install
                    else
                        dialog_msgbox "Resume: Partial Recovery" \
                            "Found checkpoints on ${RESUME_FOUND_PARTITION} but could not fully infer configuration.\n\nSome fields have been pre-filled from the installed system.\nPlease complete the wizard. Completed phases will be skipped automatically."

                        run_configuration_wizard
                        screen_progress
                        run_post_install
                    fi
                    ;;
                2)
                    # Nothing found
                    init_dialog
                    dialog_msgbox "Resume: Nothing Found" \
                        "No previous installation data found on any partition.\n\nStarting full installation."

                    run_configuration_wizard
                    screen_progress
                    run_post_install
                    ;;
            esac
            ;;
        *)
            die "Unknown mode: ${MODE}"
            ;;
    esac

    einfo "Done."
}

main "$@"
