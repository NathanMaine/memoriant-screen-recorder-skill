#!/bin/bash
# Screen recording helper for memoriant-screen-recorder
# Usage: record.sh <command> [args]
#   setup                     — preflight check: deps, permissions, devices
#   start [fullscreen|pick]   — interactive guided flow (or skip prompts)
#   stop                      — stop the active recording
#   gif [fps] [width]         — convert last recording to GIF
#   crop                      — crop last recording to frontmost window
#   annotate "text"           — print a styled title card
#   status                    — check recording status

set -euo pipefail

RECORD_DIR="${RECORD_DIR:-$HOME/.memoriant/recordings}"
PID_FILE="$RECORD_DIR/.recording.pid"
LAST_FILE="$RECORD_DIR/.last_recording"
SAVE_DIR_FILE="$RECORD_DIR/.save_dir"

mkdir -p "$RECORD_DIR"

# ─────────────────────────────────────────────────────────────────────────────
# Utility
# ─────────────────────────────────────────────────────────────────────────────

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

# Get the screen capture device index from ffmpeg avfoundation
get_screen_device() {
    ffmpeg -f avfoundation -list_devices true -i "" 2>&1 \
        | grep -i "capture screen" \
        | head -1 \
        | sed 's/.*\[\([0-9]*\)\].*/\1/' \
        || echo "5"
}

# ─────────────────────────────────────────────────────────────────────────────
# setup — preflight check
# ─────────────────────────────────────────────────────────────────────────────

setup_check() {
    local os
    os=$(detect_os)
    local all_ok=true

    echo ""
    echo "Preflight check"
    echo "───────────────────────────────────────────────────────────────────"

    # OS
    case "$os" in
        macos)   echo "  ✓ macOS detected" ;;
        linux)   echo "  ✓ Linux detected" ;;
        *)       echo "  ✗ Unknown OS: $(uname -s)"; all_ok=false ;;
    esac

    # screencapture (macOS only)
    if [[ "$os" == "macos" ]]; then
        if command -v screencapture &>/dev/null; then
            echo "  ✓ screencapture available"
        else
            echo "  ✗ screencapture not found (should be built-in on macOS)"
            all_ok=false
        fi
    fi

    # ffmpeg
    if command -v ffmpeg &>/dev/null; then
        local ffver
        ffver=$(ffmpeg -version 2>&1 | head -1 | awk '{print $3}')
        echo "  ✓ ffmpeg ${ffver} installed"
    else
        echo "  ✗ ffmpeg not found"
        echo "      Fix: brew install ffmpeg"
        all_ok=false
    fi

    # Screen Recording permission (macOS)
    if [[ "$os" == "macos" ]]; then
        # Test screen recording permission using ffmpeg (screencapture -x has sandbox issues)
        if command -v ffmpeg &>/dev/null; then
            local test_vid="$RECORD_DIR/.screen-test.mov"
            local screen_dev
            screen_dev=$(get_screen_device)
            if ffmpeg -y -f avfoundation -framerate 1 -i "${screen_dev}:none" -t 0.5 -c:v libx264 -preset ultrafast "$test_vid" 2>/dev/null && [[ -s "$test_vid" ]]; then
                echo "  ✓ Screen Recording permission granted"
            else
                echo "  ✗ Screen Recording permission NOT granted"
                echo "      Fix: System Settings > Privacy & Security > Screen Recording"
                echo "           Add your terminal app (Terminal, iTerm2, VS Code, Cursor, etc.)"
                all_ok=false
            fi
            rm -f "$test_vid"
        else
            echo "  ? Screen Recording permission — install ffmpeg to test"
        fi

        # Accessibility permission (System Events query)
        local acc_test
        acc_test=$(osascript -e \
            'tell application "System Events" to return name of first application process whose frontmost is true' \
            2>/dev/null || echo "")
        if [[ -n "$acc_test" ]]; then
            echo "  ✓ Accessibility permission granted"
        else
            echo "  ✗ Accessibility permission NOT granted (needed for window picker)"
            echo "      Fix: System Settings > Privacy & Security > Accessibility"
            echo "           Add your terminal app"
            all_ok=false
        fi

        # List screen capture devices
        if command -v ffmpeg &>/dev/null; then
            echo ""
            echo "  Available screen capture devices:"
            ffmpeg -f avfoundation -list_devices true -i "" 2>&1 \
                | grep -E '(AVFoundation|capture screen|Capture screen)' \
                | grep -v "AVFoundation input device" \
                | while IFS= read -r line; do
                    echo "    $line"
                done
        fi
    fi

    echo ""
    echo "───────────────────────────────────────────────────────────────────"
    if $all_ok; then
        echo "  All checks passed. Ready to record."
    else
        echo "  One or more checks failed. Fix the issues above before recording."
    fi
    echo ""
}

# ─────────────────────────────────────────────────────────────────────────────
# Window picker — returns tab-separated: app_name, win_name, x, y, w, h
# Populates parallel arrays: WIN_APPS, WIN_POSITIONS, WIN_SIZES
# ─────────────────────────────────────────────────────────────────────────────

show_window_table() {
    local window_data
    window_data=$(osascript -e '
        tell application "System Events"
            set output to ""
            repeat with proc in (every application process whose visible is true)
                try
                    repeat with win in (every window of proc)
                        set winName to name of win
                        set appName to name of proc
                        set {x, y} to position of win
                        set {w, h} to size of win
                        set output to output & appName & "|" & winName & "|" & (x as text) & "|" & (y as text) & "|" & (w as text) & "|" & (h as text) & linefeed
                    end repeat
                end try
            end repeat
            return output
        end tell
    ' 2>/dev/null)

    # Print table header (to stderr so stdout only has the count)
    printf "\n" >&2
    printf "  | %-2s | %-15s | %-35s | %-10s |\n" "#" "App" "Window" "Size" >&2
    printf "  |-%s-|-%s-|-%s-|-%s-|\n" "----" "---------------" "-----------------------------------" "----------" >&2

    local i=1
    WIN_APPS=()
    WIN_POSITIONS=()
    WIN_SIZES=()

    while IFS='|' read -r app_name win_name wx wy ww wh; do
        [[ -z "$app_name" ]] && continue
        wx=$(echo "$wx" | tr -d ' ')
        wy=$(echo "$wy" | tr -d ' ')
        ww=$(echo "$ww" | tr -d ' ')
        wh=$(echo "$wh" | tr -d ' ')

        local display_app="$app_name"
        local display_win="$win_name"
        if [[ ${#display_app} -gt 15 ]]; then display_app="${display_app:0:12}..."; fi
        if [[ ${#display_win} -gt 35 ]]; then display_win="${display_win:0:32}..."; fi

        printf "  | %2d | %-15s | %-35s | %-5sx%-4s |\n" \
            "$i" "$display_app" "$display_win" "$ww" "$wh" >&2

        WIN_APPS[$i]="$app_name"
        WIN_POSITIONS[$i]="${wx},${wy}"
        WIN_SIZES[$i]="${ww},${wh}"
        i=$((i + 1))
    done <<< "$window_data"

    printf "\n" >&2
    echo $((i - 1))   # return ONLY the count on stdout
}

# ─────────────────────────────────────────────────────────────────────────────
# start — interactive guided flow
# ─────────────────────────────────────────────────────────────────────────────

start_recording() {
    local arg_mode="${1:-ask}"

    # ── Guard: already recording ──────────────────────────────────────────────
    if [[ -f "$PID_FILE" ]] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
        echo "Error: A recording is already in progress (PID: $(cat "$PID_FILE"))."
        echo "Run: record.sh stop"
        exit 1
    fi

    local filename
    filename="$RECORD_DIR/recording-$(date +%Y%m%d-%H%M%S)"
    local recorder
    recorder=$(detect_recorder)
    local os
    os=$(detect_os)

    # ── Step 1: Preflight ─────────────────────────────────────────────────────
    echo ""
    echo "Step 1: Checking dependencies..."

    # OS
    case "$os" in
        macos) echo "  ✓ macOS detected" ;;
        linux) echo "  ✓ Linux detected" ;;
        *)     echo "  ✗ Unknown OS"; exit 1 ;;
    esac

    # screencapture
    if [[ "$os" == "macos" ]]; then
        if command -v screencapture &>/dev/null; then
            echo "  ✓ screencapture available"
        else
            echo "  ✗ screencapture not found"
            exit 1
        fi
    fi

    # ffmpeg
    if command -v ffmpeg &>/dev/null; then
        local ffver
        ffver=$(ffmpeg -version 2>&1 | head -1 | awk '{print $3}')
        echo "  ✓ ffmpeg ${ffver} installed"
    else
        echo "  ✗ ffmpeg not found — install with: brew install ffmpeg"
        exit 1
    fi

    # Screen recording permission (macOS) — test with ffmpeg, not screencapture -x (sandbox issues)
    if [[ "$os" == "macos" ]] && command -v ffmpeg &>/dev/null; then
        local test_vid="$RECORD_DIR/.screen-test.mov"
        local screen_dev
        screen_dev=$(get_screen_device)
        if ffmpeg -y -f avfoundation -framerate 1 -i "${screen_dev}:none" -t 0.5 -c:v libx264 -preset ultrafast "$test_vid" 2>/dev/null && [[ -s "$test_vid" ]]; then
            echo "  ✓ Screen Recording permission granted"
        else
            echo "  ✗ Screen Recording permission NOT granted"
            echo "      Fix: System Settings > Privacy & Security > Screen Recording"
            echo "           Add your terminal app (Terminal, iTerm2, VS Code, Cursor, etc.)"
            rm -f "$test_vid"
            exit 1
        fi
        rm -f "$test_vid"

        # Accessibility
        local acc_test
        acc_test=$(osascript -e \
            'tell application "System Events" to return name of first application process whose frontmost is true' \
            2>/dev/null || echo "")
        if [[ -n "$acc_test" ]]; then
            echo "  ✓ Accessibility permission granted"
        else
            echo "  ✗ Accessibility permission NOT granted (window picker will not work)"
            echo "      Fix: System Settings > Privacy & Security > Accessibility"
        fi
    fi

    # ── Step 2: Capture mode ──────────────────────────────────────────────────
    local mode="$arg_mode"

    if [[ "$mode" == "ask" ]]; then
        echo ""
        echo "Step 2: What would you like to record?"
        echo ""
        echo "  1) Full screen"
        echo "  2) Pick a window (recommended)"
        echo ""
        read -r -p "  Which mode? (1/2, default: 2): " mode_choice
        case "${mode_choice:-2}" in
            1) mode="fullscreen" ;;
            2) mode="pick" ;;
            *) mode="pick" ;;
        esac
    fi

    # ── Step 3: Window picker (if pick mode) ──────────────────────────────────
    local pick_x="" pick_y="" pick_w="" pick_h="" pick_app=""

    if [[ "$mode" == "pick" ]]; then
        if ! command -v ffmpeg &>/dev/null; then
            echo ""
            echo "  Window recording requires ffmpeg. Install: brew install ffmpeg"
            echo "  Falling back to fullscreen..."
            mode="fullscreen"
        else
            echo ""
            echo "Step 3: Open windows:"

            # Declare arrays before calling show_window_table
            declare -a WIN_APPS WIN_POSITIONS WIN_SIZES
            local total
            total=$(show_window_table)

            if [[ "$total" -eq 0 ]]; then
                echo "  No visible windows found. Falling back to fullscreen."
                mode="fullscreen"
            else
                read -r -p "  Which window? (1-${total}): " pick_num

                if [[ -z "$pick_num" ]] || ! [[ "$pick_num" =~ ^[0-9]+$ ]] || \
                   [[ "$pick_num" -lt 1 || "$pick_num" -gt "$total" ]]; then
                    echo "  Invalid choice. Falling back to fullscreen."
                    mode="fullscreen"
                else
                    local pos="${WIN_POSITIONS[$pick_num]}"
                    local sz="${WIN_SIZES[$pick_num]}"
                    pick_app="${WIN_APPS[$pick_num]}"
                    IFS=',' read -r pick_x pick_y <<< "$pos"
                    IFS=',' read -r pick_w pick_h <<< "$sz"
                    # Ensure even dimensions (libx264 requirement)
                    pick_w=$(( (pick_w / 2) * 2 ))
                    pick_h=$(( (pick_h / 2) * 2 ))
                fi
            fi
        fi
    fi

    # ── Step 4: Save location ─────────────────────────────────────────────────
    echo ""
    echo "Step 4: Where should I save the output?"
    echo "  Default: ~/Desktop"
    read -r -p "  Path (or press Enter for default): " save_input
    local save_dir
    if [[ -z "$save_input" ]]; then
        save_dir="$HOME/Desktop"
    else
        # Expand ~ manually
        save_dir="${save_input/#\~/$HOME}"
    fi
    mkdir -p "$save_dir"
    echo "$save_dir" > "$SAVE_DIR_FILE"
    echo "  Saving to: $save_dir"

    # ── Step 5: Record ────────────────────────────────────────────────────────
    echo ""
    echo "Step 5: Recording... (run 'record.sh stop' when done)"
    echo ""

    case "$recorder" in
        screencapture)
            case "$mode" in
                pick)
                    local screen_device
                    screen_device=$(get_screen_device)
                    echo "  Recording: ${pick_app} — ${pick_w}x${pick_h} at ${pick_x},${pick_y}"
                    ffmpeg -y -f avfoundation -framerate 30 \
                        -i "${screen_device}:none" \
                        -vf "crop=${pick_w}:${pick_h}:${pick_x}:${pick_y}" \
                        -c:v libx264 -preset ultrafast -pix_fmt yuv420p \
                        "$filename.mov" \
                        > /dev/null 2>&1 &
                    ;;
                fullscreen)
                    screencapture -v "$filename.mov" &
                    ;;
            esac
            ;;
        ffmpeg-macos)
            ffmpeg -f avfoundation -framerate 30 -i "5:none" \
                -c:v libx264 -preset ultrafast "$filename.mov" \
                > /dev/null 2>&1 &
            ;;
        ffmpeg-linux)
            local display="${DISPLAY:-:0.0}"
            local resolution
            resolution=$(xdpyinfo 2>/dev/null | grep dimensions | awk '{print $2}' || echo "1920x1080")
            ffmpeg -f x11grab -r 30 -s "$resolution" -i "$display" "$filename.mp4" \
                > /dev/null 2>&1 &
            ;;
        wf-recorder)
            wf-recorder -f "$filename.mp4" &
            ;;
        none)
            echo "Error: No screen recorder found."
            echo "  macOS:         brew install ffmpeg"
            echo "  Ubuntu/Debian: sudo apt install ffmpeg"
            echo "  Fedora:        sudo dnf install ffmpeg"
            echo "  Arch:          sudo pacman -S ffmpeg"
            exit 1
            ;;
    esac

    local pid=$!
    echo "$pid" > "$PID_FILE"
    echo "$filename" > "$LAST_FILE"

    echo "  [REC] PID: $pid"
    echo "  [REC] Output: ${filename}.*"
    echo ""
    echo "  Run 'record.sh stop' to finish."
}

# ─────────────────────────────────────────────────────────────────────────────
# stop — stop recording, then ask about output format
# ─────────────────────────────────────────────────────────────────────────────

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
    sleep 2
    rm -f "$PID_FILE"

    local last
    last=$(cat "$LAST_FILE" 2>/dev/null || echo "")
    local outfile=""
    if [[ -n "$last" ]]; then
        outfile=$(ls "${last}".{mov,mp4,ogv} 2>/dev/null | head -1 || echo "")
    fi

    if [[ -z "$outfile" || ! -f "$outfile" ]]; then
        echo "Recording stopped. Output may still be finalizing at: ${last}.*"
        return 0
    fi

    local size
    size=$(du -h "$outfile" | cut -f1)
    echo ""
    echo "  Recording captured: $outfile ($size)"

    # ── Step 6: Format choice ─────────────────────────────────────────────────
    echo ""
    echo "Step 6: What format do you want?"
    echo ""
    echo "  1) Video only (.mov)"
    echo "  2) GIF only (.gif)"
    echo "  3) Both video and GIF"
    echo ""
    read -r -p "  Format? (1/2/3, default: 3): " fmt_choice

    local want_video=false
    local want_gif=false
    case "${fmt_choice:-3}" in
        1) want_video=true ;;
        2) want_gif=true ;;
        3) want_video=true; want_gif=true ;;
        *) want_video=true; want_gif=true ;;
    esac

    # ── Step 7: Convert if needed, copy to save location ─────────────────────
    local save_dir
    save_dir=$(cat "$SAVE_DIR_FILE" 2>/dev/null || echo "$HOME/Desktop")
    mkdir -p "$save_dir"

    local base
    base=$(basename "$last")
    local gif_file="${last}.gif"

    if $want_gif; then
        echo ""
        echo "  Converting to GIF..."
        _do_gif_convert "$outfile" "$gif_file" 15 800
    fi

    echo ""
    echo "Done! Files saved:"

    if $want_video; then
        local dest_video="${save_dir}/${base}.mov"
        cp "$outfile" "$dest_video"
        local vs
        vs=$(du -h "$dest_video" | cut -f1)
        echo "  ${dest_video} (${vs})"
    fi

    if $want_gif && [[ -f "$gif_file" ]]; then
        local dest_gif="${save_dir}/${base}.gif"
        cp "$gif_file" "$dest_gif"
        local gs
        gs=$(du -h "$dest_gif" | cut -f1)
        echo "  ${dest_gif} (${gs})"
    fi
    echo ""
}

# ─────────────────────────────────────────────────────────────────────────────
# GIF conversion (internal helper + public command)
# ─────────────────────────────────────────────────────────────────────────────

_do_gif_convert() {
    local infile="$1"
    local outfile="$2"
    local fps="${3:-15}"
    local width="${4:-800}"

    ffmpeg -y -i "$infile" \
        -vf "fps=${fps},scale=${width}:-1:flags=lanczos,split[s0][s1];[s0]palettegen[p];[s1][p]paletteuse" \
        "$outfile" 2>/dev/null

    if [[ -f "$outfile" ]]; then
        local size
        size=$(du -h "$outfile" | cut -f1)
        echo "  GIF saved: $outfile ($size)"
    else
        echo "  Error: GIF conversion failed."
        return 1
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
        echo "Specify a file: record.sh gif [fps] [width]"
        exit 1
    fi

    local fps="${1:-15}"
    local width="${2:-800}"
    local outfile="${last}.gif"

    echo "Converting to GIF..."
    echo "  Input:  $infile"
    echo "  Output: $outfile"
    echo "  fps=$fps, width=${width}px, filter=lanczos+palette"

    _do_gif_convert "$infile" "$outfile" "$fps" "$width"
}

# ─────────────────────────────────────────────────────────────────────────────
# annotate — styled title card
# ─────────────────────────────────────────────────────────────────────────────

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

# ─────────────────────────────────────────────────────────────────────────────
# status
# ─────────────────────────────────────────────────────────────────────────────

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

# ─────────────────────────────────────────────────────────────────────────────
# crop — crop last recording to frontmost window
# ─────────────────────────────────────────────────────────────────────────────

crop_recording() {
    if ! command -v ffmpeg &>/dev/null; then
        echo "Error: ffmpeg is required for cropping."
        exit 1
    fi

    local last
    last=$(cat "$LAST_FILE" 2>/dev/null || echo "")
    local infile=""
    if [[ -n "$last" ]]; then
        infile=$(ls "${last}".{mov,mp4,ogv} 2>/dev/null | head -1 || echo "")
    fi

    if [[ -z "$infile" || ! -f "$infile" ]]; then
        echo "No recording found to crop."
        exit 1
    fi

    # Detect frontmost window bounds
    local bounds x y w h
    bounds=$(osascript -e '
        tell application "System Events"
            set frontApp to first application process whose frontmost is true
            set frontWindow to first window of frontApp
            set {x, y} to position of frontWindow
            set {w, h} to size of frontWindow
            return (x as text) & "," & (y as text) & "," & (w as text) & "," & (h as text)
        end tell
    ' 2>/dev/null | tr -d ' ')

    if [[ -z "$bounds" ]]; then
        echo "Could not detect window. Specify manually: record.sh crop WxH+X+Y"
        exit 1
    fi

    IFS=',' read -r x y w h <<< "$bounds"
    w=$(( (w / 2) * 2 ))
    h=$(( (h / 2) * 2 ))

    local outfile="${last}-cropped.mov"
    echo "Cropping to ${w}x${h} at ${x},${y}..."
    ffmpeg -y -i "$infile" -vf "crop=${w}:${h}:${x}:${y}" "$outfile" 2>/dev/null

    if [[ -f "$outfile" ]]; then
        local size
        size=$(du -h "$outfile" | cut -f1)
        echo "Cropped: $outfile ($size)"
        echo "${last}-cropped" > "$LAST_FILE"
    else
        echo "Error: Crop failed."
        exit 1
    fi
}

# ─────────────────────────────────────────────────────────────────────────────
# Dispatch
# ─────────────────────────────────────────────────────────────────────────────

case "${1:-help}" in
    setup)    setup_check ;;
    start)    start_recording "${2:-ask}" ;;
    stop)     stop_recording ;;
    crop)     crop_recording ;;
    gif)      convert_to_gif "${2:-15}" "${3:-800}" ;;
    annotate) annotate "${2:-Demo}" ;;
    status)   status_check ;;
    help|*)
        echo ""
        echo "Usage: record.sh <command> [args]"
        echo ""
        echo "Commands:"
        echo "  setup                  Preflight check — verify deps and permissions"
        echo "  start                  Guided interactive flow (all 6 steps)"
        echo "  start fullscreen       Skip prompts — fullscreen, Desktop, ask format after stop"
        echo "  start pick             Skip to window list"
        echo "  stop                   Stop recording and choose output format"
        echo "  crop                   Crop last recording to the frontmost window"
        echo "  gif [fps] [width]      Convert last recording to GIF (default: 15fps, 800px)"
        echo "  annotate <text>        Print a styled title card to the terminal"
        echo "  status                 Show recording status"
        echo ""
        echo "Environment:"
        echo "  RECORD_DIR             Working directory (default: ~/.memoriant/recordings)"
        echo ""
        ;;
esac
