#!/usr/bin/env python3
"""Cut a ChatGPT grid image into equal tiles and name them.
Usage: python3 tools/slice_grid.py grid.png ui_rewards ui_rebirth ui_gift ...   (names in grid order, left-right then top-bottom)
Options: --cols 3 --rows 3 (default: square root of the number of names) --out icons/ --trim (auto-crop transparent margins)
Needs: pip install pillow
"""
import argparse, math, os
from PIL import Image

ap = argparse.ArgumentParser()
ap.add_argument("image")
ap.add_argument("names", nargs="+")
ap.add_argument("--cols", type=int)
ap.add_argument("--rows", type=int)
ap.add_argument("--out", default="icons")
ap.add_argument("--trim", action="store_true", help="auto-crop transparent margins and re-center on a square canvas")
a = ap.parse_args()

img = Image.open(a.image).convert("RGBA")
n = len(a.names)
cols = a.cols or math.ceil(math.sqrt(n))
rows = a.rows or math.ceil(n / cols)
w, h = img.size
tw, th = w // cols, h // rows
os.makedirs(a.out, exist_ok=True)
for i, name in enumerate(a.names):
    c, r = i % cols, i // cols
    tile = img.crop((c * tw, r * th, (c + 1) * tw, (r + 1) * th))
    if a.trim:
        bbox = tile.getbbox()
        if bbox:
            tile = tile.crop(bbox)
            side = max(tile.size)
            canvas = Image.new("RGBA", (side, side), (0, 0, 0, 0))
            canvas.paste(tile, ((side - tile.width) // 2, (side - tile.height) // 2))
            tile = canvas
    tile = tile.resize((512, 512), Image.LANCZOS)
    path = os.path.join(a.out, name if name.endswith(".png") else name + ".png")
    tile.save(path)
    print("wrote", path)
