# memoriant-screen-recorder

![Version](https://img.shields.io/badge/version-1.0.0-blue)
![License](https://img.shields.io/badge/license-MIT-green)
![Platform](https://img.shields.io/badge/platform-macOS%20%7C%20Linux-lightgrey)
![Marketplace](https://img.shields.io/badge/marketplace-Memoriant-purple)

Screen recording for Claude Code. Record demos, tutorials, and bug reproductions directly from your AI coding session. Export as MP4 or optimized GIF. Claude guides you through the entire process conversationally.

Part of the [Memoriant Plugin Marketplace](https://github.com/NathanMaine/memoriant-marketplace).

---

## Install

```bash
/install NathanMaine/memoriant-screen-recorder-skill
```

---

## How It Actually Works

This is a Claude Code **skill** — a set of detailed instructions (in `SKILL.md`) that Claude reads and follows. There's no background daemon, no server, no runtime. Here's the chain:

### 1. You install the plugin

Claude Code downloads the repo to `~/.claude/plugins/` and reads the `plugin.json` manifest, which points to the skills and agents inside.

### 2. You ask Claude to record

You don't need to memorize commands. Just talk naturally:

```
You: record my screen, just the terminal window
```

### 3. Claude reads the SKILL.md

The SKILL.md is Claude's instruction manual. It contains everything Claude needs to know: which recording tools exist on your OS, how to use them, what options are available, and how to guide you through choices. Claude loads this into its context and now "knows" screen recording.

### 4. Claude runs real system commands

Claude uses your Mac's built-in `screencapture` (or `ffmpeg` on Linux) to actually record the screen. These are real system processes — not simulated. Claude runs them via its Bash tool:

```bash
screencapture -v -l <window_id> ~/recording.mov &
```

### 5. Claude manages the session

Claude saves the process ID so it can stop the recording later. When you say "stop," it sends a signal to gracefully end the recording and tells you where the file is.

**The key insight:** The SKILL.md is the program. Claude's LLM capabilities are the runtime. Your system's recording tools are the execution engine.

---

## What It Feels Like to Use

### Simple recording

```
You: start a screen recording

Claude: How would you like to record?

  1) Full screen — captures your entire display
  2) Select region — drag to select an area (recommended for demos)
  3) Click window — click on the window to capture
  4) Terminal only — auto-capture just the terminal window

  I'd recommend option 2 for demos — you can frame exactly
  what you want without desktop clutter.

You: 2

Claude: Drag to select the recording area...
  [macOS crosshair appears, you drag a rectangle]

  Recording started (region): ~/.memoriant/recordings/recording-20260326-143000.mov
  Run /screen-record stop when you're finished.

  ... you do your demo ...

You: stop recording

Claude: Recording saved: recording-20260326-143000.mov (12.4MB)
  Duration: ~45 seconds

  Want me to convert it to a GIF for your README?

You: yes, make it 800px wide

Claude: Converting to GIF (fps=15, width=800)...
  GIF saved: recording-20260326-143000.gif (3.2MB)
```

### Direct and specific

If you already know what you want, Claude skips the questions:

```
You: record just the terminal window

Claude: [detects terminal window ID via AppleScript]
  Recording started (terminal): ~/.memoriant/recordings/recording-20260326-150000.mov

You: stop and convert to gif

Claude: Recording saved (8.7MB). Converting to GIF...
  GIF saved: recording-20260326-150000.gif (2.1MB)
```

### Demo with annotations

```
You: I want to record a demo of the patent search plugin with a title card

Claude: Starting recording... Drag to select the area.
  [you select the terminal region]

  [prints styled title card:]

  ╔══════════════════════════════════════╗
  ║   Patent Search Demo                 ║
  ║   /patent-search "wireless power"    ║
  ╚══════════════════════════════════════╝

  Title card displayed. Now run your demo commands —
  I'll keep recording until you say stop.
```

---

## Capture Modes

| Mode | What It Does | Best For |
|------|-------------|----------|
| **Full screen** | Records entire display | Presentations, multi-window workflows |
| **Select region** | You drag a rectangle to define the area | Clean demo recordings (recommended) |
| **Click window** | Click on any window to capture just that window | Recording a specific app |
| **Terminal only** | Auto-detects and captures the frontmost terminal | Quick terminal demos |

Claude recommends **select region** for demos — it gives you the cleanest output without accidentally showing notifications, browser tabs, or other desktop clutter.

### How each mode works under the hood

**macOS:**

| Mode | Command |
|------|---------|
| Full screen | `screencapture -v output.mov` |
| Select region | `screencapture -v -i output.mov` (crosshair appears) |
| Click window | `screencapture -v -i -w output.mov` (click target) |
| Terminal only | `screencapture -v -l <window_id> output.mov` (auto-detected via AppleScript) |

**Linux (X11):**

| Mode | Command | Extra tool needed |
|------|---------|-------------------|
| Full screen | `ffmpeg -f x11grab -s <resolution> -i :0.0 output.mp4` | None |
| Select region | `slop` picks the area, then ffmpeg records it | `sudo apt install slop` |
| Click window | `xdotool selectwindow` picks the window | `sudo apt install xdotool` |

---

## Commands Reference

| Command | What It Does |
|---------|-------------|
| `/screen-record start` | Start recording (asks for capture mode) |
| `/screen-record start fullscreen` | Start full screen recording (no prompt) |
| `/screen-record start region` | Start with region selection |
| `/screen-record start window` | Start with window click selection |
| `/screen-record start terminal` | Start recording terminal only |
| `/screen-record stop` | Stop recording, report file path and size |
| `/screen-record gif` | Convert last recording to optimized GIF (15fps, 800px) |
| `/screen-record gif 10 600` | Custom GIF settings (10fps, 600px wide) |
| `/screen-record annotate "Title"` | Print a styled title card in the terminal |
| `/screen-record demo <plugin>` | Record a scripted demo of a specific plugin |
| `/screen-record status` | Check if a recording is active |

But you don't need to memorize any of these. Just tell Claude what you want in plain English and it figures out the right command.

---

## Demo Automation

Record demos of all your Memoriant plugins in one shot:

```bash
# Show all plugin demos (display only, no recording)
./scripts/demo-all.sh

# Record each plugin demo and save individual GIFs
./scripts/demo-all.sh ~/demos --record
```

Covers all 14 Memoriant plugins with title cards and pauses between each.

---

## GIF Optimization

GIF conversion uses ffmpeg's two-pass palette method for maximum quality at minimum file size:

```bash
ffmpeg -vf "fps=15,scale=800:-1:flags=lanczos,split[s0][s1];[s0]palettegen[p];[s1][p]paletteuse"
```

Default: 15fps, 800px wide. Customize via Claude:

```
You: convert to gif but make it smaller, 10fps and 600px wide

Claude: Converting (fps=10, width=600)...
  GIF saved: recording.gif (1.8MB)
```

For even smaller GIFs, install [gifsicle](https://www.lcdf.org/gifsicle/):

```bash
gifsicle -O3 --lossy=80 -o optimized.gif recording.gif
```

---

## Setup

### macOS

No install needed for recording — `screencapture` is built into every Mac.

For GIF conversion: `brew install ffmpeg`

**First-time permission:** The first time you record, macOS will show a "Screen Recording" permission dialog. Go to System Settings > Privacy & Security > Screen Recording and allow your terminal app (Terminal, iTerm2, Warp, etc.).

### Linux

```bash
# Recording (required)
sudo apt install ffmpeg

# Region selection (optional, for "select region" mode)
sudo apt install slop

# Window selection (optional, for "click window" mode)
sudo apt install xdotool
```

---

## Where Recordings Go

All recordings are saved to `~/.memoriant/recordings/` by default.

```
~/.memoriant/recordings/
├── recording-20260326-143000.mov     # Original video
├── recording-20260326-143000.gif     # Converted GIF
├── recording-20260326-150000.mov
├── .recording.pid                     # Active recording PID (temporary)
└── .last_recording                    # Path to most recent recording
```

Override with `RECORD_DIR`:

```bash
RECORD_DIR=/tmp/my-demos /screen-record start
```

---

## FAQ

**Do I need to learn any commands?**
No. Just tell Claude what you want: "record my screen," "stop recording," "make a gif." Claude handles the rest.

**Can Claude record itself?**
Yes — Claude runs the recording tool in the background and continues working. You can ask Claude to run a patent search while recording, and it captures everything.

**What if I have multiple monitors?**
Use "select region" mode — drag across the area you want. Or "click window" to pick a specific window on any monitor.

**Does it work in VS Code's terminal?**
Yes. The recording captures whatever is on screen. If Claude Code is running in VS Code's integrated terminal, "select region" or "terminal only" mode will capture it.

**Can I record, then edit, then export?**
The skill records and converts. For editing (trimming, cutting), use ffmpeg directly:
```bash
# Trim to first 30 seconds
ffmpeg -i recording.mov -t 30 -c copy trimmed.mov
```
Or ask Claude: "trim my last recording to the first 30 seconds."

**What format is the output?**
- macOS: `.mov` (H.264, via screencapture)
- Linux: `.mp4` (H.264, via ffmpeg)
- GIF: `.gif` (palette-optimized, configurable fps/width)

---

## The Helper Script

The plugin includes `scripts/record.sh` — a standalone bash script that wraps all recording functionality. Claude can call this script, or run the commands directly. Both work.

```bash
# Direct usage (without Claude)
./scripts/record.sh start           # Interactive mode selection
./scripts/record.sh start region    # Skip prompt, go straight to region select
./scripts/record.sh stop
./scripts/record.sh gif 15 800
./scripts/record.sh annotate "My Demo"
./scripts/record.sh status
```

---

## Troubleshooting

| Problem | Fix |
|---------|-----|
| **Black/blank recording on macOS** | Screen Recording permission not granted. System Settings > Privacy & Security > Screen Recording > add your terminal. |
| **"No screen recorder found"** | Install ffmpeg: `brew install ffmpeg` (macOS) or `sudo apt install ffmpeg` (Linux) |
| **x11grab: cannot open display** | Set `export DISPLAY=:0` or start Xvfb for headless |
| **GIF is too large** | Lower fps and width: `/screen-record gif 10 600`. Or post-process with gifsicle. |
| **File not found after stop** | Process may still be finalizing. Wait 2-3 seconds and check `~/.memoriant/recordings/` |
| **"Terminal only" mode doesn't detect window** | AppleScript needs accessibility permissions. Falls back to region select. |
| **Permission denied on record.sh** | Run `chmod +x scripts/record.sh` |

---

## Cross-Platform Support

This plugin works with multiple AI coding assistants:

### Claude Code (Primary)
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

---

## Marketplace

This plugin is part of the [Memoriant Plugin Marketplace](https://github.com/NathanMaine/memoriant-marketplace) — 14 Claude Code plugins covering patent workflow, code quality, architecture, compliance, and developer experience.

```bash
/plugin marketplace add NathanMaine/memoriant-marketplace
```

---

## License

MIT — [Nathan Maine](https://github.com/NathanMaine)
