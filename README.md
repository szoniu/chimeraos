# Chimera Linux TUI Installer

Interaktywny installer Chimera Linux z interfejsem TUI (dialog). Przeprowadza za reke przez caly proces instalacji — od partycjonowania dysku po dzialajacy desktop KDE Plasma 6.

Chimera Linux: musl libc + LLVM/Clang + dinit + apk + FreeBSD coreutils. Binarne paczki, instalacja w ~15-30 minut.

## Krok po kroku

### 1. Przygotuj bootowalny pendrive

Pobierz Chimera Linux ISO:

- https://chimera-linux.org/download/ -> **GNOME Desktop** lub **Base**

Nagraj na pendrive:

```bash
# UWAGA: /dev/sdX to pendrive, nie dysk systemowy!
sudo dd if=chimera-linux-*.iso of=/dev/sdX bs=4M status=progress
sync
```

Na Windows: [Rufus](https://rufus.ie) lub [balenaEtcher](https://etcher.balena.io).

### 2. Bootuj z pendrive

- BIOS/UEFI: F2, F12, lub Del przy starcie
- **Wylacz Secure Boot**
- Boot z USB w trybie **UEFI**
- Login: `anon`, haslo: `chimera`
- Root: `doas -s` (po zalogowaniu)

### 3. Polacz sie z internetem

#### Kabel LAN

Powinno dzialac od razu:

```bash
ping -c 3 chimera-linux.org
```

#### WiFi

**`nmcli`** (NetworkManager — dostepny na Chimera Live):

```bash
nmcli device wifi list
nmcli device wifi connect 'NazwaSieci' password 'TwojeHaslo'
```

> **Uwaga**: Uzywaj **pojedynczych cudzyslowow** `'...'` w nmcli. Podwojne cudzyslowy moga powodowac problemy ze znakami specjalnymi w nazwie sieci lub hasle.

**`nmtui`** (tekstowy interfejs NetworkManager):

```bash
nmtui
```

**`iwctl`** (iwd — jesli dostepny):

```bash
iwctl
station wlan0 scan
station wlan0 get-networks
station wlan0 connect "NazwaSieci"
exit
```

Sprawdz: `ping -c 3 chimera-linux.org`

### 4. Ustaw date (wazne!)

Live ISO moze miec nieprawidlowa date systemowa. Ustaw ja **przed** klonowaniem repo:

```bash
date -s "2026-02-25 12:00:00"
```

Bez poprawnej daty `git clone` moze nie dzialac (blad SSL "certificate is not yet valid").

### 5. Sklonuj repo i uruchom

```bash
doas -s
apk add bash git
git clone https://github.com/szoniu/chimeraos.git
cd chimeraos
./install.sh
```

Albo bez git:

```bash
doas -s
apk add bash
curl -L https://github.com/szoniu/chimeraos/archive/main.tar.gz | tar xz
cd chimeraos-main
./install.sh
```

### 6. Po instalacji

Wyjmij pendrive, reboot. Zobaczysz bootloader (GRUB lub systemd-boot), potem SDDM z KDE Plasma 6.

Po zalogowaniu mozesz instalowac paczki:

```bash
doas apk add pakiet
```

## Alternatywne uruchomienie

```bash
./install.sh                    # Pelna instalacja (wizard + install)
./install.sh --configure        # Tylko wizard (generuje config)
./install.sh --install          # Tylko instalacja (wymaga configa)
./install.sh --config plik.conf --install   # Z gotowego configa
./install.sh --resume           # Wznowienie przerwanej instalacji
./install.sh --dry-run          # Symulacja bez dotykania dyskow
./install.sh --force            # Kontynuuj mimo bledow prerequisite
./install.sh --non-interactive  # Abort zamiast recovery menu
```

## Wymagania

- Komputer z **UEFI** (nie Legacy BIOS)
- **Secure Boot wylaczony**
- Minimum **20 GiB** wolnego miejsca na dysku
- Internet (LAN lub WiFi)
- Chimera Linux Live ISO (potrzebny `chimera-bootstrap` i `dialog`)

## Co robi installer

| # | Ekran | Co konfigurujesz |
|---|-------|-------------------|
| 1 | Welcome | Sprawdzenie wymagan (root, UEFI, siec, chimera-bootstrap) |
| 2 | Preset | Opcjonalne zaladowanie gotowej konfiguracji |
| 3 | Hardware | Podglad wykrytego CPU, GPU (hybrid), dyskow, peryferiow, Windows/Linux |
| 4 | Dysk | Wybor dysku + schemat (auto/dual-boot/manual) |
| 5 | Filesystem | ext4 / btrfs / XFS + opcjonalne LUKS szyfrowanie |
| 6 | Swap | zram / partycja / brak |
| 7 | Siec | Hostname |
| 8 | Locale | Timezone + keymap |
| 9 | Bootloader | GRUB / systemd-boot |
| 10 | Kernel | LTS / Stable |
| 11 | GPU | AMD (RADV) / Intel (ANV) / NVIDIA (NVK, open-source) |
| 12 | Desktop | KDE Plasma 6 + aplikacje + Flatpak/drukowanie/Bluetooth |
| 13 | Uzytkownicy | Root, user, grupy, SSH |
| 14 | Pakiety | Dodatkowe pakiety apk + opcje sprzetowe (fingerprint, Thunderbolt, itp.) |
| 15 | Preset save | Eksport konfiguracji |
| 16 | Podsumowanie | Przeglad + potwierdzenie YES + countdown |

Po potwierdzeniu installer:
1. Partycjonuje dysk (opcjonalnie z LUKS)
2. Uruchamia `chimera-bootstrap` (instalacja bazowa)
3. Wchodzi do chroota (`chimera-chroot`)
4. Instaluje kernel, bootloader, KDE Plasma
5. Konfiguruje system (timezone, hostname, uzytkownicy)
6. Wlacza uslugi dinit (SDDM, NetworkManager, etc.)

## Dual-boot z Windows/Linux

- Auto-wykrywanie ESP z Windows Boot Manager i innych Linuksow
- ESP nigdy nie jest formatowany przy reuse
- GRUB + os-prober automatycznie widzi Windows
- Wizard do zmniejszania partycji jesli brak wolnego miejsca (NTFS, ext4, btrfs)
- Ostrzezenia o istniejacych OS-ach na wybranych partycjach

## Presety

```
presets/desktop-amd.conf           # AMD + ext4 + GRUB
presets/desktop-intel.conf         # Intel + btrfs + systemd-boot
presets/desktop-nvidia-open.conf   # NVIDIA (open) + LUKS + GRUB
```

Presety przenosne — sprzet re-wykrywany przy imporcie.

## Typowe problemy

### `git clone` nie dziala (SSL certificate not yet valid)

Live ISO ma zla date. Napraw:

```bash
date -s "2026-02-25 12:00:00"
```

### DNS nie dziala (Temporary failure in name resolution)

```bash
echo "nameserver 8.8.8.8" >> /etc/resolv.conf
```

Installer probuje to naprawic automatycznie (ensure_dns), ale jesli nie — dodaj recznie.

### nmcli nie laczy z WiFi

Uzywaj **pojedynczych cudzyslowow**:

```bash
nmcli device wifi connect 'MojaSiec' password 'MojeHaslo'
```

### Instalacja przez SSH

Na Chimera Live mozesz podlaczyc sie przez SSH z innego komputera:

```bash
# Na Live ISO:
passwd root                     # Ustaw haslo roota
dinitctl start sshd             # Uruchom SSH

# Sprawdz IP:
ip addr
```

Z innego komputera:

```bash
ssh -o PubkeyAuthentication=no root@ADRES_IP
```

> **Uwaga**: Jesli laptop jest na innej sieci (np. WiFi dla gosci), SSH nie zadziala. Oba urzadzenia musza byc w tej samej sieci LAN.

> **Tip**: Po restarcie Live ISO klucz SSH sie zmienia. Jesli `ssh` odmawia polaczenia ("WARNING: REMOTE HOST IDENTIFICATION HAS CHANGED"), uruchom: `ssh-keygen -R ADRES_IP`

### System sie zawiesza podczas instalacji

Na maszynach z mala iloscia RAM (<8 GB) kompilacja duzych pakietow moze powodowac zawieszenie. Chimera uzywa binarnych paczek, wiec problem jest rzadszy niz przy Gentoo, ale nadal mozliwy.

## Co jesli cos pojdzie nie tak

- **Blad** — menu: Retry / Shell / Continue / Log / Abort
- **Awaria** — checkpointy faz, wznowienie od ostatniego kroku
- **Log** — `/tmp/chimera-installer.log`
- **Wznowienie** — po awarii/restarcie: `./install.sh --resume` skanuje dyski, odzyskuje config i checkpointy, i wznawia od ostatniego ukonczonego kroku

## Roznice vs inne installery

| | Chimera | Gentoo | NixOS |
|---|---------|--------|-------|
| Czas | ~15-30 min | 3-8h | ~15-30 min |
| Pakiety | apk (binarne) | emerge (ze zrodel) | nix (binarne) |
| Init | dinit | systemd/OpenRC | systemd |
| libc | musl | glibc | glibc |
| GPU | open-source only | proprietary OK | proprietary OK |
| Rollback | btrfs snapshots | brak | wbudowany |
| LUKS | wbudowane | do zrobienia | wbudowane |

## Testy

```bash
bash tests/test_config.sh          # Config round-trip (16 assertions)
bash tests/test_disk.sh            # Disk planning (9 assertions)
bash tests/test_infer_config.sh    # Config inference from installed system (38 assertions)
bash tests/test_shrink.sh          # Partition shrink planning (33 assertions)
bash tests/test_multiboot.sh       # Multi-boot OS detection + serialization (26 assertions)
bash tests/shellcheck.sh           # Lint
```

## Struktura

```
install.sh              — Entry point
configure.sh            — Wrapper: tylko wizard
lib/                    — Moduly (constants, logging, dialog, hardware, disk, bootstrap...)
tui/                    — 16 ekranow TUI
data/                   — GPU database, dialogrc theme, gum binary cache
presets/                — Gotowe presety
hooks/                  — before/after hooks
tests/                  — Testy
```

## FAQ

**P: Jak dlugo trwa instalacja?**
~15-30 minut (binarne paczki). Zalezy od predkosci internetu.

**P: Moge na VM?**
Tak, UEFI mode. VirtualBox: Settings -> System -> Enable EFI.

**P: Dlaczego nie ma sterownikow NVIDIA proprietary?**
Chimera Linux uzywa musl libc i nie wspiera proprietarnych sterownikow NVIDIA. Uzywany jest NVK (nouveau Vulkan) — open-source.

**P: Czym jest dinit?**
Lekki init system z zaleznosciami miedzy uslugami. Zamiast `systemctl` uzywasz `dinitctl enable/start/stop`.

**P: Czym jest doas?**
Chimera uzywa `doas` zamiast `sudo`. Skladnia: `doas apk add pakiet`.

**P: Jak wrócic do poprzedniej konfiguracji?**
Jesli uzywasz btrfs — mozesz uzyc snapshotow. W przeciwnym razie warto robic backup.
