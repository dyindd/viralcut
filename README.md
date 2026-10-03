# ViralCut

A paid web app. Users upload a **reference video** (a TikTok/Reel/Short whose editing they like) and their **raw clips**; the AI recreates the reference's structure with their footage. They get back a viral-style 9:16 video — cut to a proven rhythm, with an on-screen hook, a hook sound, word-by-word captions, whooshes on cuts, punch-in zooms, and **face tracking** that keeps the speaker centered when landscape footage is cropped to vertical.

Accounts, monthly plans (Free / Starter / Pro) and Stripe subscriptions are built in.

## Run it locally

```bash
./run.sh            # needs Python 3.10+ and FFmpeg
# open http://localhost:8000  → create an account → drop in clips
```

Headless: `python -m app.cli --clips a.mp4 b.mp4 --out edit.mp4 --style hype --hook "Your hook" --captions "line one"`

## Turn on payments (Stripe)

1. In Stripe (start in **test mode**) create two recurring monthly prices — Starter ($19.99) and Pro ($39.99) — or whatever you want. Plan names, prices shown, edit limits, clip limits and watermark rules live in `PLANS` in `app/billing.py`; keep them in sync with your Stripe prices.
2. Set environment variables:
   ```
   STRIPE_SECRET_KEY=sk_test_...
   STRIPE_PRICE_STARTER=price_...
   STRIPE_PRICE_PRO=price_...
   STRIPE_WEBHOOK_SECRET=whsec_...
   PUBLIC_URL=https://yourdomain.com
   ```
3. Add a webhook endpoint `https://yourdomain.com/api/billing/webhook` for: `checkout.session.completed`, `customer.subscription.created`, `customer.subscription.updated`, `customer.subscription.deleted`.
4. Enable the Stripe **Customer portal** (Settings → Billing) so "Manage billing" works.
5. Do a test-mode purchase with card 4242 4242 4242 4242 before going live.

Without these the site works; the upgrade buttons just say payments aren't switched on.

## The AI layer (Claude)

Set `ANTHROPIC_API_KEY` (optional `RECUT_AI_MODEL`, default `claude-sonnet-5-5`). Then:
- **On each new edit** Claude looks at frames from the reference and from every clip (and the reference transcript if speech captions are on) and returns a small validated directive: a hook line, pace, zoom energy, hook/cut sounds, caption style, shot order, which clip suits which reference shot, and a one-line note per clip. FFmpeg still does all the rendering.
- **Revisions** ("make it feel more chaotic", "use the beach clip more, hook: stop scrolling") are turned into a bounded settings patch by Claude. Every value is clamped/whitelisted; anything unexpected is dropped.
- Cost is roughly a few cents per edit (about 20 small images). No key, or any API failure → the app silently falls back to the reference's cut timing plus the keyword revision rules. Tested against a local mock of the API; **not yet run against the real Anthropic API.**

## Speech captions (auto-captions from what people say)

Typed captions always work. For automatic speech captions set `OPENAI_API_KEY` (about $0.006 per audio minute, no GPU, no model download) — `RECUT_ASR_URL` / `RECUT_ASR_MODEL` let you point at any OpenAI-compatible transcription endpoint — or `pip install faster-whisper` to run locally.

## Hosting

This needs a real server that can run FFmpeg for tens of seconds per video — it will **not** run on Netlify/Vercel functions. Use the Dockerfile on a VPS or container host (Hetzner, DigitalOcean, Fly.io, Railway, Render):

```bash
docker build -t recut . && docker run -p 8000:8000 -v recut-data:/data --env-file .env recut
```
Put it behind HTTPS (Caddy/nginx/the host's proxy; raise the proxy's upload size limit to match your clip limits), mount a persistent volume at `/data`, and set `PUBLIC_URL`. Start with 4 vCPUs; `RECUT_WORKERS` controls how many videos render at once. A 10 s video took ~35 s on a 2-core sandbox.

## How it works

1. **Read each clip** at 2 fps: motion/contrast score, near-black frames penalized, and face positions (OpenCV).
2. **Plan** — the chosen style (viral / hype / story / clean) or an optional reference video sets shot lengths and hook length; the best-scoring moments of your clips fill them, preferring moments with a visible face, varied across clips.
3. **Render** — each shot is cropped to 9:16 following the face (smoothed path), with punch-ins centered on the face; shots are joined, then captions, hook, sound effects and loudness are applied in one final pass.
4. **Revise in plain English** — "faster cuts", "make it hype", "hook sound: riser", "no face tracking", "use clip 2 more", "hook: …". Shots are cached so revisions are quick.

Sound effects (impact, hit, riser, ding, pop, whoosh) are synthesized by FFmpeg, so there is nothing to license. Drop your own files into `app/sfx/custom/` to add more (only files you have rights to).

## Settings

| Variable | Default | Meaning |
|---|---|---|
| `RECUT_DATA` | `./data` | Database + job files |
| `RECUT_RETENTION_HOURS` | 24 | Uploads/renders auto-deleted after this |
| `RECUT_WORKERS` / `RECUT_SEG_WORKERS` | 1 / cores÷2 | Parallel videos / parallel shots per video |
| `RECUT_MAX_CLIP_MB` / `_MAX_TOTAL_MB` / `_MAX_REF_MB` | 500 / 1500 / 200 | Upload limits |
| `RECUT_NAME`, `RECUT_WATERMARK` | ViralCut, "Made with Recut" | Branding / free-plan watermark text |
| `RECUT_FONT`, `RECUT_FONTS_DIR` | DejaVu Sans | Caption font (macOS: set to an installed font) |
| `RECUT_YUNET` | unset | Path to OpenCV's YuNet face model for better face detection |

## What was tested

`PYTHONPATH=. pytest -q tests/test_app.py` (21 tests, ~140 s; run `tests/make_samples.sh` first). Covers: signup/login validation, hashed passwords, brute-force throttling, access control between users, a real end-to-end render (1080×1920, face-tracked shots, sound effects, captions, hook), free-plan watermark disappearing after an upgrade, usage counting (revisions free), plan-limit 402s and clip caps, failed edits refunded, range/download, Stripe webhooks (valid, forged, stale, replayed, past-due, canceled), checkout-session construction, speech-caption flow against a local mock of the transcription API, and a path-traversal regression test (verified to fail when the fix is removed).

Face tracking was verified by detecting the face in the *output*: on a clip where a person slides across a 16:9 frame, a plain center crop kept them in view in 7 of 15 samples; the tracked crop kept them in view in 15 of 15.

## Not built / known limits — read before launching

- **Stripe checkout was never run against real Stripe** (no keys here). Webhook signature checking and plan changes are tested with locally signed events; session creation is tested against a fake. Do a test-mode purchase end to end.
- **The OpenAI transcription call was never run against the real service** — only against a local mock that checks the request format and parses the response. Speech captions in your first real test may need small fixes.
- **Face detection is OpenCV's Haar detector**: good for front-facing speakers in decent light; weaker for profiles, small faces, heavy shadow. When it finds no face, the crop falls back to centered. Setting `RECUT_YUNET` (a download from OpenCV's model zoo) is a significant upgrade.
- **No email verification, password reset, admin dashboard, or terms/privacy pages.** You need Terms, Privacy and a content/DMCA policy before taking payments.
- Hard cuts only; zoom is a static punch-in; cuts aren't snapped to a music beat.
- "Best moment" selection is a motion/contrast/face heuristic, not an understanding of what's being said. "Keep my clips in order" is better for talking-head content.
- Without `ANTHROPIC_API_KEY`, revisions are keyword rules; unrecognized requests get a list of what works.
- No timeline editor yet: changes are made by typing what you want (plus version history).
- Single-server design (in-memory job table + SQLite + local disk). Fine for launch; use a queue and object storage to scale out.
- Only add music you have rights to use. The built-in sounds are synthesized; trending TikTok/Instagram audio should be added in-app when posting.
