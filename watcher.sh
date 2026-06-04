#!/bin/bash
set -euo pipefail

WATCH_DIR="${WATCH_DIR:-/watch}"
OUTPUT_DIR="${OUTPUT_DIR:-/watch}"
INPUT_FORMAT="${INPUT_FORMAT:-flac}"
OUTPUT_FORMAT="${OUTPUT_FORMAT:-aiff}"
AUDIO_CODEC="${AUDIO_CODEC:-pcm_s16le}"
SAMPLE_RATE="${SAMPLE_RATE:-44100}"
BIT_DEPTH="${BIT_DEPTH:-16}"
RECURSIVE="${RECURSIVE:-true}"
PRESERVE_METADATA="${PRESERVE_METADATA:-true}"
DELETE_SOURCE="${DELETE_SOURCE:-false}"
LOG_LEVEL="${LOG_LEVEL:-info}"
PROCESS_EXISTING="${PROCESS_EXISTING:-true}"
FILE_STABLE_TIME="${FILE_STABLE_TIME:-2}"

log_info() {
    if [[ "$LOG_LEVEL" == "info" ]] || [[ "$LOG_LEVEL" == "debug" ]]; then
        echo "[$(date +'%Y-%m-%d %H:%M:%S')] [INFO] $*"
    fi
}

log_error() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] [ERROR] $*" >&2
}

log_debug() {
    if [[ "$LOG_LEVEL" == "debug" ]]; then
        echo "[$(date +'%Y-%m-%d %H:%M:%S')] [DEBUG] $*"
    fi
}

wait_for_file_stable() {
    local file="$1"
    local wait_time="$FILE_STABLE_TIME"
    
    log_debug "Waiting ${wait_time}s for file to stabilize: $file"
    sleep "$wait_time"
    
    if [[ ! -f "$file" ]]; then
        log_error "File disappeared while waiting: $file"
        return 1
    fi
    
    return 0
}

get_ffmpeg_metadata_flags() {
    if [[ "$PRESERVE_METADATA" == "true" ]]; then
        echo "-map_metadata 0 -id3v2_version 3 -write_id3v1 1"
    else
        echo ""
    fi
}

get_output_path() {
    local input_file="$1"
    local base_name="${input_file%.*}"
    local relative_path="${input_file#$WATCH_DIR}"
    relative_path="${relative_path#/}"
    local relative_base="${relative_path%.*}"
    
    if [[ "$OUTPUT_DIR" == "$WATCH_DIR" ]]; then
        echo "${base_name}.${OUTPUT_FORMAT}"
    else
        local output_file="${OUTPUT_DIR}/${relative_base}.${OUTPUT_FORMAT}"
        mkdir -p "$(dirname "$output_file")"
        echo "$output_file"
    fi
}

convert_file() {
    local input_file="$1"
    
    if [[ ! -f "$input_file" ]]; then
        log_error "Input file does not exist: $input_file"
        return 1
    fi
    
    if ! wait_for_file_stable "$input_file"; then
        return 1
    fi
    
    local output_file
    output_file=$(get_output_path "$input_file")
    
    if [[ -f "$output_file" ]]; then
        log_debug "Output already exists, skipping: $output_file"
        return 0
    fi
    
    log_info "Converting: $input_file -> $output_file"
    
    local metadata_flags
    metadata_flags=$(get_ffmpeg_metadata_flags)
    
    local temp_output="${output_file}.tmp"
    
    if ffmpeg -y -i "$input_file" \
        -acodec "$AUDIO_CODEC" \
        -ar "$SAMPLE_RATE" \
        -sample_fmt "s${BIT_DEPTH}" \
        $metadata_flags \
        -f "$OUTPUT_FORMAT" \
        -loglevel error \
        "$temp_output" 2>&1; then
        
        mv "$temp_output" "$output_file"
        log_info "Conversion complete: $output_file"
        
        if [[ "$DELETE_SOURCE" == "true" ]]; then
            log_info "Deleting source file: $input_file"
            rm -f "$input_file"
        fi
        
        return 0
    else
        log_error "Conversion failed: $input_file"
        rm -f "$temp_output"
        return 1
    fi
}

cleanup() {
    log_info "Received shutdown signal, cleaning up..."
    
    if [[ -n "${INOTIFY_PID:-}" ]]; then
        kill "$INOTIFY_PID" 2>/dev/null || true
    fi
    
    log_info "Shutdown complete"
    exit 0
}

trap cleanup SIGTERM SIGINT SIGQUIT

log_info "================================================"
log_info "auto-convert - Automated Audio Converter"
log_info "================================================"
log_info "Watch directory: $WATCH_DIR"
log_info "Output directory: $OUTPUT_DIR"
log_info "Input format: $INPUT_FORMAT"
log_info "Output format: $OUTPUT_FORMAT"
log_info "Audio codec: $AUDIO_CODEC"
log_info "Sample rate: ${SAMPLE_RATE}Hz"
log_info "Bit depth: ${BIT_DEPTH}bit"
log_info "Preserve metadata: $PRESERVE_METADATA"
log_info "Delete source: $DELETE_SOURCE"
log_info "Recursive: $RECURSIVE"
log_info "Process existing: $PROCESS_EXISTING"
log_info "================================================"

if [[ ! -d "$WATCH_DIR" ]]; then
    log_error "Watch directory does not exist: $WATCH_DIR"
    exit 1
fi

if [[ "$PROCESS_EXISTING" == "true" ]]; then
    log_info "Processing existing ${INPUT_FORMAT} files..."
    
    find_opts=()
    if [[ "$RECURSIVE" == "false" ]]; then
        find_opts+=("-maxdepth" "1")
    fi
    
    while IFS= read -r -d '' file; do
        convert_file "$file" || log_error "Failed to convert existing file: $file"
    done < <(find "$WATCH_DIR" "${find_opts[@]}" -type f -iname "*.${INPUT_FORMAT}" -print0 2>/dev/null)
    
    log_info "Finished processing existing files"
fi

log_info "Starting file watcher..."

inotify_opts=("-m" "-e" "close_write,moved_to" "--format" "%w%f")
if [[ "$RECURSIVE" == "true" ]]; then
    inotify_opts+=("-r")
fi

inotifywait "${inotify_opts[@]}" "$WATCH_DIR" 2>/dev/null | while IFS= read -r path; do
    log_debug "Detected change: $path"
    
    if [[ "${path,,}" == *".${INPUT_FORMAT,,}" ]]; then
        convert_file "$path" || log_error "Failed to convert: $path"
    fi
done &

INOTIFY_PID=$!

log_info "Watcher started (PID: $INOTIFY_PID)"

wait "$INOTIFY_PID"
