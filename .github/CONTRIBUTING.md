# Contributing to PACSWEEP

Thanks for your interest in PACSWEEP! Bug reports, ideas and pull requests are all welcome. This page explains how to get involved and what to expect.

## What PACSWEEP is (and isn't)

PACSWEEP is a **review-first** update tool for Arch Linux. Its job is to show you what an update changes, and why it matters for security, *before* anything is installed.

To keep it focused, contributions should fit these principles:

- **Arch Linux and Arch-based distros only.** Support for other distros is out of scope.
- **Nothing runs without the user's confirmation.** No unattended or silent installs.
- **Explicit list of supported package managers.** PACSWEEP never runs a tool just because it found it on the system.
- **No self-updating.** The package manager owns PACSWEEP's lifecycle.
- **Never run as root.** Use `sudo` only for the specific steps that need it.
- **Be honest about coverage.** If a check is skipped (missing tool, unsupported source like the AUR), say so instead of failing silently.

If you're not sure whether an idea fits, open an issue to discuss it before writing code.

## Reporting bugs

Open an issue and include:

- What you ran (the command and any flags)
- What you expected to happen, and what happened instead
- Relevant output or error messages
- Your setup: distro, `bash --version`, and which package managers are installed (yay, paru, flatpak, etc.)

You can find the run log at `~/.local/state/pacsweep/pacsweep.log`. Please remove anything private before attaching it.

## Reporting security issues

**Please don't open a public issue for security vulnerabilities.** Use GitHub's private vulnerability reporting instead (the **Security** tab → **Report a vulnerability**). I'll respond as soon as I can and credit you in the fix unless you'd rather stay anonymous.

## Suggesting features

Check the roadmap in the README and the existing issues first. If your idea isn't there, open an issue describing:

- The problem it solves
- How you imagine it working
- Whether you'd like to build it yourself

## Making a pull request

1. **Open or comment on an issue first** for anything bigger than a small fix, so we can agree on the approach before you spend time on it.
2. **Fork the repo** and create a branch from `master` with a descriptive name, like `fix-aur-picker-range` or `add-news-flag`.
3. **Keep changes focused.** One fix or feature per pull request is much easier to review.
4. **Test on a real Arch system** (or an Arch VM or container). In the pull request, say what you tested and how.
5. **Update the README** if you add or change a flag, menu option or behavior.

### Code style

PACSWEEP is a single Bash script. Please:

- Run [ShellCheck](https://www.shellcheck.net/) and fix any warnings before submitting:
  ```bash
  shellcheck PACSWEEP.sh
  bash -n PACSWEEP.sh
  ```
- Quote your variables (`"$var"`, not `$var`).
- Use `local` for variables inside functions.
- Match the existing style: function names in `snake_case`, 4-space indentation.
- Add a short comment when the *why* isn't obvious from the code.
- Prefer tools already in the dependency list over adding new ones. If a new dependency is really needed, make it optional when possible and explain why in the pull request.

### Commit messages
 
Commit messages should be detailed enough that someone reading the history understands what changed and why, without opening the diff.
 
- **Summary line:** one line in the imperative mood ("Add", "Fix", "Show", not "Added" or "Fixes") that names every area the commit touches.
- **Blank line**, then a **body** grouped by area, with a short heading for each (for example `Security check:`) followed by bullet points.
- **Each bullet says what changed and, where it matters, why:** safety checks, edge cases, and what happens on failure.
- **Wrap the body at about 72 characters** so it reads well in `git log` and on GitHub.
Example:
 
```
Add detailed security advisory list and reflector mirror refresh
 
Security check:
- List advisories affecting installed packages instead of only a count,
  sorted most severe first (Critical, High, Medium, Low)
- Show package, AVG ID, fixed version (or "no fix yet") and CVEs,
  shortening long CVE lists to the first one plus "+N more"
- Print a per-severity count line, color High/Critical red and Medium
  yellow, and a clear message when nothing is affected
 
Mirror list:
- Add Update mirror list (m, --mirrors), shown only when reflector
  is installed and confirmed before running since it needs sudo
- Run reflector as the user into a temp file and check it contains
  Server lines before replacing anything
- Back up the current list to /etc/pacman.d/mirrorlist.bak before
  installing the new one; leave it untouched if reflector fails
- Keep reflector options in a reflector_args array for easy tuning
```
 
Small fixes still get a body, even if it's one bullet explaining the cause and the fix.
## License and credit

PACSWEEP is licensed under the [GNU General Public License v3.0 or later](LICENSE). By submitting a contribution, you agree that it will be released under the same license.

You keep the copyright to your own contributions, and you'll be credited for them: your commits stay in the project history, and contributors are listed in the README.

## Code of conduct

Be respectful and constructive. Everyone here is volunteering their time, and newcomers are welcome. Harassment or personal attacks won't be tolerated.

## Questions?

Open an issue with the **question** label. No question is too small.
