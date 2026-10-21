# Security Policy

PACSWEEP runs package updates on your system and uses `sudo` for some of them, so security reports are taken seriously. Thank you for helping keep it safe.

## Supported versions

| Version | Supported |
| ------- | --------- |
| 0.1.0   | ✅ Yes    |

Only the latest release receives security fixes. Please update to the newest version before reporting an issue.

## Reporting a vulnerability

**Please don't report security vulnerabilities in public issues, pull requests or discussions.**

Report them privately through GitHub instead:

1. Go to the **Security** tab of this repository.
2. Click **Report a vulnerability**.
3. Fill in the form.

Or use this direct link: <https://github.com/Seamus-Hennigan/PACSWEEP/security/advisories/new>

Please include:

- The PACSWEEP version (`pacsweep --version` or the release tag)
- A description of the issue and its impact
- Steps to reproduce, or a proof of concept
- The command or flags involved, and any relevant output
- Your setup: distro, `bash --version`, and which optional tools are installed

### What to expect

- **Acknowledgement** within 7 days.
- **An initial assessment** (whether it's confirmed and how severe it is) as soon as possible after that.
- **Updates** as the fix progresses, and a heads-up before the fix is published.
- **Credit** in the release notes and the security advisory, unless you'd prefer to stay anonymous.

PACSWEEP is maintained by one person, so timelines may vary, but every report will get a response. Please give a reasonable amount of time to release a fix before disclosing the issue publicly.

## Scope

**In scope:** problems in PACSWEEP's own code (`PACSWEEP.sh` and the files in `lib/`), for example:

- Command injection or unsafe handling of package names, file paths or tracker data
- Running commands with `sudo` that the user didn't confirm (outside of `-y` / `--yes`)
- Unsafe temporary files, cache files or log files
- Damaging or replacing system files (such as the pacman mirror list) in an unsafe way
- Security data being shown incorrectly in a way that hides a real vulnerability

**Out of scope:** please report these to the right project instead:

- Vulnerabilities in the tools PACSWEEP calls (pacman, yay, paru, flatpak, reflector and so on). Report them to that tool's maintainers.
- Wrong or missing advisories in the Arch Linux security tracker data. Report them to the [Arch Linux Security Team](https://security.archlinux.org/).
- Malicious or vulnerable AUR packages. Report them on the package's AUR page or to the AUR maintainers.

## How PACSWEEP handles security-sensitive actions

- **It refuses to run as root.** It calls `sudo` only for the specific steps that need it.
- **It asks before running anything with `sudo`.** Menu entries that need `sudo` are marked, and each one asks for confirmation unless you pass `-y` / `--yes`.
- **Security data comes from one source over HTTPS.** PACSWEEP downloads the [Arch Linux security tracker](https://security.archlinux.org/) data with `curl`, checks that it's valid JSON before using it, and caches it in `~/.cache/pacsweep/` for one hour.
- **The mirror list is backed up before it's replaced.** `reflector` writes to a temporary file first. The new list is installed only if it contains server entries, and the old one is saved to `/etc/pacman.d/mirrorlist.bak`.
- **Logs stay on your machine.** Each run is logged to `~/.local/state/pacsweep/pacsweep.log`. PACSWEEP sends no telemetry.

### Limits of the security check

The Arch security tracker covers **official repository packages only**. AUR, Flatpak, Snap, pipx, Cargo and npm packages are **not** checked against any vulnerability database. A result with no advisories means no *known, tracked* vulnerabilities affect your official packages. It doesn't mean your system is fully secure.

## Dependencies and trust

PACSWEEP is a front end: the actual updates are done by other tools. That means its security depends on those tools too, and on what you choose to let them do. The full dependency list is in the [README](readme.md) and the PKGBUILD. This section covers only what matters for security.

- **What runs as root.** PACSWEEP itself never does. With your confirmation, it uses `sudo` to run `pacman -Syu`, `snap refresh`, firmware updates through `fwupdmgr`, and to install a new mirror list from `reflector`. AUR helpers (yay, paru, pikaur, trizen) run as your user but call `sudo` themselves to install what they build.
- **What PACSWEEP downloads.** Only the Arch security tracker data, from `security.archlinux.org` over HTTPS with `curl`. Everything else is downloaded by the package managers from their own sources, under their own security model.
- **What untrusted data PACSWEEP parses.** The tracker JSON (with `jq`) and the output of your package managers, such as package names and versions. Any way to make PACSWEEP mishandle that data is in scope for a report.
- **The biggest risk is AUR packages.** AUR packages are user-submitted build scripts that run on your machine. PACSWEEP shows you which AUR updates are pending and lets you choose which to install, but it doesn't review their contents and the security tracker doesn't cover them. Review PKGBUILDs yourself, especially for new or rarely used packages.
- **Keep the tools themselves updated.** A vulnerable `curl`, `jq`, `sudo` or package manager affects PACSWEEP too. Those are official packages, so PACSWEEP's own security check covers them.

If you find a vulnerability in one of these tools rather than in PACSWEEP, report it to that tool's maintainers (see [Scope](#scope)).
