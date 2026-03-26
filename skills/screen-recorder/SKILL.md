---
name: screen-recorder
description: >
  Manage screen recordings from within Claude Code. Start and stop recordings,
  convert to GIF, add title card annotations, and automate demo capture for
  plugin documentation. Supports macOS (screencapture, ffmpeg/avfoundation) and
  Linux (ffmpeg/x11grab, wf-recorder, recordmydesktop).
version: 1.0.0
commands:
  - /screen-record start
  - /screen-record stop
  - /screen-record gif
  - /screen-record demo <plugin-name>
  - /screen-record annotate <text>
  - /screen-record status
platforms:
  - macOS
  - Linux
---

# Screen Recorder Skill

## Overview

This skill teaches Claude Code to manage screen recording sessions. Recordings
are saved to `~/.memoriant/recordings/` by default. GIFs are placed alongside
the source video. A PID file tracks the active recording process so stop/status
work reliably across commands.

---

## Tool Detection

Before recording, check the available toolchain. The preference order is:

### macOS

1. `screencapture` — built in, no install required, records to `.mov`
2. `ffmpeg` with `-f avfoundation` — cross-platform, more control
3. AppleScript + QuickTime (interactive fallback, not scriptable for auto-stop)

Detection:

```bash
detect_recorder_macos() {
    if command -v screencapture &>/dev/null; then
        echo "screencapture"
    elif command -v ffmpeg &>/dev/null; then
        echo "ffmpeg-macos"
    else
        echo "none"
    fi
}
```

### Linux

1. `ffmpeg -f x11grab` — available on virtually any X11 system with ffmpeg
2. `wf-recorder` — Wayland native, install via package manager
3. `recordmydesktop` — GTK-based fallback, wide distro support

Detection:

```bash
detect_recorder_linux() {
    if command -v ffmpeg &>/dev/null; then
        echo "ffmpeg-linux"
    elif command -v wf-recorder &>/dev/null; then
        echo "wf-recorder"
    elif command -v recordmydesktop &>/dev/null; then
        echo "recordmydesktop"
    else
        echo "none"
    fi
}
```

If `detect_recorder` returns `none`, inform the user and suggest install
commands before proceeding:

- macOS: `brew install ffmpeg`
- Ubuntu/Debian: `sudo apt install ffmpeg`
- Fedora: `sudo dnf install ffmpeg`
- Arch: `sudo pacman -S ffmpeg`

---

## Commands

### /screen-record start

Starts a recording session. **Before recording, always ask the user which capture mode they want:**

**Step 1 — Ask capture mode:**

Present these options to the user:

```
How would you like to record?

  1. Full screen — captures your entire display
  2. Select region — you'll drag to select an area (great for just the terminal)
  3. Specific window — click on the window you want to capture
  4. Terminal only — automatically finds and records just the terminal window

Which mode? (1/2/3/4, default: 2)
```

**Recommend option 2 (select region) for demos** — it lets the user frame exactly what they want without desktop clutter.

**Step 2 — Start recording based on mode:**

Saves the process PID to `~/.memoriant/recordings/.recording.pid` for later stop.
The output filename includes a timestamp: `recording-YYYYMMDD-HHMMSS`.

**macOS — screencapture modes:**

```bash
FILENAME="$RECORD_DIR/recording-$(date +%Y%m%d-%H%M%S)"

# Mode 1: Full screen
screencapture -v "$FILENAME.mov" &

# Mode 2: Interactive region selection (user drags a rectangle)
screencapture -v -i "$FILENAME.mov" &

# Mode 3: Click a specific window
screencapture -v -i -w "$FILENAME.mov" &

# Mode 4: Terminal window (auto-detect by finding frontmost Terminal/iTerm2 window ID)
WINDOW_ID=$(osascript -e 'tell application "System Events" to get id of first window of (first process whose frontmost is true)')
screencapture -v -l "$WINDOW_ID" "$FILENAME.mov" &
```

After launching, write PID and confirm:
```bash
echo $! > "$PID_FILE"
echo "$FILENAME" > "$LAST_FILE"
echo "Recording started ($MODE): $FILENAME.mov"
echo "Run /screen-record stop when finished."
```

**macOS — ffmpeg/avfoundation:**

```bash
# Full screen
ffmpeg -f avfoundation -i "1:0" -r 30 "$FILENAME.mov" &

# Region (crop after recording — ffmpeg can't do interactive selection)
# Record full, then: ffmpeg -i full.mov -vf "crop=W:H:X:Y" cropped.mov
```

**Linux — ffmpeg/x11grab:**

```bash
# Full screen (auto-detect resolution)
RES=$(xdpyinfo | grep dimensions | awk '{print $2}')
ffmpeg -f x11grab -r 30 -s "$RES" -i :0.0 "$FILENAME.mp4" &

# Region selection (use slop to pick area)
if command -v slop &>/dev/null; then
    echo "Click and drag to select recording area..."
    GEOM=$(slop -f "%wx%h+%x,%y")
    SIZE=$(echo "$GEOM" | cut -d'+' -f1)
    OFFSET=$(echo "$GEOM" | cut -d'+' -f2)
    ffmpeg -f x11grab -r 30 -s "$SIZE" -i ":0.0+$OFFSET" "$FILENAME.mp4" &
else
    echo "Install slop for region selection: sudo apt install slop"
    echo "Falling back to full screen..."
    ffmpeg -f x11grab -r 30 -s "$RES" -i :0.0 "$FILENAME.mp4" &
fi

# Specific window (use xdotool)
if command -v xdotool &>/dev/null; then
    echo "Click on the window you want to record..."
    WID=$(xdotool selectwindow)
    GEOM=$(xdotool getwindowgeometry --shell "$WID")
    # Parse WIDTH, HEIGHT, X, Y from GEOM
    ffmpeg -f x11grab -r 30 -s "${WIDTH}x${HEIGHT}" -i ":0.0+${X},${Y}" "$FILENAME.mp4" &
fi
```

**Linux — wf-recorder (Wayland):**

```bash
wf-recorder -f "$FILENAME.mp4" &
```

**Linux — recordmydesktop:**

```bash
recordmydesktop --no-sound --fps 30 -o "$FILENAME.ogv" &
```

**Visual indicator** — print a blinking dot or status line while recording is
active. This helps confirm the session is live during terminal usage:

```
[REC] Recording to: ~/.memoriant/recordings/recording-20250326-143022.mov
      Press Ctrl+C or run /screen-record stop to finish.
```

---

### /screen-record stop

Stops the active recording by sending SIGINT to the PID, then cleans up the
PID file and reports the output.

```bash
stop_recording() {
    if [[ ! -f "$PID_FILE" ]]; then
        echo "No active recording found."
        exit 1
    fi

    local pid
    pid=$(cat "$PID_FILE")

    # SIGINT is preferred; ffmpeg/screencapture finalize on SIGINT
    kill -INT "$pid" 2>/dev/null || kill "$pid" 2>/dev/null || true

    # Give the process a moment to write its final frames
    sleep 1
    rm -f "$PID_FILE"

    local last
    last=$(cat "$LAST_FILE" 2>/dev/null || echo "")
    local outfile
    outfile=$(ls "${last}".* 2>/dev/null | head -1)

    if [[ -n "$outfile" ]]; then
        local size
        size=$(du -h "$outfile" | cut -f1)
        echo "Recording saved: $outfile ($size)"
        echo "Convert to GIF: /screen-record gif"
    else
        echo "Recording stopped. Output file not found — it may still be finalizing."
    fi
}
```

Note: `screencapture -v` finalizes cleanly on SIGINT. `ffmpeg` also respects
SIGINT for a clean exit. `wf-recorder` uses SIGINT as well. Do not use SIGKILL
unless the process is stuck, as it may leave a corrupt or missing file.

---

### /screen-record gif

Converts the last recording to a GIF using a two-pass ffmpeg palette approach.
This produces significantly smaller and sharper GIFs than a single-pass
conversion.

**Two-pass palette method:**

```bash
convert_to_gif() {
    local infile="$1"
    local outfile="${infile%.*}.gif"
    local fps="${2:-15}"
    local width="${3:-800}"

    echo "Generating palette..."
    ffmpeg -y -i "$infile" \
        -vf "fps=$fps,scale=$width:-1:flags=lanczos,palettegen" \
        /tmp/palette.png 2>/dev/null

    echo "Encoding GIF..."
    ffmpeg -y -i "$infile" -i /tmp/palette.png \
        -lavfi "fps=$fps,scale=$width:-1:flags=lanczos [x]; [x][1:v] paletteuse" \
        "$outfile" 2>/dev/null

    rm -f /tmp/palette.png
    local size
    size=$(du -h "$outfile" | cut -f1)
    echo "GIF saved: $outfile ($size)"
}
```

Or with the combined filter graph (equivalent, single ffmpeg call):

```bash
ffmpeg -y -i input.mov \
    -vf "fps=15,scale=800:-1:flags=lanczos,split[s0][s1];[s0]palettegen[p];[s1][p]paletteuse" \
    output.gif
```

**gifski alternative** (higher quality, requires install):

```bash
# Install: brew install gifski  OR  cargo install gifski
# Extract frames first, then encode
ffmpeg -i input.mov -r 15 /tmp/frames/frame%04d.png
gifski --fps 15 --width 800 -o output.gif /tmp/frames/frame*.png
```

**GIF optimization tips:**

| Setting | Recommendation | Notes |
|---------|---------------|-------|
| FPS | 15 | Smooth enough; lower = smaller file |
| Width | 800px | Good for README embeds |
| Lanczos | Always | Best downscale filter |
| Palette | Two-pass | Critical for color accuracy |
| Duration | 30-60s max | GIFs over 10MB are unwieldy |

---

### /screen-record demo \<plugin-name\>

Records a scripted demo of a named Memoriant plugin. The workflow:

1. Print an opening title card annotation
2. Start recording
3. Pause briefly (let the annotation render in the recording)
4. Print the demo commands and their descriptions
5. Stop recording
6. Convert to GIF
7. Move GIF to `demos/<plugin-name>-demo.gif`

```bash
demo_plugin() {
    local plugin="$1"
    local output_dir="demos"
    mkdir -p "$output_dir"

    annotate "Demo: $plugin"
    sleep 1

    start_recording

    echo ""
    echo "Running demo for: $plugin"
    echo "Output will be saved to: $output_dir/$plugin-demo.gif"
    sleep 2

    # Plugin-specific demo steps would go here
    # Example for patent-search:
    # annotate "/patent-search 'wireless power transfer'"
    # sleep 1
    # echo "(demo command output would appear here)"
    # sleep 2

    stop_recording
    sleep 1
    convert_to_gif "$(get_last_recording)" 15 800

    local gif_src
    gif_src=$(get_last_recording_gif)
    mv "$gif_src" "$output_dir/$plugin-demo.gif"
    echo "Demo GIF saved: $output_dir/$plugin-demo.gif"
}
```

The `scripts/demo-all.sh` helper runs this across all 13 Memoriant plugins
in sequence, suitable for a full marketplace showcase recording.

---

### /screen-record annotate \<text\>

Prints a styled ANSI title card to the terminal. Useful for labeling sections
during a live recording so viewers can follow along.

```bash
annotate() {
    local text="${1:-Demo}"
    local len=${#text}
    local pad=$((len + 4))

    printf "\n\033[1;36m"
    printf "╔"; printf '═%.0s' $(seq 1 $pad); printf "╗\n"
    printf "║  %s  ║\n" "$text"
    printf "╚"; printf '═%.0s' $(seq 1 $pad); printf "╝\n"
    printf "\033[0m\n"
}
```

Example output:

```
╔══════════════════════════════════════╗
║   Patent Search Demo                 ║
║   /patent-search "wireless power"    ║
╚══════════════════════════════════════╝
```

Multiple lines can be combined into a multi-line card:

```bash
annotate_block() {
    local lines=("$@")
    local max_len=0
    for line in "${lines[@]}"; do
        [[ ${#line} -gt $max_len ]] && max_len=${#line}
    done
    local pad=$((max_len + 4))

    printf "\n\033[1;36m"
    printf "╔"; printf '═%.0s' $(seq 1 $pad); printf "╗\n"
    for line in "${lines[@]}"; do
        printf "║  %-*s  ║\n" "$max_len" "$line"
    done
    printf "╚"; printf '═%.0s' $(seq 1 $pad); printf "╝\n"
    printf "\033[0m\n"
}
```

---

### /screen-record status

Reports whether a recording is currently active.

```bash
status() {
    if [[ -f "$PID_FILE" ]] && kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
        local pid
        pid=$(cat "$PID_FILE")
        local last
        last=$(cat "$LAST_FILE" 2>/dev/null || echo "unknown")
        echo "Recording in progress"
        echo "  PID: $pid"
        echo "  Output: $last.*"
    else
        echo "Not recording."
        if [[ -f "$LAST_FILE" ]]; then
            echo "  Last recording: $(cat "$LAST_FILE").*"
        fi
    fi
}
```

---

## macOS-Specific Notes

### Screen Recording Permissions

On macOS 10.15+, screen recording requires explicit privacy permission:

1. System Settings > Privacy & Security > Screen Recording
2. Add Terminal (or iTerm2, Warp, etc.) to the allowed list
3. If `screencapture -v` produces a blank/black file, permissions are the
   cause — the file is created but no frames are captured

Test permission status before recording:

```bash
# Returns non-zero if screen recording is blocked
screencapture -x /tmp/test-perm.png && echo "Permission OK" || echo "Permission denied"
rm -f /tmp/test-perm.png
```

### ffmpeg avfoundation Device Index

Device indices vary by machine. List available devices:

```bash
ffmpeg -f avfoundation -list_devices true -i "" 2>&1 | grep -E '^\[AVFoundation'
```

Typical output:
- `[0]` = Built-in display
- `[1]` = External display (if connected)
- Audio: `[0]` = Built-in microphone, `[1]` = Built-in output

For screen-only with no audio: `-i "0:none"` or `-i "1:none"` for the
second display.

### QuickTime AppleScript (interactive fallback)

```applescript
tell application "QuickTime Player"
    set newRecording to new screen recording
    start newRecording
end tell
```

Stop via:

```applescript
tell application "QuickTime Player"
    stop document 1
    save document 1 in POSIX file "/Users/you/recording.mov"
end tell
```

This approach is interactive and not recommended for automated demos.

---

## Linux-Specific Notes

### X11 Display

For `ffmpeg -f x11grab`, the display must be set. In most desktop environments
`:0.0` is correct. For remote sessions via VNC or Xvfb, use the virtual
display number (e.g., `:1.0`).

Check active display:

```bash
echo $DISPLAY
xdpyinfo | grep dimensions
```

Capture a specific region (useful for focused demos):

```bash
# Capture 1280x720 starting at position (100, 100)
ffmpeg -f x11grab -r 30 -s 1280x720 -i :0.0+100,100 output.mp4
```

### Wayland (wf-recorder)

Wayland compositors do not support `x11grab`. Use `wf-recorder`:

```bash
# Install
sudo apt install wf-recorder   # Debian/Ubuntu
sudo pacman -S wf-recorder     # Arch

# Record
wf-recorder -f output.mp4 &

# Stop
killall -SIGINT wf-recorder
```

For partial screen capture on Wayland, use `-g` with geometry:

```bash
wf-recorder -g "100,100 1280x720" -f output.mp4 &
```

### Headless / CI Environments

For headless recording (CI pipelines, servers), use Xvfb:

```bash
Xvfb :99 -screen 0 1920x1080x24 &
export DISPLAY=:99
ffmpeg -f x11grab -r 30 -s 1920x1080 -i :99.0 output.mp4 &
```

---

## GIF Quality Reference

### Size vs Quality Trade-offs

| Use Case | FPS | Width | Expected Size |
|----------|-----|-------|---------------|
| README badge/preview | 10 | 600 | 2-5 MB |
| Tutorial clip (30s) | 15 | 800 | 5-12 MB |
| Full demo (60s) | 15 | 1024 | 12-25 MB |
| High quality archive | 24 | 1280 | 25-50 MB |

### Reducing File Size

```bash
# Reduce colors (256 is max, lower = smaller)
ffmpeg -i input.mov \
    -vf "fps=10,scale=600:-1:flags=lanczos,split[s0][s1];[s0]palettegen=max_colors=128[p];[s1][p]paletteuse" \
    output.gif

# Trim before converting (start at 5s, capture 20s)
ffmpeg -ss 5 -t 20 -i input.mov \
    -vf "fps=15,scale=800:-1:flags=lanczos,split[s0][s1];[s0]palettegen[p];[s1][p]paletteuse" \
    output.gif
```

### gifsicle Post-Processing

```bash
# Install: brew install gifsicle  OR  sudo apt install gifsicle
# Optimize existing GIF
gifsicle -O3 --lossy=80 -o optimized.gif input.gif
```

---

## Demo Automation Workflow

For structured plugin demos, the recommended pattern is:

```
start recording
  → annotate "Plugin Name — Command"
  → sleep 1 (annotation renders)
  → run command / show output
  → sleep 2-3 (viewer can read)
  → annotate "Result"
  → sleep 2
stop recording
convert to GIF
```

The `scripts/demo-all.sh` script implements this for all 13 Memoriant plugins.
Each plugin gets its own GIF written to `demos/<plugin-name>-demo.gif`.

---

## Troubleshooting

| Problem | Cause | Fix |
|---------|-------|-----|
| Black/blank recording (macOS) | Screen Recording permission not granted | System Settings > Privacy > Screen Recording |
| `ffmpeg: command not found` | ffmpeg not installed | `brew install ffmpeg` or `sudo apt install ffmpeg` |
| x11grab: cannot open display | DISPLAY not set or X11 not running | `export DISPLAY=:0` or start Xvfb |
| wf-recorder: failed to open DRM device | Wayland compositor not detected | Ensure running under Wayland, not XWayland |
| File not found after stop | Process killed before finalizing | Use `kill -INT` not `kill -9`; wait 1s after stop |
| GIF is huge | Using single-pass conversion | Use two-pass palette method (see gif command) |
| screencapture exits immediately | Missing `-v` flag (video mode) | Ensure `-v` is present: `screencapture -v file.mov` |
| PID file stale after crash | Previous recording crashed | `rm ~/.memoriant/recordings/.recording.pid` |

---

## File Layout

```
~/.memoriant/
└── recordings/
    ├── .recording.pid          # PID of active recording process
    ├── .last_recording         # Path stub of most recent recording
    ├── recording-20250326-143022.mov
    ├── recording-20250326-143022.gif
    └── ...
```

Demo GIFs from `demo-all.sh` are written to the local `demos/` directory
within the repo, not the recordings directory.

---

## Version History

| Version | Changes |
|---------|---------|
| 1.0.0 | Initial release — start/stop/gif/annotate/demo/status. macOS + Linux. |
