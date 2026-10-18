tracker_url="https://security.archlinux.org/issues/all.json"
cache_dir="${XDG_CACHE_HOME:-$HOME/.cache}/pacsweep"
tracker_file="$cache_dir/all.json"
relevant_file="$cache_dir/relevant.json"

# Make's sure a fresh-enough copy of the Arch security tracker data is cached.
# Returns 0 if $tracker_file is usable (fresh or stale), 1 if there's no data at all.
download_security_tracker() {
    mkdir -p "$cache_dir"

    # Fresh enough? (modified in the last 60 minutes)
    if [[ -n "$(find "$tracker_file" -mmin -60 2>/dev/null)" ]]; then
        info "Using cached security data"
        return 0
    fi

    info "Downloading security data..."
    local tmp="$tracker_file.tmp"
    if curl -fsSL --max-time 20 -o "$tmp" "$tracker_url" && jq -e 'type == "array"' "$tmp" &>/dev/null; then
        mv "$tmp" "$tracker_file"
        success "Security data updated"
        return 0
    fi

    rm -f "$tmp"
    if [[ -f "$tracker_file" ]]; then
        warn "Download failed, using cached copy from $(date -r "$tracker_file" '+%Y-%m-%d %H:%M')"
        return 0
    fi

    error "No security data available (offline and nothing cached)"
    return 1
}


prune_security_data(){
    local installed_json
    installed_json=$(pacman -Q | jq -Rn '[inputs | split(" ") | {(.[0]): .[1]}] | add')

    local avg have fixed status
    local -a keep=()
    while IFS='|' read -r avg _ have fixed status; do
        if [[ -n "$fixed" ]]; then
            # A fix exists: still vulnerable if installed version is older than it
            if (( $(vercmp "$have" "$fixed") < 0 )); then
                keep+=("$avg")
            fi
        elif [[ "$status" == "Vulnerable" ]]; then
            # No fix yet and the tracker confirms it's vulnerable
            keep+=("$avg")
        fi
    done < <(jq -r --argjson inst "$installed_json" '
        .[]
        | select(.status != "Not affected")
        | .name as $avg | .status as $status | (.fixed // "") as $fixed
        | .packages[]
        | select($inst[.])
        | [$avg, ., $inst[.], $fixed, $status] | join("|")
    ' "$tracker_file")

        printf '%s\n' "${keep[@]}" | jq -R . | jq -s --slurpfile all "$tracker_file" '
        (map(select(. != "") | {(.): true}) | add // {}) as $keep
        | [ $all[0][] | select($keep[.name]) ]
    ' > "$relevant_file"
}



list_advisories() {
    local total
    total=$(jq length "$relevant_file")
    if (( total == 0 )); then
        success "No known vulnerabilities affect your insalled packeages"
        return 0
    fi

    local counts
    counts=$(jq -r  '
        def rank: {"Critical":0,"High":1,"Medium":2,"Low":3}[.] // 4;
        group_by(.severity) | sort_by(.[0].severity | rank)
        | map("\(length) \(.[0].severity)") | join(", ")
    ' "$relevant_file")
    warn "$total open advisories affect installed packages ($counts)"
    echo

    local sev pkgs avg fixed cves color
    printf '  %-9s %-22s %-10s %-14s %s\n' "SEVERITY" "PACKAGE" "ADVISORY" "FIXED IN" "CVEs"
    while IFS='|' read -r sev pkgs avg fixed cves; do
        case "$sev" in
            Critical|High) color="$red" ;;
            Medium)        color="$yellow" ;;
            *)             color="" ;;
        esac
        printf ' %s%-9s%s %-22s %-10s %-14s %s\n' "$color" "$sev" "$reset" "$pkgs" "$avg" "$fixed" "$cves"
    done < <(jq -r '
        def rank: {"Critical":0,"High":1,"Medium":2,"Low":3}[.] // 4;
        sort_by((.severity | rank), .packages[0])[]
        | [ .severity,
            (.packages | join(",")),
            .name,
            (.fixed // "no fix yet"),
            (if (.issues | length) > 2
                then "\(.issues[0]) +\((.issues | length) - 1) more"
                else (.issues | join(" ")) end)
          ] | join("|")
    ' "$relevant_file")
    echo
    info "Details: https://security.archlinux.org/<ADVISORY>"
}




security_fix_count=0

find_security_fixes() {
    local -A pending_old=() pending_new=()
    local name old new
    while read -r name old _ new _; do
        [[ -n "$new" ]] || continue
        pending_old[$name]="$old"
        pending_new[$name]="$new"
    done <<< "$1"

    local sev pkg fixed avg ncves
    while IFS='|' read -r _ sev pkg fixed avg ncves; do 
        new="${pending_new[$pkg]:-}"
        [[ -n "$new" ]] || continue
        if (( $(vercmp "$new" "$fixed") >= 0)); then
            echo "$sev|$pkg|${pending_old[$pkg]}|$new|$avg|$ncves"
        fi
    done < <(jq -r '
        def rank: {"Critical":0,"High":1,"Medium":2,"Low":3}[.] // 4;
        .[] | select(.fixed != null) | . as $a
        | .packages[]
        | [($a.severity | rank), $a.severity, ., $a.fixed, $a.name, ($a.issues | length)]
        | map(tostring) | join("|")
    ' "$relevant_file" | sort -t'|' -k1,1n)
}

show_security_fixes() {
    local pending="$1"
    security_fix_count=0
    [[ -n "$pending" ]] || return 0
    has jq || return 0

    if ! download_security_tracker > /dev/null 2>&1; then
        warn "Security data unavailable, cant check what this update fixes"
        return 0
    fi

    prune_security_data

    local fixes
    fixes=$(find_security_fixes "$pending")
    echo
    if [[ -z "$fixes" ]]; then
        info "No known vulnerabilities are fixed by this update"
        return 0
    fi


    security_fix_count=$(wc -l <<< "$fixes")
    local counts
    counts=$(cut -d'|' -f1 <<< "$fixes" | uniq -c | awk '{printf "%s%s %s", sep, $1, $2; sep=", "}')
    success "This update fixes $security_fix_count known vulnerabilit$( (( security_fix_count == 1 )) && echo y || echo ies) ($counts):"



    local sev pkg old new avg ncves color
    while IFS='|' read -r sev pkg old new avg ncves; do
        case "$sev" in
            Critical|High) color="$red" ;;
            Medium)        color="$yellow" ;;
            *)
        esac
         printf '  %s%-9s%s %-20s %s -> %s   %s (%s CVE%s)\n' \
            "$color" "$sev" "$reset" "$pkg" "$old" "$new" "$avg" "$ncves" "$( (( ncves == 1 )) || echo s)"
    done <<< "$fixes"
}


# Package sources the Arch security tracker doesn't cover: label|commands
untracked_sources=(
    "AUR|yay paru pikaur trizen"
    "Flatpak|flatpak"
    "Snap|snap"
    "pipx|pipx"
    "Cargo|cargo"
    "npm|npm"
    "Firmware|fwupdmgr"
)
declare -A untracked_noted=()

# Say once per run that a source can't be checked for vulnerabilities
untracked_note() {
    [[ -n "${untracked_noted[$1]:-}" ]] && return 0
    untracked_noted[$1]=1
    info "Not covered by the Arch security tracker: $1 (can't be checked for known vulnerabilities)"
}

# One combined note for every installed source the tracker doesn't cover
untracked_summary() {
    local entry label cmds list=()
    for entry in "${untracked_sources[@]}"; do
        IFS='|' read -r label cmds <<< "$entry"
        is_available "$cmds" || continue
        [[ -n "${untracked_noted[$label]:-}" ]] && continue   # already shown this run
        list+=("$label")
        untracked_noted[$label]=1
    done
    (( ${#list[@]} )) || return 0
    local joined
    joined=$(printf '%s, ' "${list[@]}")
    info "Not covered by the Arch security tracker: ${joined%, }"
}
