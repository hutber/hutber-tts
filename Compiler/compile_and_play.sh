#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
COMPILED_JSON="$SCRIPT_DIR/hutber_CA_2025_compiled.json"

"$SCRIPT_DIR/compile_linux.sh" --test "$@"
python3 "$SCRIPT_DIR/tts_save_and_play.py" --compiled-json "$COMPILED_JSON"
