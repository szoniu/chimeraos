#!/usr/bin/env bash
# tui/gpu_config.sh — GPU driver configuration (open-source only)
source "${LIB_DIR}/protection.sh"

screen_gpu_config() {
    local vendor="${GPU_VENDOR:-unknown}"
    local driver="${GPU_DRIVER:-mesa}"
    local device="${GPU_DEVICE_NAME:-Unknown}"

    local info_text=""

    if [[ "${HYBRID_GPU:-no}" == "yes" ]]; then
        info_text+="Hybrid GPU detected:\n"
        info_text+="  iGPU: ${IGPU_DEVICE_NAME:-unknown} (${IGPU_VENDOR:-unknown})\n"
        info_text+="  dGPU: ${DGPU_DEVICE_NAME:-unknown} (${DGPU_VENDOR:-unknown})\n\n"
        info_text+="Both GPUs will use open-source drivers.\n"
        info_text+="PRIME render offload will be available for the discrete GPU.\n"
    else
        info_text+="Detected GPU: ${device}\n"
        info_text+="Vendor: ${vendor}\n"
        info_text+="Driver: ${driver}\n\n"
    fi

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

    # Allow vendor override
    local override
    override=$(dialog_menu "GPU Configuration" \
        "auto"    "${info_text}" \
        "nvidia"  "Force NVIDIA (NVK/nouveau)" \
        "amd"     "Force AMD (RADV)" \
        "intel"   "Force Intel (ANV)" \
        "none"    "No GPU drivers (headless/server)") \
        || return "${TUI_BACK}"

    if [[ "${override}" != "auto" ]]; then
        GPU_VENDOR="${override}"
        case "${override}" in
            nvidia) GPU_DRIVER="nvk" ;;
            amd)    GPU_DRIVER="radv" ;;
            intel)  GPU_DRIVER="anv" ;;
            none)   GPU_DRIVER="mesa" ;;
        esac
    fi

    export GPU_VENDOR GPU_DRIVER GPU_DEVICE_NAME
    export HYBRID_GPU IGPU_VENDOR IGPU_DEVICE_NAME DGPU_VENDOR DGPU_DEVICE_NAME

    return "${TUI_NEXT}"
}
