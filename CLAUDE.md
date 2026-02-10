# CLAUDE.md — Kontekst projektu dla Claude Code

## Co to jest

Interaktywny TUI installer Chimera Linux w Bashu. Cel: boot z Chimera Linux Live ISO, sklonowac repo, `./install.sh` — i dostac dzialajacy desktop KDE Plasma 6.

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
├── utils.sh            — try(), checkpoint_*, is_root/is_efi/has_network
├── dialog.sh           — Wrapper dialog/whiptail, wizard runner
├── config.sh           — config_save/load/set/get (${VAR@Q})
├── hardware.sh         — detect_cpu/gpu/disks/esp
├── disk.sh             — Dwufazowe: plan -> execute, mount/unmount, LUKS
├── bootstrap.sh        — chimera-bootstrap, apk_install, apk_update
├── chroot.sh           — chimera-chroot wrapper, bind mounts, DNS
├── system.sh           — timezone, hostname, keymap, fstab, kernel, networking, users
├── bootloader.sh       — GRUB (x86_64-efi) lub systemd-boot
├── desktop.sh          — KDE Plasma, SDDM, PipeWire, GPU drivers, extras
├── swap.sh             — zram (dinit service), swap partition
├── hooks.sh            — maybe_exec 'before_X' / 'after_X'
└── preset.sh           — preset_export/import (hardware overlay)

tui/
├── welcome.sh          — Prerequisites (root, UEFI, siec, chimera-bootstrap)
├── preset_load.sh      — skip/file/browse
├── hw_detect.sh        — detect_all_hardware + summary
├── disk_select.sh      — dysk + scheme (auto/dual-boot/manual)
├── filesystem_select.sh — ext4/btrfs/xfs + LUKS encryption
├── swap_config.sh      — zram/partition/none
├── network_config.sh   — hostname
├── locale_config.sh    — timezone + keymap
├── bootloader_select.sh — GRUB vs systemd-boot
├── kernel_select.sh    — lts/stable
├── gpu_config.sh       — AMD(radv)/Intel(anv)/NVIDIA(nvk) — all open-source
├── desktop_config.sh   — KDE apps + flatpak/printing/bluetooth toggles
├── user_config.sh      — root pwd, user, grupy, SSH
├── extra_packages.sh   — wolne pole apk packages
├── preset_save.sh      — eksport
├── summary.sh          — podsumowanie + YES + countdown
└── progress.sh         — gauge + fazowa instalacja

data/
└── gpu_database.sh     — GPU recommendation + microcode packages

presets/                — desktop-amd.conf, desktop-intel.conf, desktop-nvidia-open.conf
hooks/                  — *.sh.example
tests/                  — test_config, test_disk, shellcheck
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
- `try` — interaktywne recovery na bledach
- Checkpointy — wznowienie po awarii
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

## Testy

```bash
bash tests/test_config.sh          # 13 assertions
bash tests/test_disk.sh            # 9 assertions
```

## Jak dodawac opcje

1. Dodaj zmienna do `CONFIG_VARS[]` w `lib/constants.sh`
2. Dodaj ekran TUI lub rozszerz istniejacy
3. Dodaj logike w odpowiednim module lib/
4. Dodaj test
