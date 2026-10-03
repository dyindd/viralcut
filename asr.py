"""Speech -> word timestamps for auto captions.

Provider order:
  1. OPENAI_API_KEY set  -> OpenAI-compatible /audio/transcriptions (cheap, no GPU, no model download).
     RECUT_ASR_URL (default https://api.openai.com/v1) and RECUT_ASR_MODEL (default whisper-1) override.
  2. faster-whisper installed -> local model (RECUT_WHISPER=base|small|...).
Returns [(start, end, word), ...] or None (no speech / no provider / error).
"""
from __future__ import annotations

import json
import os
import subprocess
import tempfile
import urllib.request
import uuid
from pathlib import Path
from typing import Optional

Words = list[tuple[float, float, str]]


def available() -> Optional[str]:
    if os.environ.get("OPENAI_API_KEY"):
        return "cloud"
    try:
        import faster_whisper  # noqa: F401
        return "local"
    except ImportError:
        return None


def _multipart(fields: list[tuple[str, str]], fname: str, data: bytes) -> tuple[bytes, str]:
    b = uuid.uuid4().hex
    out = b""
    for k, v in fields:
        out += f'--{b}\r\nContent-Disposition: form-data; name="{k}"\r\n\r\n{v}\r\n'.encode()
    out += (f'--{b}\r\nContent-Disposition: form-data; name="file"; filename="{fname}"\r\n'
            f"Content-Type: audio/mpeg\r\n\r\n").encode() + data + f"\r\n--{b}--\r\n".encode()
    return out, f"multipart/form-data; boundary={b}"


def parse_verbose_json(j: dict) -> Optional[Words]:
    words = [(float(w["start"]), float(w["end"]), str(w["word"]).strip())
             for w in (j.get("words") or []) if str(w.get("word", "")).strip()]
    return words or None


def _cloud(audio: Path) -> Optional[Words]:
    base = os.environ.get("RECUT_ASR_URL", "https://api.openai.com/v1").rstrip("/")
    body, ctype = _multipart(
        [("model", os.environ.get("RECUT_ASR_MODEL", "whisper-1")), ("response_format", "verbose_json"),
         ("timestamp_granularities[]", "word")], "audio.mp3", audio.read_bytes())
    req = urllib.request.Request(f"{base}/audio/transcriptions", data=body, method="POST",
                                 headers={"Authorization": f"Bearer {os.environ['OPENAI_API_KEY']}",
                                          "Content-Type": ctype})
    with urllib.request.urlopen(req, timeout=180) as r:
        return parse_verbose_json(json.loads(r.read()))


def _local(audio: Path) -> Optional[Words]:
    from faster_whisper import WhisperModel  # type: ignore
    model = WhisperModel(os.environ.get("RECUT_WHISPER", "base"), compute_type="int8")
    segs, _ = model.transcribe(str(audio), word_timestamps=True, vad_filter=True)
    words = [(w.start, w.end, w.word.strip()) for s in segs for w in (s.words or []) if w.word.strip()]
    return words or None


def transcribe(video: Path) -> Optional[Words]:
    provider = available()
    if not provider:
        return None
    with tempfile.TemporaryDirectory() as td:
        audio = Path(td) / "a.mp3"
        r = subprocess.run(["ffmpeg", "-y", "-v", "error", "-i", str(video), "-vn", "-ac", "1", "-ar", "16000",
                            "-b:a", "48k", str(audio)], capture_output=True)
        if r.returncode != 0 or not audio.exists():
            return None
        try:
            return _cloud(audio) if provider == "cloud" else _local(audio)
        except Exception as e:  # network, quota, model download...
            print("transcription failed:", repr(e)[:200])
            return None
