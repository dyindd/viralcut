#!/usr/bin/env python3
"""Upload the game's images to Roblox with the Open Cloud Assets API and write the asset IDs into
src/shared/Icons.lua. Run it on your own computer (it needs your API key).

ONE-TIME SETUP
  1. https://create.roblox.com/dashboard/credentials  ->  Create API Key
  2. Name it, add the "Assets API" with Read + Write (Create/Update) permissions
  3. Accepted IPs: add your IP, or 0.0.0.0/0 while testing. Save and copy the key.
  4. Find your user id (the number in your profile URL) or your group id.

RUN
  pip install requests
  set ROBLOX_API_KEY=...      (Windows)     /   export ROBLOX_API_KEY=...   (Mac/Linux)
  python3 tools/upload_to_roblox.py --user 123456789
  python3 tools/upload_to_roblox.py --group 987654    (if the game is owned by a group)

It uploads assets/images/*.png and assets/textures/*.png as Image assets, remembers finished uploads in
assets/upload_cache.json (safe to re-run), then fills the matching ids into src/shared/Icons.lua.
New uploads can take a minute to pass moderation before they render in Studio.
"""
import argparse, json, os, re, sys, time

try:
    import requests
except ImportError:
    sys.exit("pip install requests")

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
API = "https://apis.roblox.com/assets/v1/"
CACHE = os.path.join(ROOT, "assets", "upload_cache.json")
ICONS = os.path.join(ROOT, "src", "shared", "Icons.lua")
PREFIX_TO_SECTION = {"ui_": "UI", "cur_": "Currency", "box_": "Boxes", "trap_": "Traps", "mut_": "Mutations",
                     "pass_": "Passes", "prod_": "Products", "present_": "Presents", "wrapping_": "Textures"}

ap = argparse.ArgumentParser()
ap.add_argument("--user", help="your user id (asset owner)")
ap.add_argument("--group", help="group id (asset owner) instead of --user")
ap.add_argument("--dry-run", action="store_true", help="list what would be uploaded")
ap.add_argument("--only", help="substring filter, e.g. present_")
ap.add_argument("--decal", action="store_true", help="upload as Decal instead of Image (fallback if Image is rejected)")
a = ap.parse_args()
key = os.environ.get("ROBLOX_API_KEY")
if not a.dry_run and not key:
    sys.exit("set ROBLOX_API_KEY first (see the top of this file)")
if not a.dry_run and not (a.user or a.group):
    sys.exit("pass --user <id> or --group <id>")
creator = {"userId": str(a.user)} if a.user else {"groupId": str(a.group)}

cache = json.load(open(CACHE)) if os.path.exists(CACHE) else {}

def upload(path, name):
    req = {"assetType": "Decal" if a.decal else "Image", "displayName": name[:50], "description": "Steal a Present",
           "creationContext": {"creator": creator}}
    for attempt in range(6):
        with open(path, "rb") as f:
            r = requests.post(API + "assets", headers={"x-api-key": key},
                              files={"request": (None, json.dumps(req), "application/json"),
                                     "fileContent": (os.path.basename(path), f, "image/png")})
        if r.status_code == 429:
            wait = 15 * (attempt + 1)
            print(f"  rate limited, waiting {wait}s")
            time.sleep(wait)
            continue
        if r.status_code >= 400:
            raise RuntimeError(f"{r.status_code} {r.text[:300]}")
        op = r.json()
        op_path = op.get("path") or ("operations/" + op["operationId"])
        for _ in range(90):
            time.sleep(2)
            o = requests.get(API + op_path, headers={"x-api-key": key}).json()
            if o.get("done"):
                if "error" in o:
                    raise RuntimeError(str(o["error"])[:300])
                return o["response"]["assetId"]
        raise RuntimeError("operation timed out")
    raise RuntimeError("too many rate-limit retries")

files = []
for sub in ("images", "textures"):
    d = os.path.join(ROOT, "assets", sub)
    if os.path.isdir(d):
        for fn in sorted(os.listdir(d)):
            if fn.endswith(".png") and (not a.only or a.only in fn):
                files.append((fn[:-4], os.path.join(d, fn)))
print(f"{len(files)} files, {sum(1 for n, _ in files if n in cache)} already uploaded")
if a.dry_run:
    for n, p in files:
        print(("  cached " + cache[n] + "  ") if n in cache else "  upload ", n)
    sys.exit(0)

failed = []
for i, (name, path) in enumerate(files, 1):
    if name in cache:
        continue
    try:
        asset_id = upload(path, name)
        cache[name] = str(asset_id)
        json.dump(cache, open(CACHE, "w"), indent=1)
        print(f"[{i}/{len(files)}] {name} -> {asset_id}")
    except Exception as e:
        failed.append((name, str(e)))
        print(f"[{i}/{len(files)}] {name} FAILED: {e}")
    time.sleep(1.2)  # stay under the per-minute limit

# write Icons.lua
src = open(ICONS, encoding="utf-8").read()
written = 0
for name, asset_id in cache.items():
    for prefix, section in PREFIX_TO_SECTION.items():
        if name.startswith(prefix):
            keyname = name[len(prefix):]
            block = re.search(r"(Icons\.%s = \{)(.*?)(\n\})" % section, src, re.S)
            if not block:
                break
            body, n = re.subn(r"(\n\t%s = )\d+," % re.escape(keyname), r"\g<1>%s," % asset_id, block.group(2))
            if n:
                src = src[:block.start(2)] + body + src[block.end(2):]
                written += 1
            break
open(ICONS, "w", encoding="utf-8").write(src)
print(f"wrote {written} ids into src/shared/Icons.lua")
if failed:
    print("FAILED:", failed)
    print("Tip: if Roblox rejects assetType Image for your account, re-run with --decal and paste the decal ids into an ImageLabel in Studio once so they convert.")
