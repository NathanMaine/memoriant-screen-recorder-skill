# memoriant-screen-recorder

![Version](https://img.shields.io/badge/version-2.0.0-blue)
![License](https://img.shields.io/badge/license-MIT-green)
![Platform](https://img.shields.io/badge/platform-macOS%20%7C%20Linux-lightgrey)
![Marketplace](https://img.shields.io/badge/marketplace-Memoriant-purple)

Screen recording for Claude Code. Record demos, tutorials, and bug reproductions directly from your AI coding session. Export as video, GIF, or both. Claude guides you through a six-step interactive flow — no commands to memorize.

Part of the [Memoriant Plugin Marketplace](https://github.com/NathanMaine/memoriant-marketplace).

---

## Install

```bash
/install NathanMaine/memoriant-screen-recorder-skill
```

---

## Installation Methods

### Method 1: Clone to plugins directory (recommended)

```bash
git clone https://github.com/NathanMaine/memoriant-screen-recorder-skill.git \
    ~/.claude/plugins/memoriant-screen-recorder-skill
chmod +x ~/.claude/plugins/memoriant-screen-recorder-skill/scripts/*.sh
```

Then in Claude Code: `/reload-plugins`

### Method 2: Direct script usage (works immediately, any session)

Even without plugin registration, you can use the recording script directly. Tell Claude:

```
run ~/.claude/plugins/memoriant-screen-recorder-skill/scripts/record.sh setup
```

Or use the script manually:

```bash
# Check everything is ready
~/.claude/plugins/memoriant-screen-recorder-skill/scripts/record.sh setup

# Start recording (interactive)
~/.claude/plugins/memoriant-screen-recorder-skill/scripts/record.sh start

# Or specify mode directly
~/.claude/plugins/memoriant-screen-recorder-skill/scripts/record.sh start pick
~/.claude/plugins/memoriant-screen-recorder-skill/scripts/record.sh start fullscreen

# Stop
~/.claude/plugins/memoriant-screen-recorder-skill/scripts/record.sh stop

# Convert to GIF
~/.claude/plugins/memoriant-screen-recorder-skill/scripts/record.sh gif
```

### Method 3: Alias for quick access

Add to your `~/.zshrc` or `~/.bashrc`:

```bash
alias rec="~/.claude/plugins/memoriant-screen-recorder-skill/scripts/record.sh"
```

Then: `rec start pick`, `rec stop`, `rec gif`

---

## Important: Video Only (No Audio)

This skill records **video only** — no audio capture. This is by design:
- `screencapture -v` on macOS records video without audio
- `ffmpeg` with avfoundation captures the screen device only, not audio devices
- Terminal demos don't typically need audio — the visual output tells the story

**If you need audio recording**, use:
- **OBS Studio** — full screen + audio recording (`brew install --cask obs`)
- **QuickTime Player** — Cmd+Shift+5, select microphone in options
- **macOS Screen Recording** — built into macOS Sequoia, includes audio toggle

Audio support is on the [roadmap](ROADMAP.md) for v3.0.

---

## How It Actually Works

This is a Claude Code **skill** — a set of detailed instructions (in `skills/screen-recorder/SKILL.md`) that Claude reads and follows. There is no background daemon, no server, no runtime.

**The chain:**

1. You install the plugin. Claude Code reads the `plugin.json` manifest, which points to the SKILL.md.
2. You ask Claude to record — in plain English, no slash commands required.
3. Claude reads the SKILL.md. It is Claude's instruction manual: which recording tools exist, how to use them, how to guide you through choices.
4. Claude runs real system commands via its Bash tool. These are actual system processes — `screencapture` on macOS, `ffmpeg` on Linux.
5. Claude manages the session: saves the process ID so it can stop the recording later, then walks you through format selection and saving.

**The key insight:** The SKILL.md is the program. Claude's LLM capabilities are the runtime. Your system's recording tools are the execution engine.

---

## The Interactive Flow

When you say "start a screen recording," Claude runs through all six steps:

```text
Step 1: Checking dependencies...
  ✓ macOS detected
  ✓ screencapture available
  ✓ ffmpeg 7.1 installed
  ✓ Screen Recording permission granted
  ✓ Accessibility permission granted

Step 2: What would you like to record?
  1) Full screen
  2) Pick a window (recommended)

  Which mode? (1/2, default: 2): 2

Step 3: Open windows:
  | #  | App             | Window                              | Size       |
  |----|-----------------|-------------------------------------|------------|
  |  1 | Terminal        | zsh                                 | 597x385    |
  |  2 | Google Chrome   | New Tab                             | 1649x1866  |
  |  3 | Code            | patent submit skill                 | 1581x1431  |
  |  4 | Finder          | Downloads                           | 920x600    |

  Which window? (1-4): 3

Step 4: Where should I save the output?
  Default: ~/Desktop
  Path (or press Enter for default):

Step 5: Recording... (run 'record.sh stop' when done)

  [REC] PID: 48291
  [REC] Output: ~/.memoriant/recordings/recording-20260326-114228.*

  Run 'record.sh stop' to finish.

[... you do your demo ...]

  Recording captured: ~/.memoriant/recordings/recording-20260326-114228.mov (12.4MB)

Step 6: What format do you want?
  1) Video only (.mov)
  2) GIF only (.gif)
  3) Both video and GIF

  Format? (1/2/3, default: 3): 3

  Converting to GIF...

Done! Files saved:
  ~/Desktop/recording-20260326-114228.mov (12.4MB)
  ~/Desktop/recording-20260326-114228.gif (3.4MB)
```

---

## Example Conversations

### Natural language — Claude figures out the commands

```text
You: record my screen, just the VS Code window

Claude: Starting step 1 — checking dependencies...
  [runs preflight]
  [shows window list, finds "Code — patent submit skill"]
  Recording started. Say "stop" when done.

You: stop and make it a gif

Claude: [stops recording]
  [converts to GIF, copies to Desktop]
  Done. ~/Desktop/recording-20260326-114355.gif (2.1MB)
```

```text
You: I need a demo GIF of the patent search plugin — terminal window only, save to ~/demos

Claude: On it. Let me check permissions first...
  [preflight passes]
  [shows window list]
  [you pick Terminal]
  Saving to ~/demos. Recording started.

You: okay stop it

Claude: [stops]
  Format? (1/2/3): 2
  ~/demos/recording-20260326-120011.gif (1.8MB) — done.
```

### Annotations during a recording

```text
You: record my screen and add a title card

Claude: Starting recording...
  [preflight + window picker]
  Recording live. What should the title card say?

You: "Patent Search Demo — /patent-search 'wireless power'"

Claude: [prints:]

  ╔═══════════════════════════════════════════════════════════╗
  ║  Patent Search Demo — /patent-search 'wireless power'    ║
  ╚═══════════════════════════════════════════════════════════╝

  Title card is visible in the recording. Run your demo now.
```

---

## Use Cases

### 1. Plugin Demo GIFs for GitHub READMEs
Record your Claude Code plugin in action, convert to GIF, embed in your README. This is how every plugin in the Memoriant Marketplace gets its demo.

### 2. Bug Reproduction Videos
Record the exact steps that trigger a bug. Attach the recording to a GitHub issue instead of writing "it doesn't work." The video shows exactly what happened.

### 3. Code Review Walkthroughs
Record yourself navigating through a PR, highlighting the changes and explaining your reasoning. Share the recording in the PR comments.

### 4. Tutorial / How-To Creation
Record a step-by-step tutorial showing how to use a tool, framework, or library. Convert to GIF for documentation or keep as video for longer walkthroughs.

### 5. Before/After Comparisons
Record the UI before a change, make the change, record again. Put both GIFs side by side in a PR to show the visual difference.

### 6. Onboarding New Team Members
Record your development workflow — how you run tests, deploy, debug. New team members watch the recording instead of reading a 20-page onboarding doc.

### 7. Client Demos and Progress Updates
Record your application running, showing new features or fixes. Send the video or GIF to clients who don't want to pull and run the code themselves.

### 8. Performance Testing Evidence
Record your application under load — show the UI responsiveness, network tab, metrics dashboard. Attach to performance reports as visual evidence.

### 9. Automated CI Screenshots
Use the demo-all.sh script to generate recordings of each plugin automatically. Run it on every release to keep demo GIFs up to date.

### 10. Conference Talk Preparation
Record dry runs of your terminal demos before a conference talk. Review the recordings to check pacing, identify where you need to slow down, and ensure commands work smoothly.

---

## How Pick Mode Works (Step by Step)

Pick mode records a single window without capturing the rest of your screen. Here is exactly what happens under the hood:

1. **AppleScript queries System Events** for every visible window on screen — app name, window title, x/y position, width/height.

2. **Claude formats the results** into a numbered table:

   ```text
   | #  | App             | Window                              | Size       |
   |----|-----------------|-------------------------------------|------------|
   |  1 | Terminal        | zsh                                 | 597x385    |
   |  2 | Google Chrome   | New Tab                             | 1649x1866  |
   ```

3. **You pick a number.** Claude reads the corresponding position and size.

4. **ffmpeg records the full screen** using the avfoundation device, then applies a real-time `crop` filter:

   ```bash
   ffmpeg -f avfoundation -framerate 30 -i "1:none" \
       -vf "crop=1581:1431:100:50" \
       recording.mov
   ```

   The crop rectangle is `width:height:x:y` — the exact bounds of the window you picked.

5. The result is a video that only shows that window, with no desktop clutter, no menu bar, no other apps.

---

## Why `screencapture -v -i` Does Not Work (and How We Solved It)

Apple's `screencapture` command has two flags that look like they should work together but do not:

- `-v` — video mode (records a movie instead of a screenshot)
- `-i` — interactive mode (lets you drag a rectangle or click a window)

When you combine them: `screencapture -v -i output.mov`, you get this error:

```text
screencapture: video not valid with -i
```

Apple has never implemented interactive selection for video capture in `screencapture`. This is a hard limitation with no workaround inside `screencapture` itself.

**How we solved it:** Two methods, depending on what you need.

### Method 1 — Fullscreen then crop after

Record the entire screen with `screencapture -v`, then use `record.sh crop` to trim it to the frontmost window after the fact. Simple, reliable, no extra tools needed.

```bash
# Record everything
screencapture -v recording.mov

# Crop to frontmost window (auto-detected via AppleScript)
record.sh crop
```

Best for: quick recordings where you do not mind the extra crop step.

### Method 2 — ffmpeg with real-time crop (used in pick mode)

Use AppleScript to get the pixel coordinates of the window you want, then tell ffmpeg to record the full screen but apply a crop filter that isolates just that window — in real time, as it records.

```bash
# Get window bounds
bounds=$(osascript -e '
    tell application "System Events"
        set frontApp to first application process whose frontmost is true
        set frontWindow to first window of frontApp
        set {x, y} to position of frontWindow
        set {w, h} to size of frontWindow
        return (x as text) & "," & (y as text) & "," & (w as text) & "," & (h as text)
    end tell
')

# Record with real-time crop
ffmpeg -f avfoundation -framerate 30 -i "1:none" \
    -vf "crop=${w}:${h}:${x}:${y}" \
    -c:v libx264 -preset ultrafast -pix_fmt yuv420p \
    recording.mov
```

Best for: clean demos where you want a single window from the start, with no post-processing step.

**Pick mode uses Method 2.** You select the window from the list, and ffmpeg crops to it in real time.

---

## Setup and Preflight Check

### Run the preflight check before your first recording

```bash
record.sh setup
```

Output:

```text
Preflight check
───────────────────────────────────────────────────────────────────
  ✓ macOS detected
  ✓ screencapture available
  ✓ ffmpeg 7.1 installed
  ✓ Screen Recording permission granted
  ✓ Accessibility permission granted

  Available screen capture devices:
    [AVFoundation] [0] Capture screen 0
    [AVFoundation] [1] Capture screen 1

───────────────────────────────────────────────────────────────────
  All checks passed. Ready to record.
```

If anything fails, the setup command prints the exact fix.

### macOS permissions — step by step

**Screen Recording** (required to capture video):

1. Open System Settings
2. Go to Privacy & Security > Screen Recording
3. Find your terminal app (Terminal, iTerm2, Warp, etc.) in the list
4. Toggle it on
5. Restart the terminal app

**Accessibility** (required for window picker):

1. Open System Settings
2. Go to Privacy & Security > Accessibility
3. Find your terminal app
4. Toggle it on

You only need to do this once.

### Install ffmpeg (required for GIF conversion and pick mode)

```bash
# macOS
brew install ffmpeg

# Ubuntu / Debian
sudo apt install ffmpeg

# Fedora
sudo dnf install ffmpeg

# Arch
sudo pacman -S ffmpeg
```

---

## All Commands Reference

| Command | What It Does |
| --- | --- |
| `record.sh setup` | Preflight check — OS, tools, permissions, devices |
| `record.sh start` | Full interactive flow (all 6 steps) |
| `record.sh start fullscreen` | Skip prompts — fullscreen, Desktop, ask format after stop |
| `record.sh start pick` | Skip step 2 and go straight to window list |
| `record.sh stop` | Stop recording, choose format, copy to save location |
| `record.sh gif` | Convert last recording to GIF (15fps, 800px) |
| `record.sh gif 10 600` | Custom GIF settings (10fps, 600px wide) |
| `record.sh crop` | Crop last recording to frontmost window bounds |
| `record.sh annotate "Title"` | Print styled title card in terminal |
| `record.sh status` | Check if a recording is active |

You do not need to memorize these. Just tell Claude what you want in plain English.

---

## GIF Conversion

GIF conversion uses ffmpeg's two-pass palette method — the highest quality approach available without third-party encoders:

```bash
ffmpeg -y -i input.mov \
    -vf "fps=15,scale=800:-1:flags=lanczos,split[s0][s1];[s0]palettegen[p];[s1][p]paletteuse" \
    output.gif
```

Single-pass GIF conversion produces muddy colors and banding. The palette method generates a custom 256-color palette from your specific video, then uses it when encoding — resulting in significantly sharper, more accurate GIFs at smaller file sizes.

### Size vs quality guide

| Use case | FPS | Width | Expected size |
| --- | --- | --- | --- |
| README preview / badge | 10 | 600 | 2–5 MB |
| Tutorial clip (30s) | 15 | 800 | 5–12 MB |
| Full demo (60s) | 15 | 1024 | 12–25 MB |

For even smaller GIFs, post-process with gifsicle:

```bash
brew install gifsicle
gifsicle -O3 --lossy=80 -o optimized.gif recording.gif
```

---

## Where Files Go

During recording, files go to the working directory:

```text
~/.memoriant/recordings/
├── recording-20260326-114228.mov   # captured video
├── recording-20260326-114228.gif   # converted GIF (if requested)
├── .recording.pid                   # active recording PID (temporary)
├── .last_recording                  # path stub for last recording
└── .save_dir                        # chosen save location
```

After you choose a format in Step 6, the final files are copied to your chosen save location (default: `~/Desktop`).

Override the working directory:

```bash
RECORD_DIR=/tmp/my-demos record.sh start
```

---

## FAQ

**Do I need to learn any commands?**
No. Just tell Claude what you want: "record my screen," "stop recording," "make a gif." Claude handles the commands.

**Can Claude record itself while working?**
Yes. Claude runs the recording tool in the background and keeps working. You can ask Claude to run a demo while it records, and it captures everything.

**What if I have multiple monitors?**
Use pick mode — select the window you want from the list. It works regardless of which monitor the window is on.

**Does it work in VS Code's terminal?**
Yes. The recording captures the screen. Run it from VS Code's integrated terminal and pick mode will see VS Code's windows.

**What if my window moves or resizes during recording?**
The crop coordinates are captured at recording start. If the window moves, the recording will show whatever is in that rectangle — including parts of other windows. Keep the window stationary during recording.

**Can I record, then edit, then export?**
The skill records and converts. For editing, use ffmpeg directly:

```bash
# Trim to first 30 seconds
ffmpeg -i recording.mov -t 30 -c copy trimmed.mov

# Or ask Claude: "trim my last recording to the first 30 seconds"
```

---

## Known Limitations

| Limitation | Reason | Workaround |
|-----------|--------|------------|
| **No audio recording** | screencapture -v and ffmpeg avfoundation screen capture don't include audio by default | Use OBS or QuickTime for audio |
| **No interactive region select from Claude Code** | macOS screencapture -v doesn't support -i (interactive). Claude Code's shell lacks GUI event loop | Use pick mode (lists windows) or fullscreen + crop |
| **Single recording at a time** | One PID file tracks one session | Multi-session support planned for v2.1 |
| **Window must stay visible** | ffmpeg crops from the full screen capture — if a window is hidden or minimized, it won't appear | Keep the target window visible during recording |
| **Retina displays may double coordinates** | macOS reports logical pixels but ffmpeg may capture at physical pixels | If crop is offset, try doubling x/y/w/h values |
| **Large GIFs** | Long recordings at high resolution produce multi-MB GIFs | Lower fps (10) and width (600) for smaller files |

---

## Troubleshooting

| Problem | Fix |
| --- | --- |
| Black / blank recording on macOS | Screen Recording permission not granted. System Settings > Privacy & Security > Screen Recording. Add your terminal. Restart it. |
| "No screen recorder found" | Install ffmpeg: `brew install ffmpeg` (macOS) or `sudo apt install ffmpeg` (Linux) |
| Window picker shows no windows | Accessibility permission not granted. System Settings > Privacy & Security > Accessibility. |
| Window picker shows wrong size | macOS reports logical pixels. On a Retina display, the actual pixel count is 2x. ffmpeg handles this automatically via the avfoundation device. |
| GIF is too large | Lower fps and width: `record.sh gif 10 600`. Post-process with gifsicle. |
| File not found after stop | Process may still be finalizing. Wait 2–3 seconds and check `~/.memoriant/recordings/` |
| "Permission denied on record.sh" | Run `chmod +x scripts/record.sh` |
| x11grab: cannot open display | Set `export DISPLAY=:0` or start Xvfb for headless environments |
| PID file stale after crash | `rm ~/.memoriant/recordings/.recording.pid` |

---

## Demo Automation

Record all plugin demos at once:

```bash
# Show all plugin demos (display only, no recording)
./scripts/demo-all.sh

# Record each plugin demo and save individual GIFs
./scripts/demo-all.sh ~/demos --record
```

---

## Cross-Platform Support

This plugin works with multiple AI coding assistants.

### Claude Code (primary)

```bash
/install NathanMaine/memoriant-screen-recorder-skill
```

### OpenAI Codex CLI

```bash
git clone https://github.com/NathanMaine/memoriant-screen-recorder-skill.git ~/.codex/skills/screen-recorder
codex --enable skills
```

### Gemini CLI

```bash
gemini extensions install https://github.com/NathanMaine/memoriant-screen-recorder-skill.git --consent
```

All three AI runtimes can read the SKILL.md and execute the bash commands. The interactive prompts and window picker work the same way regardless of which AI is driving.

---

## Marketplace

This plugin is part of the [Memoriant Plugin Marketplace](https://github.com/NathanMaine/memoriant-marketplace) — 14 Claude Code plugins covering patent workflow, code quality, architecture, compliance, and developer experience.

```bash
/plugin marketplace add NathanMaine/memoriant-marketplace
```

---

## License

MIT — [Nathan Maine](https://github.com/NathanMaine)
