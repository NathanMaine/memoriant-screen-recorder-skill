# Roadmap

## v2.0 (Current)
- [x] Guided 6-step flow (preflight, mode, window picker, save location, record, format)
- [x] Pick mode — list all windows as a table, user picks by number
- [x] Fullscreen mode via screencapture
- [x] Window recording via ffmpeg real-time crop
- [x] GIF conversion with two-pass palette optimization
- [x] Annotations / title cards
- [x] Demo automation script
- [x] Cross-platform: Claude Code + Codex CLI + Gemini CLI
- [x] Preflight check (dependencies, permissions)

## v2.1 (Planned)
- [ ] Multi-session recording — record two windows simultaneously with named sessions
  - `record.sh start pick --session demo1`
  - `record.sh start pick --session demo2`
  - `record.sh stop demo1`
  - Track multiple PIDs in separate files
- [ ] Auto-trim silence — detect and remove idle periods from recordings
- [ ] Timestamp overlay — burn in elapsed time counter
- [ ] Custom framerate per session

## v3.0 (Future)
- [ ] Audio recording support (system audio + microphone)
- [ ] Picture-in-picture (webcam overlay on screen recording)
- [ ] Automatic chapter markers from annotations
- [ ] Upload to GitHub Releases / S3 / Supabase Storage after recording
- [ ] CI integration — record test runs in GitHub Actions

## Not Planned
- Real-time streaming (use OBS for that)
- Video editing beyond trim/crop (use DaVinci Resolve or iMovie)
