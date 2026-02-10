#!/usr/bin/env bash
# tui/gpu_config.sh — GPU driver configuration
source "${LIB_DIR}/protection.sh"

screen_gpu_config() {
    local vendor="${GPU_VENDOR:-unknown}"
    local driver="${GPU_DRIVER:-mesa}"
    local device="${GPU_DEVICE_NAME:-Unknown}"

    local info_text=""
    info_text+="Detected GPU: ${device}\n"
    info_text+="Vendor: ${vendor}\n"
    info_text+="Driver: ${driver}\n\n"

    case "${vendor}" in
        nvidia)
            info_text+="NVIDIA GPUs use open-source NVK/nouveau drivers.\n"
            info_text+="Chimera Linux does NOT support proprietary NVIDIA drivers.\n"
            info_text+="Performance may be limited compared to proprietary drivers.\n"
            ;;
        amd)
            info_text+="AMD GPUs have excellent open-source support.\n"
            info_text+="Using RADV Vulkan driver (recommended).\n"
            ;;
        intel)
            info_text+="Intel GPUs use open-source ANV Vulkan driver.\n"
            info_text+="Supported for Gen 7 and newer.\n"
            ;;
        *)
            info_text+="Using generic Mesa drivers.\n"
            ;;
    esac

    info_text+="\nAll GPU drivers on Chimera Linux are open-source."

    dialog_yesno "GPU Configuration" \
        "${info_text}\n\nAccept this configuration?" \
        && return "${TUI_NEXT}" \
        || return "${TUI_BACK}"
}
