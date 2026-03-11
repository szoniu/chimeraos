# CLAUDE.md — Kontekst projektu dla Claude Code

## Co to jest

Interaktywny TUI installer Chimera Linux w Bashu. Cel: boot z Chimera Linux Live ISO (Base, Plasma lub GNOME), sklonowac repo, `./install.sh` — i dostac dzialajacy desktop KDE Plasma 6 lub GNOME.

Chimera Linux to:
- **musl libc** (nie glibc)
- **LLVM/Clang** (nie GCC)
- **dinit** init system (nie systemd, nie OpenRC)
- **apk** package manager (jak Alpine)
- **FreeBSD coreutils** (nie GNU)
- **Open-source GPU drivers only** (brak NVIDIA proprietary)

## Architektura

### Model: outer process + chroot

1. Wizard TUI -> konfiguracja
2. Partycjonowanie dysku (opcjonalnie LUKS)
3. `chimera-bootstrap` -> instalacja bazowa
4. `chimera-chroot` -> konfiguracja wewnatrz
5. Kernel + bootloader + desktop + uzytkownicy
6. Finalizacja

### Struktura plikow

```
install.sh              — Entry point, parsowanie argumentow, orchestracja
configure.sh            — Wrapper: exec install.sh --configure

lib/
├── protection.sh       — Guard: sprawdza $_CHIMERA_INSTALLER
├── constants.sh        — Stale, sciezki, CONFIG_VARS[]
├── logging.sh          — elog/einfo/ewarn/eerror/die/die_trace
├── utils.sh            — try() (text fallback, LIVE_OUTPUT), checkpoint_*/validate/migrate, cleanup_target_disk, try_resume_from_disk, infer_config_from_partition
├── dialog.sh           — Wrapper gum/dialog/whiptail, primitives, wizard runner, bundled gum extraction
├── config.sh           — config_save/load/set/get/dump/diff (${VAR@Q}), validate_config()
├── hardware.sh         — detect_cpu/gpu(multi-GPU/hybrid)/disks/esp/installed_oses, detect_asus_rog, detect_bluetooth/fingerprint/thunderbolt/sensors/webcam/wwan, serialize/deserialize_detected_oses, get_hardware_summary()
├── disk.sh             — Dwufazowe: plan -> execute, mount/unmount, LUKS, shrink helpers (disk_plan_shrink via parted)
├── bootstrap.sh        — chimera-bootstrap, apk_install, apk_update
├── chroot.sh           — chimera-chroot wrapper, bind mounts, DNS
├── system.sh           — timezone, hostname, keymap, fstab, kernel, networking, users
├── bootloader.sh       — GRUB (x86_64-efi) lub systemd-boot
├── desktop.sh          — KDE Plasma / GNOME, SDDM/GDM, PipeWire, GPU drivers, extras
├── swap.sh             — zram (dinit service), swap partition
├── hooks.sh            — maybe_exec 'before_X' / 'after_X'
└── preset.sh           — preset_export/import (hardware overlay)

tui/
├── welcome.sh          — Prerequisites (root, UEFI, siec, chimera-bootstrap)
├── preset_load.sh      — skip/file/browse
├── hw_detect.sh        — detect_all_hardware + summary
├── disk_select.sh      — dysk + scheme (auto/dual-boot/manual) + _shrink_wizard()
├── filesystem_select.sh — ext4/btrfs/xfs + LUKS encryption
├── swap_config.sh      — zram/partition/none
├── network_config.sh   — hostname
├── locale_config.sh    — timezone + keymap
├── bootloader_select.sh — GRUB vs systemd-boot
├── kernel_select.sh    — lts/stable
├── gpu_config.sh       — AMD(radv)/Intel(anv)/NVIDIA(nvk) — all open-source, hybrid GPU display
├── desktop_config.sh   — KDE/GNOME wybor + apps + flatpak/printing/bluetooth toggles
├── user_config.sh      — root pwd, user, grupy, SSH
├── extra_packages.sh   — checklist (extras + conditional hw items) + wolne pole apk packages
├── preset_save.sh      — eksport
├── summary.sh          — validate_config + podsumowanie + YES + countdown
└── progress.sh         — resume detection + infobox/live output + fazowa instalacja

data/
├── gpu_database.sh     — GPU recommendation + microcode packages, get_hybrid_gpu_recommendation()
├── dialogrc            — Dark TUI theme (loaded by DIALOGRC in init_dialog)
└── gum.tar.gz          — Bundled gum v0.17.0 binary (static ELF x86-64, ~4.5 MB)

presets/                — desktop-amd.conf, desktop-intel.conf, desktop-nvidia-open.conf
hooks/                  — *.sh.example
tests/                  — test_config, test_disk, test_infer_config, test_multiboot, test_shrink, shellcheck
```

### Kluczowe moduly

#### lib/bootstrap.sh
- `chimera-bootstrap` do instalacji bazowej (jak pacstrap w Arch)
- `apk_install()` — wrapper na `apk add` w chroot
- `apk_install_if_available()` — sprawdza dostepnosc w repo

#### lib/system.sh — wielofunkcyjny modul
- `kernel_install()` — `apk add linux-lts` lub `linux-stable` + firmware + microcode + `update-initramfs`
- `install_networking()` — NetworkManager + `dinitctl enable`
- `system_create_users()` — useradd, doas (nie sudo), SSH
- `generate_fstab()` — `genfstab -U` lub manualna generacja

#### lib/bootloader.sh
- GRUB: `grub-x86_64-efi` + `grub-install` + `update-grub`
- systemd-boot: `bootctl install` + `gen-systemd-boot`
- Oba z wsparciem LUKS i dual-boot

### Konwencje (identyczne jak w Gentoo/NixOS)

- Ekrany TUI: `screen_*()` zwracaja 0=next, 1=back, 2=abort
- `try` — interaktywne recovery na bledach, text fallback bez dialog, `LIVE_OUTPUT=1` via tee
- Checkpointy — wznowienie po awarii, `checkpoint_validate` weryfikuje artefakty, `checkpoint_migrate_to_target` przenosi na dysk docelowy
- `cleanup_target_disk` — odmontowuje partycje i swap przed partycjonowaniem
- `--resume` — skanuje dyski (`try_resume_from_disk`), 0=config+checkpoints, 1=tylko checkpoints (inference), 2=nic
- `infer_config_from_partition` — odczytuje konfiguracje z fstab, hostname, localtime, vconsole.conf, crypttab
- `${VAR@Q}` — bezpieczny quoting w configach
- `(( var++ )) || true` — pod set -e
- `_CHIMERA_INSTALLER` — guard w protection.sh
- `chroot_exec` — wrapper na chimera-chroot lub chroot

### Roznice vs Gentoo i NixOS installer

| | Chimera | Gentoo | NixOS |
|---|---------|--------|-------|
| Bootstrap | chimera-bootstrap | stage3 + emerge | nixos-install |
| Pkg mgr | apk add | emerge | deklaratywny (nix) |
| Init | dinit (dinitctl) | systemd/OpenRC | systemd |
| Kernel | apk add linux-lts | genkernel/dist-kernel | nixos-generate-config |
| Bootloader | GRUB/systemd-boot | GRUB | systemd-boot |
| Users | useradd + doas | useradd + sudo | deklaratywne |
| GPU | open-source only | proprietary OK | proprietary OK |
| Chroot | chimera-chroot | manual chroot | nixos-install |
| Service mgmt | dinitctl enable | systemctl/rc-update | deklaratywne |

### Chimera Linux specyfika

- `dinitctl -o enable <service>` — wlaczanie uslug (-o = offline, w chroot)
- `doas` zamiast `sudo` — konfiguracja w `/etc/doas.conf`
- `chimera-chroot` — automatycznie montuje pseudo-FS
- `genfstab -U /` — generowanie fstab z UUID
- `update-initramfs -c -k all` — generowanie initramfs
- `update-grub` — regeneracja konfiguracji GRUB
- `gen-systemd-boot` — generacja wpisow systemd-boot
- Turnstile — manager sesji uzytkownika (PipeWire, etc.)
- Brak init system choice — zawsze dinit
- Brak CPU march flags — binarne paczki, nie kompilowane

### gum TUI backend

Third TUI backend alongside `dialog` and `whiptail`. Static binary bundled as `data/gum.tar.gz` (gum v0.17.0, ~4.5 MB). Zero network dependencies.

- Detection priority: gum > dialog > whiptail. Opt-out: `GUM_BACKEND=0`
- Desc→tag mapping via parallel arrays (gum 0.17.0 `--label-delimiter` is broken)
- Phantom ESC detection: `EPOCHREALTIME` with 150ms threshold, 3 retries then text fallback
- Terminal response handling: `COLORFGBG="15;0"`, `stty -echo`, `_gum_drain_tty()`

### Hybrid GPU detection

`detect_gpu()` scans ALL GPUs from `lspci -nn` (not just `head -1`). Classification:
- NVIDIA = always dGPU; Intel = always iGPU; AMD — if NVIDIA also present then iGPU, otherwise single
- PCI slot heuristic: bus `00` = iGPU, `01+` = dGPU
- When 2 GPUs: `HYBRID_GPU=yes`, `IGPU_*`, `DGPU_*` set
- Note: Chimera uses open-source GPU drivers only — no PRIME offload config needed

ASUS ROG detection: `detect_asus_rog()` — DMI sysfs. Sets `ASUS_ROG_DETECTED=0/1`.

### Peripheral detection

6 detection functions in `lib/hardware.sh`, called from `detect_all_hardware()`:
- `detect_bluetooth()` — `/sys/class/bluetooth/hci*`
- `detect_fingerprint()` — USB vendor IDs (06cb, 27c6, 147e, 138a, 04f3)
- `detect_thunderbolt()` — sysfs + lspci
- `detect_sensors()` — IIO sysfs
- `detect_webcam()` — `/sys/class/video4linux/video*/name`
- `detect_wwan()` — `lspci -nnd 8086:7360`

Opt-in in `tui/extra_packages.sh` checklist (visible only when detected):
- Fingerprint → fprintd, Thunderbolt → bolt, IIO sensors → iio-sensor-proxy, WWAN → modemmanager

### Multi-OS detection

`detect_installed_oses()` scans partitions for Windows (NTFS bootmgfw.efi) and Linux (/etc/os-release). Results in `DETECTED_OSES[]` assoc array, serialized to `DETECTED_OSES_SERIALIZED` for config save/load.

### Partition shrink wizard

When dual-boot selected and not enough free space, `_shrink_wizard()` in `tui/disk_select.sh` offers to shrink an existing partition:
- Supported: NTFS, ext4, btrfs (XFS cannot be shrunk)
- Safety: 1 GiB margin, minimum CHIMERA_MIN_SIZE_MIB (8 GiB)
- Helpers in `lib/disk.sh`: `disk_get_free_space_mib()`, `disk_plan_shrink()` (uses `parted resizepart`)

### Config validation

`validate_config()` in `lib/config.sh` — validates config BEFORE install. Called at entry to `screen_summary()`.
Checks: required variables, enum values, hostname RFC 1123, block device existence, cross-field consistency.

### New CONFIG_VARS

```
HYBRID_GPU, IGPU_VENDOR, IGPU_DEVICE_NAME, DGPU_VENDOR, DGPU_DEVICE_NAME
LUKS_ENABLED, LUKS_PARTITION, BOOTLOADER_TYPE
GPU_DEVICE_ID, ENABLE_FLATPAK, ENABLE_PRINTING, ENABLE_BLUETOOTH, ENABLE_SSH
BLUETOOTH_DETECTED, FINGERPRINT_DETECTED, ENABLE_FINGERPRINT
THUNDERBOLT_DETECTED, ENABLE_THUNDERBOLT, SENSORS_DETECTED, ENABLE_SENSORS
WEBCAM_DETECTED, WWAN_DETECTED, ENABLE_WWAN
WINDOWS_DETECTED, LINUX_DETECTED, DETECTED_OSES_SERIALIZED
SHRINK_PARTITION, SHRINK_PARTITION_FSTYPE, SHRINK_NEW_SIZE_MIB
```

## Testy

```bash
bash tests/test_config.sh          # Config round-trip
bash tests/test_disk.sh            # Disk planning
bash tests/test_infer_config.sh    # Config inference from installed system
bash tests/test_multiboot.sh       # Multi-OS detection + dual-boot
bash tests/test_shrink.sh          # Partition shrink wizard
```

## Jak dodawac opcje

1. Dodaj zmienna do `CONFIG_VARS[]` w `lib/constants.sh`
2. Dodaj ekran TUI lub rozszerz istniejacy
3. Dodaj logike w odpowiednim module lib/
4. Dodaj test
