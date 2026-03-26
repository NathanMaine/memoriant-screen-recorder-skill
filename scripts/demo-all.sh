#!/bin/bash
# Demo all Memoriant plugins with screen recording
# Usage: demo-all.sh [output-dir]

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUTPUT_DIR="${1:-$HOME/.memoriant/demos}"
RECORD_SCRIPT="$SCRIPT_DIR/record.sh"

mkdir -p "$OUTPUT_DIR"

if [[ ! -f "$RECORD_SCRIPT" ]]; then
    echo "Error: record.sh not found at $RECORD_SCRIPT"
    exit 1
fi

# ─── Plugin registry ──────────────────────────────────────────────────────────
# Format: "plugin-name|Display Title|example command"

plugins=(
    "memoriant-patent-skills|Patent Search|/patent-search 'wireless power transfer for medical implants'"
    "memoriant-test-coverage-skill|Test Coverage Analysis|/test-coverage scan src/"
    "memoriant-architecture-review-skill|Architecture Review|/architecture-review 'Microservices API gateway'"
    "memoriant-docforce-skill|Documentation Drift|/docforce scan"
    "memoriant-env-bootstrap-skill|Environment Bootstrap|/env-bootstrap"
    "memoriant-perf-test-skill|Load Test Planning|/perf-test generate --profile api-server"
    "memoriant-eval-sandbox-skill|Agent Evaluation|/eval-sandbox run --scenario basic"
    "memoriant-llm-gateway-skill|LLM Gateway|/llm-gateway audit --last 24h"
    "memoriant-temporal-planner-skill|Task Planning|/temporal-planner plan 'deploy v2.0'"
    "memoriant-governance-compiler-skill|Policy Compilation|/governance-compiler compile policies/"
    "memoriant-voice-test-skill|Voice Testing|/voice-test run fixtures/basic.yaml"
    "memoriant-ops-bot-skill|Remote Agent Ops|/ops-bot status"
    "memoriant-mcp-data-skill|Data Queries|/mcp-data query 'show all open tickets'"
)

total=${#plugins[@]}

# ─── Opening card ─────────────────────────────────────────────────────────────

echo ""
echo "╔══════════════════════════════════════════════════╗"
echo "║   Memoriant Plugin Marketplace — Full Demo       ║"
echo "║   $total plugins, all categories                     ║"
echo "╚══════════════════════════════════════════════════╝"
echo ""
echo "Output directory: $OUTPUT_DIR"
echo ""
sleep 2

# ─── Plugin demos ─────────────────────────────────────────────────────────────

current=0
for entry in "${plugins[@]}"; do
    IFS='|' read -r name title command <<< "$entry"
    current=$((current + 1))

    echo ""
    echo "┌──────────────────────────────────────────────────────┐"
    printf "│  [%02d/%02d]  %s\n" "$current" "$total" "$title"
    echo "│  Plugin:   $name"
    echo "│  Command:  $command"
    echo "└──────────────────────────────────────────────────────┘"
    echo ""

    # Show the annotation card (visible during screen recording)
    bash "$RECORD_SCRIPT" annotate "$title — $command"

    sleep 3  # Pause for readability during recording
done

# ─── Closing card ─────────────────────────────────────────────────────────────

echo ""
echo "╔══════════════════════════════════════════════════╗"
echo "║   Demo complete — $total plugins showcased           ║"
echo "║   github.com/NathanMaine/memoriant-marketplace   ║"
echo "╚══════════════════════════════════════════════════╝"
echo ""

# ─── Individual GIF generation (when run with --record flag) ──────────────────
# Usage: demo-all.sh [output-dir] --record
# Records each plugin demo separately and saves individual GIFs.

if [[ "${2:-}" == "--record" ]]; then
    echo "Recording individual plugin demos..."
    echo ""

    for entry in "${plugins[@]}"; do
        IFS='|' read -r name title command <<< "$entry"

        gif_path="$OUTPUT_DIR/$name-demo.gif"

        if [[ -f "$gif_path" ]]; then
            echo "Skipping $name (GIF already exists: $gif_path)"
            continue
        fi

        echo "Recording demo: $title"

        # Annotation before start so it appears at top of recording
        bash "$RECORD_SCRIPT" annotate "$title"
        sleep 0.5

        bash "$RECORD_SCRIPT" start

        sleep 1
        bash "$RECORD_SCRIPT" annotate "Command: $command"
        sleep 2
        echo "(demo output for $name would appear here)"
        sleep 3

        bash "$RECORD_SCRIPT" stop
        sleep 1

        bash "$RECORD_SCRIPT" gif 15 800

        # Move the generated GIF to output dir
        last_recording=$(cat "$HOME/.memoriant/recordings/.last_recording" 2>/dev/null || echo "")
        last_gif=$(ls "${last_recording}".gif 2>/dev/null | head -1 || echo "")
        if [[ -n "$last_gif" && -f "$last_gif" ]]; then
            mv "$last_gif" "$gif_path"
            echo "Saved: $gif_path"
        fi

        echo ""
        sleep 1
    done

    echo "All demos recorded."
    echo "GIFs saved to: $OUTPUT_DIR"
fi
