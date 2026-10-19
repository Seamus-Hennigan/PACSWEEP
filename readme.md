<p align="center">
  <img src="assets/pacsweep-logo.svg" alt="PACSWEEP" width="720">
</p>

<p align="center">
  <b>Review and update everything on your Arch Linux system, with the security context pacman doesn't give you.</b><br>
  pacman · AUR · Flatpak · Snap · pipx · Cargo · npm · firmware
</p>

<p align="center">
  <img alt="License: GPL v3 or later" src="https://img.shields.io/badge/license-GPLv3%2B-blue.svg">
  <img alt="Platform: Arch Linux" src="https://img.shields.io/badge/platform-Arch%20Linux-1793d1.svg">
  <img alt="Shell: Bash" src="https://img.shields.io/badge/shell-bash-4eaa25.svg">
</p>

---

## What is PACSWEEP?

PACSWEEP is a Bash script for Arch Linux and Arch-based distros. It finds the package managers you have installed and lets you update them from one menu.

Before you update, it shows what's pending, which known vulnerabilities affect the packages you have installed, and which of them the pending update fixes. `pacman -Syu` gives you package names and version numbers; PACSWEEP adds the security context so you can decide what you're installing.

It never installs anything without asking. Every step that uses `sudo` asks for confirmation first, and a system upgrade shows the pending updates and the security fixes they include before you confirm.

<!-- TODO: add a screenshot or GIF of the menu here -->
<!-- ![PACSWEEP menu](assets/screenshot.png) -->

## Features

- **Detects package managers automatically.** The menu only shows the managers installed on your system.
- **Preview pending updates** (`--preview`). Shows repo updates (via `checkupdates`) and AUR updates without changing anything.
- **Shows what an update fixes.** Before a system upgrade, lists the known vulnerabilities the pending updates fix, most severe first, and mentions the count in the confirmation prompt.
- **Security check** (`--security`). Lists advisories from the [Arch Linux security tracker](https://security.archlinux.org/) that affect your installed package versions, most severe first, with CVEs and fixed versions.
- **Honest about coverage.** Tells you which of your package sources (AUR, Flatpak, and so on) the security tracker can't check, so no warning is never mistaken for "safe".
- **AUR package picker.** Choose which AUR updates to install (`1 3`, `2-4`, Enter for all, `n` to cancel).
- **Mirror list refresh** (`--mirrors`). Ranks mirrors with `reflector`, backs up the old list, and replaces it.
- **Update history** (`--history`). Each run's results are logged.
- **Update everything at once,** or one manager at a time.
- **Two menu styles.** Use the arrow keys with [`fzf`](https://github.com/junegunn/fzf) if it's installed, or a numbered menu if it isn't.
- **Command-line flags** for scripting and quick runs, also usable at the menu prompt.
- **Summary at the end** that lists what succeeded and what failed, plus a warning if you need to reboot for a new kernel.
- **Refuses to run as root.** It calls `sudo` only for the steps that need it.

## What the security check covers

PACSWEEP gets its vulnerability data from the [Arch Linux Security Tracker](https://security.archlinux.org/), which only tracks packages from the **official Arch repositories** (core, extra, multilib).

| Source | Checked for known vulnerabilities? |
| --- | :---: |
| Official repo packages (`pacman`) | ✓ |
| AUR packages | ✗ |
| Flatpak, Snap, pipx, Cargo, npm | ✗ |
| Firmware (`fwupd`) | ✗ |

When you update or preview, PACSWEEP says which of your installed sources aren't covered. A clean security check means *no known advisories for your official packages*, not that your whole system is free of vulnerabilities.

The tracker is maintained by volunteers, so some entries stay marked as vulnerable after upstream has fixed them, and new issues can take time to appear. Each advisory has an ID like `AVG-1234`; you can read the full details at `https://security.archlinux.org/AVG-1234`.

## Supported package managers

| Manager | What it updates | Needs sudo |
| --- | --- | :---: |
| `pacman` | System packages | ✓ |
| `yay` / `paru` / `pikaur` / `trizen` | AUR packages (first one found is used) | |
| `flatpak` | Flatpak apps | |
| `snap` | Snap packages | ✓ |
| `pipx` | pipx applications | |
| `cargo` | Cargo binaries (needs [`cargo-update`](https://github.com/nabijaczleweli/cargo-update)) | |
| `npm` | Global npm packages (only when the prefix is in `$HOME`) | |
| `fwupdmgr` | Device firmware | ✓ |

## Requirements

**Required**

- Arch Linux or an Arch-based distro
- `bash`, `pacman`, `sudo`
- `curl` and `jq` (download and read the security tracker data)
- `pacman-contrib` (provides `checkupdates`, used for previews and to see what an update fixes)

```bash
sudo pacman -S --needed curl jq pacman-contrib
```

**Optional.** Each one adds its entry to the menu when installed:

| Package | Adds |
| --- | --- |
| `fzf` | Arrow-key menu |
| `yay` or `paru` | AUR updates with the package picker (`pikaur` and `trizen` also work, without the picker) |
| `reflector` | Mirror list refresh |
| `flatpak`, `snapd`, `python-pipx`, `npm` | Updates for that manager |
| `cargo` + `cargo-update` | Cargo binary updates |
| `fwupd` | Firmware updates |

## Installation

### From source

```bash
git clone https://github.com/Seamus-Hennigan/PACSWEEP.git
cd PACSWEEP
./PACSWEEP.sh
```

PACSWEEP finds its `lib/` folder relative to the script, so you can run it from anywhere, or symlink it into your `PATH`:

```bash
ln -s "$PWD/PACSWEEP.sh" ~/.local/bin/pacsweep
```

<!-- TODO: add "From the AUR" (yay -S pacsweep) once the package is published -->

## Usage

### Interactive menu

Run the script with no arguments:

```bash
./PACSWEEP.sh
```

```
Review (start here)
    1) [p] Preview pending updates
    2) [v] Security check

Update
   10) [a] Update all packages (sudo)
   11) [s] System packages (pacman) (sudo)
   12) [u] AUR packages
   13)     Flatpak apps
   ...

Tools
   19) [i] Show system info
   20) [m] Update mirror list (reflector) (sudo)
   21) [h] Show update history
    0) [q] Exit
```

Choose an option by number or letter. To run several in order, separate them with spaces or commas, for example `1 2 10`. Press Enter to run the default (`p`, preview).

You can also type command-line flags at the prompt, so you never have to quit and rerun the script. For example, `--preview --aur` or `1 --flatpak`. In the fzf menu, type the flags and press Enter. Typing `-y` skips the sudo confirmations for that line only, `--help` shows the full list, and `--no-fzf` switches to the numbered menu.

### Command-line flags

```bash
./PACSWEEP.sh --preview          # show pending updates and what they fix, then exit
./PACSWEEP.sh --security         # list advisories affecting installed packages
./PACSWEEP.sh --all              # update everything
./PACSWEEP.sh --system --flatpak # run several actions in order
./PACSWEEP.sh -y --all           # don't ask before sudo actions
```

| Flag | Action |
| --- | --- |
| `--preview` | Preview pending updates and the vulnerabilities they fix |
| `--security` | Security check |
| `--all` | Update all packages |
| `--system` | System packages (pacman) |
| `--aur` | AUR packages |
| `--flatpak` / `--snap` / `--pipx` / `--cargo` / `--npm` | Update that manager |
| `--firmware` | Firmware |
| `--info` | Show system info |
| `--mirrors` | Update mirror list with reflector |
| `--history` | Show update history |
| `-y`, `--yes` | Don't ask before sudo actions |
| `--no-fzf` | Use the numbered menu even if fzf is installed |
| `-h`, `--help` | Show help |

`--help` lists only the actions available on your system. `-y` only skips PACSWEEP's own confirmation; pacman and your AUR helper still ask their own questions.

## How the security check works

1. **Download.** Fetches `https://security.archlinux.org/issues/all.json` into the cache folder. A copy less than an hour old is reused. A new download is checked to be valid JSON before it replaces the old copy, and if the download fails, PACSWEEP uses the cached copy and tells you how old it is.
2. **Filter to your system.** Compares each advisory with your installed packages (`pacman -Q`). It keeps an advisory if your installed version is older than the fixed version (compared with `vercmp`, the same way pacman compares versions), or if there's no fix yet and the tracker marks it as vulnerable.
3. **Security check** (`v`, `--security`) lists those advisories, most severe first, with the advisory ID, CVEs, and the fixed version or "no fix yet".
4. **Before updating,** Preview and the system update confirmation compare the advisories with your pending updates (`checkupdates`). If a pending version is the fixed version or newer, the update fixes that vulnerability and PACSWEEP lists it.

Missing data never blocks an update. If you're offline with no cached data, or `jq` isn't available, PACSWEEP skips the security section and carries on.

## Files

PACSWEEP keeps a small amount of data in the standard XDG locations:

| Path | Contents |
| --- | --- |
| `~/.cache/pacsweep/` (or `$XDG_CACHE_HOME/pacsweep/`) | Security tracker data (`all.json`) and the filtered list (`relevant.json`). Safe to delete; it's downloaded again when needed. |
| `~/.local/state/pacsweep/pacsweep.log` (or `$XDG_STATE_HOME/pacsweep/`) | Update history, one line per run. |

The mirror refresh also saves your previous mirror list as `/etc/pacman.d/mirrorlist.bak`.

## Project structure

```
PACSWEEP/
├── PACSWEEP.sh                 # main script: menu, flags, update actions
├── lib/
│   └── security_download.sh    # security tracker download, filtering, and matching
├── packaging/
│   └── PKGBUILD                # Arch package build file (makepkg -si)
├── assets/
│   └── pacsweep-logo.svg
├── .gitignore                  # keeps makepkg build output out of git
├── LICENSE
└── readme.md
```

When installed as a package, the files go here:

```
/usr/bin/pacsweep                          # PACSWEEP.sh
/usr/lib/pacsweep/security_download.sh     # lib/security_download.sh
/usr/share/doc/pacsweep/README.md          # readme.md
```

## Roadmap

### Planned (already stubbed in the menu)

- [ ] **Arch news** (`--news`): show recent [Arch Linux news](https://archlinux.org/news/) before upgrading, and highlight posts that need manual intervention.
- [ ] **Full report** (`--report`): one view with pending updates, security advisories, and news.
- [ ] **Refresh security data** (`--refresh-security`): download the tracker data again even if the cache is still fresh.

### Ideas / future scope

- [ ] Clean up the system: remove orphaned packages, clear the package cache with `paccache`, and find `.pacnew` / `.pacsave` files.
- [ ] Optional snapshot before upgrading (Timeshift / Snapper / btrfs).
- [ ] Config file (`~/.config/pacsweep/config`) for default actions, skipped managers, and cache time.
- [ ] systemd timer or notification for available updates.
- [ ] Install system-wide (`/usr/bin/pacsweep`) and publish an AUR package.
- [ ] Shell completions for bash, zsh, and fish.

<!-- TODO: move items between sections as they ship -->

## Contributing

Issues and pull requests are welcome. Before submitting:

- Run `shellcheck -x PACSWEEP.sh` (the `-x` lets it follow the `lib/` file) and fix any warnings.
- Keep the script working with `set -euo pipefail`.
- To add a menu item, add an entry to the `menu_items` array in `PACSWEEP.sh` (`number|key|label|function|sudo|requires`). The menu, the fzf picker, the command-line flags, and `--help` all read from that array.

## License

PACSWEEP is licensed under the [GNU General Public License v3.0 or later](LICENSE) (`GPL-3.0-or-later`).
