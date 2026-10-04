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
