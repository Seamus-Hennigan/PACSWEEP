#!/usr/bin/env bash
set -euo pipefail

if [[ -t 1 ]]; then
    blue=$'\e[1;34m'
    green=$'\e[1;32m'
    yellow=$'\e[1;33m'
    red=$'\e[1;31m'
    reset=$'\e[0m'
else
    blue="" green="" yellow="" red="" reset=""
fi

info()    { echo "${blue}::${reset} $*"; }
success() { echo "${green}✓${reset} $*"; }
warn()    { echo "${yellow}!${reset} $*"; }
error()   { echo "${red}✗${reset} $*" >&2; }




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


if [[ $EUID -eq 0 ]]; then
    error "Run this script as a regular user, not as root."
    exit 1
fi



has() {
    command -v "$1" &> /dev/null
}



run_setup() {
    local name="$1"
    shift
    info "Updating $name..."
    if run "$@"; then
        success "$name updated"
    else
        error "Failed to update $name"
    fi
}
candidates=(pacman yay paru pikaur trizen flatpak snap pipx cargo npm fwupdmgr)
found=()

for pm in "${candidates[@]}"; do
    if has "$pm"; then
        found+=("$pm")
    fi
done



show_info() {
    local last_update
    last_update=$(grep 'starting full system upgrade' /var/log/pacman.log 2> /dev/null | tail -n 1 | cut -c2-11 || true)
    
    echo "  Kernel:            $(uname -r)"
    echo "  Packages:          $(pacman -Qq | wc -l) installed"
    echo "  Last full update:  ${last_update:-unknown}"
    echo "  Package managers:  ${found[*]}"
}

update_system() {
    info "Updating system packages..."
    warn "Kernal updates rebuild drivers and can take several minutes. DO NOT INTERRUPT!"
    if sudo pacman -Syu; then
        success "System packages updated"
    else
        error "Failed to update system packages"
        return 1
    fi
}

update_npn() {
    if ! has npm; then
        info "npm not found, skipping npm package updates."
        return
    fi
    
    local prefix
    prefix=$(npm config get prefix 2> /dev/null || true)

    if [[ -n "$prefix" && "$prefix" == "$HOME"* ]]; then
        run_setup "npm packages" npm update -g
    else
        info "npm global packages are not managed by pacman, skipping"
    fi
}

update_firmware() {
    if has fwupdmgr; then
        info "Checking for firmware updates..."
        fwupdmgr refresh || true
        fwupdmgr update || true
        success "Firmware updates checked"
    else
        info "fwupdmgr not found, skipping firmware updates."
    fi
}

update_aur() {
    local helper
    for helper in yay paru pikar trizen; do
        if has "$helper"; then
            run_setup "AUR packages ($helper)" "$helper" -Sua
            return
        fi
    done
    info "No AUR helper found, skipping AUR package updates."
}

update_flatpak() {
    if has flatpak; then
        run_setup "Flatpak apps" flatpak update
    else
        info "Flatpak not found, skipping Flatpak app updates."
    fi
}

update_snap() {
    if has snap; then
        run_setup "Snap packages" sudo snap refresh
    else
        info "Snap not found, skipping Snap package updates."
    fi
}

update_pipx() {
    if has pipx; then
        run_setup "pipx packages" pipx upgrade-all
    else
        info "pipx not found, skipping pipx package updates."
    fi
}

update_cargo() {
    if has cargo; then
        run_setup "Cargo packages" cargo install-update -a
    else
        info "Cargo not found, skipping Cargo package updates."
    fi
}

update_all() {
    if update_system; then
        update_aur
        update_flatpak
        update_snap
        update_pipx
        update_cargo
        update_npn
        update_firmware
    else
        error "System update failed, skipping other updates."
    fi
}



check_reboot() {
    if [[ ! -d "/usr/lib/modules/$(uname -r)" ]]; then
        warn "Kernel has been updated. Reboot to start using it."
    fi
}

show_menu() {
    echo
    echo "Select an option:"
    echo "1) Update all packages"
    echo "2) Update system packages only"
    echo "3) Update AUR packages only"
    echo "4) Update Flatpak apps only"
    echo "5) Update Snap packages only"
    echo "6) Update pipx packages only"
    echo "7) Update Cargo packages only"
    echo "8) Update npm packages only"
    echo "9) Update firmware only"
    echo "10) Show system info"
    echo "0) Exit"
}


echo
show_info

while true; do
    show_menu
    read -rp "Choose an option: " choice
    case "$choice" in
        1) update_all ;;
        2) update_system || true ;;
        3) update_aur ;;
        4) update_flatpak ;;
        5) update_snap ;;
        6) update_pipx ;;
        7) update_cargo ;;
        8) update_npn ;;
        9) update_firmware ;;
        10) show_info ;;
        0) break ;;
        *) warn "Not a valid option: $choice" ;;
    esac
done

check_reboot
info "All done!"

