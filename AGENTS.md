# Agents

This plugin ships one agent for managing screen recording sessions.

## screen-recorder

**File:** `agents/screen-recorder-agent.md`
**Model:** claude-sonnet (latest)

Manages the full recording lifecycle: tool detection, start/stop, GIF
conversion, and automated demo creation for Memoriant plugins.

### Invoke

```
/agent:screen-recorder start a demo recording for the patent search plugin
```

### Capabilities

- Detects available recording tools on macOS and Linux
- Starts and stops background recording processes
- Converts video to optimized GIFs using two-pass ffmpeg palette method
- Prints styled ANSI annotation cards during recording
- Orchestrates the `scripts/demo-all.sh` workflow for bulk demo creation

### Platforms

| Platform | Supported Tools |
|----------|----------------|
| macOS | screencapture (native), ffmpeg/avfoundation |
| Linux X11 | ffmpeg/x11grab |
| Linux Wayland | wf-recorder |
| Linux fallback | recordmydesktop |

### Output

Recordings: `~/.memoriant/recordings/`
Demo GIFs: `demos/<plugin-name>-demo.gif` (relative to working directory)
