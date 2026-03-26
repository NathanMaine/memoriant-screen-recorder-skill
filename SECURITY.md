# Security Policy

## Supported Versions

| Version | Supported |
|---------|-----------|
| 1.0.x   | Yes       |

## Scope

This plugin operates entirely on the local machine. It does not make network
requests, transmit recordings, or store data outside `~/.memoriant/recordings/`
(or the directory specified by `RECORD_DIR`).

## What the Plugin Does

- Launches local recording processes (`screencapture`, `ffmpeg`, `wf-recorder`)
- Writes video files to a local directory
- Reads a PID file to manage the active recording process
- Converts video to GIF using local `ffmpeg`

## What the Plugin Does NOT Do

- No network access of any kind
- No cloud upload or remote storage
- No access to clipboard, keychain, or credentials
- No persistent background processes (recording stops explicitly via `stop` command)

## Privacy Considerations

Screen recordings may capture sensitive information — terminal output,
passwords typed visibly, API keys, file contents. Users are responsible for:

- Reviewing recordings before sharing
- Storing recordings in a secure location
- Deleting recordings that contain sensitive data

The default output path `~/.memoriant/recordings/` is in the user's home
directory and accessible only to that user (mode 700 on creation).

## Reporting Vulnerabilities

To report a security issue, open a private advisory at:
https://github.com/NathanMaine/memoriant-screen-recorder-skill/security/advisories/new

Or contact Nathan Maine directly via GitHub: https://github.com/NathanMaine

Please do not open public issues for security vulnerabilities.

## Dependency Security

This plugin uses no npm or Python dependencies. The only runtime dependencies
are system tools (`screencapture`, `ffmpeg`, `wf-recorder`) which are managed
by the operating system or the user's package manager.
