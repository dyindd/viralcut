"""AI layer: Claude watches the reference + the user's clips and directs the edit.

Claude never touches pixels. It returns a small, validated JSON "directive" (hook text, pace, zoom,
which clip goes with which reference shot...) and FFmpeg does the rendering. If no API key is set, or
the call fails for any reason, everything falls back to the rule-based engine, so the app never breaks.

Env: ANTHROPIC_API_KEY, RECUT_AI_MODEL (default claude-sonnet-5-5), ANTHROPIC_BASE_URL (for testing/proxies).
"""
from __future__ import annotations

import base64
import json
import os
import re
import subprocess
import tempfile
import urllib.request
from pathlib import Path
from typing import Optional

HOOK_SOUNDS = ("none", "impact", "hit", "riser", "ding", "whoosh", "pop")


def available() -> bool:
    return bool(os.environ.get("ANTHROPIC_API_KEY"))


def _model() -> str:
    return os.environ.get("RECUT_AI_MODEL", "claude-sonnet-5-5")


def _post(system: str, content: list, max_tokens: int = 1500) -> str:
    base = os.environ.get("ANTHROPIC_BASE_URL", "https://api.anthropic.com").rstrip("/")
    body = json.dumps({"model": _model(), "max_tokens": max_tokens, "system": system,
                       "messages": [{"role": "user", "content": content}]}).encode()
    req = urllib.request.Request(base + "/v1/messages", data=body, headers={
        "content-type": "application/json", "x-api-key": os.environ["ANTHROPIC_API_KEY"],
        "anthropic-version": "2023-06-01"})
    with urllib.request.urlopen(req, timeout=90) as r:
        j = json.loads(r.read())
    return "".join(b.get("text", "") for b in j.get("content", []) if b.get("type") == "text")


def _json(text: str) -> Optional[dict]:
    m = re.search(r"\{.*\}", text, re.S)
    if not m:
        return None
    try:
        v = json.loads(m.group(0))
        return v if isinstance(v, dict) else None
    except ValueError:
        return None


def frames(path: Path, times: list[float], width: int = 448) -> list[str]:
    """JPEG frames (base64) at the given times."""
    out = []
    with tempfile.TemporaryDirectory() as td:
        for i, t in enumerate(times):
            f = Path(td) / f"{i}.jpg"
            subprocess.run(["ffmpeg", "-y", "-v", "error", "-ss", f"{max(0.0, t):.2f}", "-i", str(path),
                            "-frames:v", "1", "-vf", f"scale='min({width},iw)':-2", "-q:v", "5", str(f)],
                           capture_output=True)
            if f.exists() and f.stat().st_size > 0:
                out.append(base64.b64encode(f.read_bytes()).decode())
    return out


def _img(b64: str) -> dict:
    return {"type": "image", "source": {"type": "base64", "media_type": "image/jpeg", "data": b64}}


def _clamp(v, lo, hi, default):
    try:
        return max(lo, min(hi, float(v)))
    except (TypeError, ValueError):
        return default


def _text(v, n) -> str:
    return re.sub(r"[{}\\\x00-\x08\x0b-\x1f]", "", str(v or "")).strip()[:n]


# ---------------------------------------------------------------- directive
DIRECT_SYSTEM = """You are the editor behind a short-form video tool. The user gives a REFERENCE video (a viral
TikTok/Reel/Short whose editing style they want) and their own RAW CLIPS. You see sampled frames of both.
Decide how to recreate the reference's STRUCTURE (pacing, hook, caption look, zoom energy, sound) using the clips.
Never copy the reference's content. Reply with ONE JSON object only, no prose:
{"summary": "<=140 chars on what makes the reference work",
 "hook_text": "<=60 chars punchy on-screen hook for the user's footage, or \\"\\" if unsure",
 "pace": 0.6-1.5 (multiplier on the reference shot lengths; <1 = faster),
 "zoom": 0-2 (punch-in energy; 0 = none),
 "cut_sounds": "off"|"punch"|"all",
 "hook_sound": "none"|"impact"|"hit"|"riser"|"ding"|"whoosh"|"pop",
 "caption_style": "highlight"|"classic"|"off",
 "caption_scale": 0.7-1.6,
 "order": "best"|"chronological" (chronological for talking/story footage that must stay in sequence),
 "assign": [clip number 1..N best suited for each reference shot, in order; omit if unsure],
 "clip_notes": ["<=40 chars what each clip shows, in clip order"]}"""


def direct(ref_path: Optional[Path], ref: Optional[dict], clip_paths: list[Path], clips: list[dict],
           ref_words=None) -> Optional[dict]:
    """Ask Claude for a directive. Returns a validated dict or None."""
    if not available() or not ref:
        return None
    try:
        n = len(ref["shots"])
        # one frame per reference shot (sampled down to 8)
        starts = [0.0] + list(ref.get("cuts") or [])
        mids = [min(ref["duration"] - 0.1, s + sh / 2) for s, sh in zip(starts, ref["shots"])] if not ref.get(
            "synthetic_rhythm") else [ref["duration"] * (k + .5) / 6 for k in range(6)]
        step = max(1, len(mids) // 8)
        mids = mids[::step][:8]
        content: list = [{"type": "text", "text": (
            f"REFERENCE: {ref['duration']}s, {n} shots, average shot {ref['avg_shot']}s, "
            f"shot lengths {ref['shots'][:30]}. Frames follow in order.")}]
        content += [_img(b) for b in frames(ref_path, mids)] if ref_path else []
        if ref_words:
            content.append({"type": "text", "text": "REFERENCE TRANSCRIPT: " + " ".join(w[2] for w in ref_words)[:1200]})
        for i, (p, c) in enumerate(zip(clip_paths, clips)):
            d = c["duration"]
            content.append({"type": "text", "text": f"CLIP {i + 1} ({d:.1f}s, face visible {int(c['face_frac'] * 100)}% "
                                                    f"of the time, has_audio={c['has_audio']}):"})
            content += [_img(b) for b in frames(p, [d * .25, d * .75] if d > 3 else [d * .5])]
            if i >= 11:
                break
        content.append({"type": "text", "text": "Return the JSON now."})
        return validate_directive(_json(_post(DIRECT_SYSTEM, content)), len(clip_paths), n)
    except Exception as e:  # network, quota, bad JSON... never block the edit
        print("ai.direct failed:", repr(e)[:200])
        return None


def validate_directive(d: Optional[dict], n_clips: int, n_shots: int) -> Optional[dict]:
    if not d:
        return None
    out: dict = {"summary": _text(d.get("summary"), 140), "hook_text": _text(d.get("hook_text"), 60)}
    if "pace" in d:
        out["pace"] = _clamp(d["pace"], 0.6, 1.5, 1.0)
    if "zoom" in d:
        out["zoom"] = _clamp(d["zoom"], 0.0, 2.0, 1.0)
    if d.get("cut_sounds") in ("off", "punch", "all"):
        out["cut_sounds"] = d["cut_sounds"]
    if d.get("hook_sound") in HOOK_SOUNDS:
        out["hook_sound"] = d["hook_sound"]
    if d.get("caption_style") in ("highlight", "classic", "off"):
        out["caption_style"] = d["caption_style"]
    if "caption_scale" in d:
        out["caption_scale"] = _clamp(d["caption_scale"], 0.7, 1.6, 1.0)
    if d.get("order") in ("best", "chronological"):
        out["order"] = d["order"]
    a = d.get("assign")
    if isinstance(a, list):
        idx = []
        for x in a[:max(n_shots, 1) * 2]:
            try:
                k = int(x) - 1
            except (TypeError, ValueError):
                k = -1
            idx.append(k if 0 <= k < n_clips else -1)
        if any(k >= 0 for k in idx):
            out["assign"] = idx
    notes = d.get("clip_notes")
    if isinstance(notes, list):
        out["clip_notes"] = [_text(x, 40) for x in notes[:n_clips]]
    return out


def apply_directive(settings: dict, d: dict, user_hook: str = "") -> dict:
    """Merge a directive into settings. The user's own typed hook always wins."""
    s = dict(settings)
    for k in ("pace", "zoom", "cut_sounds", "hook_sound", "caption_style", "caption_scale", "order", "assign"):
        if k in d:
            s[k] = d[k]
    if not user_hook and d.get("hook_text"):
        s["hook_text"] = d["hook_text"]
    return s


# ---------------------------------------------------------------- revisions
REVISE_SYSTEM = """You turn a user's plain-English change request for a short video edit into a JSON patch.
Reply with ONE JSON object only. Include only keys that should change:
{"hook_text": str, "caption_text": str (one phrase per line), "caption_style": "highlight"|"classic"|"off",
 "caption_scale_mult": 0.5-2, "pace_mult": 0.5-2 (<1 = faster cuts), "zoom": 0-2, "hook_sound": "none"|"impact"|"hit"|
 "riser"|"ding"|"whoosh"|"pop", "cut_sounds": "off"|"punch"|"all", "face_track": bool, "fit": "crop"|"blur",
 "order": "best"|"chronological", "reshuffle": true, "target_seconds": 5-60,
 "boost": {"<clip number>": -0.9..2 change in how much that clip is used},
 "reply": "one short sentence saying what you changed"}
If the request can't be done with these controls, return {"reply": "<what you can do instead>"}."""


def revise(text: str, settings: dict, n_clips: int, notes: Optional[list] = None):
    """(new_settings, what_changed, reply) from Claude, or None to fall back to the rule parser."""
    if not available():
        return None
    try:
        ctx = {k: settings.get(k) for k in ("hook_text", "caption_style", "pace", "zoom", "hook_sound", "cut_sounds",
                                             "face_track", "fit", "order", "target")}
        content = [{"type": "text", "text": f"Current settings: {json.dumps(ctx)}\nClips: {n_clips}"
                    + (f" ({json.dumps(notes)})" if notes else "") + f"\nRequest: {text[:600]}"}]
        patch = _json(_post(REVISE_SYSTEM, content, 700))
        if patch is None:
            return None
        new, done = apply_patch(settings, patch, n_clips)
        return new, done, _text(patch.get("reply"), 200)
    except Exception as e:
        print("ai.revise failed:", repr(e)[:200])
        return None


def apply_patch(settings: dict, p: dict, n_clips: int) -> tuple[dict, list[str]]:
    s = {**settings, "boost": dict(settings.get("boost") or {})}
    done: list[str] = []
    if "hook_text" in p:
        s["hook_text"] = _text(p["hook_text"], 120); done.append("Updated the hook")
    if "caption_text" in p:
        s["caption_text"] = re.sub(r"[{}\\]", "", str(p["caption_text"]))[:1500].strip()
        done.append("Rewrote the captions")
    if p.get("caption_style") in ("highlight", "classic", "off"):
        s["caption_style"] = p["caption_style"]; done.append(f"Captions: {p['caption_style']}")
    if "caption_scale_mult" in p:
        s["caption_scale"] = max(0.6, min(1.8, float(s.get("caption_scale", 1)) *
                                          _clamp(p["caption_scale_mult"], 0.5, 2, 1.0)))
        done.append("Resized captions")
    if "pace_mult" in p:
        s["pace"] = max(0.4, min(2.0, float(s.get("pace", 1)) * _clamp(p["pace_mult"], 0.5, 2, 1.0)))
        done.append("Faster cuts" if _clamp(p["pace_mult"], .5, 2, 1) < 1 else "Slower cuts")
    if "zoom" in p:
        s["zoom"] = _clamp(p["zoom"], 0, 2, 1.0); done.append("Changed the zoom")
    if p.get("hook_sound") in HOOK_SOUNDS:
        s["hook_sound"] = p["hook_sound"]; done.append(f"Hook sound: {p['hook_sound']}")
    if p.get("cut_sounds") in ("off", "punch", "all"):
        s["cut_sounds"] = p["cut_sounds"]; done.append(f"Cut sounds: {p['cut_sounds']}")
    if isinstance(p.get("face_track"), bool):
        s["face_track"] = p["face_track"]; done.append("Face tracking " + ("on" if p["face_track"] else "off"))
    if p.get("fit") in ("crop", "blur"):
        s["fit"] = p["fit"]; done.append("Framing: " + p["fit"])
    if p.get("order") in ("best", "chronological"):
        s["order"] = p["order"]; done.append("Shot order: " + p["order"])
    if p.get("reshuffle") is True:
        s["seed"] = int(s.get("seed", 1)) + 1; done.append("Picked different moments")
    if "target_seconds" in p:
        s["target"] = _clamp(p["target_seconds"], 5, 60, 20); done.append("Changed the length")
    if isinstance(p.get("boost"), dict):
        for k, v in p["boost"].items():
            try:
                i = int(k) - 1
            except (TypeError, ValueError):
                continue
            if 0 <= i < n_clips:
                cur = float(s["boost"].get(str(i), 0))
                s["boost"][str(i)] = max(-0.9, min(2.0, cur + _clamp(v, -0.9, 2.0, 0.0)))
                done.append(f"Clip {i + 1} {'more' if float(v) > 0 else 'less'}")
    if not done and p.get("reply"):
        return s, []
    return s, done
