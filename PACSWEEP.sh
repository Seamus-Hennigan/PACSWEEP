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



# Display ASCII art banner
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


# Checks to see if the script is being run as a regular user. If it is being run as root, it will exit with an error message.
if [[ $EUID -eq 0 ]]; then
    error "Run this script as a regular user, not as root."
    exit 1
fi


# Function to check if a command exists
has() {
    command -v "$1" &> /dev/null
}

# 
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

# List of potential package managers to check for
candidates=(pacman yay paru pikaur trizen flatpak snap pipx cargo npm fwupdmgr)
found=()

# Check which package managers are available on the system
for pm in "${candidates[@]}"; do
    if has "$pm"; then
        found+=("$pm")
    fi
done


# Function to show the last update done to the system, aswell as the kernel version and number of packages installed
show_info() {
    local last_update
    last_update=$(grep 'starting full system upgrade' /var/log/pacman.log 2> /dev/null | tail -n 1 | cut -c2-11 || true)
    
    echo "  Kernel:            $(uname -r)"
    echo "  Packages:          $(pacman -Qq | wc -l) installed"
    echo "  Last full update:  ${last_update:-unknown}"
    echo "  Package managers:  ${found[*]}"
}


# Function to update system packages using pacman
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

# Function to update npm packages if npm is installed and the global prefix is in the user's home directory
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

# Function to update firmware using fwupdmgr if it is installed
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

# Function to update AUR packages using the first available AUR helper
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


# Function to update Flatpak apps if Flatpak is installed
update_flatpak() {
    if has flatpak; then
        run_setup "Flatpak apps" flatpak update
    else
        info "Flatpak not found, skipping Flatpak app updates."
    fi
}

# Function to update Snap packages if Snap is installed
update_snap() {
    if has snap; then
        run_setup "Snap packages" sudo snap refresh
    else
        info "Snap not found, skipping Snap package updates."
    fi
}

# Function to update pipx packages if pipx is installed
update_pipx() {
    if has pipx; then
        run_setup "pipx packages" pipx upgrade-all
    else
        info "pipx not found, skipping pipx package updates."
    fi
}

# Function to update Cargo packages if Cargo is installed
update_cargo() {
    if has cargo; then
        run_setup "Cargo packages" cargo install-update -a
    else
        info "Cargo not found, skipping Cargo package updates."
    fi
}

# Quickly update all package managers in one go
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


# Checks to see if a reboot is required by checking if the current kernel version's modules directory exists. If it doesn't, it warns the user to reboot.
check_reboot() {
    if [[ ! -d "/usr/lib/modules/$(uname -r)" ]]; then
        warn "Kernel has been updated. Reboot to start using it."
    fi
}

# Function to display the menu options to the user
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


# Main loop to display the menu and handle user input
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

