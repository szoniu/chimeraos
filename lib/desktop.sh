#!/usr/bin/env bash
# desktop.sh — KDE Plasma, SDDM, PipeWire, GPU drivers
source "${LIB_DIR}/protection.sh"

# desktop_install — Install full KDE Plasma desktop
desktop_install() {
    einfo "Installing KDE Plasma desktop..."

    # Install GPU drivers first
    _install_gpu_drivers

    # Install KDE Plasma
    apk_install "Installing KDE Plasma" plasma-desktop

    # Install SDDM display manager
    apk_install "Installing SDDM" sddm

    # PipeWire is typically included, but ensure it
    _install_pipewire

    # Auto-install Bluetooth (like PipeWire — always with desktop)
    _install_bluetooth

    # Install KDE applications
    _install_kde_apps

    # Enable display manager
    _enable_display_manager

    # Configure Plasma defaults
    _configure_plasma

    # Optional extras
    _install_extras

    einfo "Desktop installation complete"
}

# _install_gpu_drivers — Install GPU-specific open-source drivers
_install_gpu_drivers() {
    local vendor="${GPU_VENDOR:-unknown}"

    einfo "Installing GPU drivers for ${vendor} (open-source)..."

    # Always install mesa base
    apk_install "Installing Mesa" mesa mesa-dri

    if [[ "${HYBRID_GPU:-no}" == "yes" ]]; then
        # Hybrid GPU — install drivers for both iGPU and dGPU
        einfo "Hybrid GPU setup: ${IGPU_VENDOR:-?} iGPU + ${DGPU_VENDOR:-?} dGPU"

        case "${IGPU_VENDOR:-}" in
            amd) _install_amd_drivers ;;
            intel) _install_intel_drivers ;;
        esac
        case "${DGPU_VENDOR:-}" in
            nvidia) _install_nvidia_open ;;
            amd) _install_amd_drivers ;;
        esac
    else
        case "${vendor}" in
            nvidia) _install_nvidia_open ;;
            amd)    _install_amd_drivers ;;
            intel)  _install_intel_drivers ;;
            *)      einfo "No specific GPU driver to install" ;;
        esac
    fi

    # Vulkan support
    apk_install "Installing Vulkan loader" vulkan-loader
}

# _install_nvidia_open — Install NVIDIA open-source drivers (NVK/nouveau)
_install_nvidia_open() {
    einfo "Installing NVIDIA open-source drivers (NVK/nouveau)..."

    apk_install "Installing NVIDIA firmware" firmware-linux-nvidia

    ewarn "Note: Chimera Linux does not support NVIDIA proprietary drivers."
    ewarn "Using NVK (nouveau Vulkan driver). Performance may be limited."
}

# _install_amd_drivers — Install AMD GPU drivers
_install_amd_drivers() {
    einfo "Installing AMD GPU drivers..."

    apk_install "Installing AMD firmware" firmware-linux-amdgpu

    einfo "AMD GPU drivers installed (RADV Vulkan)"
}

# _install_intel_drivers — Install Intel GPU drivers
_install_intel_drivers() {
    einfo "Installing Intel GPU drivers..."

    # Intel drivers are in mesa by default
    einfo "Intel GPU drivers installed (ANV Vulkan)"
}

# _install_pipewire — Install PipeWire audio system
_install_pipewire() {
    einfo "Installing PipeWire audio..."

    apk_install "Installing PipeWire" pipewire wireplumber

    # PipeWire is managed by Turnstile user services in Chimera
    einfo "PipeWire installed (managed by Turnstile)"
}

# _install_kde_apps — Install selected KDE applications
_install_kde_apps() {
    local extras="${DESKTOP_EXTRAS:-}"

    # Always install some basics
    apk_install "Installing basic KDE apps" \
        konsole dolphin

    # Install selected extras
    if [[ -n "${extras}" ]]; then
        local cleaned
        cleaned=$(echo "${extras}" | tr -d '"')
        local pkg
        for pkg in ${cleaned}; do
            case "${pkg}" in
                kate)          apk_install "Installing ${pkg}" kate ;;
                firefox)       apk_install "Installing ${pkg}" firefox ;;
                gwenview)      apk_install "Installing ${pkg}" gwenview ;;
                okular)        apk_install "Installing ${pkg}" okular ;;
                ark)           apk_install "Installing ${pkg}" ark ;;
                spectacle)     apk_install "Installing ${pkg}" spectacle ;;
                kcalc)         apk_install "Installing ${pkg}" kcalc ;;
                elisa)         apk_install "Installing ${pkg}" elisa ;;
                vlc)           apk_install "Installing ${pkg}" vlc ;;
                libreoffice)   apk_install "Installing ${pkg}" libreoffice ;;
                thunderbird)   apk_install "Installing ${pkg}" thunderbird ;;
                *)             apk_install_if_available "${pkg}" ;;
            esac
        done
    fi
}

# _enable_display_manager — Enable SDDM via dinit
_enable_display_manager() {
    einfo "Enabling SDDM display manager..."

    try "Enabling SDDM" \
        chroot_exec "dinitctl -o enable sddm"

    einfo "SDDM enabled"
}

# _configure_plasma — Set up KDE Plasma defaults
_configure_plasma() {
    einfo "Configuring Plasma defaults..."

    # Set SDDM theme
    chroot_exec "mkdir -p /etc/sddm.conf.d"
    chroot_exec "cat > /etc/sddm.conf.d/chimera.conf << 'SDDMEOF'
[Theme]
Current=breeze

[General]
InputMethod=
SDDMEOF"

    # Ensure dbus is available (should be part of base)
    try "Enabling dbus" \
        chroot_exec "dinitctl -o enable dbus" 2>/dev/null || true

    # Enable Turnstile for user services (PipeWire, etc.)
    try "Enabling turnstile" \
        chroot_exec "dinitctl -o enable turnstiled" 2>/dev/null || true

    einfo "Plasma defaults configured"
}

# _install_bluetooth — Auto-install Bluetooth support if hardware detected
_install_bluetooth() {
    if [[ "${BLUETOOTH_DETECTED:-0}" == "1" ]] || [[ "${ENABLE_BLUETOOTH:-no}" == "yes" ]]; then
        einfo "Installing Bluetooth support..."
        apk_install "Installing Bluetooth" bluez
        try "Enabling Bluetooth" \
            chroot_exec "dinitctl -o enable bluetoothd" 2>/dev/null || true
        ENABLE_BLUETOOTH="yes"
        export ENABLE_BLUETOOTH
    fi
}

# _install_printing — Auto-install printing support
_install_printing() {
    if [[ "${ENABLE_PRINTING:-no}" == "yes" ]]; then
        einfo "Installing printing support..."
        apk_install "Installing CUPS" cups cups-filters
        try "Enabling CUPS" \
            chroot_exec "dinitctl -o enable cupsd" 2>/dev/null || true
    fi
}

# _install_extras — Install optional extras (Flatpak, printing)
_install_extras() {
    if [[ "${ENABLE_FLATPAK:-no}" == "yes" ]]; then
        einfo "Installing Flatpak..."
        apk_install "Installing Flatpak" flatpak
        chroot_exec "flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo" 2>/dev/null || true
    fi

    _install_printing
}

# install_extra_packages — Install user-specified extra packages
install_extra_packages() {
    if [[ -n "${EXTRA_PACKAGES:-}" ]]; then
        einfo "Installing extra packages: ${EXTRA_PACKAGES}"
        local pkg
        for pkg in ${EXTRA_PACKAGES}; do
            # Validate package name (alphanumeric, hyphens, dots, underscores, slashes)
            if [[ ! "${pkg}" =~ ^[a-zA-Z0-9][a-zA-Z0-9_./-]*$ ]]; then
                ewarn "Skipping invalid package name: ${pkg}"
                continue
            fi
            apk_install_if_available "${pkg}"
        done
    fi
}
