#!/usr/bin/env bash
# tui/progress.sh — Installation progress screen with gauge
source "${LIB_DIR}/protection.sh"

# Phase definitions: "phase_name|description|weight"
readonly -a INSTALL_PHASES=(
    "preflight|Preflight checks|2"
    "disks|Disk operations|5"
    "bootstrap|Bootstrap Chimera Linux|20"
    "chroot_setup|Chroot setup|2"
    "apk_update|Package update|5"
    "kernel|Kernel installation|10"
    "fstab|Filesystem table|2"
    "system_config|System configuration|3"
    "bootloader|Bootloader installation|5"
    "swap_setup|Swap configuration|2"
    "networking|Network configuration|3"
    "desktop|Desktop installation|30"
    "users|User configuration|3"
    "extras|Extra packages|5"
    "finalize|Finalization|3"
)

screen_progress() {
    local total_weight=0
    local entry
    for entry in "${INSTALL_PHASES[@]}"; do
        local weight
        IFS='|' read -r _ _ weight <<< "${entry}"
        (( total_weight += weight ))
    done

    local progress_pipe="/tmp/chimera-progress-$$"
    mkfifo "${progress_pipe}" 2>/dev/null || true

    dialog_gauge "Installing Chimera Linux" \
        "Preparing installation..." 0 < "${progress_pipe}" &
    local gauge_pid=$!

    exec 3>"${progress_pipe}"

    local completed_weight=0
    for entry in "${INSTALL_PHASES[@]}"; do
        local phase_name phase_desc weight
        IFS='|' read -r phase_name phase_desc weight <<< "${entry}"

        local percent=$(( completed_weight * 100 / total_weight ))
        echo "XXX" >&3 2>/dev/null || true
        echo "${percent}" >&3 2>/dev/null || true
        echo "${phase_desc}..." >&3 2>/dev/null || true
        echo "XXX" >&3 2>/dev/null || true

        if checkpoint_reached "${phase_name}"; then
            einfo "Phase ${phase_name} already completed (checkpoint)"
        else
            _execute_phase "${phase_name}" "${phase_desc}"
        fi

        (( completed_weight += weight ))
    done

    echo "XXX" >&3 2>/dev/null || true
    echo "100" >&3 2>/dev/null || true
    echo "Installation complete!" >&3 2>/dev/null || true
    echo "XXX" >&3 2>/dev/null || true

    exec 3>&-
    wait "${gauge_pid}" 2>/dev/null || true
    rm -f "${progress_pipe}"

    dialog_msgbox "Complete" "Chimera Linux installation has finished successfully!"

    return "${TUI_NEXT}"
}

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
            ;;
        finalize)
            system_finalize
            ;;
    esac

    maybe_exec "after_${phase_name}"
    checkpoint_set "${phase_name}"
}
