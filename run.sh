#!/usr/bin/env bash
# Start Recut locally:  ./run.sh   ->  http://localhost:8000
set -e
cd "$(dirname "$0")"
ROOT="$PWD"
command -v ffmpeg >/dev/null || { echo "FFmpeg is required. macOS: brew install ffmpeg | Ubuntu: sudo apt install ffmpeg fonts-dejavu-core"; exit 1; }
[ -d .venv ] || python3 -m venv .venv
. .venv/bin/activate
pip install -q -r requirements.txt
# The repo is flat; the code expects an app/ package with app/static/index.html (same layout the Dockerfile builds).
rm -rf .run && mkdir -p .run/app/static
cp ./*.py .run/app/
cp index*.html .run/app/static/index.html
export RECUT_DATA="${RECUT_DATA:-$ROOT/data}"
# macOS has no DejaVu by default; point at any font folder + family name you like:
#   export RECUT_FONTS_DIR="/System/Library/Fonts/Supplemental" RECUT_FONT="Arial Black"
cd .run
exec uvicorn app.main:app --host 0.0.0.0 --port "${PORT:-8000}"
