# memoriant-screen-recorder

![Version](https://img.shields.io/badge/version-1.0.0-blue)
![License](https://img.shields.io/badge/license-MIT-green)
![Platform](https://img.shields.io/badge/platform-macOS%20%7C%20Linux-lightgrey)
![Marketplace](https://img.shields.io/badge/marketplace-Memoriant-purple)

Screen recording for Claude Code. Record demos, tutorials, and bug reproductions
directly from your AI coding session. Export as MP4 or optimized GIF. Automate
demo creation for all your plugins.

Part of the [Memoriant Plugin Marketplace](https://github.com/NathanMaine/memoriant-marketplace).

---

## Install

```bash
claude plugin install https://github.com/NathanMaine/memoriant-screen-recorder-skill
```

---

## Quick Start

```bash
# Start recording
/screen-record start

# Do your thing — code, demo, reproduce a bug

# Stop and save
/screen-record stop

# Convert to GIF for your README
/screen-record gif
```

---

## Commands

| Command | Description |
|---------|-------------|
| `/screen-record start` | Start a background screen recording |
| `/screen-record stop` | Stop recording and report the output file |
| `/screen-record gif` | Convert last recording to optimized GIF |
| `/screen-record annotate <text>` | Print a styled title card in the terminal |
| `/screen-record demo <plugin-name>` | Record a scripted plugin demo |
| `/screen-record status` | Check if a recording is currently active |

---

## Demo Automation

Record demos of all your Memoriant plugins in one shot:

```bash
# Show all plugin demos (no recording — just the display)
./scripts/demo-all.sh

# Record each plugin's demo and save individual GIFs
./scripts/demo-all.sh ~/demos --record
```

The `demo-all.sh` script covers all 13 Memoriant plugins:

- Patent Search
- Test Coverage Analysis
- Architecture Review
- Documentation Drift
- Environment Bootstrap
- Load Test Planning
- Agent Evaluation
- LLM Gateway
- Task Planning
- Policy Compilation
- Voice Testing
- Remote Agent Ops
- Data Queries

---

## Annotations

Add title cards to your recordings so viewers know what they're watching:

```bash
/screen-record annotate "Patent Search Demo"
```

Output:

```
╔══════════════════════════════╗
║  Patent Search Demo          ║
╚══════════════════════════════╝
```

Uses ANSI cyan with box-drawing characters. Looks great in terminal recordings.

---

## GIF Optimization

GIF conversion uses ffmpeg's two-pass palette method for maximum quality
at minimum file size:

```bash
ffmpeg -vf "fps=15,scale=800:-1:flags=lanczos,split[s0][s1];[s0]palettegen[p];[s1][p]paletteuse"
```

Default output: 15fps, 800px wide. Customize:

```bash
# Lower fps for smaller files
/screen-record gif 10 600

# Higher resolution
/screen-record gif 24 1280
```

For even smaller GIFs, install [gifsicle](https://www.lcdf.org/gifsicle/) and
post-process:

```bash
gifsicle -O3 --lossy=80 -o optimized.gif recording.gif
```

Or use [gifski](https://gif.ski/) for higher color fidelity:

```bash
brew install gifski
gifski --fps 15 --width 800 -o output.gif *.png
```

---

## Supported Platforms

### macOS

| Tool | Install | Priority |
|------|---------|----------|
| `screencapture` | Built-in | 1st choice |
| `ffmpeg` (avfoundation) | `brew install ffmpeg` | Fallback |

**Permission required:** System Settings > Privacy & Security > Screen Recording
— add your terminal app.

### Linux

| Tool | Install | Priority |
|------|---------|----------|
| `ffmpeg` (x11grab) | `sudo apt install ffmpeg` | 1st choice (X11) |
| `wf-recorder` | `sudo apt install wf-recorder` | 1st choice (Wayland) |
| `recordmydesktop` | `sudo apt install recordmydesktop` | Fallback |

---

## Requirements

- **macOS:** No install needed (uses built-in `screencapture`). For GIF
  conversion: `brew install ffmpeg`
- **Linux:** `sudo apt install ffmpeg` (or distro equivalent)
- **GIF conversion:** ffmpeg required on both platforms

---

## Output Location

All recordings are saved to `~/.memoriant/recordings/` by default.

Override with the `RECORD_DIR` environment variable:

```bash
RECORD_DIR=/tmp/my-demos /screen-record start
```

Demo GIFs from `demo-all.sh --record` are saved to `~/demos/` (or the
directory you pass as the first argument).

---

## Troubleshooting

**Black/blank recording on macOS**
Screen Recording permission not granted. Go to System Settings > Privacy &
Security > Screen Recording and add your terminal.

**"No screen recorder found"**
Install ffmpeg: `brew install ffmpeg` (macOS) or `sudo apt install ffmpeg` (Linux).

**x11grab: cannot open display**
Set the display: `export DISPLAY=:0` — or start an Xvfb server for headless use.

**GIF is very large**
Lower the fps and width: `/screen-record gif 10 600`. Or post-process with gifsicle.

**File not found after stop**
The process may still be finalizing. Wait 2-3 seconds and check
`~/.memoriant/recordings/` directly.

---

## Marketplace

This plugin is part of the Memoriant Plugin Marketplace — a collection of
Claude Code plugins for AI-assisted development workflows.

[View all plugins](https://github.com/NathanMaine/memoriant-marketplace)

---

## License

MIT — Nathan Maine
