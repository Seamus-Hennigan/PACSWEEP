#!/usr/bin/env bash
set -euo pipefail


#-------------------------------------------------------------------
#                           Colors & Messages                       |
#-------------------------------------------------------------------
if [[ -t 1 ]]; then
    blue=$'\e[1;34m'
    green=$'\e[1;32m'
    yellow=$'\e[1;33m'
    red=$'\e[1;31m'
    reset=$'\e[0m'
    bold=$'\e[1m'
else
    blue="" green="" yellow="" red="" reset="" bold=""
fi

info()    { echo "${blue}::${reset} $*"; }
success() { echo "${green}✓${reset} $*"; }
warn()    { echo "${yellow}!${reset} $*"; }
error()   { echo "${red}✗${reset} $*" >&2; }

script_dir="$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")"
source "$script_dir/cache/security_download.sh"

# Checks to see if the script is being run as a regular user. If it is being run as root, it will exit with an error message.
if [[ $EUID -eq 0 ]]; then
    error "Run this script as a regular user, not as root."
    exit 1
fi


#-------------------------------------------------------------------
#                           Helpers                                |
#-------------------------------------------------------------------
# Function to check if a command exists
has() {
    command -v "$1" &> /dev/null
}

is_available() {
    local req
    for req in $1; do
        has "$req" && return 0
    done
    [[ -z "$1" ]]
}



#Sets an empty array for both Succeded and Failed
succeeded=()
failed=()

# Function that will record the results of the update process and display a message to the user. 
#It takes the name of the package manager and the command to run as arguments.
run_setup() {
    local name="$1"; shift
    info "Updating $name..."
    if "$@"; then
        success "$name updated"
        succeeded+=("$name")
    else
        error "Failed to update $name"
        failed+=("$name")
    fi
}


#-------------------------------------------------------------------
#                   List of possible package managers               |
#-------------------------------------------------------------------

# List of potential package managers to check for
candidates=(pacman yay paru pikaur trizen flatpak snap pipx cargo npm fwupdmgr)
found=()

# Check which package managers are available on the system
for pm in "${candidates[@]}"; do
    if has "$pm"; then
        found+=("$pm")
    fi
done

#-------------------------------------------------------------------
#                     Banner, Summary, Reboot Check                 |
#-------------------------------------------------------------------

# Display ASCII art banner
show_banner() {
cat <<'EOF'

██╗    ██╗███████╗██╗      ██████╗ ██████╗ ███╗   ███╗███████╗    ████████╗ ██████╗ 
██║    ██║██╔════╝██║     ██╔════╝██╔═══██╗████╗ ████║██╔════╝    ╚══██╔══╝██╔═══██╗
██║ █╗ ██║█████╗  ██║     ██║     ██║   ██║██╔████╔██║█████╗         ██║   ██║   ██║
██║███╗██║██╔══╝  ██║     ██║     ██║   ██║██║╚██╔╝██║██╔══╝         ██║   ██║   ██║
╚███╔███╔╝███████╗███████╗╚██████╗╚██████╔╝██║ ╚═╝ ██║███████╗       ██║   ╚██████╔╝
 ╚══╝╚══╝ ╚══════╝╚══════╝ ╚═════╝ ╚═════╝ ╚═╝     ╚═╝╚══════╝       ╚═╝    ╚═════╝ 
                                                                                    
██████╗  █████╗  ██████╗███████╗██╗    ██╗███████╗███████╗██████╗                    
██╔══██╗██╔══██╗██╔════╝██╔════╝██║    ██║██╔════╝██╔════╝██╔══██╗                  
██████╔╝███████║██║     ███████╗██║ █╗ ██║█████╗  █████╗  ██████╔╝                  
██╔═══╝ ██╔══██║██║     ╚════██║██║███╗██║██╔══╝  ██╔══╝  ██╔═══╝                   
██║     ██║  ██║╚██████╗███████║╚███╔███╔╝███████╗███████╗██║                       
╚═╝     ╚═╝  ╚═╝ ╚═════╝╚══════╝ ╚══╝╚══╝ ╚══════╝╚══════╝╚═╝                                                                                                             
EOF
}

log_dir="${XDG__STATE_HOME:-$HOME/.local/state}/pacsweep"
log_file="$log_dir/pacsweep.log"


write_log() {
    (( ${#succeeded[@]} + ${#failed[@]} == 0 )) && return 0
    mkdir -p "$log_dir"
    printf '%s | updated: %s | failed: %s\n' \
        "$(date '+%Y-%m-%d %H:%M:%S')" \
        "${succeeded[*]:-none}" "${failed[*]:-none}" >> "$log_file"
}

show_history() {
    if [[ ! -s "$log_file" ]]; then
        info "No update history yet (it's saved to $log_file after each run)"
        return 0
    fi
    info "Last 15 runs (from $log_file):"
    tail -n 15 "$log_file" | sed 's/^/ /'

}


show_summary() {
    (( ${#succeeded[@]} + ${#failed[@]} == 0 )) && return
    write_log
    echo
    info "Summary"
    (( ${#succeeded[@]} )) && success "Updated: ${succeeded[*]}"
    (( ${#failed[@]} )) && error "Failed: ${failed[*]}"
    return 0
}

# Checks to see if a reboot is required by checking if the current kernel version's modules directory exists. If it doesn't, it warns the user to reboot.
check_reboot() {
    if [[ ! -d "/usr/lib/modules/$(uname -r)" ]]; then
        warn "Kernel has been updated. Reboot to start using it."
    fi
}


#-------------------------------------------------------------------
#                           Info Actions                           |
#-------------------------------------------------------------------
# Function to show the last update done to the system, aswell as the kernel version and number of packages installed
show_info() {
    local last_update
    last_update=$(grep 'starting full system upgrade' /var/log/pacman.log 2> /dev/null | tail -n 1 | cut -c2-11 || true)
    
    echo "  Kernel:            $(uname -r)"
    echo "  Packages:          $(pacman -Qq | wc -l) installed"
    echo "  Last full update:  ${last_update:-unknown}"
    echo "  Package managers:  ${found[*]}"
}

# Read-only look at what would be updated. Installs nothing.
preview_updates() {
    security_fix_count=0
    local pending=""
    info "Pending repo updates:"
    if has checkupdates; then
        local rc=0
        pending=$(checkupdates) || rc=$?
        (( rc == 0 )) && printf '%s\n' "$pending"
        (( rc == 2 )) && success "Repo packages are up to date"
        (( rc == 1 )) && error "checkupdates failed"
    else
        warn "Install pacman-contrib to preview repo updates (provides checkupdates)"
    fi

    local helper
    for helper in yay paru; do
        if has "$helper"; then
            echo
            info "Pending AUR updates ($helper):"
            "$helper" -Qua 2>/dev/null || success "AUR packages are up to date"
            break
        fi
    done

    show_security_fixes "$pending"
    untracked_noted=()       # the review screen always shows the full note
    untracked_summary
    return 0
}


#-------------------------------------------------------------------
#                           Update Actions                          |
#-------------------------------------------------------------------
# Function to update system packages using pacman
update_system() {
    info "Updating system packages..."
    warn "Kernel updates rebuild drivers and can take several minutes. DO NOT INTERRUPT!"
    if sudo pacman -Syu; then
        success "System packages updated"
        succeeded+=("System packages")
    else
        error "Failed to update system packages"
        failed+=("System packages")
        return 1
    fi
}

# Function to update AUR packages using the first available AUR helper
update_aur() {
    local helper="" h
    for h in yay paru pikaur trizen; do
        if has "$h"; then
            helper="$h";
            break
        fi
    done
    if [[ -z "$helper" ]]; then
        info "No AUR helper found, skipping AUR package updates."
        return
    fi

    # Only yay and paru support -Qua; others keep their own prompt
    if [[ "$helper" != "yay" && "$helper" != "paru" ]]; then
        untracked_note "AUR"
        run_setup "AUR packages" "$helper" -Sua
        return
    fi
    
    local -a lines=() names=() picks=()
    mapfile -t lines < <("$helper" -Qua 2> /dev/null)

    if (( "${#lines[@]}" == 0 )); then
        info "No AUR packages to update."
        return
    fi

    info "${#lines[@]} AUR updates available:"
    local i name old new
    for i in "${!lines[@]}"; do
        read -r name old _ new _ <<< "${lines[i]}"
        names[i]="$name"
        printf '  %2d) %-28s %s -> %s\n' $((i + 1)) "$name" "$old" "$new"
    done
    echo
    untracked_note "AUR"

# Asks the user which AUR Install optoin they would like
    echo
    local input
    read -rp "Install which? [Enter = all, e.g. 1 3 or 2-4, n = cancel]: " input || return 0

    # Handles the input from the user on AUR update choices
     case "$input" in
        ""|a|all) picks=("${names[@]}") ;;
        n|N)      info "Skipped AUR updates"; return ;;
        *)
            local tok start end j
            declare -A seen=()
            for tok in ${input//,/ }; do
                if [[ "$tok" =~ ^([0-9]+)-([0-9]+)$ ]]; then
                    start=$((10#${BASH_REMATCH[1]})) end=$((10#${BASH_REMATCH[2]}))
                elif [[ "$tok" =~ ^[0-9]+$ ]]; then
                    start=$((10#$tok)) end=$start
                else
                    warn "Ignoring '$tok'"; continue
                fi
                for (( j = start; j <= end; j++ )); do
                    if (( j < 1 || j > ${#names[@]} )); then
                        warn "No package number $j"; continue
                    fi
                    if [[ -z "${seen[$j]:-}" ]]; then
                        seen[$j]=1
                        picks+=("${names[j - 1]}")
                    fi
                done
            done
            ;;
    esac


    if (( ${#picks[@]} == 0 )); then
        info "No AUR packages selected for update."
        return
    fi

    run_setup "AUR: ${picks[*]}" "$helper" -S --needed "${picks[@]}"
}

# Function to update Flatpak apps if Flatpak is installed
update_flatpak() {
    if has flatpak; then
        untracked_note "Flatpak"
        run_setup "Flatpak apps" flatpak update
    else
        info "Flatpak not found, skipping Flatpak app updates."
    fi
}

# Function to update Snap packages if Snap is installed
update_snap() {
    if has snap; then
        untracked_note "Snap"
        run_setup "Snap packages" sudo snap refresh
    else
        info "Snap not found, skipping Snap package updates."
    fi
}

# Function to update pipx packages if pipx is installed
update_pipx() {
    if has pipx; then
        untracked_note "pipx"
        run_setup "pipx packages" pipx upgrade-all
    else
        info "pipx not found, skipping pipx package updates."
    fi
}

# Function to update Cargo packages if Cargo is installed
update_cargo() {
    if ! has cargo; then
        info "Cargo not found, skipping Cargo package updates."
    elif ! cargo install-update --version &> /dev/null; then
        info "cargo-update not installed (cargo install cargo-update), skipping Cargo package updates."
    else
        untracked_note "Cargo"
        run_setup "Cargo packages" cargo install-update -a
    fi
}

# Function to update npm packages if npm is installed and the global prefix is in the user's home directory
update_npm() {
    if ! has npm; then
        info "npm not found, skipping npm package updates."
        return
    fi
    
    local prefix
    prefix=$(npm config get prefix 2> /dev/null || true)

    if [[ -n "$prefix" && "$prefix" == "$HOME"* ]]; then
        untracked_note "npm"
        run_setup "npm packages" npm update -g
    else
        info "npm global packages are managed by pacman, skipping"
    fi
}

# Function to update firmware using fwupdmgr if it is installed
update_firmware() {
    if has fwupdmgr; then
        info "Checking for firmware updates..."
        untracked_note "Firmware"
        fwupdmgr refresh || true
        local rc=0
        fwupdmgr update || rc=$?
        case "$rc" in
            0) success "Firmware updated"; succeeded+=("Firmware") ;;
            2) info "No firmware updates available" ;;
            *) error "Firmware update failed"; failed+=("Firmware") ;;
        esac
    else
        info "fwupdmgr not found, skipping firmware updates."
    fi
}

reflector_args=(--protocol https --latest 20 --age 12 --sort rate --number 10)


update_mirrors() {
    local mirrorlist=/etc/pacman.d/mirrorlist
    local tmp
    tmp=$(mktemp)


    info "Ranking mirros (this tests download speeds and can take a minute)..."
    if ! reflector "${reflector_args[@]}" --save "$tmp" || ! grep -q '^Server' "$tmp"; then
        rm -f "$tmp"
        error "Reflector failed, mirror list left unchanged"
        failed+=("Mirror list")
        return 1
    fi


    echo
    info "New mirror list:"
    grep '^Server' "$tmp" | sed 's/^/  /'
    echo

    if sudo cp "$mirrorlist" "$mirrorlist.bak" && sudo install -m 644 "$tmp" "$mirrorlist"; then
        rm -f "$tmp"
        success "Mirror list updated (old one saved as $mirrorlist.bak)"
        succeeded+=("Mirror list")
    else
        rm -f "$tmp"
        error "Could not write $mirrorlist"
        failed+=("Mirror list")
        return 1
    fi
}




# Quickly update all package managers in one go
update_all() {
    untracked_summary
    if update_system; then
        update_aur
        update_flatpak
        update_snap
        update_pipx
        update_cargo
        update_npm
        update_firmware
    else
        error "System update failed, skipping other updates."
    fi
}


# Security Check: download/refresh tracker data and narrow it to installed packages
show_security() {
    if download_security_tracker; then
        prune_security_data
        list_advisories
    else
        warn "Skipping security checks"
    fi
}

#-------------------------------------------------------------------
#                               Menu                               |
#-------------------------------------------------------------------

# Function to display the menu options to the user
menu_items=(
    '#Review (start here)'
    "1|p|Preview pending updates|preview_updates||"
    "2|v|Security check|show_security||"
  # "3|n|Arch news|show_news||"                    ← when built
  # "4|r|Full report|show_report||"                ← when built
    '#Update'
    "10|a|Update all packages|update_all|sudo|"
    "11|s|System packages (pacman)|update_system|sudo|pacman"
    "12|u|AUR packages|update_aur||yay paru pikaur trizen"
    "13||Flatpak apps|update_flatpak||flatpak"
    "14||Snap packages|update_snap|sudo|snap"
    "15||pipx packages|update_pipx||pipx"
    "16||Cargo packages|update_cargo||cargo"
    "17||npm packages|update_npm||npm"
    "18||Firmware|update_firmware|sudo|fwupdmgr"
    '#Tools'
    "19|i|Show system info|show_info||"
    "20|m|Update mirror list (reflector)|update_mirrors|sudo|reflector"
    "21|h|Show update history|show_history||"
  # "22|f|Refresh security data|refresh_security||" ← when built
    "0|q|Exit|quit||"
)
default_choice="p"


show_menu() {
    local item num key label action flag requires color tag
    for item in "${menu_items[@]}"; do
        if [[ "$item" == \#* ]]; then
            echo
            echo "${bold}${item#\#}${reset}"
            continue
        fi
        IFS='|' read -r num key label action flag requires <<< "$item"
        is_available "$requires" || continue
        color="" tag=""
        if [[ "$flag" == sudo ]]; then color="$yellow"; tag=" (sudo)"; fi
        printf '  %3s) %-3s %s%s%s%s\n' "$num" "${key:+[$key]}" "$color" "$label" "$tag" "$reset"
    done
    echo
    echo "  Tip: flags work here too, e.g. --preview --aur  (--help for the list)"
    echo
}

# Arrow-key menu with fzf. Prints the chosen numbers, e.g. "3 4 6".
# If the typed query starts with "-" (e.g. "--aur --flatpak"), prints that instead.
fzf_pick() {
    local item num key label action flag requires out query rc=0
    out=$(for item in "${menu_items[@]}"; do
        [[ "$item" == \#* ]] && continue
        IFS='|' read -r num key label action flag requires <<< "$item"
        is_available "$requires" || continue
        printf '%s) %s%s\n' "$num" "$label" "${flag:+ (sudo)}"
    done | fzf --multi --reverse --height=60% --prompt="PACSWEEP> " --print-query \
               --header=$'Up/Down = move, Tab = select several, Enter = run, Esc = quit\nOr type flags and press Enter, e.g. --preview --aur (--help for the list)') || rc=$?

    (( rc == 130 )) && return 1        # Esc / Ctrl+C
    query=$(head -n 1 <<< "$out")
    if [[ "$query" == -* ]]; then
        echo "$query"
        return 0
    fi
    (( rc == 0 )) || return 1
    tail -n +2 <<< "$out" | cut -d')' -f1 | tr '\n' ' '
}

# Turn one token ("3", "a", "quit", "--aur") into "function|flag|label". Fails if unknown.
resolve_choice() {
    local tok="${1,,}" item num key label action flag requires
    case "$tok" in quit|exit) tok="q" ;; esac
    if [[ "$tok" == --* ]]; then
        resolve_flag "${tok#--}"
        return
    fi
    for item in "${menu_items[@]}"; do
        [[ "$item" == \#* ]] && continue
        IFS='|' read -r num key label action flag requires <<< "$item"
        is_available "$requires" || continue
        if [[ "$tok" == "$num" || ( -n "$key" && "$tok" == "$key" ) ]]; then
            echo "$action|$flag|$label"
            return 0
        fi
    done
    return 1
}
# Ask a yes/no question. Enter = yes.
confirm() {
    local ans
    read -rp "$1 [Y/n] " ans || return 1
    [[ "${ans,,}" != n* ]]
}

pause() {
    echo
    read -rp "Press Enter to return to the menu..." _ || echo
}

# Run one menu entry ("function|flag|label"), asking first if it needs sudo
run_entry() {
    local action flag label
    IFS='|' read -r action flag label <<< "$1"
    if [[ "$flag" == sudo ]] && (( ! assume_yes )); then
        if [[ "$action" == update_system || "$action" == update_all ]]; then
            preview_updates
            echo
        fi
        local note=""
        (( security_fix_count )) && note=" It fixes $security_fix_count known vulnerabilities."
        confirm "Run \"$label\"? This uses sudo.$note" || { info "Skipped $label"; return 0; }
    fi
    "$action" || true      # one failure shouldn't kill the menu (set -e)
}

#-------------------------------------------------------------------
#                   Command-line flags and help                    |
#-------------------------------------------------------------------

# Turn a function name into a flag name: update_aur -> aur, show_info -> info
flag_name() {
    local n="${1#update_}"
    n="${n#show_}"
    echo "${n%_updates}"
}

# Find the menu entry for a command-line flag (without the leading --)
resolve_flag() {
    local item num key label action flag requires
    for item in "${menu_items[@]}"; do
        [[ "$item" == \#* ]] && continue
        IFS='|' read -r num key label action flag requires <<< "$item"
        is_available "$requires" || continue
        [[ "$action" == quit ]] && continue
        if [[ "$1" == "$(flag_name "$action")" ]]; then
            echo "$action|$flag|$label"
            return 0
        fi
    done
    return 1
}

usage() {
    local item num key label action flag requires
    echo "Usage: ${0##*/} [options]"
    echo
    echo "With no options, PACSWEEP opens the interactive menu."
    echo "All of these can also be typed at the menu prompt."
    echo
    echo "Actions:"
    for item in "${menu_items[@]}"; do
        [[ "$item" == \#* ]] && continue
        IFS='|' read -r num key label action flag requires <<< "$item"
        is_available "$requires" || continue
        [[ "$action" == quit ]] && continue
        printf '  --%-10s %s\n' "$(flag_name "$action")" "$label"
    done
    echo
    echo "Other:"
    echo "  -y, --yes     Don't ask before sudo actions"
    echo "  --no-fzf      Use the numbered menu even if fzf is installed"
    echo "  -h, --help    Show this help"
}

#-------------------------------------------------------------------
#                   Settings and command-line options              |
#-------------------------------------------------------------------


assume_yes=0
use_fzf=0
[[ -t 0 ]] && has fzf && use_fzf=1   # only when typing at a real terminal
cli_todo=()

while (( $# )); do
    case "$1" in
        -h|--help) usage; exit 0 ;;
        -y|--yes)  assume_yes=1 ;;
        --no-fzf)  use_fzf=0 ;;
        --*)
            if entry=$(resolve_flag "${1#--}"); then
                cli_todo+=("$entry")
            else
                error "Unknown option: $1"
                usage
                exit 1
            fi
            ;;
        *) error "Unknown argument: $1"; usage; exit 1 ;;
    esac
    shift
done

# Flags given: run them and exit, no menu
if (( ${#cli_todo[@]} )); then
    for entry in "${cli_todo[@]}"; do
        run_entry "$entry"
    done
    show_summary
    check_reboot
    exit 0
fi


#-------------------------------------------------------------------
#                         Interactive Menu                          |
#-------------------------------------------------------------------

# ---- Screen redraw (TEST: section clear) ----
# The banner and system info stay pinned at the top. Each time the menu comes
# back, jump to the top-left, write the header over itself, then clear
# everything below it. Whatever was below (menu, preview, update log) is wiped
# from the window; anything that had already scrolled off the top stays in the
# scrollback.
draw_header() {
    show_banner
    echo
    show_info
}

redraw_screen() {
    if [[ -t 0 && -t 1 ]]; then
        printf '\e[H'
        draw_header | sed $'s/$/\e[K/'   # \e[K wipes leftovers to the right of each line
        printf '\e[J'                    # clear from here to the bottom of the window
    else
        draw_header
    fi
}

# First draw: push whatever is already in the window (your shell prompt, earlier
# output) up into the scrollback so the redraw doesn't overwrite it
if [[ -t 0 && -t 1 ]]; then
    rows=$(tput lines 2> /dev/null) || rows=24
    for (( i = 1; i < rows; i++ )); do echo; done
fi

# On Ctrl+C, still show the summary and reboot check before exiting
trap 'echo; warn "Interrupted"; show_summary; check_reboot; exit 130' INT

running=1
while (( running )); do
    redraw_screen
    if (( use_fzf )); then
        choice=$(fzf_pick) || break        # Esc quits
        [[ -z "${choice// /}" ]] && break
    else
        show_menu
        read -rp "Choose an option (e.g. 3 4 6) [$default_choice]: " choice || { echo; break; }
        choice="${choice:-$default_choice}"
    fi

    # Check every choice first so a typo doesn't run half the list
    todo=()
    bad=0
    line_yes=0 line_help=0 line_no_fzf=0
    for tok in ${choice//,/ }; do
        case "${tok,,}" in
            -y|--yes)  line_yes=1;    continue ;;
            -h|--help) line_help=1;   continue ;;
            --no-fzf)  line_no_fzf=1; continue ;;
        esac
        if entry=$(resolve_choice "$tok"); then
            todo+=("$entry")
        else
            warn "Not a valid option: $tok"
            bad=1
        fi
    done
    if (( bad )); then pause; continue; fi

    if (( line_help )); then usage; fi
    if (( line_no_fzf && use_fzf )); then
        use_fzf=0
        info "Switched to the numbered menu"
    fi

    # -y only applies to this line, then goes back to what it was
    saved_yes=$assume_yes
    if (( line_yes )); then assume_yes=1; fi
    for entry in "${todo[@]}"; do
        if [[ "$entry" == quit\|* ]]; then
            running=0
            break
        fi
        run_entry "$entry"
    done
    assume_yes=$saved_yes

    if (( running )); then pause; fi
done

show_summary
check_reboot
info "All done!"
