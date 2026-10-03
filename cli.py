"""Headless runner:
   python -m app.cli --clips a.mp4 b.mp4 --out out.mp4 [--style viral] [--reference ref.mp4]
"""
import argparse
import json
import shutil
import tempfile
import time
from pathlib import Path

from . import engine, sfx


def main():
    ap = argparse.ArgumentParser(description="Turn your clips into a viral-style 9:16 video")
    ap.add_argument("--clips", required=True, nargs="+", type=Path)
    ap.add_argument("--out", required=True, type=Path)
    ap.add_argument("--reference", type=Path, help="optional: borrow this video's cut rhythm")
    ap.add_argument("--style", choices=list(engine.PRESETS), default="viral")
    ap.add_argument("--music", type=Path)
    ap.add_argument("--captions", default="", help="caption text, one phrase per line")
    ap.add_argument("--hook", default="")
    ap.add_argument("--hook-sound", default="impact", help="none|" + "|".join(sfx.BUILTIN))
    ap.add_argument("--cut-sounds", choices=["off", "punch", "all"], default="punch")
    ap.add_argument("--target", type=float)
    ap.add_argument("--zoom", type=float, default=1.0)
    ap.add_argument("--no-face-track", action="store_true")
    ap.add_argument("--watermark", default="")
    ap.add_argument("--audio", choices=["clip", "music", "both"], default="clip")
    ap.add_argument("--order", choices=["best", "chronological"], default="best")
    ap.add_argument("--fit", choices=["crop", "blur"], default="crop")
    ap.add_argument("--keep", action="store_true", help="keep the working directory")
    a = ap.parse_args()

    work = Path(tempfile.mkdtemp(prefix="recut_"))
    last, t0 = [""], time.time()

    def progress(stage, frac):
        key = stage.split(" (")[0]
        if key != last[0]:
            print(f"[{frac:4.0%}] {time.time() - t0:5.1f}s  {key}")
            last[0] = key

    try:
        analysis = engine.analyze(a.reference, a.clips, progress)
        print("faces seen in clips:", [c["face_frac"] for c in analysis["clips"]])
        settings = {"style": a.style, "target": a.target, "hook_text": a.hook, "caption_text": a.captions,
                    "audio_mode": a.audio, "order": a.order, "fit": a.fit, "zoom": a.zoom,
                    "face_track": not a.no_face_track, "hook_sound": a.hook_sound,
                    "cut_sounds": a.cut_sounds, "watermark": a.watermark}
        plan = engine.render(work, analysis, a.clips, a.music, settings, 1, progress)
        shutil.copy(work / plan["file"], a.out)
        print(json.dumps({k: v for k, v in plan.items() if k != "segments"}))
        print("shots:", [(s["clip"], s["dur"], s["effect"], "face" if s["face"] else "-") for s in plan["segments"]])
        print(f"wrote {a.out}")
    finally:
        if not a.keep:
            shutil.rmtree(work, ignore_errors=True)


if __name__ == "__main__":
    main()
