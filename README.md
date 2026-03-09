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
# Tylko konfiguracja (generuje plik .conf, nic nie instaluje)
./install.sh --configure

# Instalacja z gotowego configa (bez wizarda)
./install.sh --config moj-config.conf --install

# Wznow po awarii (skanuje dyski w poszukiwaniu checkpointow)
./install.sh --resume

# Dry-run — przechodzi caly flow BEZ dotykania dyskow
./install.sh --dry-run

# Z presetu (np. dla kolegi z AMD)
./install.sh --config presets/desktop-amd.conf --install
```

## Wymagania

- Komputer z **UEFI** (nie Legacy BIOS)
- **Secure Boot wylaczony**
- Minimum **20 GiB** wolnego miejsca na dysku
- Internet (LAN lub WiFi)
- Chimera Linux Live ISO (potrzebny `chimera-bootstrap`; `dialog`/`whiptail` opcjonalny — installer ma zaszyty `gum`)

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

### Drugie TTY — twoj najlepszy przyjaciel

Podczas instalacji masz dostep do wielu konsol. Przelaczaj sie przez **Ctrl+Alt+F1**...**F6**:

- **TTY1** — installer (tu leci instalacja)
- **TTY2-6** — wolne konsole do debugowania

Na drugim TTY mozesz:

```bash
# Podglad co sie dzieje w czasie rzeczywistym
top

# Log installera
tail -f /tmp/chimera-installer.log                  # przed chroot
tail -f /media/root/tmp/chimera-installer.log       # w chroot

# Sprawdz czy cos nie zawieszilo sie
ps aux | grep -E "tee|apk|chimera"
```

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

## Interfejs TUI

Installer ma trzy backendy TUI (w kolejnosci priorytetu):

1. **gum** (domyslny) — nowoczesny, zaszyty w repo jako `data/gum.tar.gz` (~4.5 MB). Ekstraowany automatycznie do `/tmp` na starcie. Zero dodatkowych zaleznosci.
2. **dialog** — klasyczny TUI, dostepny na wiekszosci live ISO
3. **whiptail** — fallback gdy brak `dialog`

Backend jest wybierany automatycznie. Zeby wymusic fallback na `dialog`/`whiptail`:

```bash
GUM_BACKEND=0 ./install.sh
```

### Aktualizacja gum

Zeby zaktualizowac bundlowana wersje gum:

```bash
# 1. Pobierz nowy tarball (podmien wersje)
curl -fSL -o data/gum.tar.gz \
  "https://github.com/charmbracelet/gum/releases/download/v0.18.0/gum_0.18.0_Linux_x86_64.tar.gz"

# 2. Zaktualizuj GUM_VERSION w lib/constants.sh (musi pasowac do nazwy podkatalogu w tarballi)
#    : "${GUM_VERSION:=0.18.0}"
```

## Hooki (zaawansowane)

Wlasne skrypty uruchamiane przed/po fazach instalacji:

```bash
cp hooks/before_install.sh.example hooks/before_install.sh
chmod +x hooks/before_install.sh
# Edytuj hook...
```

Dostepne hooki: `before_install`, `after_install`, `before_preflight`, `after_preflight`, `before_disks`, `after_disks`, `before_bootstrap`, `after_bootstrap`, `before_chroot_setup`, `after_chroot_setup`, `before_apk_update`, `after_apk_update`, `before_kernel`, `after_kernel`, `before_fstab`, `after_fstab`, `before_system_config`, `after_system_config`, `before_bootloader`, `after_bootloader`, `before_swap_setup`, `after_swap_setup`, `before_networking`, `after_networking`, `before_desktop`, `after_desktop`, `before_users`, `after_users`, `before_extras`, `after_extras`, `before_finalize`, `after_finalize`.

## Wykrywanie peryferiow

Installer automatycznie wykrywa sprzet i wyswietla go w ekranie Hardware:

| Peryferium | Metoda detekcji | Pakiet (opt-in w checklistie) |
|---|---|---|
| Bluetooth | `/sys/class/bluetooth/hci*` | automatycznie z desktopem |
| Czytnik linii papilarnych | USB vendor IDs (Synaptics, Goodix, AuthenTec, Validity, Elan) | `fprintd` |
| Thunderbolt | sysfs + lspci | `bolt` |
| Czujniki IIO (2-in-1) | `/sys/bus/iio/devices/` (accel, gyro, als) | `iio-sensor-proxy` |
| Kamera | `/sys/class/video4linux/video*/name` | — |
| WWAN LTE | lspci (Intel XMM7360) | `modemmanager` |

Wykryty sprzet pojawia sie jako opcje w ekranie "Dodatkowe pakiety" — widoczne tylko gdy odpowiedni sprzet zostal wykryty.

## ASUS ROG / TUF

Installer wykrywa laptopy ASUS ROG i TUF (przez DMI: board_vendor + product_name). Wykrycie jest wyswietlane w ekranie Hardware i podsumowaniu.

> **Uwaga**: Chimera Linux (musl libc) nie ma paczek `asusctl`/`supergfxctl`. Detekcja jest informacyjna — pozwala uzytkownikowi wiedziec, ze sprzet zostal rozpoznany.

## Opcje CLI

```
./install.sh [OPCJE] [POLECENIE]

Polecenia:
  (domyslnie)      Pelna instalacja (wizard + install)
  --configure       Tylko wizard konfiguracyjny
  --install         Tylko instalacja (wymaga configa)
  --resume          Wznow po awarii (skanuje dyski)

Opcje:
  --config PLIK     Uzyj podanego pliku konfiguracji
  --dry-run         Symulacja bez destrukcyjnych operacji
  --force           Kontynuuj mimo nieudanych prereq
  --non-interactive Przerwij na kazdym bledzie (bez recovery menu)
  --help            Pokaz pomoc

Zmienne srodowiskowe:
  GUM_BACKEND=0     Wymusz fallback na dialog/whiptail (pomin gum)
```

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

**P: Moge uzyc innego live ISO niz Chimera?**
Tak, dowolne live ISO z Linuxem zadziala, pod warunkiem ze ma `bash`, `git`, `sfdisk`, `chimera-bootstrap`. Installer ma zaszyty `gum` jako backend TUI, wiec `dialog`/`whiptail` nie jest wymagany.

**P: Co jesli `gum` nie dziala?**
Installer automatycznie uzyje `dialog` lub `whiptail` jako fallback. Mozesz tez wymusic fallback: `GUM_BACKEND=0 ./install.sh`.

**P: Jak wrócic do poprzedniej konfiguracji?**
Jesli uzywasz btrfs — mozesz uzyc snapshotow. W przeciwnym razie warto robic backup.
