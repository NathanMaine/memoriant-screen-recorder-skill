---
name: screen-recorder
description: >
  Manage screen recordings from within Claude Code. Runs a guided six-step
  interactive flow: preflight check, capture mode selection, window picker,
  save location, record, format choice. Supports macOS (screencapture +
  ffmpeg/avfoundation) and Linux (ffmpeg/x11grab, wf-recorder).
compatibility: macOS, Linux
metadata:
  version: "2.0.0"
  commands:
    - /screen-record setup
    - /screen-record start
    - /screen-record start fullscreen
    - /screen-record start pick
    - /screen-record stop
    - /screen-record gif
    - /screen-record crop
    - /screen-record annotate <text>
    - /screen-record status
---

# Screen Recorder Skill

## Overview

This skill teaches Claude Code to manage screen recording sessions through a
guided six-step interactive flow. Recordings are saved to a working directory
(`~/.memoriant/recordings/` by default) and then copied to a user-chosen
destination. A PID file tracks the active recording process so stop/status

## CRITICAL RULES — READ THESE FIRST

**NEVER use `screencapture -v -i` or `screencapture -v -i -w`.** These do NOT work.
macOS does not support interactive video selection. You will get: `screencapture: video not valid with -i`

**NEVER tell the user to click on a window, drag to select, or look for crosshairs.** There are no crosshairs for video recording on macOS.

**The ONLY methods that work for window recording:**
1. **Pick mode:** List windows as a table → user picks a number → ffmpeg records with real-time crop
2. **Fullscreen:** `screencapture -v output.mov` (records everything)

**When the user asks to record a window, ALWAYS:**
1. Run the AppleScript to get all visible windows
2. Present them as a **markdown table** — never as a raw numbered list
3. Format: `| # | App | Window | Size |` with clean, truncated titles
4. Ask "Which number?" and start recording immediately after they answer
5. Use ffmpeg with the crop filter to record ONLY that window
6. Do NOT ask extra questions — list windows, get number, record
7. To stop: `kill -INT <pid>` — NOT "click the stop button in the menu bar"

Example of the correct format:

| # | App | Window | Size |
|---|-----|--------|------|
| 1 | Terminal | zsh | 597x385 |
| 2 | Google Chrome | New Tab | 1649x1866 |
| 3 | Code | patent submit skill | 1581x1431 |

Which number?
work reliably across commands.

The helper script at `scripts/record.sh` implements all commands. Claude
should run it via Bash, or run equivalent commands directly.

---

## The Six-Step Flow

When the user says anything like "record my screen", "start a recording",
or "record the terminal window", run `record.sh start` (or equivalent).

The flow always executes all six steps in order:

```
Step 1 — Preflight check
Step 2 — Choose capture mode (fullscreen or pick a window)
Step 3 — Window picker (if pick mode)
Step 4 — Choose save location
Step 5 — Record
Step 6 — (after stop) Choose output format, copy files
```

---

## Step 1 — Preflight Check

Before recording, verify the environment. Run:

```bash
./scripts/record.sh setup
```

Or perform the checks inline inside `start`. Either way, the user sees:

```text
Step 1: Checking dependencies...
  ✓ macOS detected
  ✓ screencapture available
  ✓ ffmpeg 7.1 installed
  ✓ Screen Recording permission granted
  ✓ Accessibility permission granted
```

**Screen Recording permission test (macOS):**

```bash
screencapture -x /tmp/.memoriant-screen-test.png 2>/dev/null
if [[ $? -eq 0 && -s /tmp/.memoriant-screen-test.png ]]; then
    echo "  ✓ Screen Recording permission granted"
else
    echo "  ✗ Screen Recording permission NOT granted"
    echo "      Fix: System Settings > Privacy & Security > Screen Recording"
fi
rm -f /tmp/.memoriant-screen-test.png
```

**Accessibility permission test (macOS):**

```bash
acc=$(osascript -e \
    'tell application "System Events" to return name of first application process whose frontmost is true' \
    2>/dev/null || echo "")
if [[ -n "$acc" ]]; then
    echo "  ✓ Accessibility permission granted"
else
    echo "  ✗ Accessibility permission NOT granted"
    echo "      Fix: System Settings > Privacy & Security > Accessibility"
fi
```

If any check fails, stop and tell the user exactly what to fix before
proceeding. Do not start a recording that will produce a blank file.

---

## Step 2 — Choose Capture Mode

After preflight passes, ask:

```text
Step 2: What would you like to record?

  1) Full screen
  2) Pick a window (recommended)

  Which mode? (1/2, default: 2):
```

- If the user already said "fullscreen" or passed `start fullscreen`, skip
  to Step 4.
- If the user already said "pick" or "window" or named a specific app, skip
  to Step 3.
- Otherwise, present the prompt and wait for input.

---

## Step 3 — Window Picker (pick mode only)

Query all visible windows via AppleScript and display a formatted table:

```bash
osascript -e '
    tell application "System Events"
        set output to ""
        repeat with proc in (every application process whose visible is true)
            try
                repeat with win in (every window of proc)
                    set winName to name of win
                    set appName to name of proc
                    set {x, y} to position of win
                    set {w, h} to size of win
                    set output to output & appName & "|" & winName & "|" \
                        & (x as text) & "|" & (y as text) & "|" \
                        & (w as text) & "|" & (h as text) & linefeed
                end repeat
            end try
        end repeat
        return output
    end tell
'
```

Format as a table:

```text
Step 3: Open windows:
  | #  | App             | Window                              | Size       |
  |----|-----------------|-------------------------------------|------------|
  |  1 | Terminal        | zsh                                 | 597x385    |
  |  2 | Google Chrome   | New Tab                             | 1649x1866  |
  |  3 | Code            | patent submit skill                 | 1581x1431  |

  Which window? (1-3):
```

Store the selected window's `x`, `y`, `w`, `h` for Step 5. Ensure `w` and
`h` are even numbers (libx264 requirement):

```bash
w=$(( (w / 2) * 2 ))
h=$(( (h / 2) * 2 ))
```

If no windows are found, or the user picks an invalid number, fall back to
fullscreen and continue.

---

## Step 4 — Save Location

Ask where to save the final output files:

```text
Step 4: Where should I save the output?
  Default: ~/Desktop
  Path (or press Enter for default):
```

- Default to `~/Desktop`.
- Accept any valid directory path, expanding `~` to `$HOME`.
- Create the directory if it does not exist (`mkdir -p`).
- Store the path in `~/.memoriant/recordings/.save_dir` so `stop` can
  read it later.

---

## Step 5 — Record

Start the recording in the background. Save the PID and the output filename
stub so `stop` can find them.

**macOS — pick mode (window crop via ffmpeg):**

```bash
FILENAME="$RECORD_DIR/recording-$(date +%Y%m%d-%H%M%S)"

# Find the screen capture device
SCREEN_DEV=$(ffmpeg -f avfoundation -list_devices true -i "" 2>&1 \
    | grep -i "capture screen" | head -1 \
    | sed 's/.*\[\([0-9]*\)\].*/\1/' || echo "5")

ffmpeg -y -f avfoundation -framerate 30 -i "${SCREEN_DEV}:none" \
    -vf "crop=${w}:${h}:${x}:${y}" \
    -c:v libx264 -preset ultrafast -pix_fmt yuv420p \
    "$FILENAME.mov" > /dev/null 2>&1 &

echo $! > "$PID_FILE"
echo "$FILENAME" > "$LAST_FILE"
```

**macOS — fullscreen (screencapture):**

```bash
screencapture -v "$FILENAME.mov" &
echo $! > "$PID_FILE"
echo "$FILENAME" > "$LAST_FILE"
```

**Why `screencapture -v -i` does not work:** Apple's `screencapture` does
not support combining `-v` (video) and `-i` (interactive). The error is
`screencapture: video not valid with -i`. This is a hard macOS limitation.
Pick mode solves it via ffmpeg's real-time crop filter instead.

**Linux — ffmpeg x11grab:**

```bash
DISPLAY="${DISPLAY:-:0.0}"
RES=$(xdpyinfo 2>/dev/null | grep dimensions | awk '{print $2}' || echo "1920x1080")
ffmpeg -f x11grab -r 30 -s "$RES" -i "$DISPLAY" "$FILENAME.mp4" > /dev/null 2>&1 &
echo $! > "$PID_FILE"
echo "$FILENAME" > "$LAST_FILE"
```

**Linux — wf-recorder (Wayland):**

```bash
wf-recorder -f "$FILENAME.mp4" &
echo $! > "$PID_FILE"
echo "$FILENAME" > "$LAST_FILE"
```

After starting, confirm to the user:

```text
Step 5: Recording...

  [REC] PID: 48291
  [REC] Output: ~/.memoriant/recordings/recording-20260326-114228.*

  Run 'record.sh stop' to finish.
```

---

## Step 6 — Stop, Choose Format, Copy Files

When the user says "stop", run `record.sh stop` (or equivalent):

1. Send SIGINT to the recording PID. Use SIGINT not SIGKILL — ffmpeg,
   screencapture, and wf-recorder all finalize cleanly on SIGINT.

   ```bash
   kill -INT "$pid" 2>/dev/null || kill "$pid" 2>/dev/null || true
   sleep 2   # allow final frames to flush
   rm -f "$PID_FILE"
   ```

2. Find the output file and report its size.

3. Ask the user which format they want:

   ```text
   Step 6: What format do you want?

     1) Video only (.mov)
     2) GIF only (.gif)
     3) Both video and GIF

     Format? (1/2/3, default: 3):
   ```

4. Convert to GIF if needed (two-pass palette method):

   ```bash
   ffmpeg -y -i "$infile" \
       -vf "fps=15,scale=800:-1:flags=lanczos,split[s0][s1];[s0]palettegen[p];[s1][p]paletteuse" \
       "$outfile.gif" 2>/dev/null
   ```

5. Copy the chosen files to the save directory from Step 4:

   - Video only: copy `.mov` (or `.mp4`) to save dir.
   - GIF only: convert, copy `.gif` to save dir, do not copy the video.
   - Both: copy both files.

6. Report final paths and sizes:

   ```text
   Done! Files saved:
     ~/Desktop/recording-20260326-114228.mov (12.4MB)
     ~/Desktop/recording-20260326-114228.gif (3.4MB)
   ```

---

## /screen-record setup

Run the standalone preflight check without starting a recording:

```bash
./scripts/record.sh setup
```

Reports OS, screencapture availability, ffmpeg version, Screen Recording
permission, Accessibility permission, and available avfoundation devices.
Prints exact fix instructions for anything that fails.

---

## /screen-record gif

Convert the last recording to a GIF without going through the full flow:

```bash
./scripts/record.sh gif [fps] [width]
# defaults: 15fps, 800px wide
```

Uses the two-pass palette method. Always use this over single-pass — the
quality difference is significant and file sizes are smaller.

---

## /screen-record crop

Crop the last recording to the bounds of the frontmost window. Uses
AppleScript to detect position/size, then ffmpeg to crop:

```bash
./scripts/record.sh crop
```

This is Method 1 for window capture: record fullscreen first, then crop
after the fact. Useful when you forgot to use pick mode.

---

## /screen-record annotate \<text\>

Print a styled ANSI title card. Useful for labeling demo sections that
will appear in the recording.

```bash
./scripts/record.sh annotate "My Demo Title"
```

Output:

```text
╔════════════════════╗
║  My Demo Title     ║
╚════════════════════╝
```

---

## /screen-record status

Check whether a recording is currently active:

```bash
./scripts/record.sh status
```

---

## macOS-Specific Notes

### avfoundation device index

The screen capture device index varies by machine. Find it:

```bash
ffmpeg -f avfoundation -list_devices true -i "" 2>&1 | grep -i "capture screen"
```

The script auto-detects this index at recording time. If auto-detection
fails, it defaults to `5` (common on Apple Silicon Macs).

### Retina displays

macOS reports window coordinates in logical pixels (points). avfoundation
captures at physical pixels (2x on Retina). ffmpeg handles the scaling
automatically when using the avfoundation input device — the crop
coordinates passed from AppleScript will work correctly.

### Permissions summary

| Permission | Required for | Where to grant |
| --- | --- | --- |
| Screen Recording | All video capture | System Settings > Privacy & Security > Screen Recording |
| Accessibility | Window picker (AppleScript) | System Settings > Privacy & Security > Accessibility |

---

## Linux-Specific Notes

### X11 (ffmpeg x11grab)

```bash
# Check display
echo $DISPLAY

# Full screen
ffmpeg -f x11grab -r 30 -s 1920x1080 -i :0.0 output.mp4 &

# Region (requires slop)
GEOM=$(slop -f "%wx%h+%x,%y")
SIZE=$(echo "$GEOM" | cut -d'+' -f1)
OFFSET=$(echo "$GEOM" | cut -d'+' -f2)
ffmpeg -f x11grab -r 30 -s "$SIZE" -i ":0.0+$OFFSET" output.mp4 &
```

### Wayland (wf-recorder)

```bash
wf-recorder -f output.mp4 &
killall -SIGINT wf-recorder   # to stop
```

---

## GIF Quality Reference

| Use case | FPS | Width | Expected size |
| --- | --- | --- | --- |
| README preview / badge | 10 | 600 | 2–5 MB |
| Tutorial clip (30s) | 15 | 800 | 5–12 MB |
| Full demo (60s) | 15 | 1024 | 12–25 MB |

Post-process with gifsicle for additional size reduction:

```bash
gifsicle -O3 --lossy=80 -o optimized.gif input.gif
```

---

## File Layout

```text
~/.memoriant/
└── recordings/
    ├── .recording.pid          # PID of active recording process
    ├── .last_recording         # Path stub of most recent recording
    ├── .save_dir               # User-chosen destination directory
    ├── recording-20260326-114228.mov
    ├── recording-20260326-114228.gif
    └── ...
```

Final output files are copied from `recordings/` to the directory the user
chose in Step 4. The working files in `recordings/` remain as a cache.

---

## Troubleshooting Reference

| Problem | Cause | Fix |
| --- | --- | --- |
| Black/blank recording (macOS) | Screen Recording permission not granted | System Settings > Privacy > Screen Recording |
| `ffmpeg: command not found` | ffmpeg not installed | `brew install ffmpeg` or `sudo apt install ffmpeg` |
| Window picker shows nothing | Accessibility permission not granted | System Settings > Privacy > Accessibility |
| x11grab: cannot open display | DISPLAY not set | `export DISPLAY=:0` |
| File not found after stop | Process still finalizing | Wait 2s; check `~/.memoriant/recordings/` |
| GIF is huge | Single-pass conversion | Use two-pass palette method (default in this skill) |
| PID file stale after crash | Previous recording crashed | `rm ~/.memoriant/recordings/.recording.pid` |

---

## Version History

| Version | Changes |
| --- | --- |
| 2.0.0 | Complete rewrite: six-step guided flow, preflight check, window table, save location prompt, format selection after stop. |
| 1.0.0 | Initial release — start/stop/gif/annotate/demo/status. macOS + Linux. |
