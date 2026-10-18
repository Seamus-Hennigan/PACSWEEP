<p align="center">
  <img src="assets/pacsweep-logo.svg" alt="PACSWEEP" width="720">
</p>

<p align="center">
  <b>One script to review and update everything on your Arch Linux system.</b><br>
  pacman · AUR · Flatpak · Snap · pipx · Cargo · npm · firmware
</p>

<p align="center">
  <img alt="License: GPL v3" src="https://img.shields.io/badge/license-GPLv3-blue.svg">
  <img alt="Platform: Arch Linux" src="https://img.shields.io/badge/platform-Arch%20Linux-1793d1.svg">
  <img alt="Shell: Bash" src="https://img.shields.io/badge/shell-bash-4eaa25.svg">
</p>

---

## What is PACSWEEP?

PACSWEEP is a Bash script for Arch Linux and Arch-based distros. It finds the package managers you have installed and lets you update them from one menu. Before you update, you can see which updates are pending and check the Arch security tracker for advisories that affect packages you have installed.

It does not install anything without asking. Any step that uses `sudo` asks for confirmation first, and a full system upgrade shows the pending updates before you confirm.

<!-- TODO: add a screenshot or GIF of the menu here -->
<!-- ![PACSWEEP menu](docs/screenshot.png) -->

## Features

- **Detects package managers automatically.** The menu only shows the managers installed on your system.
- **Preview pending updates.** Shows repo updates (via `checkupdates`) and AUR updates without changing anything.
- **Security check.** Downloads the [Arch Linux security tracker](https://security.archlinux.org/) data, caches it for an hour, and filters it down to advisories for packages you have installed that are still vulnerable.
- **Security check** (`--security`): lists advisories affecting your installed packages, most severe first, with CVEs and fixed versions.
- **Update history** (`--history`): every run is logged to `~/.local/state/pacsweep/pacsweep.log`.
- **Mirror list refresh** (`--mirrors`): ranks mirrors with `reflector`, backs up the old list, and replaces it.
- **AUR package picker.** Choose which AUR updates to install (`1 3`, `2-4`, Enter for all, `n` to cancel).
- **Update everything at once,** or one manager at a time.
- **Two menu styles.** Use the arrow keys with [`fzf`](https://github.com/junegunn/fzf) if it's installed, or a numbered menu if it isn't.
- **Command-line flags** for scripting and quick runs.
- **Summary at the end** that lists what succeeded and what failed, plus a warning if you need to reboot for a new kernel.
- **Refuses to run as root.** It calls `sudo` only for the steps that need it.

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
- `bash`, `sudo`, `pacman`
- `curl` and `jq` for the security check

**Optional**

- `fzf` for the arrow-key menu
- `pacman-contrib` for `checkupdates` (repo update preview)
- An AUR helper: `yay` or `paru` (needed for the AUR picker)

```bash
sudo pacman -S --needed curl jq fzf pacman-contrib
```

## Installation

```bash
git clone https://github.com/Seamus-Hennigan/PACSWEEP.git
cd PACSWEEP
chmod +x PACSWEEP.sh
./PACSWEEP.sh
```

<!-- TODO: optional system-wide install / AUR package once available -->

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
   20) [i] Show system info
    0) [q] Exit
```

Choose an option by number or letter. To run several in order, separate them with spaces or commas, for example `1 2 10`. Press Enter to run the default (`p`, preview).

You can also type command-line flags at the prompt, so you never have to quit and rerun the script. For example, `--preview --aur` or `1 --flatpak`. In the fzf menu, type the flags and press Enter. Typing `-y` skips the sudo confirmations for that line only, `--help` shows the full list, and `--no-fzf` switches to the numbered menu.

### Command-line flags

```bash
./PACSWEEP.sh --preview          # show pending updates, then exit
./PACSWEEP.sh --security         # run the security check
./PACSWEEP.sh --all              # update everything
./PACSWEEP.sh --system --flatpak # run several actions in order
./PACSWEEP.sh -y --all           # don't ask before sudo actions
```

| Flag | Action |
| --- | --- |
| `--preview` | Preview pending updates |
| `--security` | Security check |
| `--all` | Update all packages |
| `--system` | System packages (pacman) |
| `--aur` | AUR packages |
| `--flatpak` / `--snap` / `--pipx` / `--cargo` / `--npm` | Update that manager |
| `--firmware` | Firmware |
| `--info` | Show system info |
| `-y`, `--yes` | Don't ask before sudo actions |
| `--no-fzf` | Use the numbered menu even if fzf is installed |
| `-h`, `--help` | Show help |

`--help` lists only the actions available on your system.

## How the security check works

1. Downloads `https://security.archlinux.org/issues/all.json` to `~/.cache/pacsweep/` (or `$XDG_CACHE_HOME/pacsweep/`). A copy less than 60 minutes old is reused instead of downloading again.
2. If the download fails, it uses the cached copy and tells you how old it is.
3. Compares each advisory with your installed packages (`pacman -Q`). It keeps an advisory if your installed version is older than the fixed version (`vercmp`), or if there's no fix yet and the tracker marks the package as vulnerable.
4. Writes the matching advisories to `~/.cache/pacsweep/relevant.json` and prints how many there are.

## Project structure

```
PACSWEEP/
├── PACSWEEP.sh                 # main script: menu, flags, update actions
├── lib/
│   └── security_download.sh    # security tracker download + filtering
├── pacsweep-logo.svg
├── LICENSE
└── readme.md
```

## Roadmap

### Planned (already stubbed in the menu)

- [ ] **Arch news** (`--news`): show recent [Arch Linux news](https://archlinux.org/news/) before upgrading, and highlight posts that need manual intervention.
- [ ] **Full report** (`--report`): one view with pending updates, security advisories, and news.
- [ ] **Refresh security data** (`--refresh-security`): download the tracker data again even if the cache is still fresh.

### Ideas / future scope

- [ ] Warn before an upgrade when a pending update fixes a known vulnerability.
- [ ] Clean up the system: remove orphaned packages, clear the package cache with `paccache`, and find `.pacnew` / `.pacsave` files.
- [ ] Optional snapshot before upgrading (Timeshift / Snapper / btrfs).
- [ ] Config file (`~/.config/pacsweep/config`) for default actions, skipped managers, and cache time.
- [ ] systemd timer or notification for available updates.
- [ ] Install system-wide (`/usr/bin/pacsweep`) and publish an AUR package.
- [ ] Shell completions for bash, zsh, and fish.

<!-- TODO: move items between sections as they ship -->
## Contributing

Issues and pull requests are welcome. Before submitting:

- Run [`shellcheck`](https://www.shellcheck.net/) on any changed scripts.
- Keep the script working with `set -euo pipefail`.
- To add a menu item, add an entry to the `menu_items` array in `PACSWEEP.sh` (`number|key|label|function|sudo|requires`). The menu, the fzf picker, and the command-line flags all read from that array.

## License

PACSWEEP is licensed under the [GNU General Public License v3.0](LICENSE).
