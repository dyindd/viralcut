"""Built-in sound effects, synthesized with FFmpeg (so there is nothing to license).

Drop your own .wav/.mp3 files into app/sfx/custom/ and they show up as extra hook sounds
(named custom:<filename>). Only add sounds you have the rights to use.
"""
from __future__ import annotations

import subprocess
from pathlib import Path
from typing import Optional

DIR = Path(__file__).parent / "sfx"
CUSTOM = DIR / "custom"

# name: (lavfi source, extra audio filter)
SPECS = {
    "impact": ("aevalsrc=exprs='(sin(2*PI*55*t*(1+0.6*exp(-12*t)))*exp(-5*t)*0.95+(random(0)*2-1)*exp(-40*t)*0.35)':d=1.2:s=44100",
               "lowpass=f=9000"),
    "hit":    ("aevalsrc=exprs='((random(0)*2-1)*exp(-18*t)*0.8+sin(2*PI*180*t)*exp(-25*t)*0.5)':d=0.4:s=44100",
               "highpass=f=120"),
    "riser":  ("aevalsrc=exprs='(sin(2*PI*(180*t+260*t*t))*0.5+(random(0)*2-1)*0.15)*(t/1.5)':d=1.5:s=44100",
               "lowpass=f=12000"),
    "ding":   ("aevalsrc=exprs='(sin(2*PI*1319*t)+0.4*sin(2*PI*2638*t))*exp(-6*t)*0.5':d=0.9:s=44100", "anull"),
    "pop":    ("aevalsrc=exprs='sin(2*PI*900*t)*exp(-40*t)*0.8':d=0.15:s=44100", "anull"),
    "whoosh": ("anoisesrc=d=0.6:c=pink:r=44100:a=0.9",
               "volume='pow(sin(PI*t/0.6),2)':eval=frame,highpass=f=350,lowpass=f=6500"),
}
BUILTIN = list(SPECS)


def ensure() -> None:
    """Generate any missing built-in sound (a second or two, once)."""
    DIR.mkdir(exist_ok=True)
    CUSTOM.mkdir(exist_ok=True)
    for name, (src, af) in SPECS.items():
        out = DIR / f"{name}.wav"
        if out.exists():
            continue
        subprocess.run(["ffmpeg", "-y", "-v", "error", "-f", "lavfi", "-i", src, "-af", af,
                        "-ac", "2", "-ar", "44100", str(out)], check=True, capture_output=True)


def names() -> list[str]:
    ensure()
    custom = sorted(f"custom:{p.stem}" for p in CUSTOM.glob("*") if p.suffix.lower() in (".wav", ".mp3", ".m4a", ".ogg"))
    return BUILTIN + custom


def path(name: str) -> Optional[Path]:
    ensure()
    if name.startswith("custom:"):
        stem = name.split(":", 1)[1]
        for p in CUSTOM.glob("*"):
            if p.stem == stem and p.suffix.lower() in (".wav", ".mp3", ".m4a", ".ogg"):
                return p
        return None
    if name not in BUILTIN:          # never build a path from arbitrary input
        return None
    p = DIR / f"{name}.wav"
    return p if p.exists() else None


def plan_events(segs: list[dict], hook_sound: str, cut_sounds: str) -> list[tuple[str, float, float]]:
    """(sound name, time in seconds, volume) for the hook and for cuts."""
    ev: list[tuple[str, float, float]] = []
    if hook_sound and hook_sound != "none":
        ev.append((hook_sound, 0.0, 0.9))
    if cut_sounds != "off":
        last = -9.0
        for i, sg in enumerate(segs):
            if i == 0 or (cut_sounds == "punch" and sg["effect"] == "none"):
                continue
            t = max(0.0, sg["at"] - 0.06)
            if t - last < 0.45:
                continue
            ev.append(("whoosh", t, 0.5))
            last = t
    return ev
