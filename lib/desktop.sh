#!/usr/bin/env bash
# desktop.sh — KDE Plasma / GNOME, display manager, PipeWire, GPU drivers
source "${LIB_DIR}/protection.sh"

# desktop_install — Install selected desktop environment
desktop_install() {
    local de="${DESKTOP_ENV:-kde}"

    # Install GPU drivers first (shared)
    _install_gpu_drivers

    case "${de}" in
        kde)   _install_kde ;;
        gnome) _install_gnome ;;
    esac

    # Shared: PipeWire, Bluetooth, optional extras
    _install_pipewire
    _install_bluetooth
    _install_extras

    einfo "Desktop installation complete"
}

# --- KDE Plasma ---

_install_kde() {
    einfo "Installing KDE Plasma desktop..."

    apk_install "Installing KDE Plasma" plasma-desktop
    apk_install "Installing SDDM" sddm

    _install_kde_apps
    _install_kde_lang

    # Enable SDDM
    try "Enabling SDDM" \
        chroot_exec "dinitctl -o enable sddm"

    _configure_plasma

    einfo "KDE Plasma installed"
}

# _install_kde_apps — Install selected KDE applications
_install_kde_apps() {
    local extras="${DESKTOP_EXTRAS:-}"

    apk_install "Installing basic KDE apps" \
        konsole dolphin

    if [[ -n "${extras}" ]]; then
        local cleaned
        cleaned=$(echo "${extras}" | tr -d '"')
        local pkg
        for pkg in ${cleaned}; do
            apk_install_if_available "${pkg}"
        done
    fi
}

# _install_kde_lang — Install KDE/Plasma language packs for the selected locale
_install_kde_lang() {
    local locale="${LOCALE:-en_US.UTF-8}"
    local lang="${locale%%_*}"

    if [[ "${lang}" == "en" ]]; then
        einfo "English locale — no extra language packs needed"
        return 0
    fi

    einfo "Installing KDE language packs for: ${lang}"

    local -a lang_pkgs=(
        plasma-desktop-lang
        plasma-workspace-lang
        kf6-ki18n-lang
        konsole-lang
        dolphin-lang
        sddm-lang
    )

    local pkg
    for pkg in "${lang_pkgs[@]}"; do
        apk_install_if_available "${pkg}"
    done
}

# _configure_plasma — Set up KDE Plasma defaults
_configure_plasma() {
    einfo "Configuring Plasma defaults..."

    # SDDM theme
    chroot_exec "mkdir -p /etc/sddm.conf.d"
    chroot_exec "cat > /etc/sddm.conf.d/chimera.conf << 'SDDMEOF'
[Theme]
Current=breeze

[General]
InputMethod=
SDDMEOF"

    # Plasma language for new users via skel
    local locale="${LOCALE:-en_US.UTF-8}"
    local lang="${locale%%_*}"
    if [[ "${lang}" != "en" ]]; then
        chroot_exec "mkdir -p /etc/skel/.config"
        chroot_exec "cat > /etc/skel/.config/plasma-localerc << PLEOF
[Formats]
LANG=${locale}

[Translations]
LANGUAGE=${lang}
PLEOF"
    fi

    # dbus + Turnstile (user services: PipeWire, etc.)
    try "Enabling dbus" \
        chroot_exec "dinitctl -o enable dbus" 2>/dev/null || true
    try "Enabling turnstile" \
        chroot_exec "dinitctl -o enable turnstiled" 2>/dev/null || true

    einfo "Plasma defaults configured"
}

# --- GNOME ---

_install_gnome() {
    einfo "Installing GNOME desktop..."

    apk_install "Installing GNOME" gnome
    apk_install "Installing GDM" gdm

    _install_gnome_apps

    # Enable GDM
    try "Enabling GDM" \
        chroot_exec "dinitctl -o enable gdm"

    _configure_gnome

    einfo "GNOME installed"
}

# _install_gnome_apps — Install selected GNOME applications
_install_gnome_apps() {
    local extras="${DESKTOP_EXTRAS:-}"

    if [[ -n "${extras}" ]]; then
        local cleaned
        cleaned=$(echo "${extras}" | tr -d '"')
        local pkg
        for pkg in ${cleaned}; do
            apk_install_if_available "${pkg}"
        done
    fi
}

# _configure_gnome — Set up GNOME defaults
_configure_gnome() {
    einfo "Configuring GNOME defaults..."

    # dbus + Turnstile (user services: PipeWire, etc.)
    try "Enabling dbus" \
        chroot_exec "dinitctl -o enable dbus" 2>/dev/null || true
    try "Enabling turnstile" \
        chroot_exec "dinitctl -o enable turnstiled" 2>/dev/null || true

    # GNOME locale — set via AccountsService for GDM + GNOME session
    local locale="${LOCALE:-en_US.UTF-8}"
    local lang="${locale%%_*}"

    if [[ "${lang}" != "en" ]]; then
        # GDM reads AccountsService; GNOME session reads dconf
        # Set system-wide locale override via dconf profile
        chroot_exec "mkdir -p /etc/dconf/profile"
        chroot_exec "cat > /etc/dconf/profile/user << 'DCONFEOF'
user-db:user
system-db:local
DCONFEOF"
        chroot_exec "mkdir -p /etc/dconf/db/local.d"
        chroot_exec "cat > /etc/dconf/db/local.d/00-locale << LOCEOF
[system/locale]
region='${locale}'
LOCEOF"
        chroot_exec "dconf update" 2>/dev/null || true
    fi

    einfo "GNOME defaults configured"
}

# --- Shared ---

# _install_gpu_drivers — Install GPU-specific open-source drivers
_install_gpu_drivers() {
    local vendor="${GPU_VENDOR:-unknown}"

    einfo "Installing GPU drivers for ${vendor} (open-source)..."

    apk_install "Installing Mesa" mesa mesa-dri

    if [[ "${HYBRID_GPU:-no}" == "yes" ]]; then
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

    apk_install "Installing Vulkan loader" vulkan-loader
}

_install_nvidia_open() {
    einfo "Installing NVIDIA open-source drivers (NVK/nouveau)..."
    apk_install "Installing NVIDIA firmware" firmware-linux-nvidia
    ewarn "Note: Chimera Linux does not support NVIDIA proprietary drivers."
    ewarn "Using NVK (nouveau Vulkan driver). Performance may be limited."
}

_install_amd_drivers() {
    einfo "Installing AMD GPU drivers..."
    apk_install "Installing AMD firmware" firmware-linux-amdgpu
    einfo "AMD GPU drivers installed (RADV Vulkan)"
}

_install_intel_drivers() {
    einfo "Installing Intel GPU drivers..."
    einfo "Intel GPU drivers installed (ANV Vulkan)"
}

# _install_pipewire — Install PipeWire audio system
_install_pipewire() {
    einfo "Installing PipeWire audio..."
    apk_install "Installing PipeWire" pipewire wireplumber
    einfo "PipeWire installed (managed by Turnstile)"
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

# install_hyprland_ecosystem — Hyprland + waybar, wofi, mako, grim, slurp, wl-clipboard, brightnessctl
install_hyprland_ecosystem() {
    if [[ "${ENABLE_HYPRLAND:-no}" != "yes" ]]; then
        return 0
    fi
    einfo "Installing Hyprland ecosystem..."
    local -a pkgs=(hyprland hyprpaper hypridle hyprlock
        waybar wofi mako grim slurp wl-clipboard brightnessctl)
    local pkg
    for pkg in "${pkgs[@]}"; do
        apk_install_if_available "${pkg}"
    done
    einfo "Hyprland ecosystem installed"
}

# install_extra_packages — Install user-specified extra packages
install_extra_packages() {
    if [[ -n "${EXTRA_PACKAGES:-}" ]]; then
        einfo "Installing extra packages: ${EXTRA_PACKAGES}"
        local pkg
        for pkg in ${EXTRA_PACKAGES}; do
            if [[ ! "${pkg}" =~ ^[a-zA-Z0-9][a-zA-Z0-9_./-]*$ ]]; then
                ewarn "Skipping invalid package name: ${pkg}"
                continue
            fi
            apk_install_if_available "${pkg}"
        done
    fi
}
