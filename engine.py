"""Recut engine: clips (+ optional reference) -> edit plan -> FFmpeg render.

Design rule: analysis decides *what* to do, plain FFmpeg does the pixels.
A built-in style (viral / hype / story / clean) sets the rhythm; optionally a reference video's
*structure* (cut timing only) can be borrowed instead. Reference footage/audio is never reused.
"""
from __future__ import annotations

import hashlib
import json
import math
import os
import random
import re
import subprocess
import threading
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
from typing import Callable, Optional

import cv2
import numpy as np

from . import asr, faces, sfx

W, H, FPS = 1080, 1920, 30
MIN_SHOT = 0.7
MAX_TARGET = 60.0
FACE_BOOST = 0.6
FONT_NAME = os.environ.get("RECUT_FONT", "DejaVu Sans")
FONTS_DIR = os.environ.get("RECUT_FONTS_DIR", "/usr/share/fonts/truetype/dejavu")

Progress = Callable[[str, float], None]


class EngineError(Exception):
    """A problem the user can understand (bad file, not enough footage...)."""


# name: (label, shot-length pattern after the hook, hook length)
PRESETS = {
    "viral": ("Viral fast cuts", [1.3, 1.2, 1.5, 1.0, 1.4, 1.2, 1.7, 1.1], 1.3),
    "hype":  ("Hype / rapid fire", [0.9, 0.8, 1.0, 0.7, 0.9, 0.8], 1.0),
    "story": ("Story / talking head", [2.4, 3.2, 2.6, 3.6, 2.8], 2.0),
    "clean": ("Clean & steady", [3.0, 3.6, 3.2, 4.0], 2.6),
}

DEFAULTS = {
    "style": "viral",        # preset rhythm when no reference video is used
    "target": None,          # seconds; None = automatic
    "pace": 1.0,             # <1 faster cuts, >1 slower
    "zoom": 1.0,             # punch-in intensity, 0 = off
    "fit": "crop",           # crop | blur
    "order": "best",         # best | chronological
    "seed": 1,               # bump to get different moments
    "face_track": True,      # keep the crop centred on the speaker
    "face_focus": True,      # prefer moments where a face is visible
    "hook_text": "",
    "hook_sound": "impact",  # none | impact | hit | riser | ding | whoosh | pop | custom:<name>
    "cut_sounds": "punch",   # off | punch | all  (whoosh on cuts)
    "caption_text": "",      # one phrase per line
    "auto_captions": True,   # transcribe speech if a provider is configured
    "caption_style": "highlight",  # highlight | classic | off
    "caption_scale": 1.0,
    "audio_mode": "clip",    # clip | music | both
    "watermark": "",         # e.g. "Made with Recut" (free plan)
    "boost": {},             # {"1": 0.5}  clip index (0-based) -> weight tweak
    "assign": [],            # AI: preferred clip index (0-based) for each shot, in order
}


def _run(cmd: list[str], cwd: Optional[Path] = None) -> subprocess.CompletedProcess:
    p = subprocess.run(cmd, capture_output=True, text=True, cwd=cwd)
    if p.returncode != 0:
        raise EngineError(f"{cmd[0]} failed: {p.stderr.strip()[-500:]}")
    return p


# --------------------------------------------------------------------------
# Probing
# --------------------------------------------------------------------------
def probe(path: Path) -> dict:
    p = _run(["ffprobe", "-v", "error", "-print_format", "json",
              "-show_format", "-show_streams", str(path)])
    j = json.loads(p.stdout)
    streams = j.get("streams", [])
    v = next((s for s in streams if s.get("codec_type") == "video"), None)
    if v is None:
        raise EngineError("No video stream found")
    w, h = int(v.get("width", 0)), int(v.get("height", 0))
    rot = 0
    for sd in v.get("side_data_list") or []:
        if "rotation" in sd:
            rot = int(float(sd["rotation"]))
    if "rotate" in (v.get("tags") or {}):
        rot = int(v["tags"]["rotate"])
    if abs(rot) % 180 == 90:
        w, h = h, w
    dur = float(j.get("format", {}).get("duration") or v.get("duration") or 0)
    if dur <= 0 or w <= 0:
        raise EngineError("Could not read video duration/size")
    return {"duration": dur, "width": w, "height": h,
            "has_audio": any(s.get("codec_type") == "audio" for s in streams)}


# --------------------------------------------------------------------------
# Rhythm: presets or a reference video
# --------------------------------------------------------------------------
def _pace_label(avg: float) -> str:
    return "rapid" if avg < 1.6 else "fast" if avg < 2.6 else "medium" if avg < 4 else "slow"


def preset_reference(name: str, target: float) -> dict:
    label, pattern, hook = PRESETS.get(name, PRESETS["viral"])
    shots, i = [hook], 0
    while sum(shots) < target - 0.05:
        shots.append(pattern[i % len(pattern)])
        i += 1
    avg = sum(shots) / len(shots)
    return {"duration": round(target, 2), "shots": shots, "cuts": [], "avg_shot": round(avg, 2),
            "hook_len": hook, "pace": _pace_label(avg), "synthetic_rhythm": True,
            "width": 0, "height": 0, "preset": name, "label": label}


def detect_cuts(path: Path, threshold: float = 0.30, max_seconds: int = 120) -> list[float]:
    p = subprocess.run(
        ["ffmpeg", "-hide_banner", "-nostats", "-t", str(max_seconds), "-i", str(path),
         "-an", "-vf", f"scale=320:-2,select='gt(scene,{threshold})',showinfo",
         "-f", "null", "-"],
        capture_output=True, text=True)
    times = sorted(float(x) for x in re.findall(r"pts_time:([0-9.]+)", p.stderr))
    cuts: list[float] = []
    for t in times:
        if t > 0.3 and (not cuts or t - cuts[-1] >= 0.3):
            cuts.append(round(t, 3))
    return cuts


def _synth_shots(duration: float) -> list[float]:
    """Single-take reference (talking head etc.): invent a natural rhythm."""
    pattern = [1.6, 2.4, 3.0, 2.4, 3.2]
    out, total, i = [], 0.0, 0
    while total < duration - 0.3:
        L = min(pattern[i % len(pattern)], duration - total)
        out.append(round(L, 3))
        total += L
        i += 1
    if len(out) > 1 and out[-1] < MIN_SHOT:
        out[-2] += out.pop()
    return out


def analyze_reference(path: Path) -> dict:
    info = probe(path)
    dur = min(info["duration"], 120.0)
    cuts = [c for c in detect_cuts(path) if c < dur - 0.3]
    bounds = [0.0] + cuts + [dur]
    shots = [round(bounds[i + 1] - bounds[i], 3) for i in range(len(bounds) - 1)]
    synthetic = False
    if len(shots) < 3 and dur > 4:
        shots, synthetic = _synth_shots(dur), True
    avg = sum(shots) / len(shots)
    return {"duration": round(dur, 2), "width": info["width"], "height": info["height"],
            "cuts": cuts, "shots": shots, "avg_shot": round(avg, 2),
            "hook_len": shots[0], "pace": _pace_label(avg), "synthetic_rhythm": synthetic,
            "preset": None, "label": "Your reference"}


# --------------------------------------------------------------------------
# Clip analysis: 2 fps -> motion/contrast score + face positions
# --------------------------------------------------------------------------
def analyze_clip(path: Path) -> dict:
    info = probe(path)
    sample = min(info["duration"], 300.0)
    sw = 480
    sh = max(2, int(round(sw * info["height"] / info["width"] / 2)) * 2)
    p = subprocess.run(
        ["ffmpeg", "-v", "error", "-t", str(sample), "-i", str(path), "-an",
         "-vf", f"fps=2,scale={sw}:{sh},format=gray", "-f", "rawvideo", "-"],
        capture_output=True)
    fs = sw * sh
    n = len(p.stdout) // fs
    if n == 0:
        raise EngineError("Could not decode this clip")
    frames = np.frombuffer(p.stdout[: n * fs], np.uint8).reshape(n, sh, sw)
    small = np.stack([cv2.resize(f, (64, 64), interpolation=cv2.INTER_AREA) for f in frames]).astype(np.float32)
    mean = small.mean(axis=(1, 2))
    std = small.std(axis=(1, 2))
    motion = np.zeros(n, np.float32)
    if n > 1:
        motion[1:] = np.abs(small[1:] - small[:-1]).mean(axis=(1, 2))
    scores = 0.5 + np.minimum(motion, 25.0) * 1.5 + np.minimum(std, 70.0) * 0.08
    scores = np.where((mean < 28) | (mean > 235), scores * 0.15, scores)
    face_list = [faces.detect_largest(f) for f in frames]
    return {"duration": round(info["duration"], 3), "eff": min(info["duration"], n * 0.5),
            "has_audio": info["has_audio"], "width": info["width"], "height": info["height"],
            "scores": [round(float(x), 3) for x in scores],
            "cuts": [int(x) for x in (motion > 40)],
            "faces": face_list,
            "face_frac": round(sum(1 for f in face_list if f) / n, 3)}


def _prefix(xs):
    out = [0.0]
    for x in xs:
        out.append(out[-1] + x)
    return out


def best_window(clip: dict, L: float, used: list[tuple[float, float]], lo: float = 0.0,
                hi: Optional[float] = None, face_boost: float = 0.0):
    """Best (score, start) window of length L in clip within [lo, hi], avoiding `used`."""
    eff = clip["eff"]
    hi = eff if hi is None else min(hi, eff)
    if hi - lo < L - 0.05 or clip["duration"] < L - 0.05:
        return None
    sc, cuts = clip["scores"], clip["cuts"]
    pres = [1 if f else 0 for f in (clip.get("faces") or [])] or [0] * len(sc)
    P, C, F = _prefix(sc), _prefix(cuts), _prefix(pres)
    k = max(1, round(L * 2))
    best = None
    i = int(math.ceil(lo * 2))
    while True:
        t = i * 0.5
        if t + L > hi + 1e-6 or i + k > len(sc):
            break
        if not any(t < e and t + L > s for s, e in used):
            val = (P[i + k] - P[i]) / k
            if C[i + k] - C[i + 1] > 0:      # hard cut inside the window
                val *= 0.5
            if face_boost:
                val *= 1 + face_boost * (F[i + k] - F[i]) / k
            if best is None or val > best[0]:
                best = (val, t)
        i += 1
    if best is None and len(sc) < k and lo == 0 and not any(0 < e and L > s for s, e in used):
        best = (sum(sc) / max(1, len(sc)), 0.0)
    return best


# --------------------------------------------------------------------------
# Planning
# --------------------------------------------------------------------------
def plan_lengths(shots: list[float], target: float, pace: float) -> list[float]:
    out, total, i = [], 0.0, 0
    while total < target - 0.05:
        L = max(MIN_SHOT, shots[i % len(shots)] * pace)
        L = min(L, target - total)
        if L < MIN_SHOT and out:
            out[-1] = round(out[-1] + L, 3)
            break
        out.append(round(L, 3))
        total += L
        i += 1
    return out


def _pick(clips, used, uses, L, last, boost, rng, allow_reuse, fb, pref=-1):
    for scale in (1.0, 0.85, 0.7, 0.55):
        Lx = max(MIN_SHOT, L * scale)
        best = None
        for i, c in enumerate(clips):
            w = best_window(c, Lx, [] if allow_reuse else used[i], face_boost=fb)
            if not w:
                continue
            val, t = w
            val *= max(0.05, 1 + float(boost.get(str(i), 0)))
            val *= 0.6 if i == last else 1.0
            val *= 2.5 if i == pref else 1.0   # AI's suggested clip for this shot (soft preference)
            val /= 1 + 0.25 * uses[i]
            val *= 1 + rng.uniform(-0.12, 0.12)
            if best is None or val > best[0]:
                best = (val, i, t, Lx)
        if best:
            return best[1], best[2], best[3]
    return None


def _plan_chronological(lengths, clips, boost, fb):
    weights = [max(c["eff"], 0.0) * max(0.05, 1 + float(boost.get(str(i), 0)))
               for i, c in enumerate(clips)]
    total = sum(weights) or 1.0
    n = len(lengths)
    raw = [n * w / total for w in weights]
    counts = [int(math.floor(r)) for r in raw]
    for i in sorted(range(len(clips)), key=lambda i: raw[i] - counts[i], reverse=True)[:n - sum(counts)]:
        counts[i] += 1
    segs, k = [], 0
    for ci, c in enumerate(clips):
        m = counts[ci]
        for j in range(m):
            L = lengths[k]
            k += 1
            sl = c["eff"] / m
            lo, hi = j * sl, (j + 1) * sl
            Lx = min(L, hi - lo)
            if Lx < MIN_SHOT:
                Lx = min(L, c["eff"])
                lo, hi = max(0.0, hi - Lx - 0.5), min(c["eff"], hi + 0.5)
            w = best_window(c, Lx, [], lo, hi, fb) or best_window(c, Lx, [], face_boost=fb)
            if w:
                segs.append((ci, w[1], Lx))
    return segs


def resolve_reference(analysis: dict, clips: list[dict], s: dict) -> dict:
    if analysis.get("ref"):
        return analysis["ref"]
    target = s.get("target") or min(30.0, max(8.0, 0.9 * sum(c["eff"] for c in clips)))
    return preset_reference(s.get("style", "viral"), max(5.0, min(float(target), MAX_TARGET)))


def make_plan(ref: dict, clips: list[dict], s: dict) -> dict:
    target = s.get("target") or min(ref["duration"], MAX_TARGET)
    target = max(5.0, min(float(target), MAX_TARGET))
    lengths = plan_lengths(ref["shots"], target, float(s["pace"]))
    if not [c for c in clips if c["duration"] >= MIN_SHOT]:
        raise EngineError("Your clips are too short to cut (need at least 0.7s each).")
    rng = random.Random(int(s["seed"]))
    boost = s.get("boost") or {}
    fb = FACE_BOOST if s.get("face_focus", True) else 0.0
    warnings, picks = [], []

    if s["order"] == "chronological":
        picks = _plan_chronological(lengths, clips, boost, fb)
    else:
        used = {i: [] for i in range(len(clips))}
        uses = {i: 0 for i in range(len(clips))}
        last, reused = None, False
        assign = s.get("assign") or []
        for k, L in enumerate(lengths):
            pref = assign[k] if k < len(assign) and isinstance(assign[k], int) else -1
            r = _pick(clips, used, uses, L, last, boost, rng, False, fb, pref)
            if r is None:
                r = _pick(clips, used, uses, L, last, boost, rng, True, fb, pref)
                reused = True
            if r is None:
                continue
            ci, t, d = r
            used[ci].append((t, t + d))
            uses[ci] += 1
            last = ci
            picks.append((ci, t, d))
        if reused:
            warnings.append("Not enough fresh footage for every shot, so some moments repeat. "
                            "Upload more clips for more variety.")
    if not picks:
        raise EngineError("Could not find usable footage in your clips.")

    zoom = float(s["zoom"])
    track_on = bool(s.get("face_track", True)) and s["fit"] == "crop"
    segs, cursor = [], 0.0
    for i, (ci, t, d) in enumerate(picks):
        if zoom <= 0 or i == 0:
            fx = "none"
        elif i % 2 == 1:
            fx = "punch"
        elif i % 4 == 0:
            fx = "punch2"
        else:
            fx = "none"
        track = faces.face_path(clips[ci].get("faces") or [], t, d) if track_on else None
        segs.append({"clip": ci, "start": round(t, 2), "dur": round(d, 2), "effect": fx,
                     "at": round(cursor, 2), "track": track, "face": track is not None})
        cursor += d
    if cursor < target - 1.0:
        warnings.append(f"Only {cursor:.1f}s of the {target:.0f}s target could be built from your footage.")
    return {"target": round(target, 2), "duration": round(cursor, 2), "segments": segs,
            "warnings": warnings}


# --------------------------------------------------------------------------
# Captions (ASS)
# --------------------------------------------------------------------------
def _ts(t: float) -> str:
    t = max(0.0, t)
    cs = int(round(t * 100))
    return f"{cs // 360000}:{(cs // 6000) % 60:02d}:{(cs // 100) % 60:02d}.{cs % 100:02d}"


def _clean(text: str) -> str:
    return re.sub(r"[{}\\]", "", text).replace("\n", " ").strip()


def _group(words, size: int = 3):
    for i in range(0, len(words), size):
        yield words[i:i + size]


def words_from_text(text: str, start: float, end: float):
    """Even timing for user-written captions. One phrase per line."""
    lines = [l.strip() for l in text.splitlines() if l.strip()]
    toks = [(li, w) for li, l in enumerate(lines) for w in l.split()]
    if not toks:
        return []
    step = max(0.12, (end - start) / len(toks))
    words = [(start + i * step, start + (i + 1) * step, w) for i, (_, w) in enumerate(toks)]
    groups, cur, cur_line = [], [], toks[0][0]
    for (li, _), wd in zip(toks, words):
        if li != cur_line or len(cur) == 3:
            groups.append(cur)
            cur, cur_line = [], li
        cur.append(wd)
    if cur:
        groups.append(cur)
    return groups


def build_ass(groups, hook: str, hook_dur: float, total: float, s: dict) -> str:
    scale = max(0.5, min(float(s["caption_scale"]), 2.0))
    size, hsize = int(86 * scale), int(78 * scale)
    style = s["caption_style"]
    head = f"""[Script Info]
ScriptType: v4.00+
PlayResX: {W}
PlayResY: {H}
WrapStyle: 0
ScaledBorderAndShadow: yes

[V4+ Styles]
Format: Name, Fontname, Fontsize, PrimaryColour, SecondaryColour, OutlineColour, BackColour, Bold, Italic, Underline, StrikeOut, ScaleX, ScaleY, Spacing, Angle, BorderStyle, Outline, Shadow, Alignment, MarginL, MarginR, MarginV, Encoding
Style: Cap,{FONT_NAME},{size},&H00FFFFFF,&H00FFFFFF,&H00000000,&H64000000,-1,0,0,0,100,100,0,0,1,8,2,2,80,80,520,1
Style: Hook,{FONT_NAME},{hsize},&H00FFFFFF,&H00FFFFFF,&H00000000,&H64000000,-1,0,0,0,100,100,0,0,1,8,2,8,90,90,330,1
Style: Mark,{FONT_NAME},34,&H00FFFFFF,&H00FFFFFF,&H00000000,&H64000000,-1,0,0,0,100,100,0,0,1,3,1,3,40,40,260,1

[Events]
Format: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text
"""
    ev = []
    pop = r"{\fscx82\fscy82\t(0,90,\fscx100\fscy100)}"
    for g in groups:
        if not g:
            continue
        if style == "highlight":
            for wi, (a, b, _) in enumerate(g):
                end = g[wi + 1][0] if wi + 1 < len(g) else b
                parts = []
                for wj, (_, _, w) in enumerate(g):
                    w = _clean(w).upper()
                    parts.append(r"{\c&H0000FFFF&}" + w + r"{\c&H00FFFFFF&}" if wj == wi else w)
                ev.append(f"Dialogue: 1,{_ts(a)},{_ts(end)},Cap,,0,0,0,,{pop}{' '.join(parts)}")
        else:
            txt = " ".join(_clean(w) for _, _, w in g)
            ev.append(f"Dialogue: 1,{_ts(g[0][0])},{_ts(g[-1][1])},Cap,,0,0,0,,{pop}{txt}")
    if hook.strip():
        ev.append(f"Dialogue: 2,{_ts(0)},{_ts(hook_dur)},Hook,,0,0,0,,"
                  + r"{\fad(150,250)}" + _clean(hook).upper())
    if s.get("watermark"):
        ev.append(f"Dialogue: 3,{_ts(0)},{_ts(total)},Mark,,0,0,0,,{{\\alpha&H60&}}{_clean(s['watermark'])}")
    return head + "\n".join(ev) + "\n"


# --------------------------------------------------------------------------
# Rendering
# --------------------------------------------------------------------------
def _zoom_factor(effect: str, zoom: float) -> float:
    if effect == "punch":
        return min(1.45, 1 + 0.12 * zoom)
    if effect == "punch2":
        return min(1.45, 1 + 0.22 * zoom)
    return 1.0


def _even(x: float) -> int:
    return int(x) // 2 * 2


def _clamp(v, lo, hi):
    return max(lo, min(hi, v))


def _crop_for_aspect(clip: dict, track: Optional[dict]):
    """Crop (in source pixels) that yields 9:16, following the face when we have a track.

    Returns (crop_filter or '', face_pos_in_output or None).
    """
    sw, sh = clip["width"], clip["height"]
    ar = W / H
    if abs(sw / sh - ar) < 0.01:
        if track:
            return "", (sum(v for _, v in track["cx"]) / len(track["cx"]),
                        sum(v for _, v in track["cy"]) / len(track["cy"]))
        return "", None
    if sw / sh > ar:                           # wide source: choose columns
        cw, ch = _even(sh * ar), sh
        slack = sw - cw
        if track:
            keys = [(t, _clamp(cx * sw - cw / 2, 0, slack)) for t, cx in track["cx"]]
            ax = sum(v for _, v in keys) / len(keys)
            fcx = sum(v for _, v in track["cx"]) / len(track["cx"])
            fcy = sum(v for _, v in track["cy"]) / len(track["cy"])
            face = ((fcx * sw - ax) / cw, fcy)
        else:
            keys, face = [(0.0, slack / 2)], None
        return f"crop={cw}:{ch}:x='{faces.pw_expr(keys)}':y=0", face
    cw, ch = sw, _even(sw / ar)                # tall source: choose rows
    slack = sh - ch
    if track:
        keys = [(t, _clamp(cy * sh - ch * 0.38, 0, slack)) for t, cy in track["cy"]]
        ay = sum(v for _, v in keys) / len(keys)
        fcx = sum(v for _, v in track["cx"]) / len(track["cx"])
        fcy = sum(v for _, v in track["cy"]) / len(track["cy"])
        face = (fcx, (fcy * sh - ay) / ch)
    else:
        keys, face = [(0.0, slack / 2)], None
    return f"crop={cw}:{ch}:x=0:y='{faces.pw_expr(keys)}'", face


def render_segment(clip_path: Path, clip: dict, seg: dict, s: dict, cache: Path) -> Path:
    key = hashlib.md5(json.dumps([str(clip_path), seg["start"], seg["dur"], seg["effect"], seg.get("track"),
                                  s["zoom"], s["fit"], s["audio_mode"]]).encode()).hexdigest()[:14]
    out = cache / f"seg_{key}.mp4"
    if out.exists():
        return out
    d = seg["dur"]
    face = None
    if s["fit"] == "blur":
        base = (f"[0:v]split=2[x][y];[x]scale={W}:{H}:force_original_aspect_ratio=increase,"
                f"crop={W}:{H},boxblur=25:3[bg];[y]scale={W}:{H}:force_original_aspect_ratio=decrease[fg];"
                f"[bg][fg]overlay=(W-w)/2:(H-h)/2,setsar=1,fps={FPS}[b]")
    else:
        crop, face = _crop_for_aspect(clip, seg.get("track"))
        pre = crop + "," if crop else ""
        base = f"[0:v]{pre}scale={W}:{H}:flags=lanczos,setsar=1,fps={FPS}[b]"
    z = _zoom_factor(seg["effect"], float(s["zoom"]))
    if z > 1.0:
        zw, zh = _even(W * z), _even(H * z)
        if face:
            px = _clamp(face[0] * zw - W / 2, 0, zw - W)
            py = _clamp(face[1] * zh - H * 0.42, 0, zh - H)
        else:
            px, py = (zw - W) / 2, (zh - H) / 2
        vf = base + f";[b]scale={zw}:{zh},crop={W}:{H}:x={px:.0f}:y={py:.0f}[v]"
    else:
        vf = base + ";[b]null[v]"
    use_clip_audio = clip["has_audio"] and s["audio_mode"] != "music"
    af = (f"[0:a]aformat=sample_rates=44100:channel_layouts=stereo,afade=t=in:d=0.03,"
          f"afade=t=out:st={max(0.0, d - 0.05):.3f}:d=0.05[a]") if use_clip_audio else "[1:a]anull[a]"
    cmd = ["ffmpeg", "-y", "-v", "error", "-ss", str(seg["start"]), "-t", str(d), "-i", str(clip_path),
           "-f", "lavfi", "-t", str(d), "-i", "anullsrc=r=44100:cl=stereo",
           "-filter_complex", vf + ";" + af, "-map", "[v]", "-map", "[a]",
           "-c:v", "libx264", "-preset", "ultrafast", "-crf", "17", "-pix_fmt", "yuv420p",
           "-r", str(FPS), "-c:a", "aac", "-b:a", "160k", "-ar", "44100", "-ac", "2", "-t", str(d), str(out)]
    _run(cmd)
    return out


def render_final(joined: Path, out: Path, ass: Optional[str], music: Optional[Path], mode: str,
                 total: float, workdir: Path, events: list[tuple[Path, float, float]]):
    joined, out = Path(joined).resolve(), Path(out).resolve()
    music = Path(music).resolve() if music else None
    fc = [f"[0:v]subtitles=captions.ass:fontsdir={FONTS_DIR}[v]" if ass else "[0:v]null[v]"]
    cmd = ["ffmpeg", "-y", "-v", "error", "-i", str(joined)]
    nxt = 1
    if music and mode in ("music", "both"):
        cmd += ["-stream_loop", "-1", "-i", str(music)]
        nxt = 2
        fade = max(0.0, total - 1.0)
        if mode == "music":
            fc.append(f"[1:a]volume=0.9,afade=t=out:st={fade:.2f}:d=1[am]")
        else:
            fc.append("[0:a]asplit=2[a0][sc]")
            fc.append(f"[1:a]volume=0.55,afade=t=out:st={fade:.2f}:d=1[m]")
            fc.append("[m][sc]sidechaincompress=threshold=0.03:ratio=10:attack=10:release=400[md]")
            fc.append("[a0][md]amix=inputs=2:duration=first:dropout_transition=0:normalize=0[am]")
    else:
        fc.append("[0:a]loudnorm=I=-16:TP=-1.5:LRA=11[am]")
    if events:
        labels = []
        for i, (p, t, vol) in enumerate(events):
            cmd += ["-i", str(Path(p).resolve())]
            ms = int(t * 1000)
            fc.append(f"[{nxt + i}:a]aformat=sample_rates=44100:channel_layouts=stereo,"
                      f"adelay=delays={ms}:all=1,volume={vol}[e{i}]")
            labels.append(f"[e{i}]")
        fc.append(f"[am]{''.join(labels)}amix=inputs={len(events) + 1}:duration=first:"
                  f"dropout_transition=0:normalize=0[a]")
    else:
        fc.append("[am]anull[a]")
    cmd += ["-filter_complex", ";".join(fc), "-map", "[v]", "-map", "[a]",
            "-c:v", "libx264", "-preset", "veryfast", "-crf", "20", "-pix_fmt", "yuv420p",
            "-c:a", "aac", "-b:a", "192k", "-movflags", "+faststart", "-t", f"{total:.3f}", str(out)]
    _run(cmd, cwd=workdir)


# --------------------------------------------------------------------------
# Public entry points
# --------------------------------------------------------------------------
def analyze(ref_path: Optional[Path], clip_paths: list[Path], progress: Progress) -> dict:
    ref = None
    if ref_path:
        progress("Analyzing the reference", 0.03)
        ref = analyze_reference(ref_path)
    clips = []
    for i, p in enumerate(clip_paths):
        progress(f"Reading your footage ({i + 1}/{len(clip_paths)})",
                 0.08 + 0.22 * i / max(1, len(clip_paths)))
        clips.append(analyze_clip(p))
    return {"ref": ref, "clips": clips}


def render(job_dir: Path, analysis: dict, clip_paths: list[Path], music: Optional[Path],
           s: dict, version: int, progress: Progress) -> dict:
    s = {**DEFAULTS, **s}
    progress("Planning the cuts", 0.32)
    ref = resolve_reference(analysis, analysis["clips"], s)
    plan = make_plan(ref, analysis["clips"], s)
    cache = job_dir / "cache"
    cache.mkdir(exist_ok=True)
    segs = plan["segments"]
    workers = int(os.environ.get("RECUT_SEG_WORKERS", max(1, (os.cpu_count() or 2) // 2)))
    done_n = [0]
    lock = threading.Lock()

    def one(sg):
        c = analysis["clips"][sg["clip"]]
        f = render_segment(clip_paths[sg["clip"]], c, sg, s, cache)
        with lock:
            done_n[0] += 1
            progress(f"Rendering shots ({done_n[0]}/{len(segs)})", 0.35 + 0.50 * done_n[0] / len(segs))
        return f

    with ThreadPoolExecutor(max_workers=workers) as ex:
        files = list(ex.map(one, segs))

    progress("Joining shots", 0.86)
    lst = job_dir / "concat.txt"
    lst.write_text("".join(f"file '{f.resolve()}'\n" for f in files))
    joined = job_dir / f"joined_v{version}.mp4"
    _run(["ffmpeg", "-y", "-v", "error", "-f", "concat", "-safe", "0", "-i", str(lst), "-c", "copy", str(joined)])
    total = plan["duration"]

    progress("Captions and sounds", 0.90)
    ass_text, caption_source = None, "none"
    hook_dur = min(3.0, max(1.8, segs[0]["dur"] + 0.5))
    if s["caption_style"] != "off":
        groups = None
        if s["caption_text"].strip():
            groups = words_from_text(s["caption_text"], 0.4, max(1.0, total - 0.5))
            caption_source = "your text"
        elif s["auto_captions"] and s["audio_mode"] != "music" and asr.available():
            words = asr.transcribe(joined)
            if words:
                groups = list(_group(words))
                caption_source = "speech"
        if groups or s["hook_text"].strip():
            ass_text = build_ass(groups or [], s["hook_text"], hook_dur, total, s)
    if ass_text is None and s.get("watermark"):
        ass_text = build_ass([], "", hook_dur, total, {**s, "hook_text": ""})
    if ass_text:
        (job_dir / "captions.ass").write_text(ass_text, encoding="utf-8")

    events = []
    for name, t, vol in sfx.plan_events(segs, s["hook_sound"], s["cut_sounds"]):
        p = sfx.path(name)
        if p:
            events.append((p, t, vol))
    out = job_dir / f"out_v{version}.mp4"
    mode = s["audio_mode"] if music else "clip"
    render_final(joined, out, ass_text and "captions.ass", music, mode, total, job_dir, events)
    joined.unlink(missing_ok=True)
    progress("Done", 1.0)
    plan["captions"] = caption_source
    plan["file"] = out.name
    plan["style"] = ref.get("label")
    plan["sfx"] = len(events)
    return plan


# --------------------------------------------------------------------------
# Plain-English revisions -> setting changes (rule based, works offline)
# --------------------------------------------------------------------------
def parse_revision(text: str, s: dict, n_clips: int) -> tuple[dict, list[str]]:
    t = text.lower().strip()
    s = {**DEFAULTS, **s, "boost": dict(s.get("boost") or {})}
    done: list[str] = []

    m = re.search(r"\bhook(?: text)?\s*[:\-]\s*(.+)$", text, re.I)
    if m and not re.match(r"\s*(none|impact|hit|riser|ding|whoosh|pop)\b", m.group(1), re.I):
        s["hook_text"] = m.group(1).strip().strip("\"'")
        done.append("Updated the hook text")
        t = t[:m.start()]
    m = re.search(r"\bcaptions?(?: text)?\s*[:\-]\s*(.+)$", text, re.I | re.S)
    if m:
        s["caption_text"] = m.group(1).strip()
        done.append("Replaced the caption text")
        t = t[:m.start()]

    m = re.search(r"\bhook sound\s*[:\-]?\s*(none|impact|hit|riser|ding|whoosh|pop)\b", t)
    if m:
        s["hook_sound"] = m.group(1); done.append(f"Hook sound: {m.group(1)}")
    elif re.search(r"\bno hook sound\b", t):
        s["hook_sound"] = "none"; done.append("Hook sound off")
    if re.search(r"\b(no sound effects|no whoosh(es)?|no sfx|sound effects off)\b", t):
        s["cut_sounds"] = "off"; done.append("Cut sounds off")
    elif re.search(r"\b(whoosh(es)? on every cut|more (sound effects|sfx|whoosh(es)?)|every cut)\b", t):
        s["cut_sounds"] = "all"; done.append("Whoosh on every cut")
    if re.search(r"\b(no face tracking|face tracking off|center crop|centre crop)\b", t):
        s["face_track"] = False; done.append("Face tracking off")
    elif re.search(r"\bface tracking( on)?\b|\btrack (the |my )?face\b", t):
        s["face_track"] = True; done.append("Face tracking on")
    m = re.search(r"\b(viral|hype|story|clean)\b\s*(style)?", t)
    if m and (m.group(2) or re.search(r"\b(make it|style\s*[:\-]|go|switch to)\b", t)):
        s["style"] = m.group(1); done.append(f"Style: {PRESETS[m.group(1)][0]}")

    if re.search(r"\b(faster|quicker|snappier|tighter|speed up)\b", t):
        s["pace"] = max(0.4, s["pace"] * 0.8); done.append("Faster cuts")
    if re.search(r"\b(slower|calmer|more breathing|slow down)\b", t):
        s["pace"] = min(2.0, s["pace"] * 1.25); done.append("Slower cuts")
    if re.search(r"\b(bigger|larger)\b.*caption|caption.*\b(bigger|larger)\b", t):
        s["caption_scale"] = min(1.8, s["caption_scale"] * 1.2); done.append("Bigger captions")
    if re.search(r"\bsmaller\b.*caption|caption.*\bsmaller\b", t):
        s["caption_scale"] = max(0.6, s["caption_scale"] / 1.2); done.append("Smaller captions")
    if re.search(r"\bno zoom|remove zoom|zoom off|less zoom\b", t):
        s["zoom"] = 0.0 if "less" not in t else max(0.0, s["zoom"] - 0.4)
        done.append("Less zoom")
    elif re.search(r"\bmore zoom|more punch|punch.?in|zoom more|stronger zoom\b", t):
        s["zoom"] = min(2.0, s["zoom"] + 0.4); done.append("More zoom")
    if re.search(r"\b(shuffle|remix|different (clips|moments|shots)|new order|mix it up|redo)\b", t):
        s["seed"] = int(s["seed"]) + 1; done.append("Picked different moments")
    if re.search(r"\b(chronological|in order|story order)\b", t):
        s["order"] = "chronological"; done.append("Keeping your clips in order")
    if re.search(r"\b(best moments|best parts|out of order)\b", t):
        s["order"] = "best"; done.append("Using the best moments")
    if re.search(r"\b(shorter|trim it)\b", t):
        s["target"] = max(5.0, (s.get("target") or 20) * 0.8); done.append("Shorter video")
    if re.search(r"\b(longer|extend)\b", t):
        s["target"] = min(MAX_TARGET, (s.get("target") or 20) * 1.25); done.append("Longer video")
    if re.search(r"\bhighlight", t):
        s["caption_style"] = "highlight"; done.append("Highlighted caption style")
    if re.search(r"\bclassic|plain captions|simple captions", t):
        s["caption_style"] = "classic"; done.append("Classic caption style")
    if re.search(r"\b(no captions|remove captions|captions off)\b", t):
        s["caption_style"] = "off"; done.append("Captions off")
    if re.search(r"\bblur", t):
        s["fit"] = "blur"; done.append("Blurred-background framing")
    if re.search(r"\bfill the (screen|frame)|crop to fill|full screen\b", t):
        s["fit"] = "crop"; done.append("Cropped to fill the frame")

    for m in re.finditer(r"\b(more|less|fewer|without|skip|drop)\b[^.,;]*?\bclip\s*#?(\d+)", t):
        idx = int(m.group(2)) - 1
        if 0 <= idx < n_clips:
            up = m.group(1) == "more"
            cur = float(s["boost"].get(str(idx), 0))
            s["boost"][str(idx)] = min(2.0, cur + 0.6) if up else max(-0.9, cur - 0.6)
            done.append(f"{'More' if up else 'Less'} of clip {idx + 1}")
    for m in re.finditer(r"\buse clip\s*#?(\d+)\s*more", t):
        idx = int(m.group(1)) - 1
        if 0 <= idx < n_clips and f"More of clip {idx + 1}" not in done:
            s["boost"][str(idx)] = min(2.0, float(s["boost"].get(str(idx), 0)) + 0.6)
            done.append(f"More of clip {idx + 1}")
    return s, done
