"""Recut web app: upload clips -> get a finished, viral-style 9:16 video. Accounts + paid plans."""
from __future__ import annotations

import json
import os
import re
import secrets
import shutil
import threading
import time
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path
from typing import List, Optional

from fastapi import FastAPI, File, Form, HTTPException, Request, Response, UploadFile
from fastapi.concurrency import run_in_threadpool
from fastapi.responses import FileResponse
from fastapi.staticfiles import StaticFiles

from . import ai, asr, billing, db, engine, sfx

APP_NAME = os.environ.get("RECUT_NAME", "ViralCut")
DATA = Path(os.environ.get("RECUT_DATA", "data")).resolve()
JOBS = DATA / "jobs"
JOBS.mkdir(parents=True, exist_ok=True)
db.init(DATA)
sfx.ensure()

RETENTION_HOURS = float(os.environ.get("RECUT_RETENTION_HOURS", "24"))
MAX_REF_MB = int(os.environ.get("RECUT_MAX_REF_MB", "200"))
MAX_CLIP_MB = int(os.environ.get("RECUT_MAX_CLIP_MB", "500"))
MAX_TOTAL_MB = int(os.environ.get("RECUT_MAX_TOTAL_MB", "1500"))
MAX_REF_SECONDS = 120
PUBLIC_URL = os.environ.get("PUBLIC_URL", "").rstrip("/")
SECURE_COOKIE = PUBLIC_URL.startswith("https")
VIDEO_EXT = {".mp4", ".mov", ".m4v", ".webm", ".mkv", ".avi"}
AUDIO_EXT = {".mp3", ".m4a", ".wav", ".aac", ".ogg"}
WATERMARK_TEXT = os.environ.get("RECUT_WATERMARK", f"Made with {APP_NAME}")
EMAIL_RE = re.compile(r"^[^@\s]{1,64}@[^@\s]+\.[^@\s]{2,}$")

app = FastAPI(title=APP_NAME)
pool = ThreadPoolExecutor(max_workers=int(os.environ.get("RECUT_WORKERS", "1")))
jobs: dict[str, dict] = {}
jobs_lock = threading.Lock()
_attempts: dict[str, list[float]] = {}
_attempts_lock = threading.Lock()


# ---------------------------------------------------------------- persistence
def _save(job: dict):
    d = JOBS / job["id"]
    tmp = d / "job.json.tmp"
    tmp.write_text(json.dumps(job))
    tmp.replace(d / "job.json")


def _load_all():
    for jf in JOBS.glob("*/job.json"):
        try:
            j = json.loads(jf.read_text())
        except Exception:
            continue
        if j.get("status") in ("queued", "running"):
            j["status"], j["message"] = "error", "The server restarted while this was running. Please try again."
        jobs[j["id"]] = j


def _cleanup_loop():
    while True:
        cutoff = time.time() - RETENTION_HOURS * 3600
        for d in JOBS.iterdir():
            try:
                if d.is_dir() and d.stat().st_mtime < cutoff:
                    with jobs_lock:
                        jobs.pop(d.name, None)
                    shutil.rmtree(d, ignore_errors=True)
            except OSError:
                pass
        time.sleep(600)


_load_all()
threading.Thread(target=_cleanup_loop, daemon=True).start()


# ----------------------------------------------------------------------- auth
def _throttle(key: str, limit: int, window: int):
    now = time.time()
    with _attempts_lock:
        hits = [t for t in _attempts.get(key, []) if now - t < window]
        if len(hits) >= limit:
            raise HTTPException(429, "Too many attempts. Please wait a few minutes and try again.")
        _attempts[key] = hits


def _record(key: str):
    with _attempts_lock:
        _attempts.setdefault(key, []).append(time.time())


def _ip(request: Request) -> str:
    return request.client.host if request.client else "?"


def current_user(request: Request):
    tok = request.cookies.get("rc_session")
    return db.session_user(tok) if tok else None


def require_user(request: Request):
    u = current_user(request)
    if not u:
        raise HTTPException(401, "Please sign in first.")
    return u


def _login_cookie(response: Response, user_id: int):
    response.set_cookie("rc_session", db.create_session(user_id), max_age=30 * 86400, httponly=True,
                        samesite="lax", secure=SECURE_COOKIE)


def account(u) -> dict:
    p = billing.PLANS.get(u["plan"], billing.PLANS["free"])
    return {"email": u["email"], "plan": u["plan"], "plan_label": p["label"], "edits_limit": p["edits"],
            "edits_used": db.used(u["id"]), "watermark": p["watermark"], "max_clips": p["max_clips"],
            "max_seconds": p["max_seconds"], "can_manage": bool(u["stripe_customer"])}


def _base_url(request: Request) -> str:
    return PUBLIC_URL or str(request.base_url).rstrip("/")


@app.post("/api/auth/signup")
async def signup(request: Request, response: Response):
    body = await request.json()
    email = str(body.get("email", "")).strip().lower()
    pw = str(body.get("password", ""))
    if not EMAIL_RE.match(email) or len(email) > 254:
        raise HTTPException(400, "Enter a valid email address.")
    if len(pw) < 8 or len(pw) > 200:
        raise HTTPException(400, "Use a password with at least 8 characters.")
    _throttle("signup:" + _ip(request), 10, 3600)
    _record("signup:" + _ip(request))
    try:
        uid = await run_in_threadpool(db.create_user, email, pw)
    except ValueError:
        raise HTTPException(409, "An account with that email already exists. Try signing in.")
    _login_cookie(response, uid)
    return account(db.get_user(uid))


@app.post("/api/auth/login")
async def login(request: Request, response: Response):
    body = await request.json()
    email = str(body.get("email", "")).strip().lower()
    pw = str(body.get("password", ""))
    key = f"login:{_ip(request)}:{email}"
    _throttle(key, 8, 600)
    u = db.get_user_by_email(email)
    ok = bool(u) and await run_in_threadpool(db.check_pw, pw, u["pw"])
    if not ok:
        _record(key)
        raise HTTPException(401, "Wrong email or password.")
    _login_cookie(response, u["id"])
    return account(u)


@app.post("/api/auth/logout")
def logout(request: Request, response: Response):
    tok = request.cookies.get("rc_session")
    if tok:
        db.delete_session(tok)
    response.delete_cookie("rc_session")
    return {"ok": True}


@app.get("/api/me")
def me(request: Request):
    u = current_user(request)
    return {"user": account(u) if u else None}


# -------------------------------------------------------------------- billing
@app.get("/api/config")
def config():
    return {"name": APP_NAME, "styles": [{"id": k, "label": v[0]} for k, v in engine.PRESETS.items()],
            "sounds": ["none"] + sfx.names(), "captions_from_speech": asr.available(),
            "billing": billing.enabled(), "ai": ai.available(), "plans": billing.public_plans(),
            "max_target": engine.MAX_TARGET, "retention_hours": RETENTION_HOURS}


@app.get("/api/sfx/{name:path}")
def sfx_preview(name: str):
    p = sfx.path(name)
    if not p:
        raise HTTPException(404, "No such sound.")
    return FileResponse(p)


@app.post("/api/billing/checkout")
async def checkout(request: Request):
    u = require_user(request)
    body = await request.json()
    try:
        url = await run_in_threadpool(billing.create_checkout, u, str(body.get("plan", "")), _base_url(request))
    except (RuntimeError, ValueError) as e:
        raise HTTPException(400, str(e))
    return {"url": url}


@app.post("/api/billing/portal")
async def portal(request: Request):
    u = require_user(request)
    try:
        url = await run_in_threadpool(billing.create_portal, u, _base_url(request))
    except RuntimeError as e:
        raise HTTPException(400, str(e))
    return {"url": url}


@app.post("/api/billing/webhook")
async def stripe_webhook(request: Request):
    payload = await request.body()
    try:
        result = await run_in_threadpool(billing.handle_webhook, payload, request.headers.get("stripe-signature", ""))
    except ValueError as e:
        raise HTTPException(400, str(e))
    return {"received": True, "result": result}


# -------------------------------------------------------------------- helpers
def _get_job(job_id: str, user) -> dict:
    j = jobs.get(job_id)
    if not j or j.get("uid") != user["id"]:
        raise HTTPException(404, "Job not found (it may have expired and been deleted).")
    return j


async def _store(up: UploadFile, dest: Path, limit_mb: int) -> int:
    size, limit = 0, limit_mb * 1024 * 1024
    with dest.open("wb") as f:
        while chunk := await up.read(1 << 20):
            size += len(chunk)
            if size > limit:
                f.close()
                dest.unlink(missing_ok=True)
                raise HTTPException(413, f"'{up.filename}' is over the {limit_mb} MB limit.")
            f.write(chunk)
    return size


def _public(j: dict) -> dict:
    keys = ["id", "status", "stage", "progress", "message", "versions", "analysis", "settings",
            "clip_names", "has_music", "created"]
    return {k: j.get(k) for k in keys}


def _set(j: dict, **kw):
    j.update(kw)
    try:
        _save(j)
    except OSError:
        pass


def _run_job(job_id: str):
    j = jobs[job_id]
    d = JOBS / job_id
    first_run = not j["versions"]
    clip_paths = [d / n for n in j["clip_files"]]
    music = d / j["music_file"] if j.get("music_file") else None

    def progress(stage: str, frac: float):
        j["stage"], j["progress"] = stage, round(frac, 3)

    try:
        _set(j, status="running", message="", stage="Starting", progress=0.01)
        u = db.get_user(j["uid"])
        plan = billing.PLANS.get(u["plan"] if u else "free", billing.PLANS["free"])
        af = d / "analysis.json"
        if af.exists():
            analysis = json.loads(af.read_text())
        else:
            ref = d / j["ref_file"] if j.get("ref_file") else None
            analysis = engine.analyze(ref, clip_paths, progress)
            if ref and ai.available():
                progress("AI is studying the reference", 0.31)
                words = asr.transcribe(ref) if asr.available() else None
                analysis["directive"] = ai.direct(ref, analysis["ref"], clip_paths, analysis["clips"], words)
                if analysis["directive"]:
                    j["settings"] = ai.apply_directive(j["settings"], analysis["directive"],
                                                       j["settings"].get("hook_text", ""))
            af.write_text(json.dumps(analysis))
        ref = analysis.get("ref")
        dr = analysis.get("directive") or {}
        j["analysis"] = {
            "reference": bool(ref), "ai": bool(dr), "summary": dr.get("summary", ""),
            "clip_notes": dr.get("clip_notes", []),
            "clips": [{"duration": c["duration"], "has_audio": c["has_audio"], "face_frac": c["face_frac"]}
                      for c in analysis["clips"]]}
        if ref:
            j["analysis"].update({"shots": len(ref["shots"]), "avg_shot": ref["avg_shot"], "pace": ref["pace"]})
        version = len(j["versions"]) + 1
        render_settings = {**j["settings"], "watermark": WATERMARK_TEXT if plan["watermark"] else ""}
        result = engine.render(d, analysis, clip_paths, music, render_settings, version, progress)
        j["versions"].append({
            "n": version, "file": result["file"], "created": time.time(), "note": j.pop("pending_note", "First edit"),
            "duration": result["duration"], "captions": result["captions"], "warnings": result["warnings"],
            "style": result["style"], "sfx": result["sfx"],
            "segments": [{"clip": s["clip"], "at": s["at"], "dur": s["dur"], "effect": s["effect"], "face": s["face"]}
                         for s in result["segments"]]})
        _set(j, status="done", stage="Done", progress=1.0)
    except engine.EngineError as e:
        _fail(j, first_run, str(e))
    except Exception as e:  # never leave a job spinning
        print("job failed", job_id, repr(e))
        _fail(j, first_run, f"Something went wrong while editing: {type(e).__name__}")


def _fail(j: dict, first_run: bool, msg: str):
    if first_run:
        db.add_usage(j["uid"], -1)          # failed edits are free
        msg += " (This edit didn't count against your plan.)"
    _set(j, status="error", message=msg)


# ------------------------------------------------------------------------ API
@app.post("/api/jobs")
async def create_job(
    request: Request,
    clips: List[UploadFile] = File(...),
    reference: Optional[UploadFile] = File(None),
    music: Optional[UploadFile] = File(None),
    style: str = Form("viral"),
    target_seconds: Optional[float] = Form(None),
    hook_text: str = Form(""),
    hook_sound: str = Form("impact"),
    cut_sounds: str = Form("punch"),
    face_track: str = Form("1"),
    caption_text: str = Form(""),
    caption_style: str = Form("highlight"),
    audio_mode: str = Form("clip"),
    fit: str = Form("crop"),
    order: str = Form("best"),
):
    user = require_user(request)
    plan = billing.PLANS.get(user["plan"], billing.PLANS["free"])
    if db.used(user["id"]) >= plan["edits"]:
        raise HTTPException(402, f"You've used all {plan['edits']} edits on the {plan['label']} plan this month. "
                                 f"Upgrade for more.")
    clips = [c for c in clips if c.filename]
    if not clips:
        raise HTTPException(400, "Add at least one clip.")
    if len(clips) > plan["max_clips"]:
        raise HTTPException(400, f"The {plan['label']} plan allows up to {plan['max_clips']} clips per edit.")
    if (caption_style not in ("highlight", "classic", "off") or audio_mode not in ("clip", "music", "both")
            or fit not in ("crop", "blur") or order not in ("best", "chronological")
            or style not in engine.PRESETS or cut_sounds not in ("off", "punch", "all")
            or hook_sound not in ["none"] + sfx.names()):
        raise HTTPException(400, "Invalid option.")
    if target_seconds is not None:
        target_seconds = max(5.0, min(float(target_seconds), float(plan["max_seconds"])))

    job_id = secrets.token_urlsafe(9).replace("-", "x").replace("_", "y")
    d = JOBS / job_id
    d.mkdir(parents=True)
    try:
        total = 0
        ref_file = None
        if reference is not None and reference.filename:
            rext = Path(reference.filename).suffix.lower()
            if rext not in VIDEO_EXT:
                raise HTTPException(400, "The reference must be a video file (mp4, mov, webm...).")
            ref_file = f"ref{rext}"
            total += await _store(reference, d / ref_file, MAX_REF_MB)
        clip_files, names = [], []
        for i, c in enumerate(clips):
            ext = Path(c.filename).suffix.lower()
            if ext not in VIDEO_EXT:
                raise HTTPException(400, f"'{c.filename}' isn't a video file.")
            fn = f"clip_{i:02d}{ext}"
            total += await _store(c, d / fn, MAX_CLIP_MB)
            if total > MAX_TOTAL_MB * 1024 * 1024:
                raise HTTPException(413, f"Uploads are over the {MAX_TOTAL_MB} MB total limit.")
            clip_files.append(fn)
            names.append(c.filename[:80])
        music_file = None
        if music is not None and music.filename:
            mext = Path(music.filename).suffix.lower()
            if mext not in AUDIO_EXT | VIDEO_EXT:
                raise HTTPException(400, "Music must be an audio file (mp3, m4a, wav...).")
            music_file = f"music{mext}"
            await _store(music, d / music_file, 100)

        def check():  # fail fast with a friendly message
            if ref_file:
                r = engine.probe(d / ref_file)
                if r["duration"] > MAX_REF_SECONDS:
                    raise engine.EngineError(f"The reference is {r['duration']:.0f}s; keep it under {MAX_REF_SECONDS}s.")
            for fn, nm in zip(clip_files, names):
                try:
                    engine.probe(d / fn)
                except engine.EngineError:
                    raise engine.EngineError(f"Couldn't read '{nm}'. Is it a valid video?")
            if music_file:
                engine._run(["ffprobe", "-v", "error", "-show_streams", str(d / music_file)])
        try:
            await run_in_threadpool(check)
        except engine.EngineError as e:
            raise HTTPException(400, str(e))
    except HTTPException:
        shutil.rmtree(d, ignore_errors=True)
        raise

    settings = {**engine.DEFAULTS, "style": style, "target": target_seconds, "hook_text": hook_text.strip()[:120],
                "hook_sound": hook_sound, "cut_sounds": cut_sounds, "face_track": face_track != "0",
                "caption_text": caption_text.strip()[:1500], "caption_style": caption_style,
                "audio_mode": audio_mode if music_file else "clip", "fit": fit, "order": order}
    j = {"id": job_id, "uid": user["id"], "status": "queued", "stage": "Queued", "progress": 0.0, "message": "",
         "created": time.time(), "versions": [], "settings": settings, "clip_names": names,
         "clip_files": clip_files, "ref_file": ref_file, "music_file": music_file,
         "has_music": bool(music_file), "analysis": None}
    with jobs_lock:
        jobs[job_id] = j
    _set(j)
    db.add_usage(user["id"], 1)
    pool.submit(_run_job, job_id)
    return {"id": job_id}


@app.get("/api/jobs/{job_id}")
def job_status(job_id: str, request: Request):
    return _public(_get_job(job_id, require_user(request)))


@app.post("/api/jobs/{job_id}/revise")
async def revise(job_id: str, request: Request):
    j = _get_job(job_id, require_user(request))
    if j["status"] in ("queued", "running"):
        raise HTTPException(409, "Still working on the last change.")
    body = await request.json()
    text = str(body.get("instruction", "")).strip()[:600]
    if not text:
        raise HTTPException(400, "Tell me what to change.")
    notes = (j.get("analysis") or {}).get("clip_notes")
    r = await run_in_threadpool(ai.revise, text, j["settings"], len(j["clip_files"]), notes)
    if r is not None:
        new, done, reply = r
        if not done:
            return {"applied": [], "message": reply or "I couldn't turn that into an edit. Try describing it differently."}
    else:
        new, done = engine.parse_revision(text, j["settings"], len(j["clip_files"]))
    if not done:
        return {"applied": [], "message": (
            "I couldn't match that to an edit. Try: faster cuts, bigger captions, more zoom, shuffle the moments, "
            "use clip 2 more, make it hype, hook sound: riser, no sound effects, no face tracking, "
            "hook: Your new hook, or caption text: your words (one phrase per line).")}
    if new.get("audio_mode") != "clip" and not j.get("music_file"):
        new["audio_mode"] = "clip"
    j["settings"] = new
    j["pending_note"] = "; ".join(done)
    _set(j, status="queued", stage="Queued", progress=0.0, message="")
    pool.submit(_run_job, job_id)
    return {"applied": done}


@app.get("/api/jobs/{job_id}/video/{n}")
def video(job_id: str, n: int, request: Request, download: int = 0):
    j = _get_job(job_id, require_user(request))
    v = next((v for v in j["versions"] if v["n"] == n), None)
    f = JOBS / job_id / v["file"] if v else None
    if not f or not f.exists():
        raise HTTPException(404, "That version isn't available.")
    return FileResponse(f, media_type="video/mp4",
                        filename=f"{APP_NAME.lower()}-edit-v{n}.mp4" if download else None,
                        content_disposition_type="attachment" if download else "inline")


@app.delete("/api/jobs/{job_id}")
def delete_job(job_id: str, request: Request):
    j = _get_job(job_id, require_user(request))
    if j["status"] in ("queued", "running"):
        raise HTTPException(409, "Wait for it to finish first.")
    with jobs_lock:
        jobs.pop(job_id, None)
    shutil.rmtree(JOBS / job_id, ignore_errors=True)
    return {"deleted": True}


app.mount("/", StaticFiles(directory=Path(__file__).parent / "static", html=True), name="static")
