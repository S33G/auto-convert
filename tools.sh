#!/bin/bash
set -uo pipefail

if [[ -f ".env" ]]; then
    set -a
    # shellcheck disable=SC1091
    source .env
    set +a
fi

MUSIC_DIR="${MUSIC_DIR:-./music}"
OUTPUT_DIR_HOST="${OUTPUT_DIR_HOST:-${OUTPUT_DIR:-$MUSIC_DIR}}"
INPUT_FORMAT="${INPUT_FORMAT:-flac}"
OUTPUT_FORMAT="${OUTPUT_FORMAT:-aiff}"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m'

ok()      { echo -e "  ${GREEN}✔${NC}  $*"; }
warn()    { echo -e "  ${YELLOW}⚠${NC}  $*"; }
fail()    { echo -e "  ${RED}✖${NC}  $*"; }
info()    { echo -e "  ${CYAN}→${NC}  $*"; }
section() { echo ""; echo -e "${BOLD}$*${NC}"; echo -e "${DIM}$(printf '─%.0s' {1..52})${NC}"; }

confirm() {
    local prompt="$1"
    if [[ ! -t 0 ]]; then
        echo ""
        fail "Stdin is not interactive — cannot prompt for confirmation. Aborting."
        exit 1
    fi
    echo ""
    echo -e "  ${YELLOW}${BOLD}⚠  WARNING:${NC} $prompt"
    echo ""
    printf "  Type 'yes' to confirm: "
    local response
    read -r response
    if [[ "$response" != "yes" ]]; then
        echo ""
        echo "  Aborted."
        echo ""
        exit 0
    fi
}

find_files() {
    local dir="$1"
    local fmt="$2"
    local f
    while IFS= read -r f; do
        [[ -n "$f" ]] && printf '%s\n' "$f"
    done < <(find "$dir" -type f -iname "*.${fmt}" 2>/dev/null | sort)
}

cmd_doctor() {
    echo ""
    echo -e "${BOLD}${CYAN}  auto-convert · Doctor${NC}"
    echo -e "${DIM}  $(printf '─%.0s' {1..52})${NC}"

    section "  System"

    if docker info > /dev/null 2>&1; then
        ok "Docker is running"
    else
        fail "Docker is not running or not accessible"
    fi

    if docker compose version > /dev/null 2>&1; then
        local dc_ver
        dc_ver=$(docker compose version 2>/dev/null | head -1)
        ok "docker compose: $dc_ver"
    else
        fail "docker compose not found"
    fi

    section "  Configuration"

    if [[ -f ".env" ]]; then
        ok ".env found"
    else
        warn ".env not found — using defaults"
        info "Create one: cp .env.example .env"
    fi

    info "Watch dir (host):   $MUSIC_DIR"
    info "Output dir (host):  $OUTPUT_DIR_HOST"
    info "Input format:       .$INPUT_FORMAT"
    info "Output format:      .$OUTPUT_FORMAT"

    if [[ "$OUTPUT_DIR_HOST" == "$MUSIC_DIR" ]]; then
        info "Mode: in-place (input and output share the same directory)"
    else
        info "Mode: separate directories"
    fi

    section "  Directories"

    if [[ -d "$MUSIC_DIR" ]]; then
        ok "Watch directory exists"
        if [[ -r "$MUSIC_DIR" ]]; then ok "Watch directory is readable"; else fail "Watch directory is NOT readable"; fi
        if [[ -w "$MUSIC_DIR" ]]; then ok "Watch directory is writable"; else warn "Watch directory is NOT writable"; fi

        local input_files input_count=0
        input_files=$(find_files "$MUSIC_DIR" "$INPUT_FORMAT")
        [[ -n "$input_files" ]] && input_count=$(echo "$input_files" | wc -l | tr -d ' ')
        info "*.${INPUT_FORMAT} files: $input_count"
    else
        fail "Watch directory does not exist: $MUSIC_DIR"
        info "Create it: mkdir -p $MUSIC_DIR"
    fi

    if [[ "$OUTPUT_DIR_HOST" != "$MUSIC_DIR" ]]; then
        if [[ -d "$OUTPUT_DIR_HOST" ]]; then
            ok "Output directory exists"
            if [[ -w "$OUTPUT_DIR_HOST" ]]; then ok "Output directory is writable"; else warn "Output directory is NOT writable"; fi

            local output_files output_count=0
            output_files=$(find_files "$OUTPUT_DIR_HOST" "$OUTPUT_FORMAT")
            [[ -n "$output_files" ]] && output_count=$(echo "$output_files" | wc -l | tr -d ' ')
            info "*.${OUTPUT_FORMAT} files: $output_count"
        else
            warn "Output directory does not exist: $OUTPUT_DIR_HOST"
            info "It will be created automatically on first run"
        fi
    fi

    section "  Disk Space"

    if [[ -d "$MUSIC_DIR" ]]; then
        local df_watch
        df_watch=$(df -h "$MUSIC_DIR" 2>/dev/null | tail -1)
        info "Watch:  $df_watch"
    fi

    if [[ "$OUTPUT_DIR_HOST" != "$MUSIC_DIR" ]] && [[ -d "$OUTPUT_DIR_HOST" ]]; then
        local df_out
        df_out=$(df -h "$OUTPUT_DIR_HOST" 2>/dev/null | tail -1)
        info "Output: $df_out"
    fi

    section "  Container"

    local container_live=false

    if docker inspect auto-convert > /dev/null 2>&1; then
        local running health_status
        running=$(docker inspect --format='{{.State.Running}}' auto-convert 2>/dev/null)
        health_status=$(docker inspect \
            --format='{{if .State.Health}}{{.State.Health.Status}}{{else}}no-healthcheck{{end}}' \
            auto-convert 2>/dev/null || echo "unknown")

        if [[ "$running" == "true" ]]; then
            container_live=true
            case "$health_status" in
                healthy)
                    ok "Container is running and healthy" ;;
                starting)
                    warn "Container is running (health check still starting)" ;;
                unhealthy)
                    warn "Container is running but unhealthy" ;;
                *)
                    ok "Container is running" ;;
            esac
        else
            fail "Container exists but is not running"
            info "Start with: docker compose up -d"
        fi
    else
        warn "Container 'auto-convert' not found"
        info "Start with: docker compose up -d"
    fi

    if [[ "$container_live" == "true" ]]; then
        if docker compose exec -T auto-convert which ffmpeg > /dev/null 2>&1; then
            local ffmpeg_ver
            ffmpeg_ver=$(docker compose exec -T auto-convert ffmpeg -version 2>&1 | head -1 \
                | sed 's/ffmpeg version //')
            ok "ffmpeg: $ffmpeg_ver"
        else
            fail "ffmpeg not found in container"
        fi

        if docker compose exec -T auto-convert which inotifywait > /dev/null 2>&1; then
            ok "inotifywait is available"
        else
            fail "inotifywait not found in container"
        fi

        if docker compose exec -T auto-convert pgrep -f watcher.sh > /dev/null 2>&1; then
            ok "watcher.sh process is running"
        else
            warn "watcher.sh process not detected"
        fi
    fi

    echo ""
    echo -e "  ${DIM}$(printf '─%.0s' {1..52})${NC}"
    echo ""
}

cmd_purge_input() {
    echo ""
    echo -e "${BOLD}${CYAN}  auto-convert · Purge Input${NC}"
    echo -e "${DIM}  $(printf '─%.0s' {1..52})${NC}"

    if [[ ! -d "$MUSIC_DIR" ]]; then
        echo ""
        fail "Watch directory does not exist: $MUSIC_DIR"
        echo ""
        exit 1
    fi

    local files_str
    files_str=$(find_files "$MUSIC_DIR" "$INPUT_FORMAT")

    if [[ -z "$files_str" ]]; then
        echo ""
        info "No *.${INPUT_FORMAT} files found in: $MUSIC_DIR"
        echo ""
        exit 0
    fi

    local count
    count=$(echo "$files_str" | wc -l | tr -d ' ')

    echo ""
    info "Found $count *.${INPUT_FORMAT} file(s) in: $MUSIC_DIR"
    echo ""
    while IFS= read -r f; do
        echo -e "    ${DIM}$f${NC}"
    done <<< "$files_str"

    confirm "This will permanently delete $count *.${INPUT_FORMAT} file(s) from $MUSIC_DIR"

    echo ""
    info "Deleting..."
    local deleted=0
    while IFS= read -r f; do
        rm -f "$f"
        echo "    Deleted: $f"
        (( deleted++ )) || true
    done <<< "$files_str"

    echo ""
    ok "Deleted $deleted file(s)."

    local empty_dirs
    empty_dirs=$(find "$MUSIC_DIR" -mindepth 1 -depth -type d -empty 2>/dev/null) || true
    if [[ -n "$empty_dirs" ]]; then
        local dir_count
        dir_count=$(echo "$empty_dirs" | wc -l | tr -d ' ')
        find "$MUSIC_DIR" -mindepth 1 -depth -type d -empty -delete 2>/dev/null || true
        ok "Removed $dir_count empty director(ies)."
    fi
    echo ""
}

cmd_purge_output() {
    echo ""
    echo -e "${BOLD}${CYAN}  auto-convert · Purge Output${NC}"
    echo -e "${DIM}  $(printf '─%.0s' {1..52})${NC}"

    if [[ ! -d "$OUTPUT_DIR_HOST" ]]; then
        echo ""
        fail "Output directory does not exist: $OUTPUT_DIR_HOST"
        echo ""
        exit 1
    fi

    local files_str
    files_str=$(find_files "$OUTPUT_DIR_HOST" "$OUTPUT_FORMAT")

    if [[ -z "$files_str" ]]; then
        echo ""
        info "No *.${OUTPUT_FORMAT} files found in: $OUTPUT_DIR_HOST"
        echo ""
        exit 0
    fi

    local count
    count=$(echo "$files_str" | wc -l | tr -d ' ')

    echo ""
    info "Found $count *.${OUTPUT_FORMAT} file(s) in: $OUTPUT_DIR_HOST"
    echo ""
    while IFS= read -r f; do
        echo -e "    ${DIM}$f${NC}"
    done <<< "$files_str"

    confirm "This will permanently delete $count *.${OUTPUT_FORMAT} file(s) from $OUTPUT_DIR_HOST"

    echo ""
    info "Deleting..."
    local deleted=0
    while IFS= read -r f; do
        rm -f "$f"
        echo "    Deleted: $f"
        (( deleted++ )) || true
    done <<< "$files_str"

    echo ""
    ok "Deleted $deleted file(s)."

    local empty_dirs
    empty_dirs=$(find "$OUTPUT_DIR_HOST" -mindepth 1 -depth -type d -empty 2>/dev/null) || true
    if [[ -n "$empty_dirs" ]]; then
        local dir_count
        dir_count=$(echo "$empty_dirs" | wc -l | tr -d ' ')
        find "$OUTPUT_DIR_HOST" -mindepth 1 -depth -type d -empty -delete 2>/dev/null || true
        ok "Removed $dir_count empty director(ies)."
    fi
    echo ""
}

cmd_purge() {
    echo ""
    echo -e "${BOLD}${CYAN}  auto-convert · Purge All${NC}"
    echo -e "${DIM}  $(printf '─%.0s' {1..52})${NC}"

    local input_files_str="" output_files_str=""
    local input_count=0 output_count=0

    if [[ -d "$MUSIC_DIR" ]]; then
        input_files_str=$(find_files "$MUSIC_DIR" "$INPUT_FORMAT")
        [[ -n "$input_files_str" ]] && input_count=$(echo "$input_files_str" | wc -l | tr -d ' ')
    fi

    if [[ -d "$OUTPUT_DIR_HOST" ]]; then
        output_files_str=$(find_files "$OUTPUT_DIR_HOST" "$OUTPUT_FORMAT")
        [[ -n "$output_files_str" ]] && output_count=$(echo "$output_files_str" | wc -l | tr -d ' ')
    fi

    local total=$(( input_count + output_count ))

    if [[ $total -eq 0 ]]; then
        echo ""
        info "No matching files found in either directory."
        echo ""
        exit 0
    fi

    echo ""

    if [[ $input_count -gt 0 ]]; then
        info "Input ($MUSIC_DIR): $input_count *.${INPUT_FORMAT} file(s)"
        while IFS= read -r f; do
            echo -e "    ${DIM}$f${NC}"
        done <<< "$input_files_str"
    fi

    if [[ $output_count -gt 0 ]]; then
        [[ $input_count -gt 0 ]] && echo ""
        info "Output ($OUTPUT_DIR_HOST): $output_count *.${OUTPUT_FORMAT} file(s)"
        while IFS= read -r f; do
            echo -e "    ${DIM}$f${NC}"
        done <<< "$output_files_str"
    fi

    confirm "This will permanently delete $total file(s) from both directories"

    echo ""
    info "Deleting..."
    local deleted=0

    if [[ $input_count -gt 0 ]]; then
        while IFS= read -r f; do
            rm -f "$f"
            echo "    Deleted: $f"
            (( deleted++ )) || true
        done <<< "$input_files_str"
    fi

    if [[ $output_count -gt 0 ]]; then
        while IFS= read -r f; do
            rm -f "$f"
            echo "    Deleted: $f"
            (( deleted++ )) || true
        done <<< "$output_files_str"
    fi

    echo ""
    ok "Deleted $deleted file(s)."

    local total_dir_count=0
    local empty_input_dirs="" empty_output_dirs=""
    empty_input_dirs=$(find "$MUSIC_DIR" -mindepth 1 -depth -type d -empty 2>/dev/null) || true
    if [[ "$OUTPUT_DIR_HOST" != "$MUSIC_DIR" ]]; then
        empty_output_dirs=$(find "$OUTPUT_DIR_HOST" -mindepth 1 -depth -type d -empty 2>/dev/null) || true
    fi
    [[ -n "$empty_input_dirs" ]] && (( total_dir_count += $(echo "$empty_input_dirs" | wc -l | tr -d ' ') )) || true
    [[ -n "$empty_output_dirs" ]] && (( total_dir_count += $(echo "$empty_output_dirs" | wc -l | tr -d ' ') )) || true
    if [[ $total_dir_count -gt 0 ]]; then
        [[ -n "$empty_input_dirs" ]] && find "$MUSIC_DIR" -mindepth 1 -depth -type d -empty -delete 2>/dev/null || true
        [[ -n "$empty_output_dirs" ]] && find "$OUTPUT_DIR_HOST" -mindepth 1 -depth -type d -empty -delete 2>/dev/null || true
        ok "Removed $total_dir_count empty director(ies)."
    fi
    echo ""
}

usage() {
    echo ""
    echo -e "${BOLD}  auto-convert tools${NC}"
    echo ""
    echo "  Usage:  ./tools.sh <command>"
    echo ""
    echo "  Commands:"
    printf "    ${BOLD}%-16s${NC}  %s\n" "doctor"        "Check Docker, directories, container health, and internal tools"
    printf "    ${BOLD}%-16s${NC}  %s\n" "purge-input"   "Delete all *.${INPUT_FORMAT} files from the watch directory"
    printf "    ${BOLD}%-16s${NC}  %s\n" "purge-output"  "Delete all *.${OUTPUT_FORMAT} files from the output directory"
    printf "    ${BOLD}%-16s${NC}  %s\n" "purge"         "Delete all input AND output files (requires confirmation)"
    printf "    ${BOLD}%-16s${NC}  %s\n" "help"          "Show this help"
    echo ""
    echo "  Reads .env if present. Relevant variables:"
    printf "    %-20s  %s\n" "MUSIC_DIR"        "${MUSIC_DIR}"
    printf "    %-20s  %s\n" "OUTPUT_DIR_HOST"  "${OUTPUT_DIR_HOST}"
    printf "    %-20s  %s\n" "INPUT_FORMAT"     "${INPUT_FORMAT}"
    printf "    %-20s  %s\n" "OUTPUT_FORMAT"    "${OUTPUT_FORMAT}"
    echo ""
}

case "${1:-help}" in
    doctor)          cmd_doctor ;;
    purge-input)     cmd_purge_input ;;
    purge-output)    cmd_purge_output ;;
    purge)           cmd_purge ;;
    help|--help|-h)  usage ;;
    *)
        echo ""
        echo -e "  ${RED}Unknown command: $1${NC}"
        usage
        exit 1
        ;;
esac
