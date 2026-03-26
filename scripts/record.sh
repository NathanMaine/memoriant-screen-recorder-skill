#!/bin/bash
# Screen recording helper for memoriant-screen-recorder
# Usage: record.sh start|stop|gif|annotate [args]

set -euo pipefail

RECORD_DIR="${RECORD_DIR:-$HOME/.memoriant/recordings}"
PID_FILE="$RECORD_DIR/.recording.pid"
LAST_FILE="$RECORD_DIR/.last_recording"

mkdir -p "$RECORD_DIR"

detect_os() {
    case "$(uname -s)" in
        Darwin) echo "macos" ;;
        Linux)  echo "linux" ;;
        *)      echo "unknown" ;;
    esac
}

detect_recorder() {
    local os
    os=$(detect_os)
    if [[ "$os" == "macos" ]]; then
        if command -v screencapture &>/dev/null; then echo "screencapture"
        elif command -v ffmpeg &>/dev/null; then echo "ffmpeg-macos"
        else echo "none"; fi
    else
        if command -v ffmpeg &>/dev/null; then echo "ffmpeg-linux"
        elif command -v wf-recorder &>/dev/null; then echo "wf-recorder"
        else echo "none"; fi
    fi
}

start_recording() {
    if [[ -f "$PID_FILE" ]] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
        echo "Error: A recording is already in progress (PID: $(cat "$PID_FILE"))."
        echo "Run: record.sh stop"
        exit 1
    fi

    local filename
    filename="$RECORD_DIR/recording-$(date +%Y%m%d-%H%M%S)"
    local recorder
    recorder=$(detect_recorder)

    case "$recorder" in
        screencapture)
            screencapture -v "$filename.mov" &
            ;;
        ffmpeg-macos)
            ffmpeg -f avfoundation -i "1:0" -r 30 "$filename.mov" &
            ;;
        ffmpeg-linux)
            local display="${DISPLAY:-:0.0}"
            local resolution
            resolution=$(xdpyinfo 2>/dev/null | grep dimensions | awk '{print $2}' || echo "1920x1080")
            ffmpeg -f x11grab -r 30 -s "$resolution" -i "$display" "$filename.mp4" &
            ;;
        wf-recorder)
            wf-recorder -f "$filename.mp4" &
            ;;
        none)
            echo "Error: No screen recorder found."
            echo "Install ffmpeg:"
            echo "  macOS:          brew install ffmpeg"
            echo "  Ubuntu/Debian:  sudo apt install ffmpeg"
            echo "  Fedora:         sudo dnf install ffmpeg"
            echo "  Arch:           sudo pacman -S ffmpeg"
            exit 1
            ;;
    esac

    local pid=$!
    echo "$pid" > "$PID_FILE"
    echo "$filename" > "$LAST_FILE"
    echo "[REC] Recording started: $filename"
    echo "      Recorder: $recorder"
    echo "      Run 'record.sh stop' to finish."
}

stop_recording() {
    if [[ ! -f "$PID_FILE" ]]; then
        echo "No active recording found."
        exit 1
    fi

    local pid
    pid=$(cat "$PID_FILE")

    if ! kill -0 "$pid" 2>/dev/null; then
        echo "Recording process $pid is no longer running."
        rm -f "$PID_FILE"
        exit 0
    fi

    # SIGINT triggers clean finalization for ffmpeg, screencapture, and wf-recorder
    kill -INT "$pid" 2>/dev/null || kill "$pid" 2>/dev/null || true

    # Give the process time to write final frames and close the file
    sleep 1
    rm -f "$PID_FILE"

    local last
    last=$(cat "$LAST_FILE" 2>/dev/null || echo "")
    local outfile=""
    if [[ -n "$last" ]]; then
        outfile=$(ls "${last}".* 2>/dev/null | head -1 || echo "")
    fi

    if [[ -n "$outfile" && -f "$outfile" ]]; then
        local size
        size=$(du -h "$outfile" | cut -f1)
        echo "Recording saved: $outfile ($size)"
        echo "Convert to GIF: record.sh gif"
    else
        echo "Recording stopped. Output may still be finalizing at: $last.*"
    fi
}

convert_to_gif() {
    if ! command -v ffmpeg &>/dev/null; then
        echo "Error: ffmpeg is required for GIF conversion."
        exit 1
    fi

    local last
    last=$(cat "$LAST_FILE" 2>/dev/null || echo "")
    local infile=""
    if [[ -n "$last" ]]; then
        infile=$(ls "${last}".{mov,mp4,ogv} 2>/dev/null | head -1 || echo "")
    fi

    if [[ -z "$infile" || ! -f "$infile" ]]; then
        echo "No recording found to convert."
        echo "Specify a file: record.sh gif [fps] [width] <input-file>"
        exit 1
    fi

    local fps="${1:-15}"
    local width="${2:-800}"
    local outfile="${last}.gif"

    echo "Converting to GIF..."
    echo "  Input:  $infile"
    echo "  Output: $outfile"
    echo "  fps=$fps, width=${width}px, filter=lanczos+palette"

    # Two-pass palette method for maximum quality
    ffmpeg -y -i "$infile" \
        -vf "fps=${fps},scale=${width}:-1:flags=lanczos,split[s0][s1];[s0]palettegen[p];[s1][p]paletteuse" \
        "$outfile" 2>/dev/null

    if [[ -f "$outfile" ]]; then
        local size
        size=$(du -h "$outfile" | cut -f1)
        echo "GIF saved: $outfile ($size)"
    else
        echo "Error: GIF conversion failed."
        exit 1
    fi
}

annotate() {
    local text="${1:-Demo}"
    local len=${#text}
    local pad=$((len + 4))

    printf "\n\033[1;36m"
    printf "╔"
    printf '═%.0s' $(seq 1 $pad)
    printf "╗\n"
    printf "║  %s  ║\n" "$text"
    printf "╚"
    printf '═%.0s' $(seq 1 $pad)
    printf "╝\n"
    printf "\033[0m\n"
}

status_check() {
    if [[ -f "$PID_FILE" ]] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
        local pid
        pid=$(cat "$PID_FILE")
        local last
        last=$(cat "$LAST_FILE" 2>/dev/null || echo "unknown")
        echo "Recording in progress"
        echo "  PID:    $pid"
        echo "  Output: ${last}.*"
    else
        echo "Not recording."
        if [[ -f "$LAST_FILE" ]]; then
            local last
            last=$(cat "$LAST_FILE")
            local lastfile
            lastfile=$(ls "${last}".* 2>/dev/null | head -1 || echo "")
            if [[ -n "$lastfile" ]]; then
                local size
                size=$(du -h "$lastfile" | cut -f1)
                echo "  Last recording: $lastfile ($size)"
            fi
        fi
    fi
}

case "${1:-help}" in
    start)    start_recording ;;
    stop)     stop_recording ;;
    gif)      convert_to_gif "${2:-15}" "${3:-800}" ;;
    annotate) annotate "${2:-Demo}" ;;
    status)   status_check ;;
    help|*)
        echo "Usage: record.sh <command> [args]"
        echo ""
        echo "Commands:"
        echo "  start                  Start a screen recording"
        echo "  stop                   Stop the active recording"
        echo "  gif [fps] [width]      Convert last recording to GIF (default: 15fps, 800px)"
        echo "  annotate <text>        Print a styled title card to the terminal"
        echo "  status                 Show recording status"
        echo ""
        echo "Environment:"
        echo "  RECORD_DIR             Output directory (default: ~/.memoriant/recordings)"
        ;;
esac
