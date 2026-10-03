#!/usr/bin/env bash
# Start Recut locally:  ./run.sh   ->  http://localhost:8000
set -e
cd "$(dirname "$0")"
command -v ffmpeg >/dev/null || { echo "FFmpeg is required. macOS: brew install ffmpeg | Ubuntu: sudo apt install ffmpeg fonts-dejavu-core"; exit 1; }
[ -d .venv ] || python3 -m venv .venv
. .venv/bin/activate
pip install -q -r requirements.txt
# macOS has no DejaVu by default; point at any font folder + family name you like:
#   export RECUT_FONTS_DIR="/System/Library/Fonts/Supplemental" RECUT_FONT="Arial Black"
exec uvicorn app.main:app --host 0.0.0.0 --port "${PORT:-8000}"
