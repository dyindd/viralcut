"""Face detection + smooth crop paths for 9:16 auto-reframing.

Default detector is OpenCV's bundled Haar cascade (no model download, CPU only).
For better accuracy drop OpenCV's YuNet model (face_detection_yunet_*.onnx) anywhere and set
RECUT_YUNET=/path/to/model.onnx - it is picked up automatically.
"""
from __future__ import annotations

import math
import os
import threading
from typing import Optional

import cv2
import numpy as np

_tls = threading.local()


def _detector():
    d = getattr(_tls, "det", None)
    if d is not None:
        return d
    model = os.environ.get("RECUT_YUNET")
    if model and os.path.exists(model) and hasattr(cv2, "FaceDetectorYN"):
        d = ("yunet", cv2.FaceDetectorYN.create(model, "", (320, 320), 0.6, 0.3, 5000))
    else:
        d = ("haar", cv2.CascadeClassifier(cv2.data.haarcascades + "haarcascade_frontalface_default.xml"))
    _tls.det = d
    return d


def detect_largest(gray: np.ndarray) -> Optional[list]:
    """Largest face in a grayscale frame -> [cx, cy, width] normalised to 0..1, or None."""
    kind, det = _detector()
    h, w = gray.shape[:2]
    if kind == "yunet":
        det.setInputSize((w, h))
        _, res = det.detect(cv2.cvtColor(gray, cv2.COLOR_GRAY2BGR))
        if res is None or len(res) == 0:
            return None
        x, y, fw, fh = res[int(np.argmax(res[:, 2] * res[:, 3]))][:4]
    else:
        rects = det.detectMultiScale(cv2.equalizeHist(gray), scaleFactor=1.1, minNeighbors=6,
                                     minSize=(max(24, int(w * 0.05)),) * 2)
        if len(rects) == 0:
            return None
        x, y, fw, fh = max(rects, key=lambda r: r[2] * r[3])
    return [float((x + fw / 2) / w), float((y + fh / 2) / h), float(fw / w)]


def face_path(samples: list, t0: float, dur: float, step: float = 0.5) -> Optional[dict]:
    """Smoothed face centre keyframes for the shot [t0, t0+dur] of a clip.

    samples[i] is the face at clip time i*step (or None). Returns None when the face is visible
    in too little of the shot - the caller then falls back to a centred crop.
    """
    n = len(samples)
    if n == 0:
        return None
    i0 = max(0, int(math.floor(t0 / step)) - 2)
    i1 = min(n - 1, int(math.ceil((t0 + dur) / step)) + 2)
    pts = [(i * step, samples[i][0], samples[i][1]) for i in range(i0, i1 + 1) if samples[i] is not None]
    inside = [p for p in pts if t0 - 1e-6 <= p[0] <= t0 + dur + 1e-6]
    if len(inside) < max(1.0, 0.35 * max(1, int(dur / step))):
        return None
    ts = np.array([p[0] for p in pts])
    cx = np.array([p[1] for p in pts])
    cy = np.array([p[2] for p in pts])
    grid = np.arange(0.0, dur + 1e-6, step)
    if grid[-1] < dur - 1e-6:
        grid = np.append(grid, dur)
    gx = np.interp(grid + t0, ts, cx)
    gy = np.interp(grid + t0, ts, cy)

    def smooth(a):
        if len(a) < 3:
            return a
        k = np.convolve(a, [0.25, 0.5, 0.25], mode="same")
        k[0], k[-1] = a[0], a[-1]
        return k

    gx, gy = smooth(gx), smooth(gy)
    if gx.max() - gx.min() < 0.04:      # tiny drift looks like jitter: hold still
        gx[:] = gx.mean()
    if gy.max() - gy.min() < 0.04:
        gy[:] = gy.mean()
    return {"cx": [[round(float(t), 3), round(float(v), 4)] for t, v in zip(grid, gx)],
            "cy": [[round(float(t), 3), round(float(v), 4)] for t, v in zip(grid, gy)]}


def pw_expr(keys) -> str:
    """Piecewise-linear ffmpeg expression in t through [(t, value), ...]."""
    keys = [(float(t), float(v)) for t, v in keys]
    if len(keys) == 1 or all(abs(v - keys[0][1]) < 0.5 for _, v in keys):
        return f"{keys[0][1]:.1f}"
    expr = f"{keys[-1][1]:.1f}"
    for (t0, v0), (t1, v1) in reversed(list(zip(keys, keys[1:]))):
        if t1 - t0 < 1e-6:
            continue
        slope = (v1 - v0) / (t1 - t0)
        expr = f"if(lt(t,{t1:.3f}),{v0:.1f}+({slope:.3f})*(t-{t0:.3f}),{expr})"
    return expr
