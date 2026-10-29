#!/usr/bin/env python3
"""Normalize generated art into the repo's assets/ layout.
Usage: python3 tools/prepare_images.py <raw_folder> assets
  icons   -> assets/images/<name>.png   512x512, alpha-trimmed, centered with a 5% margin
  game_icon*.png -> assets/marketing/   512x512
  thumbnail_*.png -> assets/marketing/  1920x1080
  wrapping_*.png -> assets/textures/    1024x1024
Needs: pip install pillow
"""
import os, sys
from PIL import Image

raw, out = sys.argv[1], sys.argv[2]
ICON, MARGIN = 512, 0.05
files = {}
for dp, _, fns in os.walk(raw):
    for fn in fns:
        if fn.lower().endswith(".png"):
            files[fn[:-4]] = os.path.join(dp, fn)

def icon(im):
    im = im.convert("RGBA")
    bbox = im.getchannel("A").getbbox() or (0, 0, im.width, im.height)
    im = im.crop(bbox)
    side = max(im.size)
    pad = int(side * MARGIN)
    canvas = Image.new("RGBA", (side + 2 * pad, side + 2 * pad), (0, 0, 0, 0))
    canvas.paste(im, (pad + (side - im.width) // 2, pad + (side - im.height) // 2), im)
    return canvas.resize((ICON, ICON), Image.LANCZOS)

counts = {"images": 0, "marketing": 0, "textures": 0}
for stem in sorted(files):
    im = Image.open(files[stem])
    if stem.startswith("thumbnail"):
        sub, result = "marketing", im.convert("RGB").resize((1920, 1080), Image.LANCZOS)
    elif stem.startswith("game_icon"):
        sub, result = "marketing", im.convert("RGB").resize((512, 512), Image.LANCZOS)
    elif stem.startswith("wrapping_"):
        sub, result = "textures", im.convert("RGB").resize((1024, 1024), Image.LANCZOS)
    else:
        sub, result = "images", icon(im)
    os.makedirs(os.path.join(out, sub), exist_ok=True)
    result.save(os.path.join(out, sub, stem + ".png"), optimize=True)
    counts[sub] += 1
print(counts)
